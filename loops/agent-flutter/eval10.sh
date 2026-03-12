#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/agent-flutter"

PASS=0
FAIL=0
gate() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS  $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"; FAIL=$((FAIL + 1))
  fi
}

echo "=== agent-flutter Phase 10 eval ==="

echo ""
echo "── Gate 1: text command exists ──"
gate "text command file exists" test -f src/commands/text.ts
gate "text parser file exists" test -f src/text-parser.ts

echo ""
echo "── Gate 2: Transport dumpText ──"
gate "AdbTransport has dumpText" grep -q 'dumpText' src/transport/adb.ts
gate "DeviceTransport interface has dumpText" grep -q 'dumpText' src/transport/types.ts
gate "iOS transport has dumpText stub" grep -q 'dumpText' src/transport/ios-sim.ts

echo ""
echo "── Gate 3: XML parser ──"
gate "parser exports parseUiAutomatorXml" grep -q 'parseUiAutomatorXml' src/text-parser.ts
gate "parser extracts text attribute" grep -q "text" src/text-parser.ts
gate "parser extracts content-desc" grep -q "content-desc" src/text-parser.ts

echo ""
echo "── Gate 4: Schema ──"
gate "text command in schema" grep -q "'text'" src/command-schema.ts

echo ""
echo "── Gate 5: CLI dispatch ──"
gate "text case in CLI dispatch" grep -q "'text'" src/cli.ts

echo ""
echo "── Gate 6: Tests ──"
gate "text parser tests exist" test -f __tests__/text-parser.test.ts

echo ""
echo "── Gate 7: Typecheck ──"
gate "typecheck passes" npx tsc --noEmit

echo ""
echo "── Gate 8: All tests pass ──"
TEST_OUTPUT=$(node --experimental-strip-types --test __tests__/*.test.ts 2>&1) || true
TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -oP '(?<=pass )\d+' || echo "0")
if echo "$TEST_OUTPUT" | grep -q "fail 0"; then
  echo "  PASS  all tests pass"; PASS=$((PASS + 1))
else
  echo "  FAIL  all tests pass"; FAIL=$((FAIL + 1))
fi
if test "$TEST_COUNT" -gt 43; then
  echo "  PASS  test count > 43 (was $TEST_COUNT)"; PASS=$((PASS + 1))
else
  echo "  FAIL  test count > 43 (was $TEST_COUNT)"; FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo "EVAL: PASS"
else
  echo "EVAL: FAIL"
  exit 1
fi
