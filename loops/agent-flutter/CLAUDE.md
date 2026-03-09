# CLAUDE.md — agent-flutter loop

Instructions for Claude Code instances working in the agent-flutter build loop.

## Loop location

- Loop workspace: `loops/agent-flutter/`
- Build target: `loops/agent-flutter/agent-flutter/`
- Test fixture: `shared/e2e-flutter-app/`
- Product repo: [`beastoin/agent-flutter`](https://github.com/beastoin/agent-flutter) (publish target only)

## Build and test

```bash
cd loops/agent-flutter/agent-flutter
pnpm typecheck
pnpm test:unit
```

```bash
# Phase evaluator (from repo root)
bash loops/agent-flutter/eval.sh
```

## Loop contract

3 immutable files control each phase:

1. `program*.md` — requirements and acceptance criteria
2. `eval.sh` — pass/fail gate (build/typecheck/test/e2e)
3. `e2e-test.ts` — real runtime validation

Do not modify these files during an active loop iteration. Only modify when starting a new phase.

## Publish rule

autoloop is the source of truth. Do not edit `beastoin/agent-flutter` directly.
After a phase completes: copy build target → product repo → npm publish.

## Runtime conventions

- Node.js: `>=22`
- Language: TypeScript (ESM)
- CLI style: deterministic, machine-parseable with `--json`
- Zero external runtime dependencies
- Keep changes phase-scoped — no broad refactors

## Architecture (key modules)

- `src/cli.ts` — global flags, mode resolution, command dispatch, exit behavior
- `src/vm-client.ts` — WebSocket JSON-RPC client for Dart VM Service + Marionette
- `src/session.ts` — file-backed session (`AGENT_FLUTTER_HOME/session.json`)
- `src/snapshot-fmt.ts` — ref assignment, human/JSON snapshot formatting
- `src/errors.ts` — structured errors (`code`, `message`, `hint?`, `diagnosticId`)
- `src/validate.ts` — pre-dispatch input validation
- `src/command-schema.ts` — canonical schema for `schema` and JSON help
- `src/commands/*.ts` — one file per command

## Phase detection (eval.sh)

`eval.sh` auto-detects current phase via file existence:

- phase 1: default
- phase 2: `src/commands/press.ts` exists
- phase 3: `src/commands/screenshot.ts` exists
- phase 4: `src/commands/wait.ts` exists
- phase 5: `src/command-schema.ts` exists

## Common pitfalls

- Adding commands without schema update
- Changing JSON envelope shape without contract tests
- Bypassing validation for new args
- Changing exit-code semantics
- Introducing non-deterministic output
- Editing control files during loops

## If blocked

Report: (1) blocker, (2) why it blocks, (3) exact next action needed.
