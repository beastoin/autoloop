# agent-flow — Agent Workflow Guide

## What is agent-flow

agent-flow is the **flow layer** — it discovers, executes, and reports on app flows.
It uses [agent-flutter](https://github.com/beastoin/agent-flutter) and [agent-swift](https://github.com/beastoin/agent-swift) as **transport layers** that control specific platforms.

**Eight commands:**
- `walk` — BFS-explore the app, discover screens, generate YAML flows
- `record` — 3-phase recording: `init` → `stream` → `finish`
- `verify` — Verify recorded events against flow expectations, produce run.json
- `report` — Generate self-contained HTML report from run results
- `push` — Upload report to hosted service, return shareable URL
- `get` — Fetch run data from hosted service by run ID
- `snapshot` — Save/load replay data for fast re-execution
- `schema` — Machine-readable command introspection (agent discovery)

## Agent-first workflow

```bash
# 1. Discover available commands
agent-flow schema                    # → { version, commands: [...] }
agent-flow schema record             # → args, flags with types, exit codes

# 2. Record a flow (3-phase pipeline)
agent-flow record init --flow flow.yaml --json
# => {"id":"P-tnB_sgKA","dir":"runs/P-tnB_sgKA","recipe":[...]}

# 3. Stream events
echo '{"type":"step.start","step_id":"S1"}' | \
  agent-flow record stream --run-id P-tnB_sgKA --run-dir runs/P-tnB_sgKA

# 4. Finish recording
agent-flow record finish --run-id P-tnB_sgKA --run-dir runs/P-tnB_sgKA \
  --status pass --flow flow.yaml --json

# 5. Verify events against flow expectations
agent-flow verify flow.yaml --run-dir runs/P-tnB_sgKA --json > runs/P-tnB_sgKA/run.json

# 6. Report
agent-flow report runs/P-tnB_sgKA/

# 7. Share (hosted)
agent-flow push runs/P-tnB_sgKA/ --json  # → { id, url, htmlUrl, expiresAt }

# 8. Retrieve run data later
agent-flow get P-tnB_sgKA --json          # → run.json content

# Version check
agent-flow --version                      # → agent-flow 0.6.1
agent-flow --version --json               # → {"version":"0.6.1"}
```

## Prerequisites

1. **agent-flutter** installed and in PATH (`npm install -g @beastoin/agent-flutter`)
2. Flutter app running with Marionette initialized
3. ADB connected (Android) or Simulator running (iOS)
4. Run `agent-flutter doctor` to verify setup

## Run IDs

Every `agent-flow record init` generates a unique **10-char base64url ID** (e.g. `P-tnB_sgKA`).

- Output goes to `<output-dir>/<run-id>/` — multiple runs never overwrite
- `run.json` includes `"id": "P-tnB_sgKA"` as top-level field
- Agents can correlate runs by ID across logs, reports, and API calls
- Composite key `{flow}/{id}` (e.g. `tab-navigation/P-tnB_sgKA`) for human reference

## Canonical workflows

### Auto-explore an app

```bash
agent-flutter connect ws://127.0.0.1:38047/abc=/ws
agent-flow walk --skip-connect --max-depth 3 --output-dir ./flows/
# Output: YAML flows + _nav-graph.json
```

### Record and verify a flow

```bash
# Initialize run
agent-flow record init --flow flows/login.yaml --json
# => {"id":"P-tnB_sgKA","dir":"runs/P-tnB_sgKA"}

# (Agent executes flow, streams events via record stream)

# Finish and verify
agent-flow record finish --run-id P-tnB_sgKA --run-dir runs/ --status pass --flow flows/login.yaml
agent-flow verify flows/login.yaml --run-dir runs/P-tnB_sgKA --json > runs/P-tnB_sgKA/run.json
```

### Generate report

```bash
agent-flow report runs/P-tnB_sgKA/
# Output: report.html (self-contained, can be shared)
```

### Run a flow suite

```bash
for flow in flows/*.yaml; do
  ID=$(agent-flow record init --flow "$flow" --json | jq -r '.id')
  # ... agent executes and streams events ...
  agent-flow record finish --run-id "$ID" --run-dir runs/ --status pass --flow "$flow"
  agent-flow verify "$flow" --run-dir "runs/$ID" --json > "runs/$ID/run.json"
done
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
  "version": "0.6.1",
  "commands": [
    {
      "name": "record",
      "description": "3-phase recording pipeline: init → stream → finish",
      "args": [{ "name": "subcommand", "required": true, "type": "string", "description": "init|stream|finish" }],
      "flags": [{ "name": "--json", "type": "boolean", "description": "..." }],
      "exitCodes": { "0": "success", "2": "error" },
      "examples": ["agent-flow record init --flow flow.yaml --json"]
    }
  ]
}
```

### push result (from push --json)

```json
{
  "id": "25h7afGwBK",
  "url": "https://agent-flow.beastoin.workers.dev/runs/25h7afGwBK",
  "htmlUrl": "https://agent-flow.beastoin.workers.dev/runs/25h7afGwBK.html",
  "expiresAt": "2026-04-11T13:22:12.070Z"
}
```

### Command outputShape (from schema)

Commands that produce structured output declare their fields via `outputShape`:

```json
{
  "name": "verify",
  "outputShape": [
    { "name": "flow", "type": "string", "description": "Flow name" },
    { "name": "result", "type": "pass|fail|unverified", "description": "Overall result" },
    { "name": "automatedResult", "type": "pass|fail", "description": "Tier 1 result" },
    { "name": "agentResult", "type": "pass|fail|pending", "description": "Tier 2 result" },
    { "name": "steps", "type": "StepResult[]", "description": "Per-step results" }
  ]
}
```

Commands with `outputShape`: `verify`, `push`, `get`. Use `agent-flow schema <cmd>` to inspect.

### Agent-readable run data

After push, structured run data is available. URLs are agent-first — JSON by default:

```bash
# JSON (default) — for agents
curl https://agent-flow.beastoin.workers.dev/runs/25h7afGwBK
curl https://agent-flow.beastoin.workers.dev/runs/25h7afGwBK.json

# HTML — for humans
open https://agent-flow.beastoin.workers.dev/runs/25h7afGwBK.html
```

Returns run.json structure (without local file paths like video/screenshot filenames).

CLI equivalent:

```bash
agent-flow get 25h7afGwBK          # pretty-printed JSON
agent-flow get 25h7afGwBK --json   # compact JSON (pipe-friendly)
agent-flow get 25h7afGwBK | jq '.steps[] | select(.status=="fail")'
```

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
| Text visible | `text_visible: ["Featured", "Home"]` |
| Text absent | `text_not_visible: ["Error", "Sign In"]` |

Text assertions use Android UIAutomator (via `agent-flutter text`) to check visible text from the accessibility layer. This captures text that Marionette snapshots miss (labels, content descriptions, system UI).

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Flow has failing steps |
| `2` | Error (invalid args, file not found, device error) |

## Error codes

Every error returns `{"error": {"code": "...", "message": "...", "hint": "...", "diagnosticId": "..."}}`.

| Code | Meaning | Common cause |
|------|---------|-------------|
| `INVALID_ARGS` | Bad CLI arguments | Missing required arg, unknown subcommand |
| `INVALID_INPUT` | Input fails validation | Path traversal, control chars, bad URI format |
| `FILE_NOT_FOUND` | Required file missing | No flow YAML, no run.json, remote run not found |
| `FLOW_PARSE_ERROR` | Invalid YAML flow | Malformed YAML, missing name/steps |
| `COMMAND_FAILED` | External command error | agent-flutter failure, network error, upload failure |

## Environment variables

Precedence: CLI flag > env var > default.

| Variable | Purpose | Default |
|----------|---------|---------|
| `AGENT_FLOW_OUTPUT_DIR` | Default output directory | `./run-output/` |
| `AGENT_FLOW_AGENT_PATH` | Path to agent-flutter binary | `agent-flutter` |
| `AGENT_FLOW_DRY_RUN` | Enable dry-run mode | `0` |
| `AGENT_FLOW_JSON` | Force JSON output | auto (TTY detection) |
| `AGENT_FLOW_API_URL` | Hosted service URL for push/get | `https://agent-flow.beastoin.workers.dev` |
| `AGENT_FLUTTER_DEVICE` | ADB device ID | auto-detect |

JSON output precedence: `--no-json` > `--json` > `AGENT_FLOW_JSON=1` > TTY auto-detect (non-TTY defaults to JSON).
