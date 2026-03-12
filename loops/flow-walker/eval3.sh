#!/usr/bin/env bash
# Eval harness for flow-walker Phase 3 (Agent-grade foundation).
# Applies Poehnelt principles: structured errors, input hardening, schema, TTY-aware JSON.
# Usage: bash loops/flow-walker/eval3.sh
# DO NOT MODIFY THIS FILE DURING ACTIVE LOOP.

set -uo pipefail
cd "$(dirname "$0")/../.."

export PATH="/home/claude/tools/node/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export NODE_OPTIONS="--experimental-strip-types"

WALKER_DIR="loops/flow-walker/flow-walker"
PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== flow-walker Phase 3 eval ==="

# ── Gate 1: Phase 2 still passes ──
echo ""
echo "── Gate 1: Phase 2 regression ──"
check "Phase 2 eval passes" bash loops/flow-walker/eval2.sh

# ── Gate 2: New source files exist ──
echo ""
echo "── Gate 2: New source files ──"
check "src/errors.ts exists" test -f "$WALKER_DIR/src/errors.ts"
check "src/validate.ts exists" test -f "$WALKER_DIR/src/validate.ts"
check "src/command-schema.ts exists" test -f "$WALKER_DIR/src/command-schema.ts"

# ── Gate 3: Typecheck ──
echo ""
echo "── Gate 3: Typecheck ──"
check "typecheck passes" bash -c "cd '$WALKER_DIR' && npx tsc --noEmit 2>&1"

# ── Gate 4: All tests pass, count increased ──
echo ""
echo "── Gate 4: Tests ──"
TEST_OUTPUT=$(cd "$WALKER_DIR" && npm test 2>&1)
check "all tests pass" bash -c "echo '$TEST_OUTPUT' | grep -q 'fail 0'"

TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -oP 'tests \K\d+' || echo "0")
check "test count > 126 (was $TEST_COUNT)" bash -c "[ '$TEST_COUNT' -gt 126 ]"

# ── Gate 5: Structured errors ──
echo ""
echo "── Gate 5: Structured errors ──"

check "errors.ts exports FlowWalkerError" bash -c "
  grep -qE 'export.*(FlowWalkerError|class FlowWalkerError)' '$WALKER_DIR/src/errors.ts'
"

check "errors.ts exports ErrorCodes" bash -c "
  grep -qE 'export.*(ErrorCodes|ERROR_CODES)' '$WALKER_DIR/src/errors.ts'
"

check "errors.ts has diagnosticId" bash -c "
  grep -qE 'diagnosticId' '$WALKER_DIR/src/errors.ts'
"

check "errors.ts has hint field" bash -c "
  grep -qE 'hint' '$WALKER_DIR/src/errors.ts'
"

check "no raw Error() in runner.ts" bash -c "
  ! grep -qE 'new Error\(' '$WALKER_DIR/src/runner.ts'
"

check "no raw Error() in flow-parser.ts" bash -c "
  ! grep -qE 'new Error\(' '$WALKER_DIR/src/flow-parser.ts'
"

check "no raw Error() in agent-bridge.ts" bash -c "
  ! grep -qE 'new Error\(' '$WALKER_DIR/src/agent-bridge.ts'
"

# ── Gate 6: Input validation ──
echo ""
echo "── Gate 6: Input validation ──"

check "validate.ts exports validateFlowPath" bash -c "
  grep -qE 'export.*validateFlowPath' '$WALKER_DIR/src/validate.ts'
"

check "validate.ts exports validateOutputDir" bash -c "
  grep -qE 'export.*validateOutputDir' '$WALKER_DIR/src/validate.ts'
"

check "validate.ts exports validateUri" bash -c "
  grep -qE 'export.*validateUri' '$WALKER_DIR/src/validate.ts'
"

check "validate.ts rejects path traversal" bash -c "
  grep -qE '\.\.' '$WALKER_DIR/src/validate.ts'
"

check "validate.ts rejects control chars" bash -c "
  grep -qE 'control|\\\\x00|\\\\x1f|[\x00-\x1f]' '$WALKER_DIR/src/validate.ts'
"

check "cli.ts imports from validate.ts" bash -c "
  grep -qE 'validate' '$WALKER_DIR/src/cli.ts'
"

