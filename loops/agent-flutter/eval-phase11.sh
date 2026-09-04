#!/usr/bin/env bash
# Phase 11 eval: Audit remediation — docs, contracts, cleanup
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
SRC="loops/agent-flutter/agent-flutter"

PASS=0
FAIL=0
gate() {
  if eval "$2"; then echo "✅ $1"; ((PASS++)); else echo "❌ $1"; ((FAIL++)); fi
}

# HIGH: Package identity
gate "readme_install_beastoin" "grep -q '@beastoin/agent-flutter' $SRC/README.md"
gate "readme_no_old_name" "! grep -q 'agent-flutter-cli' $SRC/README.md"
gate "lockfile_name" "grep -q '@beastoin/agent-flutter' $SRC/package-lock.json"

# MEDIUM: Node engine
gate "engine_node22" "grep -q '\"node\".*22' $SRC/package.json"

# MEDIUM: README commands
gate "readme_has_dismiss" "grep -qi 'dismiss' $SRC/README.md"
gate "readme_has_text_cmd" "grep -q '| \`text' $SRC/README.md"
gate "readme_has_native_flag" "grep -q '\-\-native' $SRC/README.md"

# MEDIUM: No WIDGET_SUPPORT ref
gate "no_widget_support_ref" "! grep -q 'WIDGET_SUPPORT' $SRC/AGENTS.md"

# MEDIUM: Loop README current
gate "loop_readme_phase" "grep -qi 'phase.*[7-9]\|phase.*1[0-9]' loops/agent-flutter/README.md"

# Tests
gate "tests_pass" "(cd $SRC && npm test 2>&1 | grep -q 'fail 0')"
TEST_COUNT=$(cd $SRC && npm test 2>&1 | grep '^ℹ tests' | awk '{print $3}')
cd "$REPO_ROOT"
gate "test_count_gte_75" "[ \"${TEST_COUNT:-0}\" -ge 75 ]"

# Typecheck
gate "typecheck" "(cd $SRC && npx tsc --noEmit > /dev/null 2>&1)"

# Dead code cleanup
gate "no_unused_clearSession" "! grep -q 'clearSession' $SRC/src/commands/connect.ts"

echo ""
echo "Phase 11 eval: $PASS passed, $FAIL failed"
if [ $FAIL -eq 0 ]; then echo "phase_complete=yes"; else echo "phase_complete=no"; fi
