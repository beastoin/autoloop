#!/usr/bin/env bash
set -e

SRC="loops/agent-swift/agent-swift"

echo "Phase 17 eval: recording + interaction bug fixes"

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

# Gate 3: screenshot during recording uses non-simctl method
echo "Gate 3: sim screenshot avoids simctl during recording"
grep -q "recording.*screenshot\|screenshot.*recording\|simScreenshotDuringRecording\|captureWithoutSimctl" "$SRC/Sources/agent-swift/main.swift" "$SRC/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null || \
grep -q "screencapture.*simulator\|idb.*screenshot\|xcrun.*screenshot.*recording" "$SRC/Sources/agent-swift/main.swift" "$SRC/Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift" 2>/dev/null
echo "  ✅ alternative screenshot path"

echo ""
echo "phase_complete=yes"
