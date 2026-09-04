#!/usr/bin/env bash
# Full E2E test suite for agent-flutter + agent-flow against the shared test app.
# Requires: emulator running, E2E app launched via `flutter run`, VM_SERVICE_URI set.
#
# Usage:
#   VM_SERVICE_URI=ws://... bash shared/e2e-flutter-app/e2e/e2e-full.sh
#
# Tests cover:
#   1. agent-flutter: connect, snapshot, press, get, find, is, wait, screenshot, text, fill, disconnect
#   2. agent-flow: record init → stream → finish → verify → report (full pipeline)
#   3. Cross-tool: run ID contract, snapshot format

set -uo pipefail

DEVICE="${AGENT_FLUTTER_DEVICE:-emulator-5558}"
CMD_TIMEOUT=15  # seconds per command
PASS=0
FAIL=0
SKIP=0
TOTAL=0
RUN_DIR=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

check() {
  local name="$1"
  shift
  ((TOTAL++))
  if timeout $CMD_TIMEOUT bash -c "$@" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ $name${NC}"
    ((PASS++))
  else
    echo -e "  ${RED}❌ $name${NC}"
    ((FAIL++))
  fi
}

check_output() {
  local name="$1"
  local cmd="$2"
  local expected="$3"
  ((TOTAL++))
  local output
  output=$(timeout $CMD_TIMEOUT bash -c "$cmd" 2>&1) || true
  if echo "$output" | grep -q "$expected"; then
    echo -e "  ${GREEN}✅ $name${NC}"
    ((PASS++))
  else
    echo -e "  ${RED}❌ $name${NC} (expected: $expected, got: $(echo "$output" | head -1))"
    ((FAIL++))
  fi
}

skip() {
  local name="$1"
  ((TOTAL++))
  ((SKIP++))
  echo -e "  ${YELLOW}⏭  $name (skipped)${NC}"
}

# Helper: ensure connection is alive, reconnect if needed
ensure_connected() {
  local status
  status=$(timeout 5 agent-flutter status --device "$DEVICE" --json 2>&1) || true
  if ! echo "$status" | grep -q '"connected":true'; then
    timeout $CMD_TIMEOUT agent-flutter connect "$VM_SERVICE_URI" --device "$DEVICE" >/dev/null 2>&1
  fi
}

# Helper: take a fresh snapshot (refreshes refs)
refresh_snapshot() {
  timeout $CMD_TIMEOUT agent-flutter snapshot -i --device "$DEVICE" >/dev/null 2>&1
}

cleanup() {
  agent-flutter disconnect --device "$DEVICE" 2>/dev/null || true
  if [ -n "$RUN_DIR" ] && [ -d "$RUN_DIR" ]; then
    rm -rf "$RUN_DIR"
  fi
}
trap cleanup EXIT

echo "═══════════════════════════════════════════"
echo "  E2E Test Suite — agent-flutter + agent-flow"
echo "═══════════════════════════════════════════"
echo ""

if [ -z "${VM_SERVICE_URI:-}" ]; then
  echo "ERROR: VM_SERVICE_URI not set. Launch the E2E app with:"
  echo "  cd shared/e2e-flutter-app && flutter run -d $DEVICE"
  echo "  Then export VM_SERVICE_URI=ws://..."
  exit 2
fi

echo "Device: $DEVICE"
echo "VM URI: $VM_SERVICE_URI"
echo ""

# ═══════════════════════════════════════════
# Part 1: agent-flutter CLI
# ═══════════════════════════════════════════
echo "── Part 1: agent-flutter CLI ──"

# 1.1 Connect
echo ""
echo "1.1 Connection"
agent-flutter disconnect --device "$DEVICE" 2>/dev/null || true
check "connect to app" "agent-flutter connect '$VM_SERVICE_URI' --device '$DEVICE'"
check "status shows connected" "agent-flutter status --device '$DEVICE' --json | grep -q '\"connected\":true'"
check "status shows isolate" "agent-flutter status --device '$DEVICE' --json | grep -q 'isolate'"

# Reset app state
refresh_snapshot
RESET_INIT=$(timeout 10 agent-flutter snapshot -i --device "$DEVICE" --json 2>/dev/null | python3 -c "import sys,json; elems=json.load(sys.stdin); r=[e for e in elems if e.get('key')=='reset_btn']; print(r[0]['ref'] if r else '')" 2>/dev/null || echo "")
if [ -n "$RESET_INIT" ]; then
  timeout 10 agent-flutter press "$RESET_INIT" --device "$DEVICE" >/dev/null 2>&1
  sleep 0.5
fi

