# Phase 3: Agent-grade foundation

Applies Justin Poehnelt's "Rewrite your CLI for AI agents" principles to flow-walker.
Core idea: "Human DX optimizes for discoverability and forgiveness. Agent DX optimizes for predictability and defense-in-depth."

## Reference

- https://justin.poehnelt.com/posts/rewrite-your-cli-for-ai-agents/
- agent-flutter Phase 5 (src/errors.ts, src/validate.ts, src/command-schema.ts)

## Requirements

### 1. Structured errors (src/errors.ts)

Every error must be a typed object with:
- `code` — machine-readable error code (INVALID_ARGS, INVALID_INPUT, FILE_NOT_FOUND, FLOW_PARSE_ERROR, STEP_FAILED, DEVICE_ERROR, COMMAND_FAILED)
- `message` — human-readable description
- `hint` — actionable recovery suggestion ("Run: flow-walker schema run")
- `diagnosticId` — unique 8-char hex ID for log correlation

JSON error envelope: `{"error": {"code": "...", "message": "...", "hint": "...", "diagnosticId": "..."}}`

All throw sites in walker.ts, runner.ts, flow-parser.ts, agent-bridge.ts, capture.ts must use FlowWalkerError, not raw Error/string.

### 2. Input hardening (src/validate.ts)

"Agents hallucinate. Build like it." — validate all inputs before dispatch:

- `validateFlowPath(path)` — file exists, ends in .yaml/.yml, no path traversal (reject ..), no control chars
- `validateOutputDir(dir)` — no path traversal, sandboxed to cwd or absolute, no control chars
- `validateUri(uri)` — valid ws:// or wss:// URI format
- `validateBundleId(id)` — valid reverse-domain format, no control chars
- `rejectControlChars(str)` — reject ASCII < 0x20 except \n and \t

Applied in cli.ts BEFORE command dispatch. Fail fast with FlowWalkerError(INVALID_INPUT, ...).

### 3. Command schema (src/command-schema.ts)

Centralized metadata for all commands — single source of truth:

```typescript
type CommandSchema = {
  name: string;
  description: string;
  args: { name: string; required: boolean; description: string }[];
  flags: { name: string; description: string; default?: string }[];
  exitCodes: Record<string, string>;
  examples: string[];
};
```

Must cover: walk, run, report, schema.

### 4. `schema` subcommand

```bash
flow-walker schema           # all commands (JSON array)
flow-walker schema walk      # single command schema
flow-walker schema run
flow-walker schema report
```

Always outputs JSON. Agents use this for runtime introspection — no static docs needed.

### 5. TTY-aware JSON mode resolution

Precedence: `--no-json` > `--json` > `FLOW_WALKER_JSON=1` env > TTY detection

- Human at terminal (TTY) → friendly human output by default
- Piped/CI (non-TTY) → auto-JSON
- `--json` or `--no-json` always wins
- `FLOW_WALKER_JSON=1` env var enables JSON in TTY

All three commands (walk, run, report) must respect this.

### 6. `--dry-run` for `run` command

Parses the YAML flow, resolves all step targets against current snapshot, reports what WOULD happen — without executing any actions.

Output (JSON): array of { step, action, target, resolved: true/false }

Lets agents validate flows before mutating device state.

### 7. NDJSON streaming for `walk`

In JSON mode, walk emits one JSON line per event (newline-delimited JSON):
- `{"type":"screen","id":"abc123","name":"home","elementCount":24}`
- `{"type":"edge","source":"abc123","target":"def456","element":"@e3"}`
- `{"type":"skip","element":"@e5","reason":"blocklist: delete"}`
- `{"type":"error","code":"DEVICE_ERROR","message":"..."}`
- `{"type":"result","screensFound":24,"flowsGenerated":12}`

Agents can process incrementally without buffering. Protects context window.

### 8. Pre-dispatch validation in cli.ts

cli.ts must validate all inputs BEFORE calling walk/run/report handlers:
- Check required args (flow path for run, run dir for report)
- Validate paths via validate.ts
- Validate URIs via validate.ts
- Resolve JSON mode via flag > env > TTY
- Fail with structured FlowWalkerError, not process.exit with console.error

### 9. Environment variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `FLOW_WALKER_JSON` | JSON output mode (`1`) | unset (TTY detection) |
| `FLOW_WALKER_DRY_RUN` | Dry-run mode (`1`) | unset |
| `FLOW_WALKER_OUTPUT_DIR` | Default output directory | `./flows/` (walk), `./run-output/` (run) |
| `FLOW_WALKER_AGENT_PATH` | Path to agent-flutter binary | `agent-flutter` |

Precedence: CLI flag > env var > built-in default.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (walk complete, all flow steps pass) |
| `1` | Flow has failing steps (run command only) |
| `2` | Error (invalid args, file not found, device error, parse error) |

## Acceptance criteria

1. `flow-walker schema` outputs valid JSON array with all 4 commands
2. `flow-walker schema run` outputs single command schema
3. `flow-walker run nonexistent.yaml` produces structured JSON error with code INVALID_INPUT and hint
4. `flow-walker run --dry-run flow.yaml` parses and resolves without executing
5. Non-TTY output is JSON by default (without --json flag)
6. `FLOW_WALKER_JSON=1 flow-walker walk --help` produces JSON, not human text
7. All validate.ts functions reject path traversal (../), control chars, invalid URIs
8. All errors include diagnosticId (8-char hex)
9. walk in JSON mode emits NDJSON (one object per line)
10. Every FlowWalkerError has code, message, hint fields
11. No raw Error() or string throws remain in src/*.ts (all converted to FlowWalkerError)
12. Tests cover: error codes, validation functions, schema output, JSON mode resolution, dry-run
