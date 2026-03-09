#!/usr/bin/env bash
# Eval harness for agent-swift standalone CLI.
# Usage: bash loops/agent-swift/eval.sh
# DO NOT MODIFY THIS FILE.

set -uo pipefail
cd "$(dirname "$0")/../.."

AGENT_SWIFT_DIR="loops/agent-swift/agent-swift"
BINARY_PATH="$AGENT_SWIFT_DIR/.build/debug/agent-swift"

echo "---"

json_check() {
  local file="$1"
  local mode="$2"

  python3 - "$file" "$mode" <<'PY'
import json
import sys
from pathlib import Path

file = Path(sys.argv[1])
mode = sys.argv[2]

try:
    raw = file.read_text(encoding="utf-8").strip()
except Exception:
    sys.exit(1)

if not raw:
    sys.exit(1)

try:
    parsed = json.loads(raw)
except Exception:
    sys.exit(1)

core_commands = {"doctor", "connect", "disconnect", "status", "snapshot", "press"}
full_commands = {
    "doctor", "connect", "disconnect", "snapshot", "press", "fill",
    "get", "find", "wait", "is", "screenshot", "schema"
}

if mode == "json":
    sys.exit(0)

if mode == "array":
    sys.exit(0 if isinstance(parsed, list) else 1)

if mode == "object":
    sys.exit(0 if isinstance(parsed, dict) else 1)

if mode == "schema-core":
    if not isinstance(parsed, list):
        sys.exit(1)
    names = {
        entry.get("name")
        for entry in parsed
        if isinstance(entry, dict) and isinstance(entry.get("name"), str)
    }
    sys.exit(0 if core_commands.issubset(names) else 1)

if mode == "schema-full":
    if not isinstance(parsed, list):
        sys.exit(1)
    names = {
        entry.get("name")
        for entry in parsed
        if isinstance(entry, dict) and isinstance(entry.get("name"), str)
    }
    sys.exit(0 if full_commands.issubset(names) else 1)

if mode == "schema-press":
    if not isinstance(parsed, dict):
        sys.exit(1)
    if parsed.get("name") != "press":
        sys.exit(1)
    if not isinstance(parsed.get("description"), str) or not parsed.get("description"):
        sys.exit(1)
    if not isinstance(parsed.get("args"), list):
        sys.exit(1)
    if not isinstance(parsed.get("flags"), list):
        sys.exit(1)
    exit_codes = parsed.get("exitCodes")
    if not isinstance(exit_codes, dict):
        sys.exit(1)
    sys.exit(0)

sys.exit(1)
PY
}

command_exists_in_help() {
  local cmd="$1"
  grep -qiE "(^|[[:space:]])${cmd}([[:space:]]|$)" /tmp/as-eval-help.log 2>/dev/null
}

in_exit_contract() {
  local code="$1"
  if [ "$code" -eq 0 ] || [ "$code" -eq 1 ] || [ "$code" -eq 2 ]; then
    return 0
  fi
  return 1
}

# Detect phase via loop sentinels
PHASE=1
if [ -f "loops/agent-swift/program-phase2.md" ]; then
  PHASE=2
fi
if [ -f "loops/agent-swift/program-phase3.md" ]; then
  PHASE=3
fi
echo "phase:            $PHASE"

# Step 1: Build check
BUILD_STATUS="no_package"
if [ -f "$AGENT_SWIFT_DIR/Package.swift" ]; then
  if (cd "$AGENT_SWIFT_DIR" && swift build > /tmp/as-eval-build.log 2>&1); then
    BUILD_STATUS="pass"
  else
    BUILD_STATUS="fail"
  fi
fi
echo "build:            $BUILD_STATUS"

