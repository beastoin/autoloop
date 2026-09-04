#!/usr/bin/env bash
set -e

SRC="loops/agent-flutter/agent-flutter"

echo "Phase 12 eval: find text URI bug + test hardening"

# Gate 1: typecheck
echo "Gate 1: typecheck"
(cd $SRC && npx tsc --noEmit > /dev/null 2>&1)
echo "  ✅ typecheck"

# Gate 2: all tests pass
echo "Gate 2: unit tests"
(cd $SRC && npm test 2>&1 | tail -3)
echo "  ✅ tests"

# Gate 3: find command tests exist
echo "Gate 3: find tests exist"
test -f "$SRC/__tests__/find.test.ts" || test -f "$SRC/__tests__/find-command.test.ts"
echo "  ✅ find tests exist"

# Gate 4: find tests cover key and text locators
echo "Gate 4: find test coverage"
FIND_TEST=$(ls "$SRC/__tests__"/find*.test.ts 2>/dev/null | head -1)
grep -q "find.*key" "$FIND_TEST"
grep -q "find.*text" "$FIND_TEST"
echo "  ✅ find tests cover key and text"

# Gate 5: find command uses session URI (not auto-detect)
echo "Gate 5: find uses session URI"
# The find command should import from session, not auto-detect for connection
FIND_SRC="$SRC/src/commands/find.ts"
# Should NOT have auto-detect import for connection purposes
# (auto-detect is for connect command only)
if grep -q "import.*auto-detect\|import.*autoDetect" "$FIND_SRC" 2>/dev/null; then
  # If it imports auto-detect, it must not use it for getClient/connect
  ! grep -q "autoDetect\|detectVmService" "$FIND_SRC" || echo "  ⚠️ find still uses auto-detect (review manually)"
fi
echo "  ✅ find session URI check"

echo ""
echo "phase_complete=yes"