# 1.2 Snapshot
echo ""
echo "1.2 Snapshot"
refresh_snapshot
check "snapshot returns elements" "agent-flutter snapshot --device '$DEVICE' --json | grep -q 'ref'"
check "snapshot -i returns interactive" "agent-flutter snapshot -i --device '$DEVICE' --json | grep -q 'button\|textfield\|switch'"
SNAP_COUNT=$(timeout 10 agent-flutter snapshot -i --device "$DEVICE" --json 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
check "snapshot has >=4 interactive elements" "[ $SNAP_COUNT -ge 4 ]"

# 1.3 Get
echo ""
echo "1.3 Get"
check_output "get type @e1" "agent-flutter get type e1 --device '$DEVICE'" "button"
check_output "get key @e1" "agent-flutter get key e1 --device '$DEVICE'" "increment_btn"

# 1.4 Press + state change
echo ""
echo "1.4 Press"
check "press increment button" "agent-flutter press e1 --device '$DEVICE'"
sleep 0.5
refresh_snapshot
check_output "text shows counter at 1" "agent-flutter text --device '$DEVICE' --json" "Counter: 1"

# 1.5 Find (before fill to avoid VM deadlock)
echo ""
echo "1.5 Find"
ensure_connected
refresh_snapshot
check "find by key" "agent-flutter find key submit_btn --device '$DEVICE' 2>&1 | grep -qi 'submit_btn\|found'"
check "find by key (increment)" "agent-flutter find key increment_btn --device '$DEVICE' 2>&1 | grep -qi 'increment\|found'"

# 1.6 Is (assertions)
echo ""
echo "1.6 Is"
ensure_connected
refresh_snapshot
check "is exists @e1" "agent-flutter is exists e1 --device '$DEVICE'"
check "is visible @e1" "agent-flutter is visible e1 --device '$DEVICE'"

# 1.7 Wait
echo ""
echo "1.7 Wait"
ensure_connected
check "wait exists @e1" "agent-flutter wait exists e1 --device '$DEVICE' --timeout 5000"
check "wait text 'Counter'" "agent-flutter wait text 'Counter' --device '$DEVICE' --timeout 5000"

# 1.8 Screenshot
echo ""
echo "1.8 Screenshot"
SCREENSHOT_PATH="/tmp/e2e-test-screenshot-$$.png"
check "screenshot captures file" "agent-flutter screenshot '$SCREENSHOT_PATH' --device '$DEVICE' && [ -f '$SCREENSHOT_PATH' ] && [ -s '$SCREENSHOT_PATH' ]"
rm -f "$SCREENSHOT_PATH"

# 1.9 Text
echo ""
echo "1.9 Text"
check "text returns output" "agent-flutter text --device '$DEVICE' --json | grep -q 'Counter'"

# 1.10 Schema
echo ""
echo "1.10 Schema"
check "schema returns command list" "agent-flutter schema --json | grep -q 'connect'"
check "schema has connect detail" "agent-flutter schema connect --json | grep -q 'connect'"

# 1.11 Fill (last — may affect VM stability)
echo ""
echo "1.11 Fill"
ensure_connected
TF_REF=$(timeout 10 agent-flutter snapshot -i --device "$DEVICE" --json 2>/dev/null | python3 -c "import sys,json; elems=json.load(sys.stdin); tf=[e for e in elems if e.get('type')=='textfield']; print(tf[0]['ref'] if tf else '')" 2>/dev/null || echo "")
if [ -n "$TF_REF" ]; then
  check "fill text field" "agent-flutter fill '$TF_REF' 'E2E Test Name' --device '$DEVICE'"
  sleep 0.5
  # Dismiss keyboard by tapping a non-text element (not back — back sends app to home)
  timeout 5 agent-flutter press e1 --device "$DEVICE" >/dev/null 2>&1 || true
  sleep 0.5
  refresh_snapshot
  check_output "text shows filled value" "agent-flutter text --device '$DEVICE' --json" "E2E Test Name"
else
  skip "fill text field (no textfield found)"
  skip "text shows filled value"
fi

# 1.12 Reset
echo ""
echo "1.12 Reset"
ensure_connected
refresh_snapshot
RESET_REF=$(timeout 10 agent-flutter snapshot -i --device "$DEVICE" --json 2>/dev/null | python3 -c "import sys,json; elems=json.load(sys.stdin); r=[e for e in elems if e.get('key')=='reset_btn']; print(r[0]['ref'] if r else '')" 2>/dev/null || echo "")
if [ -n "$RESET_REF" ]; then
  check "press reset button" "agent-flutter press '$RESET_REF' --device '$DEVICE'"
  sleep 0.5
  refresh_snapshot
  check_output "counter reset to 0" "agent-flutter text --device '$DEVICE' --json" "Counter: 0"
else
  skip "press reset button (not found)"
  skip "counter reset to 0"
fi

# 1.13 Disconnect + reconnect
echo ""
echo "1.13 Disconnect/Reconnect"
check "disconnect" "agent-flutter disconnect --device '$DEVICE'"
check "status shows disconnected" "! agent-flutter status --device '$DEVICE' --json 2>&1 | grep -q '\"connected\":true'"
# Ensure app is in foreground before reconnecting
timeout 5 adb -s "$DEVICE" shell am start -n com.example.marionette_test_app/.MainActivity >/dev/null 2>&1 || true
sleep 1
check "reconnect" "agent-flutter connect '$VM_SERVICE_URI' --device '$DEVICE'"

# ═══════════════════════════════════════════
# Part 2: agent-flow recording pipeline
# ═══════════════════════════════════════════
echo ""
echo "── Part 2: agent-flow recording pipeline ──"

# Ensure connection for Part 2
ensure_connected
refresh_snapshot

FLOW_FILE="shared/e2e-flutter-app/e2e/flows/counter-increment.yaml"
RUN_OUTPUT="/tmp/e2e-agent-flow-runs-$$"
mkdir -p "$RUN_OUTPUT"

# 2.1 Record init
echo ""
echo "2.1 Record init"
INIT_OUTPUT=$(timeout 15 agent-flow record init --flow "$FLOW_FILE" --output-dir "$RUN_OUTPUT" --no-video --json 2>&1)
RUN_ID=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
RUN_DIR_PATH=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['dir'])" 2>/dev/null || echo "")