# Step 2: Tests
TEST_STATUS="no_package"
TEST_COUNT="0"
if [ -f "$AGENT_SWIFT_DIR/Package.swift" ]; then
  if (cd "$AGENT_SWIFT_DIR" && swift test > /tmp/as-eval-tests.log 2>&1); then
    TEST_STATUS="pass"
    TEST_COUNT=$(grep -c "Test Case '.*' passed" /tmp/as-eval-tests.log 2>/dev/null || true)
    TEST_COUNT="${TEST_COUNT:-0}"
  else
    TEST_STATUS="fail"
    TEST_COUNT=$(grep -c "Test Case '.*' failed" /tmp/as-eval-tests.log 2>/dev/null || true)
    TEST_COUNT="${TEST_COUNT:-0}"
  fi
fi
echo "tests:            $TEST_STATUS ($TEST_COUNT)"

# Step 2b: Contract test target (optional, phase 3+)
CONTRACT_TEST_STATUS="skip"
if [ "$PHASE" -ge 3 ]; then
  if [ -f "$AGENT_SWIFT_DIR/Package.swift" ]; then
    if (cd "$AGENT_SWIFT_DIR" && swift test --filter ContractTests > /tmp/as-eval-contract-tests.log 2>&1); then
      CONTRACT_TEST_STATUS="pass"
    else
      CONTRACT_TEST_STATUS="fail"
    fi
  else
    CONTRACT_TEST_STATUS="missing_package"
  fi
fi
echo "contract_tests:   $CONTRACT_TEST_STATUS"

# Step 3: CLI smoke
CLI_STATUS="skip"
if [ "$BUILD_STATUS" = "pass" ] && [ -x "$BINARY_PATH" ]; then
  if "$BINARY_PATH" --help > /tmp/as-eval-help.log 2>&1; then
    CLI_STATUS="pass"
  else
    CLI_STATUS="fail"
  fi
fi
echo "cli_smoke:        $CLI_STATUS"

# Step 4: Contract checks (binary, help, json, exit codes)
CONTRACT_STATUS="skip"
HELP_STATUS="skip"
JSON_STATUS="skip"
EXIT_STATUS="skip"

