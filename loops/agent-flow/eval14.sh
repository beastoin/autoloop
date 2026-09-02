#!/usr/bin/env bash
# Phase 14 eval: Rename flow-walker → agent-flow
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
gate() {
  if eval "$2"; then
    echo "✅ $1"
    ((PASS++))
  else
    echo "❌ $1"
    ((FAIL++))
  fi
}

# Directory structure
gate "directory_renamed" "[ -d loops/agent-flow/agent-flow/src ]"
gate "old_directory_gone" "[ ! -d loops/flow-walker ]"

# Package identity
gate "package_name" "grep -q '\"name\": \"agent-flow-cli\"' loops/agent-flow/agent-flow/package.json"
gate "bin_name" "grep -q '\"agent-flow\"' loops/agent-flow/agent-flow/package.json"
gate "version_060" "grep -q '\"version\": \"0.6.0\"' loops/agent-flow/agent-flow/package.json"

# Source code rename
gate "no_FlowWalkerError_in_src" "! grep -rq 'FlowWalkerError' loops/agent-flow/agent-flow/src/"
gate "has_AgentFlowError" "grep -q 'AgentFlowError' loops/agent-flow/agent-flow/src/errors.ts"
gate "cli_shows_agent_flow" "grep -q 'agent-flow' loops/agent-flow/agent-flow/src/cli.ts"
gate "no_flow_walker_in_cli" "! grep -q 'flow-walker' loops/agent-flow/agent-flow/src/cli.ts"

# Tests still pass
gate "tests_pass" "(cd loops/agent-flow/agent-flow && npm test 2>&1 | grep -q 'fail 0')"
TEST_COUNT=$(cd loops/agent-flow/agent-flow && npm test 2>&1 | grep '^ℹ tests' | awk '{print $3}')
cd "$REPO_ROOT"
gate "test_count_gte_336" "[ \"${TEST_COUNT:-0}\" -ge 336 ]"

# Documentation
gate "root_claude_md_has_agent_flow" "grep -q 'agent-flow' CLAUDE.md"
gate "root_claude_md_no_flow_walker" "! grep -q 'flow-walker' CLAUDE.md"
gate "loop_claude_md" "grep -q 'agent-flow' loops/agent-flow/CLAUDE.md"

# Worker
gate "wrangler_name" "grep -q 'name = \"agent-flow\"' loops/agent-flow/worker/wrangler.toml"

# No stale references in source
gate "no_flow_walker_in_errors" "! grep -qi 'flow.walker' loops/agent-flow/agent-flow/src/errors.ts"
gate "no_flow_walker_in_types" "! grep -qi 'flow.walker' loops/agent-flow/agent-flow/src/types.ts"

echo ""
echo "Phase 14 eval: $PASS passed, $FAIL failed"
if [ $FAIL -eq 0 ]; then echo "phase_complete=yes"; else echo "phase_complete=no"; fi
