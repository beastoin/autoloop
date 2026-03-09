# AGENTS.md — agent-flutter loop

Operating guide for AI agents working in the agent-flutter build loop.

## What this loop builds

[`agent-flutter`](https://github.com/beastoin/agent-flutter) — a CLI for AI agents to control Flutter apps via Dart VM Service + Marionette. Same `@ref + snapshot` UX as agent-device and agent-browser.

## Working in this loop

1. Read current `program*.md` and `eval.sh` first
2. Implement minimal phase-scoped changes in `agent-flutter/`
3. Run evaluator: `bash loops/agent-flutter/eval.sh`
4. Pass → keep changes
5. Fail → revert failed direction and retry
6. Repeat until `phase_complete: yes`
7. Report what passed, what failed, and any blockers

## Control files

| File | Role | Mutable? |
|------|------|----------|
| `program*.md` | Phase objectives and acceptance criteria | No (during active loop) |
| `eval.sh` | Pass/fail gate (432 lines) | No (during active loop) |
| `e2e-test.ts` | E2e runtime validation (515 lines) | No (during active loop) |
| `agent-flutter/` | Build target — the code you edit | Yes |

## Evaluator commands

```bash
# Phase gate (build + typecheck + tests + phase detection)
bash loops/agent-flutter/eval.sh

# Direct e2e (requires running Flutter app + VM Service URI)
AGENT_FLUTTER=loops/agent-flutter/agent-flutter \
VM_SERVICE_URI=ws://127.0.0.1:<port>/<token>/ws \
node --test loops/agent-flutter/e2e-test.ts
```

## Test fixture

The Marionette-enabled Flutter test app is at `shared/e2e-flutter-app/`. It's shared across loops — do not modify without coordinating.

## Guardrails

- Keep scope phase-local
- Do not add speculative features outside current phase
- Preserve deterministic CLI output and exit contract
- Do not weaken evaluator thresholds to force pass
- Do not skip e2e when phase gate requires it
- Keep logs/evidence reproducible

## Publish flow

After phase completes:
1. Copy `agent-flutter/` → `beastoin/agent-flutter` product repo
2. `npm publish` from product repo

Do not edit the product repo directly. All changes go through this loop.

## Adding a command

1. Create `agent-flutter/src/commands/<name>.ts`
2. Register dispatch in `agent-flutter/src/cli.ts`
3. Add schema entry in `agent-flutter/src/command-schema.ts`
4. Add validation in `agent-flutter/src/validate.ts`
5. Add tests in `agent-flutter/__tests__/`
6. Run evaluator

## Blocked protocol

If blocked by device/network/permissions:
1. State blocker
2. State why it prevents completion
3. State exact next command or action needed to unblock
