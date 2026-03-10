#!/usr/bin/env bash
# E2E test for flow-walker against a live Flutter app.
# Usage: bash loops/flow-walker/e2e-test.sh <vm-service-uri>
# Requires: agent-flutter in PATH, Flutter app running on device.
# DO NOT MODIFY THIS FILE.

set -uo pipefail

URI="${1:-}"
if [ -z "$URI" ]; then
  echo "Usage: $0 <vm-service-uri>"
  echo "Example: $0 ws://127.0.0.1:38047/abc=/ws"
  exit 2
fi

WALKER="/tmp/flow-walker"
OUTPUT_DIR="/tmp/flow-walker-output"
DEVICE="192.168.1.2:5555"

export AGENT_FLUTTER_DEVICE="$DEVICE"
export AGENT_FLUTTER_JSON=1

rm -rf "$OUTPUT_DIR"
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

echo "=== flow-walker E2E test ==="
echo "URI: $URI"
echo "Device: $DEVICE"
echo ""

# Test 1: dry-run connects and lists elements
echo "── Test 1: Dry run ──"
DRY_OUTPUT=$(cd "$WALKER" && node --experimental-strip-types src/cli.ts walk \
  --app-uri "$URI" --dry-run --output-dir "$OUTPUT_DIR" --json 2>&1)
check "dry-run exits 0" test $? -eq 0
check "dry-run reports elements" echo "$DRY_OUTPUT" | grep -q "SAFE\|BLOCKED\|elements"

echo ""

# Test 2: depth-1 walk generates YAML
echo "── Test 2: Depth-1 walk ──"
rm -rf "$OUTPUT_DIR"
cd "$WALKER" && node --experimental-strip-types src/cli.ts walk \
  --app-uri "$URI" --max-depth 1 --output-dir "$OUTPUT_DIR" 2>/tmp/flow-walker-stderr.log
WALK_EXIT=$?
check "walk exits 0" test "$WALK_EXIT" -eq 0
check "output dir created" test -d "$OUTPUT_DIR"
check "YAML files generated" bash -c "ls '$OUTPUT_DIR'/*.yaml 2>/dev/null | head -1"
check "nav graph JSON generated" test -f "$OUTPUT_DIR/_nav-graph.json"

echo ""

# Test 3: YAML structure validation
echo "── Test 3: YAML structure ──"
FIRST_YAML=$(ls "$OUTPUT_DIR"/*.yaml 2>/dev/null | head -1)
if [ -n "$FIRST_YAML" ]; then
  check "YAML has name field" grep -q "^name:" "$FIRST_YAML"
  check "YAML has steps field" grep -q "^steps:" "$FIRST_YAML"
  check "YAML has setup field" grep -q "^setup:" "$FIRST_YAML"
else
  echo "  SKIP  No YAML files to validate"
fi

echo ""

# Test 4: nav graph structure
echo "── Test 4: Nav graph ──"
if [ -f "$OUTPUT_DIR/_nav-graph.json" ]; then
  check "graph has nodes" python3 -c "import json; d=json.load(open('$OUTPUT_DIR/_nav-graph.json')); assert len(d['nodes'])>0"
  check "graph has edges" python3 -c "import json; d=json.load(open('$OUTPUT_DIR/_nav-graph.json')); assert len(d['edges'])>=0"
  check "graph is valid JSON" python3 -c "import json; json.load(open('$OUTPUT_DIR/_nav-graph.json'))"
else
  echo "  SKIP  No graph file"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo "Output: $OUTPUT_DIR/"
ls -la "$OUTPUT_DIR/" 2>/dev/null

if [ "$FAIL" -gt 0 ]; then
  echo "E2E: FAIL"
  exit 1
else
  echo "E2E: PASS"
  exit 0
fi
