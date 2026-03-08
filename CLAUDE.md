# CLAUDE.md

Practical guide for Claude Code instances working in `beastoin/autoloop`.

## Project map

### Autoloop system

- `autoresearch/standalone/` — autonomous loop programs + evaluator
- `autoresearch/standalone/agent-flutter/` — standalone CLI target
- `autoresearch/e2e-flutter-app/` — Marionette Flutter test app
- `autoresearch/e2e-eval.sh` — integration evaluator (app build/install/launch + tests)
- `autoresearch/e2e-test.ts` — platform-level VM client e2e suite

## Runtime and conventions

- Node.js: `>=22`
- language: TypeScript (ESM)
- CLI style: deterministic, machine-parseable when `--json`
- `agent-flutter` policy: zero external runtime dependencies
- avoid broad refactors in autoloop phases; keep changes phase-scoped

## Build and test commands

### Standalone (`agent-flutter`)

```bash
cd autoresearch/standalone/agent-flutter
pnpm typecheck
pnpm test:unit
```

### Phase + e2e evaluators

```bash
bash autoresearch/standalone/eval.sh
bash autoresearch/e2e-eval.sh
```

## Autoloop model

Each phase is controlled by immutable files:

1. `program*.md` — requirements and acceptance criteria
2. `eval.sh` — objective phase gate
3. `e2e-test.ts` — real runtime validation

Execution rule:

- read program
- implement
- run evaluator
- pass => keep
- fail => revert direction and iterate

Do not treat evaluator files as mutable implementation space unless explicitly asked to define a new phase.

## `agent-flutter` architecture (key modules)

- `src/cli.ts`
Global flags, mode resolution (`--json`/TTY/env), command dispatch, exit behavior.
- `src/vm-client.ts`
WebSocket JSON-RPC client for Dart VM Service and Marionette RPC (`ext.flutter.marionette.*`).
- `src/session.ts`
File-backed session (`AGENT_FLUTTER_HOME/session.json`) with refs and last snapshot.
- `src/snapshot-fmt.ts`
Ref assignment (`e1..eN`), human snapshot lines, JSON snapshot payload shaping.
- `src/errors.ts`
Structured errors (`code`, `message`, optional `hint`, `diagnosticId`) + formatters.
- `src/validate.ts`
Pre-dispatch validation for refs/text/path/device IDs.
- `src/command-schema.ts`
Canonical schema used by `schema`, `schema <cmd>`, and JSON help discovery.
- `src/commands/*.ts`
One file per command (`connect`, `snapshot`, `press`, `wait`, `is`, etc.).

## Important environment variables (`agent-flutter`)

- `AGENT_FLUTTER_DEVICE`
- `AGENT_FLUTTER_URI`
- `AGENT_FLUTTER_HOME`
- `AGENT_FLUTTER_TIMEOUT`
- `AGENT_FLUTTER_JSON`
- `AGENT_FLUTTER_DRY_RUN`

Precedence patterns to preserve:

- JSON mode: `--no-json` > `--json` > env > non-TTY auto JSON
- device: CLI `--device/--serial` > env > default
- timeout: command flag > env > default

## How to add a new command to `agent-flutter`

1. Create handler in `src/commands/<name>.ts`.
2. Register dispatch in `src/cli.ts`.
3. Add schema entry in `src/command-schema.ts`.
4. Add input validation path in `src/validate.ts` integration points (via `cli.ts`).
5. Return stable output in both human and JSON mode.
6. Use structured errors (`AgentFlutterError` + `ErrorCodes`) for user-facing failures.
7. Add or update tests in `__tests__/` (unit and contract when shape changes).
8. Run:
- `pnpm typecheck`
- `pnpm test:unit`
- relevant evaluator (`autoresearch/standalone/eval.sh`)

## Common pitfalls

- adding command logic without schema update
- changing JSON envelope shape without contract tests
- bypassing validation for new args
- changing exit-code semantics
- introducing non-deterministic output that breaks agent parsing
- editing phase control files during execution loops

## If blocked

Report:

1. blocker
2. why it blocks completion
3. exact next action/command needed to unblock
