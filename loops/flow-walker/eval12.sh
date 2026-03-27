#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/flow-walker"

PASS=0; FAIL=0; TOTAL=0
check() { TOTAL=$((TOTAL+1)); if eval "$2" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1"; fi; }

# ── Typecheck ──
check "tsc clean" "npx tsc --noEmit"

# ── Tests pass ──
check "npm test" "npm test"

# ── Types: claim and judge fields ──
check "FlowV2Step has claim field" "grep -q 'claim' src/types.ts"
check "FlowV2Step has judge field" "grep -q 'judge' src/types.ts"
check "FlowV2Judge interface exists" "grep -q 'FlowV2Judge\|judge.*prompt' src/types.ts"

# ── Parser: claim and judge ──
check "parser handles claim" "grep -q 'claim' src/flow-parser.ts"
check "parser handles judge" "grep -q 'judge' src/flow-parser.ts"

# ── Verify: typed check results ──
check "verify has AutomatedCheck type" "grep -q 'AutomatedCheck\|automated' src/verify.ts"
check "verify has AgentCheck type" "grep -q 'AgentCheck\|agent.*prompt\|AgentPrompt' src/verify.ts"
check "verify stores actual values" "grep -q 'actual' src/verify.ts"
check "verify has no_evidence status" "grep -q 'no_evidence' src/verify.ts"
check "verify supports --recheck" "grep -q 'recheck' src/verify.ts"
check "verify supports --agent-prompt" "grep -q 'agent.prompt\|agentPrompt\|agent-prompt' src/verify.ts src/cli.ts"

# ── Reporter: two-tier layout ──
check "reporter shows claim as headline" "grep -q 'claim' src/reporter.ts"
check "reporter has automated section" "grep -qi 'automated\|Automated' src/reporter.ts"
check "reporter has agent section" "grep -qi 'agent.*verif\|Agent.*Review\|agent.*prompt' src/reporter.ts"
check "reporter shows expected vs actual" "grep -q 'expected\|Expected' src/reporter.ts"
check "reporter embeds JSON" "grep -q 'application/json\|report-data' src/reporter.ts"

# ── Command schema ──
check "schema has --recheck flag" "grep -q 'recheck' src/command-schema.ts"
check "schema has --agent-prompt flag" "grep -q 'agent-prompt' src/command-schema.ts"
check "schema version >= 3.0.0" "grep -q \"SCHEMA_VERSION = '3\" src/command-schema.ts"

# ── CLI routing ──
check "cli routes --recheck" "grep -q 'recheck' src/cli.ts"
check "cli routes --agent-prompt" "grep -q 'agent.prompt\|agentPrompt' src/cli.ts"

# ── Backward compatibility ──
check "v2 flows without claim still parse" "node --experimental-strip-types -e \"
  const { parseFlowV2 } = require('./src/flow-parser.ts');
  const f = parseFlowV2('version: 2\nname: test\nsteps:\n  - id: S1\n    do: check\n');
  if (!f.steps[0]) process.exit(1);
\" 2>/dev/null || node --experimental-strip-types -e '
  import { parseFlowV2 } from \"./src/flow-parser.ts\";
  const f = parseFlowV2(\"version: 2\\nname: test\\nsteps:\\n  - id: S1\\n    do: check\\n\");
  if (!f.steps[0]) process.exit(1);
'"

# ── Tests for new features ──
check "test file for two-tier verify" "test -f tests/verify-tiers.test.ts || test -f tests/verify-two-tier.test.ts"
check "test for claim parsing" "grep -rq 'claim' tests/flow-parser.test.ts"
check "test for judge parsing" "grep -rq 'judge' tests/flow-parser.test.ts"
check "test for agent prompt output" "grep -rq 'agent.*prompt\|agentPrompt' tests/"
check "test for recheck" "grep -rq 'recheck' tests/"
check "test for embedded JSON in report" "grep -rq 'report-data\|application/json' tests/reporter.test.ts"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "PHASE 12 PASSED" || echo "PHASE 12 FAILED"
exit "$FAIL"
