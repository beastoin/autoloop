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
    "doctor", "connect", "disconnect", "status", "snapshot", "press", "fill",
    "get", "find", "wait", "is", "scroll", "screenshot", "schema", "click",
    "type", "swipe", "record"
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
if [ -f "loops/agent-swift/program-phase4.md" ]; then
  PHASE=4
fi
if [ -f "loops/agent-swift/program-phase5.md" ]; then
  PHASE=5
fi
if [ -f "loops/agent-swift/program-phase2b.md" ]; then
  PHASE=6  # 2b widget coverage supplement
fi
if [ -f "loops/agent-swift/program-phase6.md" ]; then
  PHASE=7  # click command
fi
if [ -f "loops/agent-swift/program-phase7.md" ]; then
  PHASE=8  # simulator support
fi
if [ -f "loops/agent-swift/program-phase8.md" ]; then
  PHASE=9  # idb transport
fi
if [ -f "loops/agent-swift/program-phase9.md" ]; then
  PHASE=10  # iPhone Mirroring
fi
if [ -f "loops/agent-swift/program-phase10.md" ]; then
  PHASE=11  # CGEvent Simulator interaction
fi
if [ -f "loops/agent-swift/program-phase11.md" ]; then
  PHASE=12  # User-driven UX: type, swipe, compound find, multi-sim
fi
if [ -f "loops/agent-swift/program-phase12.md" ]; then
  PHASE=13  # Screen video recording
fi
if [ -f "loops/agent-swift/program-phase13.md" ]; then
  PHASE=14  # Frame processing: resize, dedup, crop
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

# Step 2b: Contract test target (optional, phase 4+)
CONTRACT_TEST_STATUS="skip"
if [ "$PHASE" -ge 4 ]; then
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