if [ "$CLI_STATUS" = "pass" ]; then
  C_PASS=0
  C_TOTAL=0

  # Binary exists
  C_TOTAL=$((C_TOTAL + 1))
  if [ -x "$BINARY_PATH" ]; then
    C_PASS=$((C_PASS + 1))
  fi

  # Help includes required commands
  HELP_PASS=0
  HELP_TOTAL=0
  for CMD in doctor connect disconnect status snapshot press; do
    HELP_TOTAL=$((HELP_TOTAL + 1))
    if command_exists_in_help "$CMD"; then
      HELP_PASS=$((HELP_PASS + 1))
    fi
  done
  if [ "$PHASE" -ge 2 ]; then
    for CMD in fill get find wait is screenshot schema; do
      HELP_TOTAL=$((HELP_TOTAL + 1))
      if command_exists_in_help "$CMD"; then
        HELP_PASS=$((HELP_PASS + 1))
      fi
    done
  fi
  if [ "$HELP_PASS" -eq "$HELP_TOTAL" ]; then
    HELP_STATUS="pass"
    C_PASS=$((C_PASS + 1))
  else
    HELP_STATUS="fail ($HELP_PASS/$HELP_TOTAL)"
  fi
  C_TOTAL=$((C_TOTAL + 1))

  # Per-command help (phase 1 commands)
  PCH_PASS=0
  PCH_TOTAL=0
  for CMD in doctor connect disconnect status snapshot press; do
    PCH_TOTAL=$((PCH_TOTAL + 1))
    if "$BINARY_PATH" "$CMD" --help > /dev/null 2>&1; then
      PCH_PASS=$((PCH_PASS + 1))
    fi
  done
  if [ "$PHASE" -ge 2 ]; then
    for CMD in fill get find wait is screenshot schema; do
      PCH_TOTAL=$((PCH_TOTAL + 1))
      if "$BINARY_PATH" "$CMD" --help > /dev/null 2>&1; then
        PCH_PASS=$((PCH_PASS + 1))
      fi
    done
  fi
  C_TOTAL=$((C_TOTAL + 1))
  if [ "$PCH_PASS" -eq "$PCH_TOTAL" ]; then
    C_PASS=$((C_PASS + 1))
  fi

  # JSON output checks
  J_PASS=0
  J_TOTAL=0

  J_TOTAL=$((J_TOTAL + 1))
  "$BINARY_PATH" doctor --json > /tmp/as-eval-doctor.json 2>&1 || true
  if json_check /tmp/as-eval-doctor.json object; then
    J_PASS=$((J_PASS + 1))
  fi

  J_TOTAL=$((J_TOTAL + 1))
  "$BINARY_PATH" status --json > /tmp/as-eval-status.json 2>&1 || true
  if json_check /tmp/as-eval-status.json object; then
    J_PASS=$((J_PASS + 1))
  fi

  J_TOTAL=$((J_TOTAL + 1))
  "$BINARY_PATH" snapshot --json > /tmp/as-eval-snapshot.json 2>&1 || true
  if json_check /tmp/as-eval-snapshot.json json; then
    J_PASS=$((J_PASS + 1))
  fi

  if [ "$PHASE" -ge 2 ]; then
    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" schema > /tmp/as-eval-schema.json 2>&1 || true
    if json_check /tmp/as-eval-schema.json schema-full; then
      J_PASS=$((J_PASS + 1))
    fi

    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" schema press > /tmp/as-eval-schema-press.json 2>&1 || true
    if json_check /tmp/as-eval-schema-press.json schema-press; then
      J_PASS=$((J_PASS + 1))
    fi
  fi

  C_TOTAL=$((C_TOTAL + 1))
  if [ "$J_PASS" -eq "$J_TOTAL" ]; then
    JSON_STATUS="pass"
    C_PASS=$((C_PASS + 1))
  else
    JSON_STATUS="fail ($J_PASS/$J_TOTAL)"
  fi

  # Exit code checks
  E_PASS=0
  E_TOTAL=0

  E_TOTAL=$((E_TOTAL + 1))
  "$BINARY_PATH" --help > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    E_PASS=$((E_PASS + 1))
  fi

  E_TOTAL=$((E_TOTAL + 1))
  "$BINARY_PATH" definitely_not_a_command > /dev/null 2>&1
  if [ $? -eq 2 ]; then
    E_PASS=$((E_PASS + 1))
  fi

  E_TOTAL=$((E_TOTAL + 1))
  "$BINARY_PATH" press @e999999 > /dev/null 2>&1
  PRESS_EC=$?
  if [ "$PRESS_EC" -eq 2 ]; then
    E_PASS=$((E_PASS + 1))
  fi

  if [ "$PHASE" -ge 2 ]; then
    E_TOTAL=$((E_TOTAL + 1))
    "$BINARY_PATH" is exists @e999999 > /dev/null 2>&1
    IS_EC=$?
    if [ "$IS_EC" -eq 1 ] || [ "$IS_EC" -eq 2 ]; then
      E_PASS=$((E_PASS + 1))
    fi
  fi

  C_TOTAL=$((C_TOTAL + 1))
  if [ "$E_PASS" -eq "$E_TOTAL" ]; then
    EXIT_STATUS="pass"
    C_PASS=$((C_PASS + 1))
  else
    EXIT_STATUS="fail ($E_PASS/$E_TOTAL)"
  fi

  # Global exit contract sanity (0/1/2 only for sampled commands)
  C_TOTAL=$((C_TOTAL + 1))
  "$BINARY_PATH" status > /dev/null 2>&1
  STATUS_EC=$?
  "$BINARY_PATH" doctor > /dev/null 2>&1
  DOCTOR_EC=$?
  if in_exit_contract "$STATUS_EC" && in_exit_contract "$DOCTOR_EC"; then
    C_PASS=$((C_PASS + 1))
  fi

  if [ "$C_PASS" -eq "$C_TOTAL" ]; then
    CONTRACT_STATUS="pass"
  else
    CONTRACT_STATUS="fail ($C_PASS/$C_TOTAL)"
  fi