check "record init returns run ID" "[ -n '$RUN_ID' ]"
check "run ID is 10 chars" "[ ${#RUN_ID} -eq 10 ]"
check "run dir exists" "[ -d '$RUN_DIR_PATH' ]"
check "flow.lock.yaml created" "[ -f '$RUN_DIR_PATH/flow.lock.yaml' ]"
check "recipe returned" "echo '$INIT_OUTPUT' | grep -q 'recipe'"

# 2.2 Stream events
echo ""
echo "2.2 Record stream"

# Stream step S1 events
TS=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
EVENTS_S1=$(cat <<EOEVENTS
{"type":"step.start","step_id":"S1","name":"Verify initial state","ts":"$TS"}
{"type":"assert","step_id":"S1","expect":"text_visible","values":["Counter: 0"],"passed":true,"milestone":"counter-zero","ts":"$TS"}
{"type":"assert","step_id":"S1","expect":"text_visible","values":["Status: Ready"],"passed":true,"milestone":"status-ready","ts":"$TS"}
{"type":"step.end","step_id":"S1","status":"pass","ts":"$TS"}
EOEVENTS
)
echo "$EVENTS_S1" | timeout 15 agent-flow record stream --run-id "$RUN_ID" --run-dir "$RUN_DIR_PATH" >/dev/null 2>&1
STREAM_LINES=$(wc -l < "$RUN_DIR_PATH/events.jsonl" 2>/dev/null || echo 0)
check "stream accepts events" "[ $STREAM_LINES -gt 0 ]"

# Press increment and stream step S2
timeout 10 agent-flutter press e1 --device "$DEVICE" >/dev/null 2>&1
sleep 0.5
refresh_snapshot

TS2=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
EVENTS_S2=$(cat <<EOEVENTS2
{"type":"step.start","step_id":"S2","name":"Tap increment","ts":"$TS2"}
{"type":"action","step_id":"S2","action":"press","target":"increment_btn","ts":"$TS2"}
{"type":"assert","step_id":"S2","expect":"text_visible","values":["Counter: 1"],"passed":true,"milestone":"counter-incremented","ts":"$TS2"}
{"type":"step.end","step_id":"S2","status":"pass","ts":"$TS2"}
EOEVENTS2
)
echo "$EVENTS_S2" | timeout 15 agent-flow record stream --run-id "$RUN_ID" --run-dir "$RUN_DIR_PATH" --json >/dev/null 2>&1

# Press again and stream step S3
timeout 10 agent-flutter press e1 --device "$DEVICE" >/dev/null 2>&1
sleep 0.5
refresh_snapshot

TS3=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
EVENTS_S3=$(cat <<EOEVENTS3
{"type":"step.start","step_id":"S3","name":"Tap increment again","ts":"$TS3"}
{"type":"action","step_id":"S3","action":"press","target":"increment_btn","ts":"$TS3"}
{"type":"assert","step_id":"S3","expect":"text_visible","values":["Counter: 2"],"passed":true,"milestone":"counter-two","ts":"$TS3"}
{"type":"step.end","step_id":"S3","status":"pass","ts":"$TS3"}
EOEVENTS3
)
echo "$EVENTS_S3" | timeout 15 agent-flow record stream --run-id "$RUN_ID" --run-dir "$RUN_DIR_PATH" --json >/dev/null 2>&1

