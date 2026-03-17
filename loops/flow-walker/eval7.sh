#!/usr/bin/env bash
# Eval harness for flow-walker Phase 7 (v2 contract core).
# Usage: bash loops/flow-walker/eval7.sh
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

echo "=== flow-walker Phase 7 eval ==="

# Gate 1 (AC1): Phase sentinel exists and value is exact
echo ""
echo "── Gate 1: Phase sentinel ──"
check "AC1: phase7 sentinel exists and matches exact value" bash -c "
  [ -f '$WALKER_DIR/.phase7-contract-core' ] &&
  grep -qx 'phase7_contract_core_complete=yes' '$WALKER_DIR/.phase7-contract-core'
"

# Gate 2 (AC2): Legacy executor removed
echo ""
echo "── Gate 2: Legacy executor removal ──"
check "AC2: runner/capture source and tests are deleted" bash -c "
  [ ! -f '$WALKER_DIR/src/runner.ts' ] &&
  [ ! -f '$WALKER_DIR/src/capture.ts' ] &&
  [ ! -f '$WALKER_DIR/tests/runner.test.ts' ] &&
  [ ! -f '$WALKER_DIR/tests/capture.test.ts' ]
"

# Gate 3 (AC3): v2 schema module exists and is covered
echo ""
echo "── Gate 3: v2 schema module ──"
check "AC3: flow-v2-schema module and test suite exist" bash -c "
  [ -f '$WALKER_DIR/src/flow-v2-schema.ts' ] &&
  [ -f '$WALKER_DIR/tests/flow-v2-schema.test.ts' ]
"

