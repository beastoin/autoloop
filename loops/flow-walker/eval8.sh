#!/usr/bin/env bash
# Eval harness for flow-walker Phase 8 (record + verify).
# Usage: bash loops/flow-walker/eval8.sh
# DO NOT MODIFY THIS FILE DURING ACTIVE LOOP.

set -uo pipefail
cd "$(dirname "$0")/../.."

export PATH="/home/claude/tools/node/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export NODE_OPTIONS="--experimental-strip-types"

WALKER_DIR="loops/flow-walker/flow-walker"
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

echo "=== flow-walker Phase 8 eval ==="

# Gate 1 (AC1): record module exports
echo ""
echo "── Gate 1: Record module exports ──"
check "AC1: record.ts exports recordInit, recordStream, recordFinish" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { recordInit, recordStream, recordFinish } from \"./src/record.ts\";
    if (typeof recordInit !== \"function\") process.exit(1);
    if (typeof recordStream !== \"function\") process.exit(1);
    if (typeof recordFinish !== \"function\") process.exit(1);
  '
"

# Gate 2 (AC2): verify module exports
echo ""
echo "── Gate 2: Verify module exports ──"
check "AC2: verify.ts exports verifyRun" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { verifyRun } from \"./src/verify.ts\";
    if (typeof verifyRun !== \"function\") process.exit(1);
  '
"

# Gate 3 (AC3): event schema exports
echo ""
echo "── Gate 3: Event schema exports ──"
check "AC3: event-schema.ts exports validateEvent and EVENT_TYPES" bash -c "
  cd '$WALKER_DIR' &&
  node --experimental-strip-types --input-type=module -e '
    import { validateEvent, EVENT_TYPES } from \"./src/event-schema.ts\";
    if (typeof validateEvent !== \"function\") process.exit(1);
    if (!Array.isArray(EVENT_TYPES)) process.exit(1);
    const expected = [\"run.start\", \"step.start\", \"action\", \"assert\", \"artifact\", \"step.end\", \"run.end\", \"note\"];
    for (const t of expected) {
      if (!EVENT_TYPES.includes(t)) process.exit(1);
    }
  '
"

# Gate 4 (AC4): record init creates run directory structure
echo ""
echo "── Gate 4: Record init creates run dir ──"
check "AC4: record init creates flow.lock.yaml, run.meta.json, events.jsonl" bash -c "
  tmpdir=\$(mktemp -d)
  flowfile=\$(mktemp --suffix=.yaml)
  cat > \"\$flowfile\" <<'EOF'
version: 2
name: eval8-test
steps:
  - id: S1
    do: Open home
    anchors: [home]
    expect:
      - milestone: home-visible
        outcome: pass
    evidence:
      - screenshot: home.png
EOF
  cd '$WALKER_DIR' &&
  out=\$(node --experimental-strip-types src/cli.ts record init --flow \"\$flowfile\" --output-dir \"\$tmpdir\" --json 2>&1) &&
  run_dir=\$(echo \"\$out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.dir)})') &&
  [ -f \"\$run_dir/flow.lock.yaml\" ] &&
  [ -f \"\$run_dir/run.meta.json\" ] &&
  [ -f \"\$run_dir/events.jsonl\" ] &&
  grep -q 'version: 2' \"\$run_dir/flow.lock.yaml\" &&
  node --input-type=module -e '
    import { readFileSync } from \"fs\";
    const meta = JSON.parse(readFileSync(process.argv[1], \"utf-8\"));
    if (meta.status !== \"recording\") process.exit(1);
    if (!meta.id) process.exit(1);
    if (!meta.startedAt) process.exit(1);
  ' \"\$run_dir/run.meta.json\"
"

# Gate 5 (AC5): record stream appends events with seq/ts
echo ""
echo "── Gate 5: Record stream appends events ──"
check "AC5: record stream validates and appends events with auto-seq/ts" bash -c "
  tmpdir=\$(mktemp -d)
  flowfile=\$(mktemp --suffix=.yaml)
  cat > \"\$flowfile\" <<'EOF'
version: 2
name: eval8-stream
steps:
  - id: S1
    do: Test step
    expect: []
    evidence: []
EOF
  cd '$WALKER_DIR' &&
  init_out=\$(node --experimental-strip-types src/cli.ts record init --flow \"\$flowfile\" --output-dir \"\$tmpdir\" --json 2>&1) &&
  run_id=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.id)})') &&
  run_dir=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.dir)})') &&
  printf '{\"type\":\"step.start\",\"step_id\":\"S1\"}\n{\"type\":\"action\",\"step_id\":\"S1\",\"message\":\"pressed home\"}\n{\"type\":\"step.end\",\"step_id\":\"S1\",\"status\":\"pass\"}\n' | \
    node --experimental-strip-types src/cli.ts record stream --run-id \"\$run_id\" --run-dir \"\$tmpdir\" --json 2>&1 &&
  line_count=\$(wc -l < \"\$run_dir/events.jsonl\") &&
  [ \"\$line_count\" -eq 3 ] &&
  node --input-type=module -e '
    import { readFileSync } from \"fs\";
    const lines = readFileSync(process.argv[1], \"utf-8\").trim().split(\"\\n\");
    for (let i = 0; i < lines.length; i++) {
      const ev = JSON.parse(lines[i]);
      if (ev.seq !== i) process.exit(1);
      if (!ev.ts) process.exit(1);
    }
  ' \"\$run_dir/events.jsonl\"
"

# Gate 6 (AC6): record finish updates meta
echo ""
echo "── Gate 6: Record finish updates meta ──"
check "AC6: record finish sets finishedAt, status, eventCount in meta" bash -c "
  tmpdir=\$(mktemp -d)
  flowfile=\$(mktemp --suffix=.yaml)
  cat > \"\$flowfile\" <<'EOF'
version: 2
name: eval8-finish
steps:
  - id: S1
    do: Test step
    expect: []
    evidence: []
EOF
  cd '$WALKER_DIR' &&
  init_out=\$(node --experimental-strip-types src/cli.ts record init --flow \"\$flowfile\" --output-dir \"\$tmpdir\" --json 2>&1) &&
  run_id=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.id)})') &&
  run_dir=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.dir)})') &&
  printf '{\"type\":\"step.start\",\"step_id\":\"S1\"}\n{\"type\":\"step.end\",\"step_id\":\"S1\",\"status\":\"pass\"}\n' | \
    node --experimental-strip-types src/cli.ts record stream --run-id \"\$run_id\" --run-dir \"\$tmpdir\" --json 2>&1 &&
  node --experimental-strip-types src/cli.ts record finish --run-id \"\$run_id\" --run-dir \"\$tmpdir\" --status pass --json 2>&1 &&
  node --input-type=module -e '
    import { readFileSync } from \"fs\";
    const meta = JSON.parse(readFileSync(process.argv[1], \"utf-8\"));
    if (meta.status !== \"pass\") process.exit(1);
    if (!meta.finishedAt) process.exit(1);
    if (typeof meta.eventCount !== \"number\") process.exit(1);
    if (meta.eventCount !== 2) process.exit(1);
  ' \"\$run_dir/run.meta.json\"
"

# Gate 7 (AC7): verify strict mode
echo ""
echo "── Gate 7: Verify strict mode ──"
check "AC7: verify strict checks step order, all expects, no unknowns" bash -c "
  tmpdir=\$(mktemp -d)
  flowfile=\$(mktemp --suffix=.yaml)
  cat > \"\$flowfile\" <<'EOF'
version: 2
name: verify-strict-test
steps:
  - id: S1
    do: Open home
    expect:
      - milestone: home-visible
        outcome: pass
  - id: S2
    do: Press tab
    expect:
      - milestone: tab-switched
        outcome: pass
EOF
  cd '$WALKER_DIR' &&
  init_out=\$(node --experimental-strip-types src/cli.ts record init --flow \"\$flowfile\" --output-dir \"\$tmpdir\" --json 2>&1) &&
  run_id=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.id)})') &&
  run_dir=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.dir)})') &&
  printf '{\"type\":\"step.start\",\"step_id\":\"S1\"}\n{\"type\":\"assert\",\"step_id\":\"S1\",\"milestone\":\"home-visible\",\"outcome\":\"pass\"}\n{\"type\":\"step.end\",\"step_id\":\"S1\",\"status\":\"pass\"}\n{\"type\":\"step.start\",\"step_id\":\"S2\"}\n{\"type\":\"assert\",\"step_id\":\"S2\",\"milestone\":\"tab-switched\",\"outcome\":\"pass\"}\n{\"type\":\"step.end\",\"step_id\":\"S2\",\"status\":\"pass\"}\n' | \
    node --experimental-strip-types src/cli.ts record stream --run-id \"\$run_id\" --run-dir \"\$tmpdir\" --json 2>&1 &&
  node --experimental-strip-types src/cli.ts record finish --run-id \"\$run_id\" --run-dir \"\$tmpdir\" --status pass --json 2>&1 &&
  node --experimental-strip-types src/cli.ts verify \"\$flowfile\" --run-dir \"\$run_dir\" --mode strict --json 2>&1 &&
  verify_exit=\$? &&
  [ \"\$verify_exit\" -eq 0 ]
"

# Gate 8 (AC8): verify balanced accepts skipped
echo ""
echo "── Gate 8: Verify balanced accepts skipped ──"
check "AC8: verify balanced accepts skipped steps with reason" bash -c "
  tmpdir=\$(mktemp -d)
  flowfile=\$(mktemp --suffix=.yaml)
  cat > \"\$flowfile\" <<'EOF'
version: 2
name: verify-balanced-test
steps:
  - id: S1
    do: Open home
    expect:
      - milestone: home-visible
        outcome: pass
  - id: S2
    do: Press tab
    expect:
      - milestone: tab-switched
        outcome: pass
EOF
  cd '$WALKER_DIR' &&
  init_out=\$(node --experimental-strip-types src/cli.ts record init --flow \"\$flowfile\" --output-dir \"\$tmpdir\" --json 2>&1) &&
  run_id=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.id)})') &&
  run_dir=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.dir)})') &&
  printf '{\"type\":\"step.start\",\"step_id\":\"S1\"}\n{\"type\":\"assert\",\"step_id\":\"S1\",\"milestone\":\"home-visible\",\"outcome\":\"pass\"}\n{\"type\":\"step.end\",\"step_id\":\"S1\",\"status\":\"pass\"}\n{\"type\":\"step.start\",\"step_id\":\"S2\"}\n{\"type\":\"step.end\",\"step_id\":\"S2\",\"status\":\"skipped\",\"reason\":\"tab not visible\"}\n' | \
    node --experimental-strip-types src/cli.ts record stream --run-id \"\$run_id\" --run-dir \"\$tmpdir\" --json 2>&1 &&
  node --experimental-strip-types src/cli.ts record finish --run-id \"\$run_id\" --run-dir \"\$tmpdir\" --status pass --json 2>&1 &&
  node --experimental-strip-types src/cli.ts verify \"\$flowfile\" --run-dir \"\$run_dir\" --mode balanced --json 2>&1 &&
  verify_exit=\$? &&
  [ \"\$verify_exit\" -eq 0 ]
"

# Gate 9 (AC9): verify audit mode always passes
echo ""
echo "── Gate 9: Verify audit always passes ──"
check "AC9: verify audit mode passes even with missing steps" bash -c "
  tmpdir=\$(mktemp -d)
  flowfile=\$(mktemp --suffix=.yaml)
  cat > \"\$flowfile\" <<'EOF'
version: 2
name: verify-audit-test
steps:
  - id: S1
    do: Open home
    expect:
      - milestone: home-visible
        outcome: pass
  - id: S2
    do: Press tab
    expect:
      - milestone: tab-switched
        outcome: pass
EOF
  cd '$WALKER_DIR' &&
  init_out=\$(node --experimental-strip-types src/cli.ts record init --flow \"\$flowfile\" --output-dir \"\$tmpdir\" --json 2>&1) &&
  run_id=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.id)})') &&
  run_dir=\$(echo \"\$init_out\" | node --input-type=module -e 'let d=\"\";process.stdin.on(\"data\",c=>d+=c);process.stdin.on(\"end\",()=>{const o=JSON.parse(d);console.log(o.dir)})') &&
  printf '{\"type\":\"step.start\",\"step_id\":\"S1\"}\n{\"type\":\"step.end\",\"step_id\":\"S1\",\"status\":\"pass\"}\n' | \
    node --experimental-strip-types src/cli.ts record stream --run-id \"\$run_id\" --run-dir \"\$tmpdir\" --json 2>&1 &&
  node --experimental-strip-types src/cli.ts record finish --run-id \"\$run_id\" --run-dir \"\$tmpdir\" --status pass --json 2>&1 &&
  node --experimental-strip-types src/cli.ts verify \"\$flowfile\" --run-dir \"\$run_dir\" --mode audit --json 2>&1 &&
  verify_exit=\$? &&
  [ \"\$verify_exit\" -eq 0 ]
"

# Gate 10 (AC10): CLI wires record and verify
echo ""
echo "── Gate 10: CLI wired ──"
check "AC10: record and verify no longer return NOT_IMPLEMENTED" bash -c "
  cd '$WALKER_DIR' &&
  ! grep -q 'notImplemented.*record' src/cli.ts &&
  ! grep -q 'notImplemented.*verify' src/cli.ts
"

# Gate 11 (AC11): typecheck
echo ""
echo "── Gate 11: Typecheck ──"
check "AC11: npx tsc --noEmit passes" bash -c "
  cd '$WALKER_DIR' && npx tsc --noEmit 2>&1
"

# Gate 12 (AC12): tests pass with sufficient count
echo ""
echo "── Gate 12: Tests ──"
TEST_LOG=$(mktemp)
(cd "$WALKER_DIR" && npm test >"$TEST_LOG" 2>&1)
TEST_EXIT=$?
TEST_COUNT=$(grep -oE 'tests [0-9]+' "$TEST_LOG" | awk '{print $2}' | tail -n1)
check "AC12: npm test passes and test count >= 220 (was ${TEST_COUNT:-0})" bash -c "
  [ '$TEST_EXIT' -eq 0 ] &&
  grep -q 'fail 0' '$TEST_LOG' &&
  [ '${TEST_COUNT:-0}' -ge 220 ]
"

# ── Summary ──
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  echo "EVAL: FAIL"
  exit 1
else
  echo "EVAL: PASS"
  exit 0
fi