# Step 2c: Interaction test target (phase 3+)
INTERACTION_TEST_STATUS="skip"
if [ "$PHASE" -ge 3 ]; then
  if [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/InteractionTests.swift" ]; then
    if (cd "$AGENT_SWIFT_DIR" && swift test --filter InteractionTests > /tmp/as-eval-interaction-tests.log 2>&1); then
      INTERACTION_TEST_STATUS="pass"
    else
      INTERACTION_TEST_STATUS="fail"
    fi
  else
    INTERACTION_TEST_STATUS="missing"
  fi
fi
echo "interaction_tests: $INTERACTION_TEST_STATUS"

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
  if [ "$PHASE" -ge 3 ]; then
    for CMD in fill get find screenshot; do
      HELP_TOTAL=$((HELP_TOTAL + 1))
      if command_exists_in_help "$CMD"; then
        HELP_PASS=$((HELP_PASS + 1))
      fi
    done
  fi
  if [ "$PHASE" -ge 4 ]; then
    for CMD in wait is schema; do
      HELP_TOTAL=$((HELP_TOTAL + 1))
      if command_exists_in_help "$CMD"; then
        HELP_PASS=$((HELP_PASS + 1))
      fi
    done
  fi
  if [ "$PHASE" -ge 7 ]; then
    HELP_TOTAL=$((HELP_TOTAL + 1))
    if command_exists_in_help "click"; then
      HELP_PASS=$((HELP_PASS + 1))
    fi
  fi
  if [ "$PHASE" -ge 12 ]; then
    for CMD in type swipe; do
      HELP_TOTAL=$((HELP_TOTAL + 1))
      if command_exists_in_help "$CMD"; then
        HELP_PASS=$((HELP_PASS + 1))
      fi
    done
  fi
  if [ "$PHASE" -ge 13 ]; then
    HELP_TOTAL=$((HELP_TOTAL + 1))
    if command_exists_in_help "record"; then
      HELP_PASS=$((HELP_PASS + 1))
    fi
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
  if [ "$PHASE" -ge 3 ]; then
    for CMD in fill get find screenshot; do
      PCH_TOTAL=$((PCH_TOTAL + 1))
      if "$BINARY_PATH" "$CMD" --help > /dev/null 2>&1; then
        PCH_PASS=$((PCH_PASS + 1))
      fi
    done
  fi
  if [ "$PHASE" -ge 4 ]; then
    for CMD in wait is schema; do
      PCH_TOTAL=$((PCH_TOTAL + 1))
      if "$BINARY_PATH" "$CMD" --help > /dev/null 2>&1; then
        PCH_PASS=$((PCH_PASS + 1))
      fi
    done
  fi
  if [ "$PHASE" -ge 7 ]; then
    PCH_TOTAL=$((PCH_TOTAL + 1))
    if "$BINARY_PATH" click --help > /dev/null 2>&1; then
      PCH_PASS=$((PCH_PASS + 1))
    fi
  fi
  if [ "$PHASE" -ge 12 ]; then
    for CMD in type swipe; do
      PCH_TOTAL=$((PCH_TOTAL + 1))
      if "$BINARY_PATH" "$CMD" --help > /dev/null 2>&1; then
        PCH_PASS=$((PCH_PASS + 1))
      fi
    done
  fi
  if [ "$PHASE" -ge 13 ]; then
    PCH_TOTAL=$((PCH_TOTAL + 1))
    if "$BINARY_PATH" record --help > /dev/null 2>&1; then
      PCH_PASS=$((PCH_PASS + 1))
    fi
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

  if [ "$PHASE" -ge 3 ]; then
    # fill --json returns valid JSON
    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" fill @e999 "test" --json > /tmp/as-eval-fill.json 2>&1 || true
    if json_check /tmp/as-eval-fill.json json; then
      J_PASS=$((J_PASS + 1))
    fi

    # get attrs --json returns valid JSON
    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" get attrs @e999 --json > /tmp/as-eval-get.json 2>&1 || true
    if json_check /tmp/as-eval-get.json json; then
      J_PASS=$((J_PASS + 1))
    fi

    # screenshot --json returns valid JSON
    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" screenshot --json > /tmp/as-eval-screenshot.json 2>&1 || true
    if json_check /tmp/as-eval-screenshot.json json; then
      J_PASS=$((J_PASS + 1))
    fi
  fi

  if [ "$PHASE" -ge 4 ]; then
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

  if [ "$PHASE" -ge 7 ]; then
    # click --json on invalid ref returns valid JSON error
    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" click @e999999 --json > /tmp/as-eval-click.json 2>&1 || true
    if json_check /tmp/as-eval-click.json json; then
      J_PASS=$((J_PASS + 1))
    fi
  fi

  if [ "$PHASE" -ge 12 ]; then
    # type --json returns valid JSON
    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" type "test" --json > /tmp/as-eval-type12.json 2>&1 || true
    if json_check /tmp/as-eval-type12.json json; then
      J_PASS=$((J_PASS + 1))
    fi

    # swipe --json returns valid JSON
    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" swipe 0 0 0 100 --json > /tmp/as-eval-swipe12.json 2>&1 || true
    if json_check /tmp/as-eval-swipe12.json json; then
      J_PASS=$((J_PASS + 1))
    fi
  fi

  if [ "$PHASE" -ge 13 ]; then
    # record status --json returns valid JSON
    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" record status --json > /tmp/as-eval-record-status.json 2>&1 || true
    if json_check /tmp/as-eval-record-status.json json; then
      J_PASS=$((J_PASS + 1))
    fi

    # record stop --json returns valid JSON (error expected — no active recording)
    J_TOTAL=$((J_TOTAL + 1))
    "$BINARY_PATH" record stop --json > /tmp/as-eval-record-stop.json 2>&1 || true
    if json_check /tmp/as-eval-record-stop.json json; then
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

  if [ "$PHASE" -ge 3 ]; then
    # fill on invalid ref should exit 2
    E_TOTAL=$((E_TOTAL + 1))
    "$BINARY_PATH" fill @e999999 "test" > /dev/null 2>&1
    FILL_EC=$?
    if [ "$FILL_EC" -eq 2 ]; then
      E_PASS=$((E_PASS + 1))
    fi

    # get on invalid ref should exit 2
    E_TOTAL=$((E_TOTAL + 1))
    "$BINARY_PATH" get text @e999999 > /dev/null 2>&1
    GET_EC=$?
    if [ "$GET_EC" -eq 2 ]; then
      E_PASS=$((E_PASS + 1))
    fi
  fi

  if [ "$PHASE" -ge 4 ]; then
    E_TOTAL=$((E_TOTAL + 1))
    "$BINARY_PATH" is exists @e999999 > /dev/null 2>&1
    IS_EC=$?
    if [ "$IS_EC" -eq 1 ] || [ "$IS_EC" -eq 2 ]; then
      E_PASS=$((E_PASS + 1))
    fi
  fi

  if [ "$PHASE" -ge 7 ]; then
    # click on invalid ref should exit 2
    E_TOTAL=$((E_TOTAL + 1))
    "$BINARY_PATH" click @e999999 > /dev/null 2>&1
    CLICK_EC=$?
    if [ "$CLICK_EC" -eq 2 ]; then
      E_PASS=$((E_PASS + 1))
    fi
  fi

  if [ "$PHASE" -ge 12 ]; then
    # type without session should exit 2 (use clean session dir)
    E_TOTAL=$((E_TOTAL + 1))
    CLEAN_HOME=$(mktemp -d)
    AGENT_SWIFT_HOME="$CLEAN_HOME" "$BINARY_PATH" type "test" > /dev/null 2>&1
    TYPE_EC=$?
    rm -rf "$CLEAN_HOME"
    if [ "$TYPE_EC" -eq 2 ]; then
      E_PASS=$((E_PASS + 1))
    fi

    # swipe without session should exit 2 (use clean session dir)
    E_TOTAL=$((E_TOTAL + 1))
    CLEAN_HOME=$(mktemp -d)
    AGENT_SWIFT_HOME="$CLEAN_HOME" "$BINARY_PATH" swipe 0 0 0 100 > /dev/null 2>&1
    SWIPE_EC=$?
    rm -rf "$CLEAN_HOME"
    if [ "$SWIPE_EC" -eq 2 ]; then
      E_PASS=$((E_PASS + 1))
    fi
  fi

  if [ "$PHASE" -ge 13 ]; then
    # record stop without active recording should exit 2 (use clean session dir)
    E_TOTAL=$((E_TOTAL + 1))
    CLEAN_HOME=$(mktemp -d)
    AGENT_SWIFT_HOME="$CLEAN_HOME" "$BINARY_PATH" record stop > /dev/null 2>&1
    RECORD_STOP_EC=$?
    rm -rf "$CLEAN_HOME"
    if [ "$RECORD_STOP_EC" -eq 2 ]; then
      E_PASS=$((E_PASS + 1))
    fi

    # record frame without recording should exit 2 (use clean session dir)
    E_TOTAL=$((E_TOTAL + 1))
    CLEAN_HOME=$(mktemp -d)
    AGENT_SWIFT_HOME="$CLEAN_HOME" "$BINARY_PATH" record frame --at 1.0 > /dev/null 2>&1
    RECORD_FRAME_EC=$?
    rm -rf "$CLEAN_HOME"
    if [ "$RECORD_FRAME_EC" -eq 2 ]; then
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

# Step 4c: Phase 3 interaction gates
P3_INTERACTION="skip"
if [ "$PHASE" -ge 3 ] && [ "$CLI_STATUS" = "pass" ]; then
  P3_PASS=0
  P3_TOTAL=0

  # Gate 1: fill command exists in help
  P3_TOTAL=$((P3_TOTAL + 1))
  if command_exists_in_help "fill"; then
    P3_PASS=$((P3_PASS + 1))
  fi

  # Gate 2: get command exists in help
  P3_TOTAL=$((P3_TOTAL + 1))
  if command_exists_in_help "get"; then
    P3_PASS=$((P3_PASS + 1))
  fi

  # Gate 3: find command exists in help
  P3_TOTAL=$((P3_TOTAL + 1))
  if command_exists_in_help "find"; then
    P3_PASS=$((P3_PASS + 1))
  fi

  # Gate 4: screenshot command exists in help
  P3_TOTAL=$((P3_TOTAL + 1))
  if command_exists_in_help "screenshot"; then
    P3_PASS=$((P3_PASS + 1))
  fi

  # Gate 5: interactiveSnapshot field in SessionStore.swift
  P3_TOTAL=$((P3_TOTAL + 1))
  if grep -q "interactiveSnapshot" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Session/SessionStore.swift" 2>/dev/null; then
    P3_PASS=$((P3_PASS + 1))
  fi

  # Gate 6: performFill in AXClient.swift
  P3_TOTAL=$((P3_TOTAL + 1))
  if grep -q "performFill" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/AX/AXClient.swift" 2>/dev/null; then
    P3_PASS=$((P3_PASS + 1))
  fi

  # Gate 7: captureScreenshot in AXClient.swift
  P3_TOTAL=$((P3_TOTAL + 1))
  if grep -q "captureScreenshot" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/AX/AXClient.swift" 2>/dev/null; then
    P3_PASS=$((P3_PASS + 1))
  fi

  # Gate 8: InteractionTests.swift exists
  P3_TOTAL=$((P3_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/InteractionTests.swift" ]; then
    P3_PASS=$((P3_PASS + 1))
  fi

  # Gate 9: >= 20 XCTAssert calls in interaction tests
  P3_TOTAL=$((P3_TOTAL + 1))
  IC_ASSERTIONS=$(grep -cE "XCTAssert" "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/InteractionTests.swift" 2>/dev/null || echo "0")
  if [ "$IC_ASSERTIONS" -ge 20 ]; then
    P3_PASS=$((P3_PASS + 1))
  fi

  # Gate 10: Interaction tests pass
  P3_TOTAL=$((P3_TOTAL + 1))
  if [ "$INTERACTION_TEST_STATUS" = "pass" ]; then
    P3_PASS=$((P3_PASS + 1))
  fi

  if [ "$P3_PASS" -eq "$P3_TOTAL" ]; then
    P3_INTERACTION="pass"
  else
    P3_INTERACTION="fail ($P3_PASS/$P3_TOTAL)"
  fi
fi
echo "p3_interaction:   $P3_INTERACTION"

# Step 4d: Phase 4 autonomy gates
P4_AUTONOMY="skip"
if [ "$PHASE" -ge 4 ] && [ "$CLI_STATUS" = "pass" ]; then
  P4_PASS=0
  P4_TOTAL=0

  # Gate 1: is command exists in help
  P4_TOTAL=$((P4_TOTAL + 1))
  if command_exists_in_help "is"; then
    P4_PASS=$((P4_PASS + 1))
  fi

  # Gate 2: wait command exists in help
  P4_TOTAL=$((P4_TOTAL + 1))
  if command_exists_in_help "wait"; then
    P4_PASS=$((P4_PASS + 1))
  fi

  # Gate 3: scroll command exists in help
  P4_TOTAL=$((P4_TOTAL + 1))
  if command_exists_in_help "scroll"; then
    P4_PASS=$((P4_PASS + 1))
  fi

  # Gate 4: schema command exists in help
  P4_TOTAL=$((P4_TOTAL + 1))
  if command_exists_in_help "schema"; then
    P4_PASS=$((P4_PASS + 1))
  fi

  # Gate 5: is exits 1 for false assertion (not 2)
  P4_TOTAL=$((P4_TOTAL + 1))
  "$BINARY_PATH" is exists @e999999 > /dev/null 2>&1
  IS_EC=$?
  if [ "$IS_EC" -eq 1 ]; then
    P4_PASS=$((P4_PASS + 1))
  fi

  # Gate 6: schema returns valid JSON array
  P4_TOTAL=$((P4_TOTAL + 1))
  "$BINARY_PATH" schema > /tmp/as-eval-schema.json 2>&1 || true
  if json_check /tmp/as-eval-schema.json array; then
    P4_PASS=$((P4_PASS + 1))
  fi

  # Gate 7: schema press returns valid JSON object
  P4_TOTAL=$((P4_TOTAL + 1))
  "$BINARY_PATH" schema press > /tmp/as-eval-schema-press.json 2>&1 || true
  if json_check /tmp/as-eval-schema-press.json schema-press; then
    P4_PASS=$((P4_PASS + 1))
  fi

  # Gate 8: schema lists all commands
  P4_TOTAL=$((P4_TOTAL + 1))
  if json_check /tmp/as-eval-schema.json schema-full; then
    P4_PASS=$((P4_PASS + 1))
  fi

  # Gate 9: wait <ms> exits 0
  P4_TOTAL=$((P4_TOTAL + 1))
  "$BINARY_PATH" wait 100 > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    P4_PASS=$((P4_PASS + 1))
  fi

  # Gate 10: AutonomyTests.swift exists with >= 20 assertions
  P4_TOTAL=$((P4_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/AutonomyTests.swift" ]; then
    AT_ASSERTIONS=$(grep -cE "XCTAssert" "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/AutonomyTests.swift" 2>/dev/null || echo "0")
    if [ "$AT_ASSERTIONS" -ge 20 ]; then
      P4_PASS=$((P4_PASS + 1))
    fi
  fi

  if [ "$P4_PASS" -eq "$P4_TOTAL" ]; then
    P4_AUTONOMY="pass"
  else
    P4_AUTONOMY="fail ($P4_PASS/$P4_TOTAL)"
  fi
fi
echo "p4_autonomy:      $P4_AUTONOMY"

# Phase 5 gates: Polish
P5_POLISH="skip"
if [ "$PHASE" -ge 5 ] && [ "$CLI_STATUS" = "pass" ]; then
  P5_PASS=0
  P5_TOTAL=0

  # Gate 1: version is 0.2.x or higher (0.3.x for phase 8+)
  P5_TOTAL=$((P5_TOTAL + 1))
  VERSION_OUT=$("$BINARY_PATH" --version 2>&1 || true)
  if echo "$VERSION_OUT" | grep -qE "0\.[2-9]\.[0-9]+|0\.[1-9][0-9]+\.[0-9]+"; then
    P5_PASS=$((P5_PASS + 1))
  fi

  # Gate 2: AGENT_SWIFT_JSON=1 makes status output JSON (without --json flag)
  P5_TOTAL=$((P5_TOTAL + 1))
  AGENT_SWIFT_JSON=1 "$BINARY_PATH" status > /tmp/as-eval-envjson.json 2>&1 || true
  if json_check /tmp/as-eval-envjson.json object; then
    P5_PASS=$((P5_PASS + 1))
  fi

  # Gate 3: Non-TTY pipe produces JSON output
  P5_TOTAL=$((P5_TOTAL + 1))
  "$BINARY_PATH" status 2>/dev/null | cat > /tmp/as-eval-tty.json
  if json_check /tmp/as-eval-tty.json object; then
    P5_PASS=$((P5_PASS + 1))
  fi

  # Gate 4: AGENTS.md has env vars section
  P5_TOTAL=$((P5_TOTAL + 1))
  AGENTS_FILE="loops/agent-swift/AGENTS.md"
  if [ -f "$AGENTS_FILE" ] && grep -q "AGENT_SWIFT_JSON" "$AGENTS_FILE" && grep -q "AGENT_SWIFT_TIMEOUT" "$AGENTS_FILE"; then
    P5_PASS=$((P5_PASS + 1))
  fi

  # Gate 5: AGENTS.md has CLAUDE.md snippet section
  P5_TOTAL=$((P5_TOTAL + 1))
  if [ -f "$AGENTS_FILE" ] && grep -qi "CLAUDE.md" "$AGENTS_FILE"; then
    P5_PASS=$((P5_PASS + 1))
  fi

  # Gate 6: AGENTS.md has scroll in idempotency table
  P5_TOTAL=$((P5_TOTAL + 1))
  if [ -f "$AGENTS_FILE" ] && grep -q "scroll" "$AGENTS_FILE"; then
    P5_PASS=$((P5_PASS + 1))
  fi

  # Gate 7: Tests pass with >= 59 total
  P5_TOTAL=$((P5_TOTAL + 1))
  if [ "$TEST_STATUS" = "pass" ]; then
    TEST_NUM=$(echo "$TEST_COUNT" | tr -dc '0-9')
    if [ "$TEST_NUM" -ge 59 ]; then
      P5_PASS=$((P5_PASS + 1))
    fi
  fi

  # Gate 8: AGENT_SWIFT_HOME works for session path
  P5_TOTAL=$((P5_TOTAL + 1))
  TMPDIR_TEST=$(mktemp -d)
  AGENT_SWIFT_HOME="$TMPDIR_TEST" "$BINARY_PATH" status > /dev/null 2>&1 || true
  # Just check it doesn't crash — the session file should be read from custom dir
  if [ $? -le 2 ]; then
    P5_PASS=$((P5_PASS + 1))
  fi
  rm -rf "$TMPDIR_TEST"

  if [ "$P5_PASS" -eq "$P5_TOTAL" ]; then
    P5_POLISH="pass"
  else
    P5_POLISH="fail ($P5_PASS/$P5_TOTAL)"
  fi
fi
echo "p5_polish:        $P5_POLISH"

# Phase 2b gates: Complete widget coverage
P2B_WIDGET="skip"
if [ "$PHASE" -ge 6 ] && [ "$TEST_STATUS" = "pass" ]; then
  P2B_PASS=0
  P2B_TOTAL=0

  # Gate 1: ROLE_MAP has >= 72 entries
  P2B_TOTAL=$((P2B_TOTAL + 1))
  ROLEMAP_COUNT=$(grep -c '"AX[A-Za-z]*":' "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/AX/AXClient.swift" 2>/dev/null || echo "0")
  if [ "$ROLEMAP_COUNT" -ge 72 ]; then
    P2B_PASS=$((P2B_PASS + 1))
  fi

  # Gate 2: AXTimeField in ROLE_MAP
  P2B_TOTAL=$((P2B_TOTAL + 1))
  if grep -q '"AXTimeField"' "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/AX/AXClient.swift" 2>/dev/null; then
    P2B_PASS=$((P2B_PASS + 1))
  fi

  # Gate 3: AXDockItem in ROLE_MAP
  P2B_TOTAL=$((P2B_TOTAL + 1))
  if grep -q '"AXDockItem"' "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/AX/AXClient.swift" 2>/dev/null; then
    P2B_PASS=$((P2B_PASS + 1))
  fi

  # Gate 4: AXGrid in ROLE_MAP
  P2B_TOTAL=$((P2B_TOTAL + 1))
  if grep -q '"AXGrid"' "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/AX/AXClient.swift" 2>/dev/null; then
    P2B_PASS=$((P2B_PASS + 1))
  fi

  # Gate 5: AXPage in ROLE_MAP
  P2B_TOTAL=$((P2B_TOTAL + 1))
  if grep -q '"AXPage"' "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/AX/AXClient.swift" 2>/dev/null; then
    P2B_PASS=$((P2B_PASS + 1))
  fi

  # Gate 6: WIDGET_SUPPORT.md exists and mentions AXTimeField
  P2B_TOTAL=$((P2B_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/WIDGET_SUPPORT.md" ] && grep -q "AXTimeField" "$AGENT_SWIFT_DIR/WIDGET_SUPPORT.md" 2>/dev/null; then
    P2B_PASS=$((P2B_PASS + 1))
  fi

  # Gate 7: Tests >= 63 (59 existing + 4 new widget coverage tests)
  P2B_TOTAL=$((P2B_TOTAL + 1))
  TEST_NUM=$(echo "$TEST_COUNT" | tr -dc '0-9')
  if [ "$TEST_NUM" -ge 63 ]; then
    P2B_PASS=$((P2B_PASS + 1))
  fi

  # Gate 8: Live snapshot against Finder (always running) produces valid JSON
  P2B_TOTAL=$((P2B_TOTAL + 1))
  if [ -x "$BINARY_PATH" ]; then
    "$BINARY_PATH" connect --bundle-id com.apple.finder --json > /dev/null 2>&1 || true
    "$BINARY_PATH" snapshot -i --json > /tmp/as-eval-finder.json 2>&1 || true
    "$BINARY_PATH" disconnect --json > /dev/null 2>&1 || true
    if json_check /tmp/as-eval-finder.json array; then
      P2B_PASS=$((P2B_PASS + 1))
    fi
  fi

  if [ "$P2B_PASS" -eq "$P2B_TOTAL" ]; then
    P2B_WIDGET="pass"
  else
    P2B_WIDGET="fail ($P2B_PASS/$P2B_TOTAL)"
  fi
fi
echo "p2b_widget_cov:   $P2B_WIDGET"

# Phase 7 gates: Click command
P7_CLICK="skip"
if [ "$PHASE" -ge 7 ] && [ "$CLI_STATUS" = "pass" ]; then
  P7_PASS=0
  P7_TOTAL=0

  # Gate 1: click command exists in help
  P7_TOTAL=$((P7_TOTAL + 1))
  if command_exists_in_help "click"; then
    P7_PASS=$((P7_PASS + 1))
  fi

  # Gate 2: version is 0.2.1 or higher (0.3.x for phase 8+)
  P7_TOTAL=$((P7_TOTAL + 1))
  VERSION_OUT=$("$BINARY_PATH" --version 2>&1 || true)
  if echo "$VERSION_OUT" | grep -qE "0\.(2\.1|[3-9]\.[0-9]+|[1-9][0-9]+\.[0-9]+)"; then
    P7_PASS=$((P7_PASS + 1))
  fi

  # Gate 3: performClick exists in AXClient.swift
  P7_TOTAL=$((P7_TOTAL + 1))
  if grep -q "performClick" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/AX/AXClient.swift" 2>/dev/null; then
    P7_PASS=$((P7_PASS + 1))
  fi

  # Gate 4: schema lists 15 commands
  P7_TOTAL=$((P7_TOTAL + 1))
  "$BINARY_PATH" schema > /tmp/as-eval-schema7.json 2>&1 || true
  SCHEMA_COUNT=$(python3 -c "import json; d=json.load(open('/tmp/as-eval-schema7.json')); print(len(d))" 2>/dev/null || echo "0")
  if [ "$SCHEMA_COUNT" -ge 15 ]; then
    P7_PASS=$((P7_PASS + 1))
  fi

  # Gate 5: click on invalid ref exits 2
  P7_TOTAL=$((P7_TOTAL + 1))
  "$BINARY_PATH" click @e999999 > /dev/null 2>&1
  if [ $? -eq 2 ]; then
    P7_PASS=$((P7_PASS + 1))
  fi

  # Gate 6: Tests >= 68 (63 existing + 5 new)
  P7_TOTAL=$((P7_TOTAL + 1))
  TEST_NUM=$(echo "$TEST_COUNT" | tr -dc '0-9')
  if [ "$TEST_NUM" -ge 68 ]; then
    P7_PASS=$((P7_PASS + 1))
  fi

  # Gate 7: AGENTS.md mentions click
  P7_TOTAL=$((P7_TOTAL + 1))
  AGENTS_FILE="loops/agent-swift/AGENTS.md"
  if [ -f "$AGENTS_FILE" ] && grep -q "click" "$AGENTS_FILE"; then
    P7_PASS=$((P7_PASS + 1))
  fi

  # Gate 8: Live click test — connect to Finder, click command doesn't crash
  P7_TOTAL=$((P7_TOTAL + 1))
  if [ -x "$BINARY_PATH" ]; then
    "$BINARY_PATH" connect --bundle-id com.apple.finder --json > /dev/null 2>&1 || true
    "$BINARY_PATH" snapshot -i --json > /dev/null 2>&1 || true
    "$BINARY_PATH" click @e1 --json > /tmp/as-eval-click-live.json 2>&1 || true
    "$BINARY_PATH" disconnect --json > /dev/null 2>&1 || true
    if json_check /tmp/as-eval-click-live.json json; then
      P7_PASS=$((P7_PASS + 1))
    fi
  fi

  if [ "$P7_PASS" -eq "$P7_TOTAL" ]; then
    P7_CLICK="pass"
  else
    P7_CLICK="fail ($P7_PASS/$P7_TOTAL)"
  fi
fi
echo "p7_click:         $P7_CLICK"

# Phase 8 gates: Simulator support
P8_SIMULATOR="skip"
if [ "$PHASE" -ge 8 ] && [ "$CLI_STATUS" = "pass" ]; then
  P8_PASS=0
  P8_TOTAL=0

  # Gate 1: SimulatorBridge.swift exists
  P8_TOTAL=$((P8_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" ]; then
    P8_PASS=$((P8_PASS + 1))
  fi

  # Gate 2: connect --simulator flag in help
  P8_TOTAL=$((P8_TOTAL + 1))
  "$BINARY_PATH" connect --help > /tmp/as-eval-connect-help.txt 2>&1 || true
  if grep -q "simulator" /tmp/as-eval-connect-help.txt 2>/dev/null; then
    P8_PASS=$((P8_PASS + 1))
  fi

  # Gate 3: SessionStore has simulatorUDID field
  P8_TOTAL=$((P8_TOTAL + 1))
  if grep -q "simulatorUDID" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Session/SessionStore.swift" 2>/dev/null; then
    P8_PASS=$((P8_PASS + 1))
  fi

  # Gate 4: version is 0.3.x
  P8_TOTAL=$((P8_TOTAL + 1))
  VERSION_OUT=$("$BINARY_PATH" --version 2>&1 || true)
  if echo "$VERSION_OUT" | grep -qE "0\.[3-9]\.[0-9]+|0\.[1-9][0-9]+\.[0-9]+"; then
    P8_PASS=$((P8_PASS + 1))
  fi

  # Gate 5: SimulatorTests.swift exists
  P8_TOTAL=$((P8_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/SimulatorTests.swift" ]; then
    P8_PASS=$((P8_PASS + 1))
  fi

  # Gate 6: >= 10 XCTAssert calls in SimulatorTests
  P8_TOTAL=$((P8_TOTAL + 1))
  SIM_ASSERTIONS=$(grep -cE "XCTAssert" "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/SimulatorTests.swift" 2>/dev/null || echo "0")
  if [ "$SIM_ASSERTIONS" -ge 10 ]; then
    P8_PASS=$((P8_PASS + 1))
  fi

  # Gate 7: Tests >= 78 (68 existing + 10 new)
  P8_TOTAL=$((P8_TOTAL + 1))
  TEST_NUM=$(echo "$TEST_COUNT" | tr -dc '0-9')
  if [ "$TEST_NUM" -ge 78 ]; then
    P8_PASS=$((P8_PASS + 1))
  fi

  # Gate 8: screenshot command references simctl (in source)
  P8_TOTAL=$((P8_TOTAL + 1))
  if grep -q "simctl" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null; then
    P8_PASS=$((P8_PASS + 1))
  fi

  # Gate 9: iosPointToScreen coordinate mapping exists
  P8_TOTAL=$((P8_TOTAL + 1))
  if grep -q "iosPointToScreen" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null; then
    P8_PASS=$((P8_PASS + 1))
  fi

  # Gate 10: status --json shows mode field when not connected (backwards compat)
  P8_TOTAL=$((P8_TOTAL + 1))
  "$BINARY_PATH" status --json > /tmp/as-eval-status-sim.json 2>&1 || true
  if json_check /tmp/as-eval-status-sim.json object; then
    P8_PASS=$((P8_PASS + 1))
  fi

  if [ "$P8_PASS" -eq "$P8_TOTAL" ]; then
    P8_SIMULATOR="pass"
  else
    P8_SIMULATOR="fail ($P8_PASS/$P8_TOTAL)"
  fi
fi
echo "p8_simulator:     $P8_SIMULATOR"

# Phase 9 gates: idb transport
P9_IDB="skip"
if [ "$PHASE" -ge 9 ] && [ "$CLI_STATUS" = "pass" ]; then
  P9_PASS=0
  P9_TOTAL=0

  # Gate 1: IdbBridge.swift exists
  P9_TOTAL=$((P9_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/IdbBridge.swift" ]; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 2: IdbBridge has describeAll method
  P9_TOTAL=$((P9_TOTAL + 1))
  if grep -q "describeAll" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/IdbBridge.swift" 2>/dev/null; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 3: IdbBridge has tap method
  P9_TOTAL=$((P9_TOTAL + 1))
  if grep -qE "func tap\b" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/IdbBridge.swift" 2>/dev/null; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 4: IdbBridge has text method
  P9_TOTAL=$((P9_TOTAL + 1))
  if grep -qE "func text\b" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/IdbBridge.swift" 2>/dev/null; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 5: IdbBridge has swipe method
  P9_TOTAL=$((P9_TOTAL + 1))
  if grep -qE "func swipe\b" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/IdbBridge.swift" 2>/dev/null; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 6: IdbBridge has enableAccessibility method
  P9_TOTAL=$((P9_TOTAL + 1))
  if grep -q "enableAccessibility" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/IdbBridge.swift" 2>/dev/null; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 7: version is 0.4.x
  P9_TOTAL=$((P9_TOTAL + 1))
  VERSION_OUT=$("$BINARY_PATH" --version 2>&1 || true)
  if echo "$VERSION_OUT" | grep -qE "0\.[4-9]\.[0-9]+|0\.[1-9][0-9]+\.[0-9]+"; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 8: IdbTests.swift exists
  P9_TOTAL=$((P9_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/IdbTests.swift" ]; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 9: >= 15 XCTAssert calls in IdbTests
  P9_TOTAL=$((P9_TOTAL + 1))
  IDB_ASSERTIONS=$(grep -cE "XCTAssert" "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/IdbTests.swift" 2>/dev/null || echo "0")
  if [ "$IDB_ASSERTIONS" -ge 15 ]; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 10: Tests >= 95 (85 existing + 10 new)
  P9_TOTAL=$((P9_TOTAL + 1))
  TEST_NUM=$(echo "$TEST_COUNT" | tr -dc '0-9')
  if [ "$TEST_NUM" -ge 95 ]; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 11: IdbElement struct exists
  P9_TOTAL=$((P9_TOTAL + 1))
  if grep -q "struct IdbElement" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/IdbBridge.swift" 2>/dev/null; then
    P9_PASS=$((P9_PASS + 1))
  fi

  # Gate 12: runIdb helper exists
  P9_TOTAL=$((P9_TOTAL + 1))
  if grep -q "runIdb" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/IdbBridge.swift" 2>/dev/null; then
    P9_PASS=$((P9_PASS + 1))
  fi

  if [ "$P9_PASS" -eq "$P9_TOTAL" ]; then
    P9_IDB="pass"
  else
    P9_IDB="fail ($P9_PASS/$P9_TOTAL)"
  fi
fi
echo "p9_idb:           $P9_IDB"

# Phase 10 gates: iPhone Mirroring
P10_MIRROR="skip"
if [ "$PHASE" -ge 10 ] && [ "$CLI_STATUS" = "pass" ]; then
  P10_PASS=0
  P10_TOTAL=0

  # Gate 1: MirrorBridge.swift exists
  P10_TOTAL=$((P10_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Mirror/MirrorBridge.swift" ]; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 2: MirrorBridge has screenshot method
  P10_TOTAL=$((P10_TOTAL + 1))
  if grep -qE "func screenshot\b" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Mirror/MirrorBridge.swift" 2>/dev/null; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 3: MirrorBridge has tap method
  P10_TOTAL=$((P10_TOTAL + 1))
  if grep -qE "func tap\b" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Mirror/MirrorBridge.swift" 2>/dev/null; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 4: MirrorBridge has swipe method
  P10_TOTAL=$((P10_TOTAL + 1))
  if grep -qE "func swipe\b" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Mirror/MirrorBridge.swift" 2>/dev/null; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 5: MirrorBridge has windowInfo method
  P10_TOTAL=$((P10_TOTAL + 1))
  if grep -q "windowInfo" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Mirror/MirrorBridge.swift" 2>/dev/null; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 6: MirrorBridge has iosPointToScreen coordinate mapping
  P10_TOTAL=$((P10_TOTAL + 1))
  if grep -q "iosPointToScreen" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Mirror/MirrorBridge.swift" 2>/dev/null; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 7: connect --mirror flag in help
  P10_TOTAL=$((P10_TOTAL + 1))
  "$BINARY_PATH" connect --help > /tmp/as-eval-connect-help10.txt 2>&1 || true
  if grep -q "mirror" /tmp/as-eval-connect-help10.txt 2>/dev/null; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 8: version is 0.5.x or higher (forward-compatible)
  P10_TOTAL=$((P10_TOTAL + 1))
  VERSION_OUT=$("$BINARY_PATH" --version 2>&1 || true)
  if echo "$VERSION_OUT" | grep -qE "0\.[5-9]\.[0-9]+|0\.[1-9][0-9]+\.[0-9]+|[1-9]+\.[0-9]+\.[0-9]+"; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 9: MirrorTests.swift exists
  P10_TOTAL=$((P10_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/MirrorTests.swift" ]; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 10: >= 15 XCTAssert calls in MirrorTests
  P10_TOTAL=$((P10_TOTAL + 1))
  MIRROR_ASSERTIONS=$(grep -cE "XCTAssert" "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/MirrorTests.swift" 2>/dev/null || echo "0")
  if [ "$MIRROR_ASSERTIONS" -ge 15 ]; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 11: Tests >= 110 (102 existing + 8 new)
  P10_TOTAL=$((P10_TOTAL + 1))
  TEST_NUM=$(echo "$TEST_COUNT" | tr -dc '0-9')
  if [ "$TEST_NUM" -ge 110 ]; then
    P10_PASS=$((P10_PASS + 1))
  fi

  # Gate 12: MirrorWindowInfo struct exists
  P10_TOTAL=$((P10_TOTAL + 1))
  if grep -q "struct MirrorWindowInfo" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Mirror/MirrorBridge.swift" 2>/dev/null; then
    P10_PASS=$((P10_PASS + 1))
  fi

  if [ "$P10_PASS" -eq "$P10_TOTAL" ]; then
    P10_MIRROR="pass"
  else
    P10_MIRROR="fail ($P10_PASS/$P10_TOTAL)"
  fi
fi
echo "p10_mirror:       $P10_MIRROR"

# Phase 11 gates: CGEvent Simulator interaction
P11_CGEVENT_SIM="skip"
if [ "$PHASE" -ge 11 ] && [ "$CLI_STATUS" = "pass" ]; then
  P11_PASS=0
  P11_TOTAL=0

  # Gate 1: SimulatorBridge has CGEvent tap method
  P11_TOTAL=$((P11_TOTAL + 1))
  if grep -qE "func tap\b" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null; then
    P11_PASS=$((P11_PASS + 1))
  fi

  # Gate 2: SimulatorBridge has CGEvent swipe method
  P11_TOTAL=$((P11_TOTAL + 1))
  if grep -qE "func swipe\b" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null; then
    P11_PASS=$((P11_PASS + 1))
  fi

  # Gate 3: SimulatorBridge has directionToSwipeCoords
  P11_TOTAL=$((P11_TOTAL + 1))
  if grep -q "directionToSwipeCoords" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null; then
    P11_PASS=$((P11_PASS + 1))
  fi

  # Gate 4: SimulatorBridge has activateSimulator private helper
  P11_TOTAL=$((P11_TOTAL + 1))
  if grep -q "activateSimulator" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null; then
    P11_PASS=$((P11_PASS + 1))
  fi

  # Gate 5: CGEvent used in SimulatorBridge (not just IdbBridge)
  P11_TOTAL=$((P11_TOTAL + 1))
  if grep -q "CGEvent" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null; then
    P11_PASS=$((P11_PASS + 1))
  fi

  # Gate 6: version is 0.6.x or higher (forward-compatible)
  P11_TOTAL=$((P11_TOTAL + 1))
  VERSION_OUT=$("$BINARY_PATH" --version 2>&1 || true)
  if echo "$VERSION_OUT" | grep -qE "0\.[6-9]\.[0-9]+|0\.[1-9][0-9]+\.[0-9]+|[1-9]+\.[0-9]+\.[0-9]+"; then
    P11_PASS=$((P11_PASS + 1))
  fi

  # Gate 7: Tests >= 130
  P11_TOTAL=$((P11_TOTAL + 1))
  TEST_NUM=$(echo "$TEST_COUNT" | tr -dc '0-9')
  if [ "$TEST_NUM" -ge 130 ]; then
    P11_PASS=$((P11_PASS + 1))
  fi

  # Gate 8: SimulatorTests has >= 20 assertions (original 10 + 10 new for CGEvent)
  P11_TOTAL=$((P11_TOTAL + 1))
  SIM_ASSERTIONS=$(grep -cE "XCTAssert" "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/SimulatorTests.swift" 2>/dev/null || echo "0")
  if [ "$SIM_ASSERTIONS" -ge 20 ]; then
    P11_PASS=$((P11_PASS + 1))
  fi

  # Gate 9: click in sim mode outputs screenPoint in JSON
  P11_TOTAL=$((P11_TOTAL + 1))
  if grep -q "screenPoint" "$AGENT_SWIFT_DIR/Sources/agent-swift/main.swift" 2>/dev/null; then
    P11_PASS=$((P11_PASS + 1))
  fi

  # Gate 10: scroll in sim mode uses SimulatorBridge swipe (not just idb)
  P11_TOTAL=$((P11_TOTAL + 1))
  if grep -q "scrollSimulatorCGEvent\|SimulatorBridge.*swipe\|bridge\.swipe" "$AGENT_SWIFT_DIR/Sources/agent-swift/main.swift" 2>/dev/null; then
    P11_PASS=$((P11_PASS + 1))
  fi

  if [ "$P11_PASS" -eq "$P11_TOTAL" ]; then
    P11_CGEVENT_SIM="pass"
  else
    P11_CGEVENT_SIM="fail ($P11_PASS/$P11_TOTAL)"
  fi
fi
echo "p11_cgevent_sim:  $P11_CGEVENT_SIM"

# Phase 12 gates: User-driven UX (type, swipe, compound find, multi-sim)
P12_USER_UX="skip"
if [ "$PHASE" -ge 12 ] && [ "$CLI_STATUS" = "pass" ]; then
  P12_PASS=0
  P12_TOTAL=0

  # Gate 1: type command exists in help
  P12_TOTAL=$((P12_TOTAL + 1))
  if command_exists_in_help "type"; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 2: swipe command exists in help
  P12_TOTAL=$((P12_TOTAL + 1))
  if command_exists_in_help "swipe"; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 3: type command in schema output
  P12_TOTAL=$((P12_TOTAL + 1))
  "$BINARY_PATH" schema > /tmp/as-eval-schema12.json 2>&1 || true
  if python3 -c "import json; d=json.load(open('/tmp/as-eval-schema12.json')); assert any(c.get('name')=='type' for c in d)" 2>/dev/null; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 4: swipe command in schema output
  P12_TOTAL=$((P12_TOTAL + 1))
  if python3 -c "import json; d=json.load(open('/tmp/as-eval-schema12.json')); assert any(c.get('name')=='swipe' for c in d)" 2>/dev/null; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 5: TypeCommand struct exists in main.swift
  P12_TOTAL=$((P12_TOTAL + 1))
  if grep -q "struct TypeCommand" "$AGENT_SWIFT_DIR/Sources/agent-swift/main.swift" 2>/dev/null; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 6: SwipeCommand struct exists in main.swift
  P12_TOTAL=$((P12_TOTAL + 1))
  if grep -q "struct SwipeCommand" "$AGENT_SWIFT_DIR/Sources/agent-swift/main.swift" 2>/dev/null; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 7: connect --udid flag exists
  P12_TOTAL=$((P12_TOTAL + 1))
  "$BINARY_PATH" connect --help > /tmp/as-eval-connect-help12.txt 2>&1 || true
  if grep -q "udid" /tmp/as-eval-connect-help12.txt 2>/dev/null; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 8: snapshot --all flag exists
  P12_TOTAL=$((P12_TOTAL + 1))
  "$BINARY_PATH" snapshot --help > /tmp/as-eval-snapshot-help12.txt 2>&1 || true
  if grep -qi "\-\-all" /tmp/as-eval-snapshot-help12.txt 2>/dev/null; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 9: find handles compound locators (role+text pattern in source)
  P12_TOTAL=$((P12_TOTAL + 1))
  if grep -qE "compound|locatorPairs|locators.*role.*text" "$AGENT_SWIFT_DIR/Sources/agent-swift/main.swift" 2>/dev/null; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 10: version is 0.7.x or higher
  P12_TOTAL=$((P12_TOTAL + 1))
  VERSION_OUT=$("$BINARY_PATH" --version 2>&1 || true)
  if echo "$VERSION_OUT" | grep -qE "0\.[7-9]\.[0-9]+|0\.[1-9][0-9]+\.[0-9]+|[1-9]+\.[0-9]+\.[0-9]+"; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 11: Tests >= 145
  P12_TOTAL=$((P12_TOTAL + 1))
  TEST_NUM=$(echo "$TEST_COUNT" | tr -dc '0-9')
  if [ "$TEST_NUM" -ge 145 ]; then
    P12_PASS=$((P12_PASS + 1))
  fi

  # Gate 12: type --json on invalid state returns valid JSON error
  P12_TOTAL=$((P12_TOTAL + 1))
  "$BINARY_PATH" type "test" --json > /tmp/as-eval-type.json 2>&1 || true
  if json_check /tmp/as-eval-type.json json; then
    P12_PASS=$((P12_PASS + 1))
  fi

  if [ "$P12_PASS" -eq "$P12_TOTAL" ]; then
    P12_USER_UX="pass"
  else
    P12_USER_UX="fail ($P12_PASS/$P12_TOTAL)"
  fi
fi
echo "p12_user_ux:      $P12_USER_UX"

# Phase 13 gates: Screen video recording
P13_RECORDING="skip"
if [ "$PHASE" -ge 13 ] && [ "$CLI_STATUS" = "pass" ]; then
  P13_PASS=0
  P13_TOTAL=0

  # Gate 1: record command exists in help
  P13_TOTAL=$((P13_TOTAL + 1))
  if command_exists_in_help "record"; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 2: record --help shows start, stop, frame, status subcommands
  P13_TOTAL=$((P13_TOTAL + 1))
  "$BINARY_PATH" record --help > /tmp/as-eval-record-help.txt 2>&1 || true
  REC_SUBS=0
  for SUB in start stop frame status; do
    if grep -qi "$SUB" /tmp/as-eval-record-help.txt 2>/dev/null; then
      REC_SUBS=$((REC_SUBS + 1))
    fi
  done
  if [ "$REC_SUBS" -ge 4 ]; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 3: record appears in schema output
  P13_TOTAL=$((P13_TOTAL + 1))
  "$BINARY_PATH" schema > /tmp/as-eval-schema13.json 2>&1 || true
  if python3 -c "import json; d=json.load(open('/tmp/as-eval-schema13.json')); assert any(c.get('name')=='record' for c in d)" 2>/dev/null; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 4: RecordingSession in SessionStore.swift
  P13_TOTAL=$((P13_TOTAL + 1))
  if grep -q "RecordingSession\|recordingSession\|recording" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Session/SessionStore.swift" 2>/dev/null; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 5: record status --json returns valid JSON
  P13_TOTAL=$((P13_TOTAL + 1))
  "$BINARY_PATH" record status --json > /tmp/as-eval-record-status13.json 2>&1 || true
  if json_check /tmp/as-eval-record-status13.json json; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 6: record stop without recording exits 2 (use clean session dir)
  P13_TOTAL=$((P13_TOTAL + 1))
  CLEAN_HOME=$(mktemp -d)
  AGENT_SWIFT_HOME="$CLEAN_HOME" "$BINARY_PATH" record stop --json > /tmp/as-eval-record-stop13.json 2>&1
  STOP_EC=$?
  rm -rf "$CLEAN_HOME"
  if [ "$STOP_EC" -eq 2 ]; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 7: ffmpeg check referenced in source (graceful error)
  P13_TOTAL=$((P13_TOTAL + 1))
  if grep -q "ffmpeg" "$AGENT_SWIFT_DIR/Sources/agent-swift/main.swift" 2>/dev/null; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 8: simctl recordVideo referenced in source
  P13_TOTAL=$((P13_TOTAL + 1))
  if grep -q "recordVideo" "$AGENT_SWIFT_DIR/Sources/agent-swift/main.swift" 2>/dev/null || \
     grep -q "recordVideo" "$AGENT_SWIFT_DIR/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 9: version is 0.8.x or higher
  P13_TOTAL=$((P13_TOTAL + 1))
  VERSION_OUT=$("$BINARY_PATH" --version 2>&1 || true)
  if echo "$VERSION_OUT" | grep -qE "0\.[8-9]\.[0-9]+|0\.[1-9][0-9]+\.[0-9]+|[1-9]+\.[0-9]+\.[0-9]+"; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 10: RecordingTests.swift exists
  P13_TOTAL=$((P13_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/RecordingTests.swift" ]; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 11: >= 15 XCTAssert calls in RecordingTests
  P13_TOTAL=$((P13_TOTAL + 1))
  REC_ASSERTIONS=$(grep -cE "XCTAssert" "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/RecordingTests.swift" 2>/dev/null || echo "0")
  if [ "$REC_ASSERTIONS" -ge 15 ]; then
    P13_PASS=$((P13_PASS + 1))
  fi

  # Gate 12: Tests >= 165
  P13_TOTAL=$((P13_TOTAL + 1))
  TEST_NUM=$(echo "$TEST_COUNT" | tr -dc '0-9')
  if [ "$TEST_NUM" -ge 165 ]; then
    P13_PASS=$((P13_PASS + 1))
  fi

  if [ "$P13_PASS" -eq "$P13_TOTAL" ]; then
    P13_RECORDING="pass"
  else
    P13_RECORDING="fail ($P13_PASS/$P13_TOTAL)"
  fi
fi
echo "p13_recording:    $P13_RECORDING"

# Phase 14 gates: Frame processing (resize, dedup, crop, batch)
P14_FRAME_PROC="skip"
if [ "$PHASE" -ge 14 ] && [ "$BUILD_STATUS" = "pass" ]; then
  P14_PASS=0
  P14_TOTAL=0

  # 1. record frame --help mentions --max-width
  P14_TOTAL=$((P14_TOTAL + 1))
  if "$BINARY_PATH" record frame --help 2>&1 | grep -q "max-width"; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 2. record frame --help mentions --crop
  P14_TOTAL=$((P14_TOTAL + 1))
  if "$BINARY_PATH" record frame --help 2>&1 | grep -q "\-\-crop"; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 3. record frame --help mentions --dedup-threshold
  P14_TOTAL=$((P14_TOTAL + 1))
  if "$BINARY_PATH" record frame --help 2>&1 | grep -q "dedup-threshold"; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 4. record frames subcommand exists
  P14_TOTAL=$((P14_TOTAL + 1))
  if "$BINARY_PATH" record frames --help 2>&1 | grep -q "frames\|every\|batch"; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 5. record frames --help mentions --every
  P14_TOTAL=$((P14_TOTAL + 1))
  if "$BINARY_PATH" record frames --help 2>&1 | grep -q "\-\-every"; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 6. schema mentions --max-width or --crop or --dedup-threshold
  P14_TOTAL=$((P14_TOTAL + 1))
  if "$BINARY_PATH" schema 2>&1 | grep -q "max-width\|dedup-threshold\|crop"; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 7. lastFramePath in source
  P14_TOTAL=$((P14_TOTAL + 1))
  if grep -rq "lastFramePath" "$AGENT_SWIFT_DIR/Sources/"; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 8. sips in source (for resize/crop)
  P14_TOTAL=$((P14_TOTAL + 1))
  if grep -rq "sips" "$AGENT_SWIFT_DIR/Sources/"; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 9. FrameProcessingTests.swift exists
  P14_TOTAL=$((P14_TOTAL + 1))
  if [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/FrameProcessingTests.swift" ]; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 10. >= 15 assertions in FrameProcessingTests
  P14_TOTAL=$((P14_TOTAL + 1))
  FP_ASSERTS=0
  if [ -f "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/FrameProcessingTests.swift" ]; then
    FP_ASSERTS=$(grep -c "XCTAssert" "$AGENT_SWIFT_DIR/Tests/agent-swiftTests/FrameProcessingTests.swift" 2>/dev/null || echo 0)
  fi
  if [ "$FP_ASSERTS" -ge 15 ]; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 11. version 0.9.x
  P14_TOTAL=$((P14_TOTAL + 1))
  if "$BINARY_PATH" --version 2>&1 | grep -qE "^0\.9\.[0-9]+"; then
    P14_PASS=$((P14_PASS + 1))
  fi

  # 12. total tests >= 195
  P14_TOTAL=$((P14_TOTAL + 1))
  if [ "$TEST_COUNT" -ge 195 ]; then
    P14_PASS=$((P14_PASS + 1))
  fi

  if [ "$P14_PASS" -eq "$P14_TOTAL" ]; then
    P14_FRAME_PROC="pass"
  else
    P14_FRAME_PROC="fail ($P14_PASS/$P14_TOTAL)"
  fi
fi
echo "p14_frame_proc:   $P14_FRAME_PROC"

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
         [ "$P3_INTERACTION" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    4)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    5)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    6)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ] && \
         [ "$P2B_WIDGET" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    7)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ] && \
         [ "$P2B_WIDGET" = "pass" ] && \
         [ "$P7_CLICK" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    8)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ] && \
         [ "$P2B_WIDGET" = "pass" ] && \
         [ "$P7_CLICK" = "pass" ] && \
         [ "$P8_SIMULATOR" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    9)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ] && \
         [ "$P2B_WIDGET" = "pass" ] && \
         [ "$P7_CLICK" = "pass" ] && \
         [ "$P8_SIMULATOR" = "pass" ] && \
         [ "$P9_IDB" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    10)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ] && \
         [ "$P2B_WIDGET" = "pass" ] && \
         [ "$P7_CLICK" = "pass" ] && \
         [ "$P8_SIMULATOR" = "pass" ] && \
         [ "$P9_IDB" = "pass" ] && \
         [ "$P10_MIRROR" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    11)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ] && \
         [ "$P2B_WIDGET" = "pass" ] && \
         [ "$P7_CLICK" = "pass" ] && \
         [ "$P8_SIMULATOR" = "pass" ] && \
         [ "$P9_IDB" = "pass" ] && \
         [ "$P10_MIRROR" = "pass" ] && \
         [ "$P11_CGEVENT_SIM" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    12)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ] && \
         [ "$P2B_WIDGET" = "pass" ] && \
         [ "$P7_CLICK" = "pass" ] && \
         [ "$P8_SIMULATOR" = "pass" ] && \
         [ "$P9_IDB" = "pass" ] && \
         [ "$P10_MIRROR" = "pass" ] && \
         [ "$P11_CGEVENT_SIM" = "pass" ] && \
         [ "$P12_USER_UX" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    13)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ] && \
         [ "$P2B_WIDGET" = "pass" ] && \
         [ "$P7_CLICK" = "pass" ] && \
         [ "$P8_SIMULATOR" = "pass" ] && \
         [ "$P9_IDB" = "pass" ] && \
         [ "$P10_MIRROR" = "pass" ] && \
         [ "$P11_CGEVENT_SIM" = "pass" ] && \
         [ "$P12_USER_UX" = "pass" ] && \
         [ "$P13_RECORDING" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    14)
      if [ "$HELP_STATUS" = "pass" ] && \
         [ "$JSON_STATUS" = "pass" ] && \
         [ "$EXIT_STATUS" = "pass" ] && \
         [ "$P3_INTERACTION" = "pass" ] && \
         [ "$P4_AUTONOMY" = "pass" ] && \
         [ "$P5_POLISH" = "pass" ] && \
         [ "$P2B_WIDGET" = "pass" ] && \
         [ "$P7_CLICK" = "pass" ] && \
         [ "$P8_SIMULATOR" = "pass" ] && \
         [ "$P9_IDB" = "pass" ] && \
         [ "$P10_MIRROR" = "pass" ] && \
         [ "$P11_CGEVENT_SIM" = "pass" ] && \
         [ "$P12_USER_UX" = "pass" ] && \
         [ "$P13_RECORDING" = "pass" ] && \
         [ "$P14_FRAME_PROC" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
  esac
fi
echo "phase_complete:   $PHASE_COMPLETE"
echo "---"
