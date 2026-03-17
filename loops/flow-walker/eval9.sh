#!/usr/bin/env bash
# Eval harness for flow-walker Phase 9 (migrate + pipeline).
# Usage: bash loops/flow-walker/eval9.sh
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

echo "=== flow-walker Phase 9 eval ==="

# Gate 1 (AC1): migrate module exports
echo ""
echo "── Gate 1: Migrate module exports ──"
check "AC1: migrate.ts exports migrateFlowV1toV2" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { migrateFlowV1toV2 } from \"./src/migrate.ts\";
    if (typeof migrateFlowV1toV2 !== \"function\") process.exit(1);
  '
"

# Gate 2 (AC2): migrate converts v1 to valid v2
echo ""
echo "── Gate 2: Migrate produces valid v2 ──"
check "AC2: migrate output passes validateFlowV2" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { migrateFlowV1toV2 } from \"./src/migrate.ts\";
    import { validateFlowV2 } from \"./src/flow-v2-schema.ts\";
    const v1 = {
      name: \"test-flow\",
      description: \"Test\",
      setup: \"normal\",
      steps: [
        { name: \"Open home\", press: { type: \"button\", hint: \"Settings\" }, screenshot: \"home\" },
        { name: \"Scroll down\", scroll: \"down\" },
        { name: \"Go back\", back: true },
      ],
    };
    const v2 = migrateFlowV1toV2(v1);
    validateFlowV2(v2);
    if (v2.version !== 2) process.exit(1);
    if (v2.steps.length !== 3) process.exit(1);
  '
"

# Gate 3 (AC3): step IDs auto-generated
echo ""
echo "── Gate 3: Step IDs auto-generated ──"
check "AC3: migrate generates S1, S2, S3... IDs" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { migrateFlowV1toV2 } from \"./src/migrate.ts\";
    const v1 = {
      name: \"id-test\", description: \"Test\", setup: \"normal\",
      steps: [{ name: \"A\" }, { name: \"B\" }, { name: \"C\" }],
    };
    const v2 = migrateFlowV1toV2(v1);
    if (v2.steps[0].id !== \"S1\") process.exit(1);
    if (v2.steps[1].id !== \"S2\") process.exit(1);
    if (v2.steps[2].id !== \"S3\") process.exit(1);
  '
"

# Gate 4 (AC4): press/fill/scroll/back converted to do:
echo ""
echo "── Gate 4: Actions converted to do: ──"
check "AC4: press, fill, scroll, back become do: instructions" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { migrateFlowV1toV2 } from \"./src/migrate.ts\";
    const v1 = {
      name: \"action-test\", description: \"Test\", setup: \"normal\",
      steps: [
        { name: \"Press button\", press: { type: \"button\", hint: \"Settings\" } },
        { name: \"Fill field\", fill: { type: \"textfield\", value: \"hello\" } },
        { name: \"Scroll down\", scroll: \"down\" },
        { name: \"Go back\", back: true },
      ],
    };
    const v2 = migrateFlowV1toV2(v1);
    for (const s of v2.steps) {
      if (!s.do || typeof s.do !== \"string\") process.exit(1);
      if (s.do.length < 5) process.exit(1);
    }
    // Must not have legacy keys
    for (const s of v2.steps) {
      if (\"press\" in s || \"fill\" in s || \"scroll\" in s || \"back\" in s) process.exit(1);
    }
  '
"

# Gate 5 (AC5): metadata preserved
echo ""
echo "── Gate 5: Metadata preserved ──"
check "AC5: name, description, covers, app preserved" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { migrateFlowV1toV2 } from \"./src/migrate.ts\";
    const v1 = {
      name: \"meta-test\", description: \"Test desc\", setup: \"normal\",
      app: \"TestApp\", appUrl: \"https://test.app\",
      covers: [\"lib/home.dart\"], prerequisites: [\"auth_ready\"],
      steps: [{ name: \"Step\" }],
    };
    const v2 = migrateFlowV1toV2(v1);
    if (v2.name !== \"meta-test\") process.exit(1);
    if (v2.description !== \"Test desc\") process.exit(1);
    if (v2.app !== \"TestApp\") process.exit(1);
    if (v2.appUrl !== \"https://test.app\") process.exit(1);
    if (!v2.covers || v2.covers[0] !== \"lib/home.dart\") process.exit(1);
    if (!v2.preconditions || v2.preconditions[0] !== \"auth_ready\") process.exit(1);
  '
"

# Gate 6 (AC6): CLI migrate writes v2 YAML
echo ""
echo "── Gate 6: CLI migrate writes v2 YAML ──"
check "AC6: flow-walker migrate writes v2 YAML with --output" bash -c "
  tmpdir=\$(mktemp -d)
  v1file=\$(mktemp --suffix=.yaml)
  outfile=\"\$tmpdir/migrated.yaml\"
  cat > \"\$v1file\" <<'YAML'
name: cli-migrate-test
description: Test CLI migration
setup: normal
steps:
  - name: Open home
    press: { type: button, position: rightmost }
    screenshot: home
  - name: Scroll down
    scroll: down
  - name: Go back
    back: true
YAML
  cd '$WALKER_DIR' &&
  node --experimental-strip-types src/cli.ts migrate \"\$v1file\" --output \"\$outfile\" --json 2>&1 &&
  [ -f \"\$outfile\" ] &&
  grep -q '^version: 2' \"\$outfile\" &&
  grep -q 'id:' \"\$outfile\" &&
  grep -q 'do:' \"\$outfile\"
"

# Gate 7 (AC7): report generates HTML from v2 run.json
echo ""
echo "── Gate 7: Report from v2 run.json ──"
check "AC7: report generates HTML from v2 verify result" bash -c "
  tmpdir=\$(mktemp -d)
  cat > \"\$tmpdir/run.json\" <<'JSON'
{
  \"flow\": \"test-flow\",
  \"mode\": \"balanced\",
  \"result\": \"pass\",
  \"steps\": [
    {\"id\": \"S1\", \"name\": \"Home\", \"do\": \"Open home\", \"outcome\": \"pass\", \"events\": [], \"expectations\": []}
  ],
  \"issues\": []
}
JSON
  cd '$WALKER_DIR' &&
  node --experimental-strip-types src/cli.ts report \"\$tmpdir\" --json 2>&1 &&
  [ -f \"\$tmpdir/report.html\" ] &&
  grep -q 'test-flow' \"\$tmpdir/report.html\" &&
  grep -q 'pass' \"\$tmpdir/report.html\"
"

# Gate 8 (AC8): no more NOT_IMPLEMENTED stubs
echo ""
echo "── Gate 8: No NOT_IMPLEMENTED stubs ──"
check "AC8: report, push, migrate no longer return NOT_IMPLEMENTED" bash -c "
  cd '$WALKER_DIR' &&
  ! grep -q 'notImplemented.*report' src/cli.ts &&
  ! grep -q 'notImplemented.*push' src/cli.ts &&
  ! grep -q 'notImplemented.*migrate' src/cli.ts
"

# Gate 9 (AC9): typecheck
echo ""
echo "── Gate 9: Typecheck ──"
check "AC9: npx tsc --noEmit passes" bash -c "
  cd '$WALKER_DIR' && npx tsc --noEmit 2>&1
"

# Gate 10 (AC10): tests pass with sufficient count
echo ""
echo "── Gate 10: Tests ──"
TEST_LOG=$(mktemp)
(cd "$WALKER_DIR" && npm test >"$TEST_LOG" 2>&1)
TEST_EXIT=$?
TEST_COUNT=$(grep -oE 'tests [0-9]+' "$TEST_LOG" | awk '{print $2}' | tail -n1)
check "AC10: npm test passes and test count >= 260 (was ${TEST_COUNT:-0})" bash -c "
  [ '$TEST_EXIT' -eq 0 ] &&
  grep -q 'fail 0' '$TEST_LOG' &&
  [ '${TEST_COUNT:-0}' -ge 260 ]
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
