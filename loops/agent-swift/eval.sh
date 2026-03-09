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
    "get", "find", "wait", "is", "scroll", "screenshot", "schema"
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

  # Gate 1: version is 0.2.0
  P5_TOTAL=$((P5_TOTAL + 1))
  VERSION_OUT=$("$BINARY_PATH" --version 2>&1 || true)
  if echo "$VERSION_OUT" | grep -q "0.2.0"; then
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
  esac
fi
echo "phase_complete:   $PHASE_COMPLETE"
echo "---"
