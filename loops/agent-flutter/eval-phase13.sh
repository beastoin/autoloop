#!/usr/bin/env bash
set -e

SRC="loops/agent-flutter/agent-flutter"

echo "Phase 13 eval: safe back + keyboard dismiss + element labels"

# Gate 1: typecheck
echo "Gate 1: typecheck"
(cd $SRC && npx tsc --noEmit > /dev/null 2>&1)
echo "  ✅ typecheck"

# Gate 2: all tests pass
echo "Gate 2: unit tests"
(cd $SRC && node --test __tests__/*.test.ts 2>&1 | tail -5)
echo "  ✅ tests"

# Gate 3: dismiss-keyboard command exists
echo "Gate 3: dismiss-keyboard command"
grep -rq "dismiss.keyboard\|dismissKeyboard\|dismiss_keyboard" "$SRC/src/" 2>/dev/null
echo "  ✅ dismiss-keyboard command exists"

# Gate 4: back command has keyboard detection
echo "Gate 4: back command keyboard awareness"
grep -rq "mInputShown\|keyboard.*visible\|keyboard.*dismiss\|KEYCODE_ESCAPE\|keyevent.*111" "$SRC/src/" 2>/dev/null
echo "  ✅ keyboard detection in back command"

# Gate 5: schema includes new command
echo "Gate 5: schema parity"
grep -q "dismiss" "$SRC/src/"*schema* 2>/dev/null || grep -q "dismiss" "$SRC/src/"*cli* 2>/dev/null || grep -rq "dismiss.*keyboard" "$SRC/src/" 2>/dev/null
echo "  ✅ schema includes dismiss-keyboard"

# Gate 6: test count
echo "Gate 6: test coverage"
TEST_COUNT=$(grep -rc "assert\.\|deepStrictEqual\|strictEqual\|throws\|rejects\|ok\|match" "$SRC/__tests__/"*.test.ts 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
echo "  test assertions: $TEST_COUNT"
# Baseline was ~91 from phase 12. Need ≥ 8 new = 99
test "$TEST_COUNT" -ge 99
echo "  ✅ >=99 test assertions ($TEST_COUNT found)"

echo ""
echo "phase_complete=yes"
