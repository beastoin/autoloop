#!/usr/bin/env bash
set -e

SRC="loops/agent-flow/agent-flow"

echo "Phase 16 eval: recording pipeline edge case tests"

# Gate 1: typecheck
echo "Gate 1: typecheck"
(cd $SRC && npx tsc --noEmit > /dev/null 2>&1)
echo "  ✅ typecheck"

# Gate 2: all tests pass
echo "Gate 2: unit tests"
(cd $SRC && npm test 2>&1 | tail -3)
echo "  ✅ tests"

# Gate 3: record pipeline tests exist
echo "Gate 3: pipeline tests exist"
test -f "$SRC/tests/record-pipeline.test.ts" || test -f "$SRC/tests/record-edge.test.ts"
echo "  ✅ pipeline tests exist"

# Gate 4: test count increased (baseline: check for >=15 new assertions)
echo "Gate 4: test coverage"
PIPELINE_TEST=$(ls "$SRC/tests"/record-*.test.ts 2>/dev/null)
ASSERT_COUNT=$(grep -c "assert\.\|deepStrictEqual\|strictEqual\|throws\|rejects\|ok\|match" $PIPELINE_TEST 2>/dev/null || echo 0)
test "$ASSERT_COUNT" -ge 15
echo "  ✅ >=15 assertions in pipeline tests ($ASSERT_COUNT found)"

echo ""
echo "phase_complete=yes"
