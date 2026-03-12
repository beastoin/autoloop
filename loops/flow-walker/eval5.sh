#!/usr/bin/env bash
# Eval harness for flow-walker Phase 5 (Landing page with live metrics).
# Usage: bash loops/flow-walker/eval5.sh
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

echo "=== flow-walker Phase 5 eval ==="

# ── Gate 1: Phase 4 still passes ──
echo ""
echo "── Gate 1: Phase 4 regression ──"
check "Phase 4 eval passes" bash loops/flow-walker/eval4.sh

# ── Gate 2: Worker serves HTML landing page ──
echo ""
echo "── Gate 2: Landing page HTML ──"
check "worker has landing page handler" bash -c "
  grep -qE 'handleLanding|landingPage|renderLanding|buildLandingPage' '$WORKER_DIR/src/worker.ts'
"
check "landing page returns HTML content type" bash -c "
  grep -qE 'text/html' '$WORKER_DIR/src/worker.ts' | true
  grep -rqE 'landingHtml|pageHtml|html.*<!DOCTYPE|<html' '$WORKER_DIR/src/'
"
check "landing page has hero section" bash -c "
  grep -rqE 'hero|headline|flow-walker' '$WORKER_DIR/src/'
"

# ── Gate 3: Stats tracking ──
echo ""
echo "── Gate 3: Stats tracking ──"
check "stats.json key in R2" bash -c "
  grep -rqE 'stats.json|stats_key|STATS_KEY' '$WORKER_DIR/src/'
"
check "stats updated on push" bash -c "
  grep -rqE 'updateStats|incrementStats|saveStats' '$WORKER_DIR/src/'
"
check "stats has totalRuns or totalReports" bash -c "
  grep -rqE 'totalRuns|totalReports' '$WORKER_DIR/src/'
"
check "recent runs tracked" bash -c "
  grep -rqE 'recentRuns|recent.*runs|lastRuns' '$WORKER_DIR/src/'
"

# ── Gate 4: API endpoint ──
echo ""
echo "── Gate 4: Stats API ──"
check "GET /api/stats route exists" bash -c "
  grep -rqE '/api/stats' '$WORKER_DIR/src/'
"

# ── Gate 5: No external dependencies ──
echo ""
echo "── Gate 5: No external deps ──"
check "no CDN links in worker" bash -c "
  ! grep -rqE 'cdn\.|googleapis\.|unpkg\.|jsdelivr\.' '$WORKER_DIR/src/'
"
check "no external font imports" bash -c "
  ! grep -rqE 'fonts\.googleapis|font-awesome|fontawesome' '$WORKER_DIR/src/'
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
check "test count > 196 (was $TEST_COUNT)" bash -c "[ '$TEST_COUNT' -gt 196 ]"

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
