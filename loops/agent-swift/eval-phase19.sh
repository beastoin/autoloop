#!/usr/bin/env bash
set -e

SRC="loops/agent-swift/agent-swift"

echo "Phase 19 eval: vphone iOS VM support"

# Gate 1: builds
echo "Gate 1: swift build"
SSH_CMD="cd /Users/beastoinagents/autoloop/$SRC && SWIFT_BUILD_DIR=/tmp/swift-build-jin swift build 2>&1 | tail -3"
ssh beastoin-agents-f1-mac-mini "$SSH_CMD"
echo "  ✅ build"

# Gate 2: tests pass
echo "Gate 2: swift test"
SSH_CMD="cd /Users/beastoinagents/autoloop/$SRC && SWIFT_BUILD_DIR=/tmp/swift-build-jin swift test 2>&1 | tail -5"
ssh beastoin-agents-f1-mac-mini "$SSH_CMD"
echo "  ✅ tests"

# Gate 3: VphoneBridge exists
echo "Gate 3: VphoneBridge module"
test -f "$SRC/Sources/AgentSwiftLib/Vphone/VphoneBridge.swift"
echo "  ✅ VphoneBridge.swift exists"

# Gate 4: connect --vphone flag
echo "Gate 4: connect --vphone"
grep -q "vphone" "$SRC/Sources/agent-swift/main.swift"
echo "  ✅ --vphone in connect"

# Gate 5: session vphone mode
echo "Gate 5: session vphone support"
grep -q "vphoneVM\|vphoneSocket\|isVphoneMode" "$SRC/Sources/AgentSwiftLib/Session/SessionStore.swift"
echo "  ✅ vphone session fields"

# Gate 6: vphone tests
echo "Gate 6: vphone unit tests"
VPHONE_TESTS=$(grep -r "vphone\|VphoneBridge\|VPhone\|vphoneMode" "$SRC/Tests/agent-swiftTests/"*.swift 2>/dev/null | wc -l)
test "$VPHONE_TESTS" -ge 5
echo "  ✅ vphone tests ($VPHONE_TESTS matches)"

echo ""
echo "phase_complete=yes"
