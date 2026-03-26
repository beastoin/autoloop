#!/usr/bin/env bash
# Eval harness for flow-walker Phase 11 (verify correctness + desktop video + YAML multi-line).
# Usage: bash loops/flow-walker/eval11.sh
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

echo "=== flow-walker Phase 11 eval ==="

# Gate 1 (AC1): Audit mode result=fail when step fails
echo ""
echo "── Gate 1: Audit mode result reflects failures ──"
check "AC1: audit result=fail when step outcome=fail" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { verifyRun } from \"./src/verify.ts\";
    import { mkdtempSync, writeFileSync } from \"node:fs\";
    import { join } from \"node:path\";
    import { tmpdir } from \"node:os\";
    const tmp = mkdtempSync(join(tmpdir(), \"fw-v-\"));
    writeFileSync(join(tmp, \"events.jsonl\"), [
      JSON.stringify({type:\"step.start\",step_id:\"S1\"}),
      JSON.stringify({type:\"step.end\",step_id:\"S1\",outcome:\"pass\"}),
      JSON.stringify({type:\"step.start\",step_id:\"S2\"}),
      JSON.stringify({type:\"step.end\",step_id:\"S2\",outcome:\"fail\"}),
    ].join(\"\\n\"));
    const flow = {version:2,name:\"test\",steps:[{id:\"S1\",do:\"step1\"},{id:\"S2\",do:\"step2\"}]};
    const r = verifyRun({flow,runDir:tmp,mode:\"audit\"});
    if (r.result !== \"fail\") { console.error(\"expected fail, got\", r.result); process.exit(1); }
  '
"

# Gate 2 (AC2): Audit mode result=pass when all pass/skipped
echo ""
echo "── Gate 2: Audit mode pass when all steps pass ──"
check "AC2: audit result=pass when all steps pass or skipped" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { verifyRun } from \"./src/verify.ts\";
    import { mkdtempSync, writeFileSync } from \"node:fs\";
    import { join } from \"node:path\";
    import { tmpdir } from \"node:os\";
    const tmp = mkdtempSync(join(tmpdir(), \"fw-v-\"));
    writeFileSync(join(tmp, \"events.jsonl\"), [
      JSON.stringify({type:\"step.start\",step_id:\"S1\"}),
      JSON.stringify({type:\"step.end\",step_id:\"S1\",outcome:\"pass\"}),
      JSON.stringify({type:\"step.start\",step_id:\"S2\"}),
      JSON.stringify({type:\"step.end\",step_id:\"S2\",outcome:\"skipped\"}),
    ].join(\"\\n\"));
    const flow = {version:2,name:\"test\",steps:[{id:\"S1\",do:\"step1\"},{id:\"S2\",do:\"step2\"}]};
    const r = verifyRun({flow,runDir:tmp,mode:\"audit\"});
    if (r.result !== \"pass\") { console.error(\"expected pass, got\", r.result); process.exit(1); }
  '
"

# Gate 3 (AC3): text_visible expectation met=false when assert passed=false
echo ""
echo "── Gate 3: text_visible expectation checking ──"
check "AC3: text_visible met=false when assert passed=false" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { verifyRun } from \"./src/verify.ts\";
    import { mkdtempSync, writeFileSync } from \"node:fs\";
    import { join } from \"node:path\";
    import { tmpdir } from \"node:os\";
    const tmp = mkdtempSync(join(tmpdir(), \"fw-v-\"));
    writeFileSync(join(tmp, \"events.jsonl\"), [
      JSON.stringify({type:\"step.start\",step_id:\"S1\"}),
      JSON.stringify({type:\"assert\",step_id:\"S1\",kind:\"text_visible\",passed:false}),
      JSON.stringify({type:\"step.end\",step_id:\"S1\",outcome:\"fail\"}),
    ].join(\"\\n\"));
    const flow = {version:2,name:\"test\",steps:[{id:\"S1\",do:\"check text\",expect:[{kind:\"text_visible\",values:[\"Hello\"]}]}]};
    const r = verifyRun({flow,runDir:tmp,mode:\"audit\"});
    const exp = r.steps[0].expectations[0];
    if (exp.met !== false) { console.error(\"expected met=false\", exp); process.exit(1); }
  '
"

# Gate 4 (AC4): interactive_count expectation met=false when assert passed=false
echo ""
echo "── Gate 4: interactive_count expectation checking ──"
check "AC4: interactive_count met=false when assert passed=false" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { verifyRun } from \"./src/verify.ts\";
    import { mkdtempSync, writeFileSync } from \"node:fs\";
    import { join } from \"node:path\";
    import { tmpdir } from \"node:os\";
    const tmp = mkdtempSync(join(tmpdir(), \"fw-v-\"));
    writeFileSync(join(tmp, \"events.jsonl\"), [
      JSON.stringify({type:\"step.start\",step_id:\"S1\"}),
      JSON.stringify({type:\"assert\",step_id:\"S1\",kind:\"interactive_count\",passed:false,actual:2}),
      JSON.stringify({type:\"step.end\",step_id:\"S1\",outcome:\"fail\"}),
    ].join(\"\\n\"));
    const flow = {version:2,name:\"test\",steps:[{id:\"S1\",do:\"check count\",expect:[{kind:\"interactive_count\",min:5}]}]};
    const r = verifyRun({flow,runDir:tmp,mode:\"audit\"});
    const exp = r.steps[0].expectations[0];
    if (exp.met !== false) { console.error(\"expected met=false\", exp); process.exit(1); }
  '
"

# Gate 5 (AC5): Outcome normalization
echo ""
echo "── Gate 5: Outcome normalization ──"
check "AC5: 'skip' normalized to 'skipped', 'partial' to 'fail'" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { verifyRun } from \"./src/verify.ts\";
    import { mkdtempSync, writeFileSync } from \"node:fs\";
    import { join } from \"node:path\";
    import { tmpdir } from \"node:os\";
    const tmp = mkdtempSync(join(tmpdir(), \"fw-v-\"));
    writeFileSync(join(tmp, \"events.jsonl\"), [
      JSON.stringify({type:\"step.start\",step_id:\"S1\"}),
      JSON.stringify({type:\"step.end\",step_id:\"S1\",outcome:\"skip\"}),
      JSON.stringify({type:\"step.start\",step_id:\"S2\"}),
      JSON.stringify({type:\"step.end\",step_id:\"S2\",outcome:\"partial\"}),
    ].join(\"\\n\"));
    const flow = {version:2,name:\"test\",steps:[{id:\"S1\",do:\"s1\"},{id:\"S2\",do:\"s2\"}]};
    const r = verifyRun({flow,runDir:tmp,mode:\"audit\"});
    if (r.steps[0].outcome !== \"skipped\") { console.error(\"S1 expected skipped, got\", r.steps[0].outcome); process.exit(1); }
    if (r.steps[1].outcome !== \"fail\") { console.error(\"S2 expected fail, got\", r.steps[1].outcome); process.exit(1); }
  '
"

# Gate 6 (AC6): Issues populated in audit mode
echo ""
echo "── Gate 6: Issues in audit mode ──"
check "AC6: audit mode populates issues for failed steps" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { verifyRun } from \"./src/verify.ts\";
    import { mkdtempSync, writeFileSync } from \"node:fs\";
    import { join } from \"node:path\";
    import { tmpdir } from \"node:os\";
    const tmp = mkdtempSync(join(tmpdir(), \"fw-v-\"));
    writeFileSync(join(tmp, \"events.jsonl\"), [
      JSON.stringify({type:\"step.start\",step_id:\"S1\"}),
      JSON.stringify({type:\"step.end\",step_id:\"S1\",outcome:\"fail\"}),
    ].join(\"\\n\"));
    const flow = {version:2,name:\"test\",steps:[{id:\"S1\",do:\"s1\"}]};
    const r = verifyRun({flow,runDir:tmp,mode:\"audit\"});
    if (r.issues.length === 0) { console.error(\"expected issues\"); process.exit(1); }
  '
"

# Gate 7 (AC7): Folded scalar >
echo ""
echo "── Gate 7: YAML folded scalar ──"
check "AC7: folded scalar > joins lines with spaces" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { parseFlowV2 } from \"./src/flow-parser.ts\";
    const yaml = \`version: 2
name: test
steps:
  - id: S1
    do: >
      Verify the home screen
      shows the heading
      and footer
    expect:
      - kind: text_visible
        values: [\"Hello\"]
\`;
    const flow = parseFlowV2(yaml);
    const doText = flow.steps[0].do;
    if (!doText.includes(\"Verify the home screen\")) { console.error(\"missing start\", doText); process.exit(1); }
    if (!doText.includes(\"shows the heading\")) { console.error(\"missing middle\", doText); process.exit(1); }
    if (!doText.includes(\"and footer\")) { console.error(\"missing end\", doText); process.exit(1); }
    if (doText.includes(\"\\n\")) { console.error(\"folded should not have newlines\", doText); process.exit(1); }
  '
"

# Gate 8 (AC8): Literal scalar |
echo ""
echo "── Gate 8: YAML literal scalar ──"
check "AC8: literal scalar | joins lines with newlines" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { parseFlowV2 } from \"./src/flow-parser.ts\";
    const yaml = \`version: 2
name: test
steps:
  - id: S1
    do: |
      Line one
      Line two
      Line three
\`;
    const flow = parseFlowV2(yaml);
    const doText = flow.steps[0].do;
    if (!doText.includes(\"Line one\")) process.exit(1);
    if (!doText.includes(\"\\n\")) { console.error(\"literal should have newlines\", doText); process.exit(1); }
  '
"

# Gate 9 (AC9): RecordInitOptions has platform
echo ""
echo "── Gate 9: Platform in RecordInitOptions ──"
check "AC9: RecordInitOptions accepts platform field" bash -c "
  cd '$WALKER_DIR' &&
  grep -q 'platform' src/record.ts
"

# Gate 10 (AC10): screencapture in record.ts
echo ""
echo "── Gate 10: macOS screencapture ──"
check "AC10: record.ts contains screencapture for macOS" bash -c "
  cd '$WALKER_DIR' &&
  grep -q 'screencapture' src/record.ts
"

# Gate 11 (AC11): Skip ADB video when desktop
echo ""
echo "── Gate 11: Auto-skip ADB on desktop ──"
check "AC11: record.ts skips ADB screenrecord when platform=desktop" bash -c "
  cd '$WALKER_DIR' &&
  grep -q 'desktop' src/record.ts
"

# Gate 12 (AC12): Event schema warns on bad outcomes
echo ""
echo "── Gate 12: Event schema outcome validation ──"
check "AC12: validateEvent returns warning for non-standard outcomes" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { validateEvent } from \"./src/event-schema.ts\";
    const r = validateEvent({type:\"step.end\",step_id:\"S1\",outcome:\"bogus\"});
    if (!r.valid) process.exit(1);
    if (!r.warning) { console.error(\"expected warning\"); process.exit(1); }
  '
"

# Gate 13 (AC13): Typecheck
echo ""
echo "── Gate 13: Typecheck ──"
check "AC13: npx tsc --noEmit passes" bash -c "
  cd '$WALKER_DIR' && npx tsc --noEmit 2>&1
"

# Gate 14 (AC14): Tests pass with sufficient count
echo ""
echo "── Gate 14: Tests ──"
TEST_LOG=$(mktemp)
(cd "$WALKER_DIR" && npm test >"$TEST_LOG" 2>&1)
TEST_EXIT=$?
TEST_COUNT=$(grep -oE 'tests [0-9]+' "$TEST_LOG" | awk '{print $2}' | tail -n1)
check "AC14: npm test passes and test count >= 310 (was ${TEST_COUNT:-0})" bash -c "
  [ '$TEST_EXIT' -eq 0 ] &&
  grep -q 'fail 0' '$TEST_LOG' &&
  [ '${TEST_COUNT:-0}' -ge 310 ]
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
