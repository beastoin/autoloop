#!/usr/bin/env bash
# Eval harness for flow-walker Phase 6 (Agent-friendly run data + app metadata).
# Usage: bash loops/flow-walker/eval6.sh
# DO NOT MODIFY THIS FILE DURING ACTIVE LOOP.

set -uo pipefail
cd "$(dirname "$0")/../.."

export PATH="/home/claude/tools/node/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export NODE_OPTIONS="--experimental-strip-types"

WALKER_DIR="loops/flow-walker/flow-walker"
WORKER_DIR="loops/flow-walker/worker"
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

echo "=== flow-walker Phase 6 eval ==="

# ── Gate 1: Phase 5 still passes ──
echo ""
echo "── Gate 1: Phase 5 regression ──"
check "Phase 5 eval passes" bash loops/flow-walker/eval5.sh

# ── Gate 2: Worker serves run data ──
echo ""
echo "── Gate 2: Run data endpoint ──"
check "worker handles GET /runs/:id/data" bash -c "
  grep -rqE '/data|handleGetData|run\.json' '$WORKER_DIR/src/'
"
check "worker handles PUT /runs/:id/data" bash -c "
  grep -rqE 'PUT.*data|handlePutData|run\.json' '$WORKER_DIR/src/'
"
check "worker supports Accept: application/json" bash -c "
  grep -rqE 'Accept|application/json|content.negoti' '$WORKER_DIR/src/'
"

# ── Gate 3: CLI uploads run.json ──
echo ""
echo "── Gate 3: CLI uploads run data ──"
check "push.ts uploads run.json" bash -c "
  grep -qE 'run\.json|runJson|runData' '$WALKER_DIR/src/push.ts'
"
check "push.ts sends PUT or POST for data" bash -c "
  grep -qE 'PUT|/data' '$WALKER_DIR/src/push.ts'
"

# ── Gate 4: App metadata in flow parser ──
echo ""
echo "── Gate 4: App metadata ──"
check "flow-parser handles app field" bash -c "
  grep -qE 'app:|app_url|appUrl|appName' '$WALKER_DIR/src/flow-parser.ts'
"
check "types.ts has app fields" bash -c "
  grep -qE 'app|appUrl' '$WALKER_DIR/src/types.ts'
"
check "push sends app metadata headers" bash -c "
  grep -qE 'X-App-Name|X-App-URL|appName|app_url' '$WALKER_DIR/src/push.ts'
"

# ── Gate 5: Landing page shows app info ──
echo ""
echo "── Gate 5: Landing page app info ──"
check "worker renders app name" bash -c "
  grep -rqE 'appName|app_name|flowName.*app' '$WORKER_DIR/src/'
"

# ── Gate 6: Typecheck ──
echo ""
echo "── Gate 6: Typecheck ──"
check "CLI typecheck passes" bash -c "cd '$WALKER_DIR' && npx tsc --noEmit 2>&1"

# ── Gate 7: Tests ──
echo ""
echo "── Gate 7: Tests ──"
TEST_OUTPUT=$(cd "$WALKER_DIR" && npm test 2>&1)
check "all tests pass" bash -c "echo '$TEST_OUTPUT' | grep -q 'fail 0'"

TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -oP 'tests \K\d+' || echo "0")
check "test count > 199 (was $TEST_COUNT)" bash -c "[ '$TEST_COUNT' -gt 199 ]"

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