# ── Gate 7: Command schema ──
echo ""
echo "── Gate 7: Command schema ──"

check "command-schema.ts exports COMMAND_SCHEMAS" bash -c "
  grep -qE 'export.*(COMMAND_SCHEMAS|commandSchemas|schemas)' '$WALKER_DIR/src/command-schema.ts'
"

check "schema covers walk command" bash -c "
  grep -qE \"'walk'|\\\"walk\\\"\" '$WALKER_DIR/src/command-schema.ts'
"

check "schema covers run command" bash -c "
  grep -qE \"'run'|\\\"run\\\"\" '$WALKER_DIR/src/command-schema.ts'
"

check "schema covers report command" bash -c "
  grep -qE \"'report'|\\\"report\\\"\" '$WALKER_DIR/src/command-schema.ts'
"

check "CLI has schema subcommand" bash -c "
  grep -qE \"'schema'|\\\"schema\\\"\" '$WALKER_DIR/src/cli.ts'
"

# ── Gate 8: JSON mode resolution ──
echo ""
echo "── Gate 8: JSON mode resolution ──"

check "cli.ts has TTY detection" bash -c "
  grep -qE 'isTTY|TTY' '$WALKER_DIR/src/cli.ts'
"

check "cli.ts reads FLOW_WALKER_JSON env" bash -c "
  grep -qE 'FLOW_WALKER_JSON' '$WALKER_DIR/src/cli.ts'
"

check "cli.ts supports --no-json flag" bash -c "
  grep -qE 'no-json|noJson' '$WALKER_DIR/src/cli.ts'
"

# ── Gate 9: Dry-run for run command ──
echo ""
echo "── Gate 9: Dry-run ──"

check "runner.ts supports dry-run" bash -c "
  grep -qE 'dryRun|dry.?run|dry_run' '$WALKER_DIR/src/runner.ts'
"

check "cli.ts passes dry-run to run handler" bash -c "
  grep -qE 'dry' '$WALKER_DIR/src/cli.ts'
"

# ── Gate 10: NDJSON streaming for walk ──
echo ""
echo "── Gate 10: NDJSON streaming ──"

check "walker.ts emits JSON events" bash -c "
  grep -qE 'JSON.stringify.*type.*screen\|JSON.stringify.*type.*edge\|ndjson\|emit' '$WALKER_DIR/src/walker.ts'
"

# ── Gate 11: Environment variables ──
echo ""
echo "── Gate 11: Environment variables ──"

check "cli.ts reads FLOW_WALKER_OUTPUT_DIR" bash -c "
  grep -qE 'FLOW_WALKER_OUTPUT_DIR' '$WALKER_DIR/src/cli.ts'
"

check "cli.ts reads FLOW_WALKER_AGENT_PATH" bash -c "
  grep -qE 'FLOW_WALKER_AGENT_PATH' '$WALKER_DIR/src/cli.ts'
"

check "cli.ts reads FLOW_WALKER_DRY_RUN" bash -c "
  grep -qE 'FLOW_WALKER_DRY_RUN' '$WALKER_DIR/src/cli.ts'
"

# ── Gate 12: Test coverage for new modules ──
echo ""
echo "── Gate 12: Test coverage ──"

check "tests/errors.test.ts exists" test -f "$WALKER_DIR/tests/errors.test.ts"
check "tests/validate.test.ts exists" test -f "$WALKER_DIR/tests/validate.test.ts"
check "tests/command-schema.test.ts exists" test -f "$WALKER_DIR/tests/command-schema.test.ts"

check "error tests cover diagnosticId" bash -c "
  grep -qE 'diagnosticId' '$WALKER_DIR/tests/errors.test.ts'
"

check "validate tests cover path traversal" bash -c "
  grep -qE '\.\.|traversal' '$WALKER_DIR/tests/validate.test.ts'
"

check "validate tests cover control chars" bash -c "
  grep -qE 'control|\\\\x00|\\\\0' '$WALKER_DIR/tests/validate.test.ts'
"

check "schema tests verify all commands present" bash -c "
  grep -qE 'walk.*run.*report|schema.*walk|schema.*run' '$WALKER_DIR/tests/command-schema.test.ts'
"

# ── Summary ──
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  echo "EVAL: FAIL"
  exit 1
else
  echo "EVAL: PASS"
  exit 0
fi
