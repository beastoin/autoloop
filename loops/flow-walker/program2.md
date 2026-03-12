# flow-walker Phase 2 — Run + Report (Open Source CLI v0.1)

## Goal

Extend flow-walker from a BFS explorer into an open-source CLI product that
**executes** YAML flow definitions and produces **interactive HTML reports**.

```
flow-walker run flow.yaml         # Execute flow → run.json + video + screenshots
flow-walker report run.json       # Generate self-contained HTML viewer
```

npm package: `flow-walker-cli` (MIT license)

## Problem

The BFS explorer (Phase 1) discovers screens automatically. But teams also need to:
- **Run** pre-defined flows (regression testing, CI)
- **Report** results with video, screenshots, and step-by-step pass/fail
- **Share** results as self-contained HTML files

No existing tool combines flow execution with auto-explore AND produces
agent-readable + human-reviewable output.

## Requirements

### 1. YAML Flow Parser
Parse the flow format used in `app/e2e/flows/*.yaml` (34 reference flows).

Fields to support:
- `name`, `description`, `covers`, `prerequisites`, `setup`
- `steps[]` — each step has:
  - `name` (required)
  - `press` — `{ type, position, hint, bottom_nav_tab }` or `{ ref }`
  - `scroll` — `up | down | left | right`
  - `fill` — `{ type, value }`
  - `back` — `true`
  - `assert` — `{ interactive_count: { min }, bottom_nav_tabs: { min } }`
  - `screenshot` — label for the capture
  - `note` — human-readable context (ignored by executor)

### 2. Step Executor
Execute each step via agent-flutter commands:
- `press` → resolve target element from snapshot, call `agent-flutter press @eN`
  - `{ type: button, position: rightmost }` → find rightmost button in snapshot
  - `{ bottom_nav_tab: N }` → find Nth InkWell at y>780
  - `{ type: gesture, hint: "..." }` → best-effort match from snapshot
  - `{ ref: "@e3" }` → direct ref (re-snapshot first, refs are stale)
- `scroll` → `agent-flutter scroll <direction>`
- `fill` → find textfield, `agent-flutter fill @eN "value"`
- `back` → `agent-flutter back`
- `assert` → snapshot and check:
  - `interactive_count.min` — at least N interactive elements
  - `bottom_nav_tabs.min` — at least N InkWell elements at y>780

Each step produces: pass/fail status, element count, timestamp.

Error handling: step fails → mark FAIL, continue remaining steps, report partial.

### 3. Per-Step Capture
For each step:
- Screenshot via `agent-flutter screenshot <path>`
- Timestamp (ms since flow start)
- Interactive element count from snapshot
- Step duration (ms)

### 4. Video Capture
- Start `adb shell screenrecord` before first step
- Stop after last step (kill process)
- Collect video file from device via `adb pull`
- Note: ADB screenrecord max 180s — warn if flow exceeds

### 5. Device Logs
- Start `adb logcat -c && adb logcat` at flow start
- Stop after last step
- Filter to app PID or Flutter tag
- Save as `<run-dir>/device.log`

### 6. run.json Schema
```json
{
  "flow": "tab-navigation",
  "device": "Pixel_7a",
  "startedAt": "2026-03-12T10:00:00Z",
  "duration": 17600,
  "result": "pass",
  "steps": [
    {
      "name": "Verify home tab",
      "action": "assert",
      "status": "pass",
      "timestamp": 1000,
      "duration": 2300,
      "elementCount": 24,
      "screenshot": "step-1-home.png",
      "assertion": { "interactive_count": { "min": 20, "actual": 24 } }
    }
  ],
  "video": "recording.mp4",
  "log": "device.log"
}
```

### 7. HTML Report Generator
Read `run.json` → self-contained HTML file with:
- Embedded video (base64 MP4) with clickable step timeline
- Per-step: screenshot thumbnail, assertion result (PASS/FAIL), YAML source
- Responsive layout (video left, steps right on desktop; stacked on mobile)
- Keyboard shortcuts: 1-N jump to step, Space play/pause
- Header: flow name, device, duration, overall pass/fail
- Legend: PASS/FAIL dots, step count, duration

Reference: `app/e2e/viewer/tab-navigation.html` (working prototype)

### 8. CLI Commands

```
flow-walker run <flow.yaml> [options]
  --output-dir <dir>    Output directory (default: ./run-<timestamp>/)
  --device <serial>     ADB device serial
  --no-video            Skip video recording
  --no-logs             Skip logcat capture
  --json                Machine-readable output

flow-walker report <run.json> [options]
  --output <path>       Output HTML path (default: <run-dir>/report.html)
  --no-video            Exclude video from HTML (smaller file)
```

### 9. npm Package Structure
```
flow-walker-cli/
  src/
    cli.ts              — CLI entry (walk, run, report subcommands)
    walker.ts           — existing BFS walker
    runner.ts           — YAML flow executor
    reporter.ts         — HTML report generator
    flow-parser.ts      — YAML flow parser + validator
    capture.ts          — screenshot, video, logcat helpers
    run-schema.ts       — run.json types + validation
    fingerprint.ts      — existing
    graph.ts            — existing
    safety.ts           — existing
    yaml-writer.ts      — existing
    agent-bridge.ts     — existing (extend with screenshot, screenrecord)
    types.ts            — existing (extend)
  tests/
    flow-parser.test.ts
    runner.test.ts
    reporter.test.ts
    capture.test.ts
    run-schema.test.ts
    ...existing tests...
  package.json          — name: flow-walker-cli, bin: flow-walker
  tsconfig.json
  LICENSE               — MIT
```

## Acceptance Criteria

- [ ] `flow-walker run tab-navigation.yaml` executes all steps, produces run.json
- [ ] run.json contains all required fields (steps, video, log, timestamps)
- [ ] Each step has pass/fail, screenshot path, element count, duration
- [ ] Video is captured and saved (or warns if >180s)
- [ ] `flow-walker report run.json` produces self-contained HTML
- [ ] HTML has embedded video with step timeline (click step → seek video)
- [ ] HTML is responsive (desktop: side-by-side; mobile: stacked)
- [ ] Existing `flow-walker walk` still works (no regression)
- [ ] All existing tests pass (43 tests)
- [ ] New tests for: flow-parser, runner, reporter, capture, run-schema
- [ ] TypeScript compiles clean

## Non-goals (Phase 2)

- Hosted sharing (Phase 2 of product = Phase 3 of autoloop)
- CI integration (v0.2)
- Native platform support without Marionette (v0.3)
- Auto-explore integration with run (v0.1.5 — separate phase)

## Build and Test

```bash
cd loops/flow-walker/flow-walker
npm install
npm test
npx tsc --noEmit
```

```bash
bash loops/flow-walker/eval2.sh
```