fi

echo "contract:         $CONTRACT_STATUS"
echo "help_contract:    $HELP_STATUS"
echo "json_contract:    $JSON_STATUS"
echo "exit_codes:       $EXIT_STATUS"

# Step 4b: Widget coverage gates (phase 2+)
P2_WIDGET_COV="skip"
if [ "$PHASE" -ge 2 ] && [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/WidgetCoverageTests.swift" ]; then
  P2_PASS=0

  # Gate 1: WidgetCoverageTests.swift exists
  P2_PASS=$((P2_PASS + 1))

  # Gate 2: Tests pass (already checked by step 2, just need the file to exist)
  if [ "$TEST_STATUS" = "pass" ]; then
    P2_PASS=$((P2_PASS + 1))
  fi

  # Gate 3: ROLE_MAP has >= 50 entries (count static let entries in ROLE_MAP or displayType mappings)
  ROLE_COUNT=$(grep -cE '"AX[A-Za-z]+"\s*:' "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/AX/AXClient.swift" 2>/dev/null || echo "0")
  if [ "$ROLE_COUNT" -ge 50 ]; then
    P2_PASS=$((P2_PASS + 1))
  fi

  # Gate 4: WIDGET_SUPPORT.md exists
  if [ -f "$AGENT_SWIFT_DIR/WIDGET_SUPPORT.md" ]; then
    P2_PASS=$((P2_PASS + 1))
  fi

  # Gate 5: >= 50 XCTAssert calls in widget coverage tests
  WC_ASSERTIONS=$(grep -cE "XCTAssert" "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/WidgetCoverageTests.swift" 2>/dev/null || echo "0")
  if [ "$WC_ASSERTIONS" -ge 50 ]; then
    P2_PASS=$((P2_PASS + 1))
  fi

  if [ "$P2_PASS" -ge 5 ]; then
    P2_WIDGET_COV="pass"
  else
    P2_WIDGET_COV="fail ($P2_PASS/5)"
  fi
fi
echo "p2_widget_cov:    $P2_WIDGET_COV"

# Step 5: E2E test (optional; enabled when e2e-test.sh exists)
E2E_STATUS="skip"
if [ -x "loops/agent-swift/e2e-test.sh" ]; then
  if bash loops/agent-swift/e2e-test.sh > /tmp/as-eval-e2e.log 2>&1; then
    E2E_STATUS="pass"
  else
    E2E_STATUS="fail"
  fi
fi
echo "e2e:              $E2E_STATUS"

# Step 6: Basic footprint
TOTAL_FILES="0"
TOTAL_LINES="0"
if [ -d "$AGENT_SWIFT_DIR/Sources" ]; then
  TOTAL_FILES=$(find "$AGENT_SWIFT_DIR/Sources" -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$TOTAL_FILES" -gt 0 ]; then
    TOTAL_LINES=$(find "$AGENT_SWIFT_DIR/Sources" -name '*.swift' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
  fi
fi
echo "files:            $TOTAL_FILES"
echo "lines:            $TOTAL_LINES"

# Final phase gate
PHASE_COMPLETE="no"
if [ "$BUILD_STATUS" = "pass" ] && [ "$TEST_STATUS" = "pass" ] && [ "$CONTRACT_STATUS" = "pass" ]; then
  case "$PHASE" in
    1)
      PHASE_COMPLETE="yes"
      ;;
    2)
      if [ "$P2_WIDGET_COV" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    3)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$CONTRACT_TEST_STATUS" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
  esac
fi
echo "phase_complete:   $PHASE_COMPLETE"
echo "---"
