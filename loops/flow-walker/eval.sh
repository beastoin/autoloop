#!/usr/bin/env bash
# Eval harness for flow-walker.
# Usage: bash loops/flow-walker/eval.sh
# DO NOT MODIFY THIS FILE.

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

echo "=== flow-walker eval ==="

# ── Gate 1: project exists ──
echo ""
echo "── Gate 1: Project structure ──"
check "package.json exists" test -f "$WALKER_DIR/package.json"
check "src/cli.ts exists" test -f "$WALKER_DIR/src/cli.ts"
check "src/walker.ts exists" test -f "$WALKER_DIR/src/walker.ts"
check "src/fingerprint.ts exists" test -f "$WALKER_DIR/src/fingerprint.ts"
check "src/graph.ts exists" test -f "$WALKER_DIR/src/graph.ts"
check "src/safety.ts exists" test -f "$WALKER_DIR/src/safety.ts"
check "src/yaml-writer.ts exists" test -f "$WALKER_DIR/src/yaml-writer.ts"
check "src/agent-bridge.ts exists" test -f "$WALKER_DIR/src/agent-bridge.ts"

# ── Gate 2: dependencies install ──
echo ""
echo "── Gate 2: Install ──"
if [ -d "$WALKER_DIR/node_modules" ]; then
  check "node_modules exists" true
else
  echo "  Installing dependencies..."
  (cd "$WALKER_DIR" && npm install --silent 2>&1) && check "npm install" true || check "npm install" false
fi

# ── Gate 3: typecheck ──
echo ""
echo "── Gate 3: Typecheck ──"
check "typecheck passes" bash -c "cd '$WALKER_DIR' && npx tsc --noEmit 2>&1"

# ── Gate 4: unit tests ──
echo ""
echo "── Gate 4: Tests ──"
check "unit tests pass" bash -c "cd '$WALKER_DIR' && npm test 2>&1"

# ── Gate 5: module contracts ──
echo ""
echo "── Gate 5: Module contracts ──"

# fingerprint module exports computeFingerprint
check "fingerprint exports computeFingerprint" bash -c "
  grep -q 'export.*computeFingerprint' '$WALKER_DIR/src/fingerprint.ts'
"

# safety module exports isSafe
check "safety exports isSafe" bash -c "
  grep -q 'export.*isSafe' '$WALKER_DIR/src/safety.ts'
"

# graph module exports NavigationGraph or addScreen/addEdge
check "graph exports graph operations" bash -c "
  grep -qE 'export.*(NavigationGraph|addScreen|addEdge|class.*Graph)' '$WALKER_DIR/src/graph.ts'
"

# yaml-writer module exports a write/generate function
check "yaml-writer exports generator" bash -c "
  grep -qE 'export.*(writeFlows|generateYaml|toYaml|FlowWriter)' '$WALKER_DIR/src/yaml-writer.ts'
"

# agent-bridge module exports connect/snapshot/press/back
check "agent-bridge exports agent commands" bash -c "
  grep -qE 'export.*(snapshot|press|connect|AgentBridge)' '$WALKER_DIR/src/agent-bridge.ts'
"

# ── Gate 6: YAML output contract ──
echo ""
echo "── Gate 6: YAML output contract ──"

# tests verify YAML structure matches reference format
check "tests cover YAML structure" bash -c "
  grep -qE '(name:|steps:|assert:|screenshot:)' '$WALKER_DIR/tests/yaml-writer.test.ts' 2>/dev/null ||
  grep -qE '(name:|steps:|assert:|screenshot:)' '$WALKER_DIR/tests/yaml-writer.test.mts' 2>/dev/null
"

# tests verify fingerprint determinism
check "tests cover fingerprint determinism" bash -c "
  grep -qE '(deterministic|same.*hash|stable|identical)' '$WALKER_DIR/tests/fingerprint.test.ts' 2>/dev/null ||
  grep -qE '(deterministic|same.*hash|stable|identical)' '$WALKER_DIR/tests/fingerprint.test.mts' 2>/dev/null
"

# tests verify blocklist safety
check "tests cover blocklist safety" bash -c "
  grep -qE '(blocklist|block.*list|dangerous|unsafe|delete|sign.out)' '$WALKER_DIR/tests/safety.test.ts' 2>/dev/null ||
  grep -qE '(blocklist|block.*list|dangerous|unsafe|delete|sign.out)' '$WALKER_DIR/tests/safety.test.mts' 2>/dev/null
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