# Gate 4 (AC4): v2-only CLI command surface
echo ""
echo "── Gate 4: v2-only CLI surface ──"
check "AC4: schema exposes v2 commands and rejects run" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { COMMAND_SCHEMAS } from \"./src/command-schema.ts\";
    const names = COMMAND_SCHEMAS.map(c => c.name);
    const expected = [\"walk\", \"record\", \"verify\", \"report\", \"push\", \"get\", \"migrate\", \"schema\"];
    const sameLength = names.length === expected.length;
    const hasAll = expected.every(n => names.includes(n));
    const noLegacy = !names.includes(\"run\");
    if (!(sameLength && hasAll && noLegacy)) process.exit(1);
  ' &&
  run_out=\$(node --experimental-strip-types src/cli.ts run 2>&1); run_code=\$? &&
  [ \$run_code -eq 2 ] &&
  echo \"\$run_out\" | grep -q 'Unknown subcommand: run'
"

# Gate 5 (AC5): Phase-gated stubs return NOT_IMPLEMENTED
echo ""
echo "── Gate 5: Phase-gated stubs ──"
check "AC5: record/verify/report/push/migrate return NOT_IMPLEMENTED (exit 2)" bash -c "
  cd '$WALKER_DIR' &&
  o1=\$(node --experimental-strip-types src/cli.ts record init 2>&1); c1=\$? &&
  o2=\$(node --experimental-strip-types src/cli.ts verify 2>&1); c2=\$? &&
  o3=\$(node --experimental-strip-types src/cli.ts report ./tmp 2>&1); c3=\$? &&
  o4=\$(node --experimental-strip-types src/cli.ts push ./tmp 2>&1); c4=\$? &&
  o5=\$(node --experimental-strip-types src/cli.ts migrate ./legacy.yaml 2>&1); c5=\$? &&
  [ \$c1 -eq 2 ] && [ \$c2 -eq 2 ] && [ \$c3 -eq 2 ] && [ \$c4 -eq 2 ] && [ \$c5 -eq 2 ] &&
  echo \"\$o1\" | grep -q 'NOT_IMPLEMENTED' &&
  echo \"\$o2\" | grep -q 'NOT_IMPLEMENTED' &&
  echo \"\$o3\" | grep -q 'NOT_IMPLEMENTED' &&
  echo \"\$o4\" | grep -q 'NOT_IMPLEMENTED' &&
  echo \"\$o5\" | grep -q 'NOT_IMPLEMENTED'
"

# Gate 6 (AC6): walk generates offline v2 scaffold
echo ""
echo "── Gate 6: walk v2 scaffold ──"
check "AC6: walk --name/--output writes version:2 + id/do/anchors/expect/evidence" bash -c "
  tmpdir=\$(mktemp -d)
  outfile=\"\$tmpdir/phase7-smoke.yaml\"
  cd '$WALKER_DIR'
  node --experimental-strip-types src/cli.ts walk --name phase7-smoke --output \"\$outfile\" >/dev/null 2>&1 &&
  [ -f \"\$outfile\" ] &&
  grep -q '^version: 2' \"\$outfile\" &&
  grep -q 'id:' \"\$outfile\" &&
  grep -q 'do:' \"\$outfile\" &&
  grep -q 'anchors:' \"\$outfile\" &&
  grep -q 'expect:' \"\$outfile\" &&
  grep -q 'evidence:' \"\$outfile\"
"

# Gate 7 (AC7): parser accepts v2 and rejects legacy keys
echo ""
echo "── Gate 7: parser contract enforcement ──"
check "AC7: parser accepts v2 flow and rejects legacy action keys" bash -c "
  valid=\$(mktemp)
  legacy=\$(mktemp)
  cat > \"\$valid\" <<'EOF'
version: 2
name: phase7-valid
steps:
  - id: S1
    do: Open home
    anchors: [home]
    expect:
      - milestone: home-visible
        outcome: pass
    evidence:
      - screenshot: home.png
EOF
  cat > \"\$legacy\" <<'EOF'
version: 2
name: phase7-legacy
steps:
  - id: S1
    do: Tap continue
    press: { ref: '@e1' }
    anchors: [cta]
    expect:
      - milestone: next-visible
        outcome: pass
    evidence: []
EOF
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { parseFlowFile } from \"./src/flow-parser.ts\";
    const flow = parseFlowFile(process.argv[1]);
    if (!flow.steps || flow.steps.length !== 1 || !flow.steps[0].id || !flow.steps[0].do) process.exit(1);
  ' \"\$valid\" &&
  node --experimental-strip-types --input-type=module -e '
    import { parseFlowFile } from \"./src/flow-parser.ts\";
    try {
      parseFlowFile(process.argv[1]);
      process.exit(1);
    } catch (e) {
      const msg = String(e?.message ?? e);
      if (!msg.includes(\"legacy\") && !msg.includes(\"press\")) process.exit(1);
    }
  ' \"\$legacy\"
"

# Gate 8 (AC8): verify modes reserved in schema
echo ""
echo "── Gate 8: verify modes ──"
check "AC8: strict/balanced/audit verify modes exist in command-schema.ts" bash -c "
  grep -q 'strict' '$WALKER_DIR/src/command-schema.ts' &&
  grep -q 'balanced' '$WALKER_DIR/src/command-schema.ts' &&
  grep -q 'audit' '$WALKER_DIR/src/command-schema.ts'
"

# Gate 9 (AC9): outcome state model includes skipped/recovered
echo ""
echo "── Gate 9: outcome states ──"
check "AC9: types include skipped and recovered outcomes" bash -c "
  grep -q 'skipped' '$WALKER_DIR/src/types.ts' &&
  grep -q 'recovered' '$WALKER_DIR/src/types.ts'
"

# Gate 10 (AC10): no runner/capture coupling
echo ""
echo "── Gate 10: no runner coupling ──"
check "AC10: cli.ts and walker.ts do not import/call runner or capture paths" bash -c "
  ! grep -qE 'from .*/runner|from .*/capture|runFlow|dryRunFlow' '$WALKER_DIR/src/cli.ts' &&
  ! grep -qE 'from .*/runner|from .*/capture|runFlow|dryRunFlow' '$WALKER_DIR/src/walker.ts'
"

# Gate 11 (AC11): typecheck
echo ""
echo "── Gate 11: Typecheck ──"
check "AC11: npx tsc --noEmit passes" bash -c "
  cd '$WALKER_DIR' && npx tsc --noEmit 2>&1
"

# Gate 12 (AC12): tests pass with reset baseline
echo ""
echo "── Gate 12: Tests ──"
TEST_LOG=$(mktemp)
(cd "$WALKER_DIR" && npm test >"$TEST_LOG" 2>&1)
TEST_EXIT=$?
TEST_COUNT=$(grep -oE 'tests [0-9]+' "$TEST_LOG" | awk '{print $2}' | tail -n1)
check "AC12: npm test passes and test count >= 46 (was ${TEST_COUNT:-0})" bash -c "
  [ '$TEST_EXIT' -eq 0 ] &&
  grep -q 'fail 0' '$TEST_LOG' &&
  [ '${TEST_COUNT:-0}' -ge 46 ]
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
