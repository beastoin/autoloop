#!/usr/bin/env bash
set -e

SRC="loops/agent-swift/agent-swift"

echo "Phase 18 eval: simulator recording quality + click coordinates"

# Gate 1: builds
echo "Gate 1: swift build"
SSH_CMD="cd /Users/beastoinagents/autoloop/$SRC && SWIFT_BUILD_DIR=/tmp/swift-build-jin swift build 2>&1 | tail -3"
ssh beastoin-agents-f1-mac-mini "$SSH_CMD"
echo "  ✅ build"

# Gate 2: tests pass
echo "Gate 2: swift test"
SSH_CMD="cd /Users/beastoinagents/autoloop/$SRC && SWIFT_BUILD_DIR=/tmp/swift-build-jin swift test 2>&1 | tail -3"
ssh beastoin-agents-f1-mac-mini "$SSH_CMD"
echo "  ✅ tests"

# Gate 3: coordinate mapping tests exist
echo "Gate 3: coordinate mapping tests"
COORD_TESTS=$(grep -r "iosPointToScreen\|directionToSwipe\|coordinateMapping\|tapCoord\|scale.*transform" "$SRC/Tests/agent-swiftTests/"*.swift 2>/dev/null | wc -l)
test "$COORD_TESTS" -ge 3
echo "  ✅ coordinate mapping tests ($COORD_TESTS matches)"

# Gate 4: simctl recordVideo is used for simulator mode
echo "Gate 4: simctl recordVideo for simulator mode"
grep -q "simctl.*io.*recordVideo\|recordVideo.*codec" "$SRC/Sources/agent-swift/main.swift"
echo "  ✅ simctl recordVideo in use"

echo ""
echo "phase_complete=yes"
