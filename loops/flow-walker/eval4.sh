#!/usr/bin/env bash
# Eval harness for flow-walker Phase 4 (Hosted reports — push command).
# Usage: bash loops/flow-walker/eval4.sh
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

echo "=== flow-walker Phase 4 eval ==="

# ── Gate 1: Phase 3 still passes ──
echo ""
echo "── Gate 1: Phase 3 regression ──"
check "Phase 3 eval passes" bash loops/flow-walker/eval3.sh

# ── Gate 2: Worker source exists ──
echo ""
echo "── Gate 2: Worker source ──"
check "worker directory exists" test -d "$WORKER_DIR"
check "worker has entry point" bash -c "
  test -f '$WORKER_DIR/src/index.ts' || test -f '$WORKER_DIR/src/worker.ts' || test -f '$WORKER_DIR/index.ts'
"
check "worker has wrangler config" bash -c "
  test -f '$WORKER_DIR/wrangler.toml' || test -f '$WORKER_DIR/wrangler.jsonc'
"

# ── Gate 3: CLI push command ──
echo ""
echo "── Gate 3: CLI push command ──"
check "cli.ts handles push subcommand" bash -c "
  grep -qE 'push|handlePush' '$WALKER_DIR/src/cli.ts'
"
check "push command in schema" bash -c "
  grep -qE \"'push'|\\\"push\\\"\" '$WALKER_DIR/src/command-schema.ts'
"
check "push uses run ID from run.json" bash -c "
  grep -qE 'run.json|runResult|runId|run_id' '$WALKER_DIR/src/cli.ts'
"

# ── Gate 4: Upload logic ──
echo ""
echo "── Gate 4: Upload logic ──"
check "upload module exists" bash -c "
  test -f '$WALKER_DIR/src/upload.ts' || test -f '$WALKER_DIR/src/push.ts'
"
check "upload uses fetch or http" bash -c "
  grep -qE 'fetch|https?://' '$WALKER_DIR/src/upload.ts' || grep -qE 'fetch|https?://' '$WALKER_DIR/src/push.ts'
"
check "upload returns URL" bash -c "
  grep -qE 'url|URL' '$WALKER_DIR/src/upload.ts' || grep -qE 'url|URL' '$WALKER_DIR/src/push.ts'
"

# ── Gate 5: Environment variable for API URL ──
echo ""
echo "── Gate 5: Configuration ──"
check "FLOW_WALKER_API_URL env var" bash -c "
  grep -qE 'FLOW_WALKER_API_URL' '$WALKER_DIR/src/cli.ts' || grep -qE 'FLOW_WALKER_API_URL' '$WALKER_DIR/src/upload.ts' || grep -qE 'FLOW_WALKER_API_URL' '$WALKER_DIR/src/push.ts'
"

# ── Gate 6: Worker handles routes ──
echo ""
echo "── Gate 6: Worker routes ──"
check "worker handles GET /runs/:id" bash -c "
  grep -rqE 'GET|runs|/runs/' '$WORKER_DIR/src/'
"
check "worker handles POST /runs" bash -c "
  grep -rqE 'POST|upload|put' '$WORKER_DIR/src/'
"
check "worker accesses R2" bash -c "
  grep -rqE 'R2|r2|bucket|BUCKET' '$WORKER_DIR/src/'
"

# ── Gate 7: Typecheck ──
echo ""
echo "── Gate 7: Typecheck ──"
check "CLI typecheck passes" bash -c "cd '$WALKER_DIR' && npx tsc --noEmit 2>&1"

# ── Gate 8: Tests ──
echo ""
echo "── Gate 8: Tests ──"
TEST_OUTPUT=$(cd "$WALKER_DIR" && npm test 2>&1)
check "all tests pass" bash -c "echo '$TEST_OUTPUT' | grep -q 'fail 0'"

TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -oP 'tests \K\d+' || echo "0")
check "test count > 189 (was $TEST_COUNT)" bash -c "[ '$TEST_COUNT' -gt 189 ]"

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
