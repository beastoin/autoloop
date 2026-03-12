#!/usr/bin/env bash
# Eval harness for flow-walker Phase 2 (Run + Report).
# Usage: bash loops/flow-walker/eval2.sh
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

echo "=== flow-walker Phase 2 eval ==="

# ── Gate 1: Phase 1 still passes ──
echo ""
echo "── Gate 1: Phase 1 regression ──"
check "Phase 1 eval passes" bash loops/flow-walker/eval.sh

# ── Gate 2: New source files exist ──
echo ""
echo "── Gate 2: New source files ──"
check "src/flow-parser.ts exists" test -f "$WALKER_DIR/src/flow-parser.ts"
check "src/runner.ts exists" test -f "$WALKER_DIR/src/runner.ts"
check "src/reporter.ts exists" test -f "$WALKER_DIR/src/reporter.ts"
check "src/capture.ts exists" test -f "$WALKER_DIR/src/capture.ts"
check "src/run-schema.ts exists" test -f "$WALKER_DIR/src/run-schema.ts"

# ── Gate 3: Typecheck ──
echo ""
echo "── Gate 3: Typecheck ──"
check "typecheck passes" bash -c "cd '$WALKER_DIR' && npx tsc --noEmit 2>&1"

# ── Gate 4: All tests pass ──
echo ""
echo "── Gate 4: Tests ──"
TEST_OUTPUT=$(cd "$WALKER_DIR" && npm test 2>&1)
check "all tests pass" bash -c "echo '$TEST_OUTPUT' | grep -q 'fail 0'"

# Count tests — must be more than Phase 1's 43
TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -oP 'tests \K\d+' || echo "0")
check "test count > 43 (was $TEST_COUNT)" bash -c "[ '$TEST_COUNT' -gt 43 ]"

# ── Gate 5: Module contracts ──
echo ""
echo "── Gate 5: Module contracts ──"

check "flow-parser exports parseFlow" bash -c "
  grep -qE 'export.*(parseFlow|FlowParser)' '$WALKER_DIR/src/flow-parser.ts'
"

check "runner exports runFlow" bash -c "
  grep -qE 'export.*(runFlow|FlowRunner|executeFlow)' '$WALKER_DIR/src/runner.ts'
"

check "reporter exports generateReport" bash -c "
  grep -qE 'export.*(generateReport|Reporter|buildHtml)' '$WALKER_DIR/src/reporter.ts'
"

check "capture exports screenshot/video helpers" bash -c "
  grep -qE 'export.*(screenshot|screenrecord|captureVideo|startRecording)' '$WALKER_DIR/src/capture.ts'
"

check "run-schema exports RunResult type" bash -c "
  grep -qE 'export.*(RunResult|RunData|FlowRun)' '$WALKER_DIR/src/run-schema.ts'
"

# ── Gate 6: CLI subcommands ──
echo ""
echo "── Gate 6: CLI subcommands ──"

check "CLI has 'run' subcommand" bash -c "
  grep -qE \"'run'|\\\"run\\\"\" '$WALKER_DIR/src/cli.ts'
"

check "CLI has 'report' subcommand" bash -c "
  grep -qE \"'report'|\\\"report\\\"\" '$WALKER_DIR/src/cli.ts'
"

check "CLI still has 'walk' subcommand" bash -c "
  grep -qE \"'walk'|\\\"walk\\\"\" '$WALKER_DIR/src/cli.ts'
"

# ── Gate 7: YAML parser tests ──
echo ""
echo "── Gate 7: Flow parser tests ──"

check "tests parse YAML steps" bash -c "
  grep -qE '(steps|press|scroll|fill|back|assert)' '$WALKER_DIR/tests/flow-parser.test.ts'
"

check "tests validate flow structure" bash -c "
  grep -qE '(name|description|prerequisites|setup)' '$WALKER_DIR/tests/flow-parser.test.ts'
"

# ── Gate 8: Run schema tests ──
echo ""
echo "── Gate 8: Run schema tests ──"

check "tests cover run.json structure" bash -c "
  grep -qE '(steps|video|duration|result|pass|fail)' '$WALKER_DIR/tests/run-schema.test.ts'
"

# ── Gate 9: Reporter tests ──
echo ""
echo "── Gate 9: Reporter tests ──"

check "tests cover HTML generation" bash -c "
  grep -qE '(html|HTML|<video|<div|report)' '$WALKER_DIR/tests/reporter.test.ts'
"

check "tests verify video embedding" bash -c "
  grep -qE '(video|mp4|base64|embed)' '$WALKER_DIR/tests/reporter.test.ts'
"

check "tests verify step timeline" bash -c "
  grep -qE '(step|timeline|data-time|jumpTo|seek)' '$WALKER_DIR/tests/reporter.test.ts'
"

# ── Gate 10: Package metadata ──
echo ""
echo "── Gate 10: Package metadata ──"

check "package.json has bin entry" bash -c "
  grep -q '\"bin\"' '$WALKER_DIR/package.json'
"

check "LICENSE file exists" bash -c "
  test -f '$WALKER_DIR/LICENSE'
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
