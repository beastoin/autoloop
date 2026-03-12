# flow-walker — Agent Workflow Guide

## What is flow-walker

flow-walker is the **flow layer** — it discovers, executes, and reports on app flows.
It uses [agent-flutter](https://github.com/beastoin/agent-flutter) and [agent-swift](https://github.com/beastoin/agent-swift) as **transport layers** that control specific platforms.

**Five commands:**
- `walk` — BFS-explore the app, discover screens, generate YAML flows
- `run` — Execute a YAML flow, produce run.json + video + screenshots
- `report` — Generate self-contained HTML report from run results
- `push` — Upload report to hosted service, return shareable URL
- `schema` — Machine-readable command introspection (agent discovery)

## Agent-first workflow

```bash
# 1. Discover available commands
flow-walker schema                    # → { version, commands: [...] }
flow-walker schema run                # → args, flags with types, exit codes

# 2. Dry-run to verify flow resolves
flow-walker run flow.yaml --dry-run   # → per-step resolved/unresolved + reasons

# 3. Execute
flow-walker run flow.yaml --json      # → run.json with unique run ID

# 4. Report
flow-walker report ./run-output/<run-id>/

# 5. Share (hosted)
flow-walker push ./run-output/<run-id>/ --json  # → { url, id, expiresAt }
# URL serves the report in a browser — no auth needed
```

## Prerequisites

1. **agent-flutter** installed and in PATH (`npm install -g agent-flutter-cli`)
2. Flutter app running with Marionette initialized
3. ADB connected (Android) or Simulator running (iOS)
4. Run `agent-flutter doctor` to verify setup

## Run IDs

Every `flow-walker run` generates a unique **10-char base64url ID** (e.g. `25h7afGwBK`).

- Output goes to `<output-dir>/<run-id>/` — multiple runs never overwrite
- `run.json` includes `"id": "25h7afGwBK"` as top-level field
- Agents can correlate runs by ID across logs, reports, and API calls
- Composite key `{flow}/{id}` (e.g. `tab-navigation/25h7afGwBK`) for human reference

## Canonical workflows

### Auto-explore an app

```bash
agent-flutter connect ws://127.0.0.1:38047/abc=/ws
flow-walker walk --skip-connect --max-depth 3 --output-dir ./flows/
# Output: YAML flows + _nav-graph.json
```

### Execute a flow

```bash
flow-walker run flows/tab-navigation.yaml --output-dir ./results/
# => Run ID: 25h7afGwBK
# => Output: ./results/25h7afGwBK/run.json, recording.mp4, step-*.png, device.log
```

### Generate report

```bash
flow-walker report ./results/25h7afGwBK/
# Output: report.html (self-contained, can be shared)
```

### Run a flow suite

```bash
for flow in flows/*.yaml; do
  flow-walker run "$flow" --output-dir ./results/ --json
done
# Each run gets its own subdirectory by run ID
```

## Output shapes

### run.json

```json
{
  "id": "25h7afGwBK",
  "flow": "tab-navigation",
  "device": "Pixel_7a",
  "startedAt": "2026-03-12T10:00:00Z",
  "duration": 14200,
  "result": "pass",
  "steps": [
    {
      "index": 0,
      "name": "Verify home tab",
      "action": "assert",
      "status": "pass",
      "timestamp": 0,
      "duration": 2300,
      "elementCount": 22,
      "screenshot": "step-1-tab-home.png",
      "assertion": {
        "interactive_count": { "min": 20, "actual": 22 },
        "bottom_nav_tabs": { "min": 4, "actual": 4 }
      }
    }
  ],
  "video": "recording.mp4",
  "log": "device.log"
}
```

### _nav-graph.json (from walk)

```json
{
  "nodes": [
    { "id": "abc123", "name": "home-screen", "elementCount": 24, "visits": 3 }
  ],
  "edges": [
    { "source": "abc123", "target": "def456", "element": { "ref": "@e3", "type": "button", "text": "Settings" } }
  ]
}
```

### Schema envelope (from schema)

```json
{
  "version": "0.1.0",
  "commands": [
    {
      "name": "run",
      "description": "Execute a YAML flow...",
      "args": [{ "name": "flow", "required": true, "type": "path", "description": "..." }],
      "flags": [{ "name": "--json", "type": "boolean", "description": "..." }],
      "exitCodes": { "0": "all steps pass", "1": "one or more steps fail", "2": "error" },
      "examples": ["flow-walker run flows/tab-navigation.yaml"]
    }
  ]
}
```

### push result (from push --json)

```json
{
  "url": "https://flow-walker.beastoin.workers.dev/runs/25h7afGwBK",
  "id": "25h7afGwBK",
  "expiresAt": "2026-04-11T13:22:12.070Z"
}
```

### Agent-readable run data

After push, structured run data is available via:

```bash
# Explicit endpoint
curl https://flow-walker.beastoin.workers.dev/runs/25h7afGwBK/data
# Content negotiation
curl -H "Accept: application/json" https://flow-walker.beastoin.workers.dev/runs/25h7afGwBK
```

Returns the same run.json structure (without local file paths like video/screenshot filenames).

### Structured error (on failure)

```json
{
  "error": {
    "code": "INVALID_INPUT",
    "message": "Path contains traversal sequences",
    "hint": "Remove .. from path",
    "diagnosticId": "a1b2c3d4"
  }
}
```

## YAML flow format

```yaml
name: flow-name
description: What this flow tests
app: Omi                          # optional: app name
app_url: https://omi.me           # optional: app URL
covers:
  - app/lib/pages/home.dart
prerequisites:
  - auth_ready
setup: normal

steps:
  - name: Step description
    press: { type: button, position: rightmost }
    assert:
      interactive_count: { min: 20 }
      has_type: { type: switch, min: 2 }
    screenshot: label
```

### Press targets

| Target | Syntax |
|--------|--------|
| By ref | `{ ref: "@e3" }` |
| By type | `{ type: button }` |
| By position | `{ type: button, position: rightmost }` |
| By nav tab | `{ bottom_nav_tab: 0 }` |

### Assertions

| Assertion | Syntax |
|-----------|--------|
| Element count | `interactive_count: { min: 20 }` |
| Nav tabs | `bottom_nav_tabs: { min: 4 }` |
| Element type | `has_type: { type: switch, min: 2 }` |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Flow has failing steps |
| `2` | Error (invalid args, file not found, device error) |

## Environment variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `FLOW_WALKER_OUTPUT_DIR` | Default output directory | `./run-output/` |
| `FLOW_WALKER_AGENT_PATH` | Path to agent-flutter binary | `agent-flutter` |
| `FLOW_WALKER_DRY_RUN` | Enable dry-run mode | `0` |
| `FLOW_WALKER_JSON` | Force JSON output | auto (TTY detection) |
| `FLOW_WALKER_API_URL` | Hosted service URL for push | `https://flow-walker.beastoin.workers.dev` |
| `AGENT_FLUTTER_DEVICE` | ADB device ID | auto-detect |
