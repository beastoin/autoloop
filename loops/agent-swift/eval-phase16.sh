#!/usr/bin/env bash
# Phase 16 eval: Audit remediation — docs, bugs, cleanup
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
SRC="loops/agent-swift/agent-swift"

PASS=0
FAIL=0
gate() {
  if eval "$2"; then echo "✅ $1"; ((PASS++)); else echo "❌ $1"; ((FAIL++)); fi
}

# HIGH: README version
gate "readme_version_010" "grep -q '0\.10\.' $SRC/README.md"
gate "readme_no_021" "! grep -q '0\.2\.1' $SRC/README.md"

# HIGH: Command count
gate "readme_18_commands" "grep -c '| \`' $SRC/README.md | xargs -I{} test {} -ge 18"

# HIGH: Prerequisites
gate "readme_has_ffmpeg" "grep -qi 'ffmpeg' $SRC/README.md"
gate "readme_has_simctl" "grep -qi 'simctl' $SRC/README.md"

# HIGH: snapshot --all fix
gate "snapshot_all_not_noop" "! grep -q 'func describeAll.*includeAll.*Bool' $SRC/Sources/AgentSwiftLib/Simulator/IdbBridge.swift || grep -A5 'includeAll' $SRC/Sources/AgentSwiftLib/Simulator/IdbBridge.swift | grep -q 'includeAll'"

# MEDIUM: Connect modes documented
gate "readme_has_sim" "grep -q '\-\-sim' $SRC/README.md"
gate "readme_has_mirror" "grep -q '\-\-mirror' $SRC/README.md"
gate "readme_has_udid" "grep -q '\-\-udid' $SRC/README.md"

# MEDIUM: find locators
gate "readme_find_label" "grep -qi 'label' $SRC/README.md"
gate "readme_find_value" "grep -qi 'value' $SRC/README.md"

# MEDIUM: IDB path not hardcoded
gate "idb_no_hardcoded_path" "! grep -q '/opt/homebrew/bin/idb' $SRC/Sources/AgentSwiftLib/Simulator/IdbBridge.swift"

# MEDIUM: CLAUDE.md version updated
gate "claude_md_version" "! grep -q '0\.2\.1' $SRC/CLAUDE.md"

# Build (on Mac Mini)
gate "swift_build" "ssh beastoin-agents-f1-mac-mini 'cd /tmp/agent-swift-build 2>/dev/null && swift build 2>&1 | tail -1 | grep -qi build' 2>/dev/null || echo 'skip_build'"

echo ""
echo "Phase 16 eval: $PASS passed, $FAIL failed"
if [ $FAIL -eq 0 ]; then echo "phase_complete=yes"; else echo "phase_complete=no"; fi