# S4 final verification
TS4=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
EVENTS_S4=$(cat <<EOEVENTS4
{"type":"step.start","step_id":"S4","name":"Verify final state","ts":"$TS4"}
{"type":"assert","step_id":"S4","expect":"text_visible","values":["Counter: 2"],"passed":true,"milestone":"counter-two-final","ts":"$TS4"}
{"type":"step.end","step_id":"S4","status":"pass","ts":"$TS4"}
EOEVENTS4
)
echo "$EVENTS_S4" | timeout 15 agent-flow record stream --run-id "$RUN_ID" --run-dir "$RUN_DIR_PATH" --json >/dev/null 2>&1

check "events.jsonl has data" "[ -s '$RUN_DIR_PATH/events.jsonl' ]"
EVENT_COUNT=$(wc -l < "$RUN_DIR_PATH/events.jsonl" 2>/dev/null || echo 0)
check ">=12 events recorded" "[ $EVENT_COUNT -ge 12 ]"

# 2.3 Record finish
echo ""
echo "2.3 Record finish"
FINISH_OUTPUT=$(timeout 15 agent-flow record finish --run-id "$RUN_ID" --run-dir "$RUN_OUTPUT" --status pass --flow "$FLOW_FILE" --json 2>&1)
check "record finish succeeds" "echo '$FINISH_OUTPUT' | python3 -c 'import sys,json; d=json.load(sys.stdin)' 2>/dev/null"
check "run.meta.json has pass status" "cat '$RUN_DIR_PATH/run.meta.json' | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d[\"status\"]==\"pass\"'"

# 2.4 Verify
echo ""
echo "2.4 Verify"
VERIFY_OUTPUT=$(timeout 15 agent-flow verify "$FLOW_FILE" --run-dir "$RUN_DIR_PATH" --json 2>&1)
check "verify produces output" "[ -n '$VERIFY_OUTPUT' ]"
check "verify result is pass" "echo '$VERIFY_OUTPUT' | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d[\"result\"]==\"pass\", d.get(\"result\",\"missing\")'"
check "verify has steps" "echo '$VERIFY_OUTPUT' | python3 -c 'import sys,json; d=json.load(sys.stdin); assert len(d[\"steps\"])>=4'"
check "verify schema v3" "echo '$VERIFY_OUTPUT' | grep -q 'agent-flow.run'"

# Save run.json for report
echo "$VERIFY_OUTPUT" > "$RUN_DIR_PATH/run.json"

# 2.5 Report
echo ""
echo "2.5 Report"
REPORT_OUTPUT=$(timeout 15 agent-flow report "$RUN_DIR_PATH" --json 2>&1)
check "report generates HTML" "ls '$RUN_DIR_PATH'/*.html 2>/dev/null | head -1 | xargs test -s"
check "report is self-contained" "ls '$RUN_DIR_PATH'/*.html 2>/dev/null | head -1 | xargs grep -q 'DOCTYPE'"

# 2.6 Schema
echo ""
echo "2.6 agent-flow schema"
check "schema returns commands" "agent-flow schema --json | grep -q 'commands'"
check "schema has record" "agent-flow schema record --json | grep -q 'record'"
check "schema has verify" "agent-flow schema verify --json | grep -q 'verify'"

# ═══════════════════════════════════════════
# Part 3: Cross-tool integration
# ═══════════════════════════════════════════
echo ""
echo "── Part 3: Cross-tool integration ──"

# 3.1 Snapshot file
echo ""
echo "3.1 Snapshot"
SNAP_FLOW="shared/e2e-flutter-app/e2e/flows/counter-increment.yaml"
if [ -f "${SNAP_FLOW%.yaml}.snapshot.json" ]; then
  check "snapshot file exists" "[ -f '${SNAP_FLOW%.yaml}.snapshot.json' ]"
  check "snapshot has steps" "python3 -c 'import json; d=json.load(open(\"${SNAP_FLOW%.yaml}.snapshot.json\")); assert \"steps\" in d' 2>/dev/null"
else
  skip "snapshot file exists (not yet created)"
  skip "snapshot has steps"
fi

# 3.2 Run ID contract
echo ""
echo "3.2 Run ID contract"
check "run ID is base64url safe" "echo '$RUN_ID' | grep -qP '^[A-Za-z0-9_-]{10}$'"
check "run dir named by ID" "basename '$RUN_DIR_PATH' | grep -q '$RUN_ID'"

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════"
echo -e "  E2E Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$SKIP skipped${NC} / $TOTAL total"
echo "═══════════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
  echo -e "  ${GREEN}ALL TESTS PASSED${NC}"
  exit 0
else
  echo -e "  ${RED}SOME TESTS FAILED${NC}"
  exit 1
fi
