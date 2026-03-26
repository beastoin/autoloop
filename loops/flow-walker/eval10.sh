#!/usr/bin/env bash
# Eval harness for flow-walker Phase 10 (desktop app support / agent-swift).
# Usage: bash loops/flow-walker/eval10.sh
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

echo "=== flow-walker Phase 10 eval ==="

# Gate 1 (AC1): AgentType exported from types.ts
echo ""
echo "── Gate 1: AgentType export ──"
check "AC1: types.ts exports AgentType" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { AgentType } from \"./src/types.ts\";
    // AgentType is a type alias — verify it compiles (TS strips it)
  ' 2>&1 || true
  # Type-only export: verify it exists in source
  grep -q 'export type AgentType' src/types.ts
"

# Gate 2 (AC2): detectAgentType function
echo ""
echo "── Gate 2: detectAgentType ──"
check "AC2: detectAgentType returns 'swift' for agent-swift paths" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { detectAgentType } from \"./src/agent-bridge.ts\";
    if (typeof detectAgentType !== \"function\") process.exit(1);
    if (detectAgentType(\"agent-swift\") !== \"swift\") process.exit(1);
    if (detectAgentType(\"/usr/local/bin/agent-swift\") !== \"swift\") process.exit(1);
    if (detectAgentType(\"agent-flutter\") !== \"flutter\") process.exit(1);
    if (detectAgentType(\"/usr/local/bin/agent-flutter\") !== \"flutter\") process.exit(1);
  '
"

# Gate 3 (AC3): AgentBridge accepts agentType
echo ""
echo "── Gate 3: AgentBridge constructor ──"
check "AC3: AgentBridge constructor accepts agentType parameter" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { AgentBridge } from \"./src/agent-bridge.ts\";
    const b1 = new AgentBridge(\"agent-flutter\", 5000, \"flutter\");
    const b2 = new AgentBridge(\"agent-swift\", 5000, \"swift\");
    // No error = pass
  '
"

# Gate 4 (AC4): exec sets AGENT_SWIFT_JSON for swift
echo ""
echo "── Gate 4: AGENT_SWIFT_JSON env ──"
check "AC4: AgentBridge uses AGENT_SWIFT_JSON for swift agent" bash -c "
  cd '$WALKER_DIR' &&
  grep -q 'AGENT_SWIFT_JSON' src/agent-bridge.ts
"

# Gate 5 (AC5): textPress uses 'find text X press' for swift
echo ""
echo "── Gate 5: textPress swift syntax ──"
check "AC5: textPress uses 'find text' for swift" bash -c "
  cd '$WALKER_DIR' &&
  grep -q 'find' src/agent-bridge.ts &&
  grep -q 'text.*press' src/agent-bridge.ts
"

# Gate 6 (AC6): --agent flag accepted
echo ""
echo "── Gate 6: --agent CLI flag ──"
check "AC6: --agent flag in CLI parseArgs" bash -c "
  cd '$WALKER_DIR' &&
  grep -q \"'agent'\" src/cli.ts
"

# Gate 7 (AC7): --agent-path flag works
echo ""
echo "── Gate 7: --agent-path CLI flag ──"
check "AC7: --agent-path flag in CLI parseArgs" bash -c "
  cd '$WALKER_DIR' &&
  grep -q \"'agent-path'\" src/cli.ts
"

# Gate 8 (AC8): Schema version 2.1.0 with new flags
echo ""
echo "── Gate 8: Schema version and flags ──"
check "AC8: SCHEMA_VERSION is 2.1.0 and walk has --agent flag" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { SCHEMA_VERSION, getCommandSchema } from \"./src/command-schema.ts\";
    if (SCHEMA_VERSION !== \"2.1.0\") process.exit(1);
    const walk = getCommandSchema(\"walk\");
    if (!walk) process.exit(1);
    const agentFlag = walk.flags.find(f => f.name === \"--agent\");
    if (!agentFlag) process.exit(1);
    if (!agentFlag.enum || !agentFlag.enum.includes(\"swift\")) process.exit(1);
    const pathFlag = walk.flags.find(f => f.name === \"--agent-path\");
    if (!pathFlag) process.exit(1);
  '
"

# Gate 9 (AC9): Usage mentions both agents
echo ""
echo "── Gate 9: Usage text ──"
check "AC9: Help text mentions agent-swift" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types src/cli.ts --help 2>&1 | grep -qi 'swift\|desktop'
"

# Gate 10 (AC10): Package version 0.3.0
echo ""
echo "── Gate 10: Package version ──"
check "AC10: package.json version is 0.3.0" bash -c "
  cd '$WALKER_DIR' &&
  node -e 'const p = require(\"./package.json\"); if (p.version !== \"0.3.0\") process.exit(1);'
"

# Gate 11 (AC11): Typecheck
echo ""
echo "── Gate 11: Typecheck ──"
check "AC11: npx tsc --noEmit passes" bash -c "
  cd '$WALKER_DIR' && npx tsc --noEmit 2>&1
"

# Gate 12 (AC12): Tests pass with sufficient count
echo ""
echo "── Gate 12: Tests ──"
TEST_LOG=$(mktemp)
(cd "$WALKER_DIR" && npm test >"$TEST_LOG" 2>&1)
TEST_EXIT=$?
TEST_COUNT=$(grep -oE 'tests [0-9]+' "$TEST_LOG" | awk '{print $2}' | tail -n1)
check "AC12: npm test passes and test count >= 290 (was ${TEST_COUNT:-0})" bash -c "
  [ '$TEST_EXIT' -eq 0 ] &&
  grep -q 'fail 0' '$TEST_LOG' &&
  [ '${TEST_COUNT:-0}' -ge 290 ]
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
