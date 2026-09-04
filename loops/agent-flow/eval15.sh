#!/usr/bin/env bash
# Phase 15 eval: Audit remediation — bugs, rename cleanup, docs
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
SRC="loops/agent-flow/agent-flow"

PASS=0
FAIL=0
gate() {
  if eval "$2"; then echo "✅ $1"; ((PASS++)); else echo "❌ $1"; ((FAIL++)); fi
}

# HIGH: Run ID length
gate "run_id_10_chars" "grep -q 'randomBytes(7)' $SRC/src/record.ts"
gate "run_id_test" "grep -q 'length.*10\|toHaveLength.*10\|=== 10' $SRC/tests/record.test.ts"

# HIGH: Verify milestone+kind
gate "verify_checks_passed" "grep -A3 'milestone' $SRC/src/verify.ts | grep -qi 'passed\|result\|pass'"
gate "verify_milestone_test" "grep -qi 'milestone.*kind\|kind.*milestone\|combined.*milestone' $SRC/tests/verify.test.ts $SRC/tests/verify-audit.test.ts $SRC/tests/verify-tiers.test.ts"

# HIGH: agentResult fail path
gate "agent_result_fail" "grep -q \"'fail'\" $SRC/src/verify.ts"
gate "agent_result_fail_test" "grep -qi 'agentResult.*fail\|result.*fail' $SRC/tests/verify.test.ts $SRC/tests/verify-tiers.test.ts"

# MEDIUM: No stale run command in AGENTS.md
gate "agents_md_no_run" "! grep -q 'agent-flow run ' $SRC/AGENTS.md"

# MEDIUM: No FLOW_WALKER in README
gate "readme_no_flow_walker" "! grep -q 'FLOW_WALKER' $SRC/README.md"

# MEDIUM: Install docs correct
gate "readme_install_beastoin" "grep -q '@beastoin/agent-flow' $SRC/README.md"

# MEDIUM: package-lock.json updated
gate "lockfile_name" "grep -q '@beastoin/agent-flow' $SRC/package-lock.json"

# MEDIUM: evidence.video round-trip
gate "yaml_writer_evidence" "grep -q 'evidence' $SRC/src/yaml-writer.ts"

# LOW: Dead code removed
gate "no_parseInlineObj" "! grep -q 'parseInlineObj' $SRC/src/flow-parser.ts"
gate "no_FlowHints" "! grep -q 'FlowHints' $SRC/src/types.ts"

# Tests
gate "tests_pass" "(cd $SRC && npm test 2>&1 | grep -q 'fail 0')"
TEST_COUNT=$(cd $SRC && npm test 2>&1 | grep '^ℹ tests' | awk '{print $3}')
cd "$REPO_ROOT"
gate "test_count_gte_345" "[ \"${TEST_COUNT:-0}\" -ge 345 ]"

# Typecheck
gate "typecheck" "(cd $SRC && npx tsc --noEmit > /dev/null 2>&1)"

echo ""
echo "Phase 15 eval: $PASS passed, $FAIL failed"
if [ $FAIL -eq 0 ]; then echo "phase_complete=yes"; else echo "phase_complete=no"; fi
