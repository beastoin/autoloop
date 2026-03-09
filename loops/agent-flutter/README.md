# Loop: agent-flutter

Autonomous build loop for [`agent-flutter`](https://github.com/beastoin/agent-flutter) — a CLI for AI agents to control Flutter apps via Dart VM Service + Marionette.

## Status

**Phase 5 complete.** 2103 lines, 18 commands, 25 source files, 36 e2e + 43 unit tests.

| Phase | Objective | Result |
|-------|-----------|--------|
| 1-3 | Core CLI matching agent-device/agent-browser UX | `connect`, `snapshot`, `press`, `fill`, `get`, `find`, `screenshot`, `reload`, `logs` |
| 4a | Autonomy-grade (agent can test without human) | `wait`, `is`, `scroll`, `swipe`, `back`, `home`, `--device`, exit-code contract |
| 5 | Agent-friendliness (Justin Poehnelt principles) | `schema`, input validation, `--dry-run`, TTY-aware JSON, `diagnosticId`, env vars |

## Layout

```text
loops/agent-flutter/
├── program.md              # phase 1-3 objectives
├── program-phase4a.md      # phase 4 objectives
├── program-phase5.md       # phase 5 objectives
├── eval.sh                 # evaluator (432 lines, immutable during loops)
├── e2e-test.ts             # e2e tests (515 lines, immutable during loops)
├── results.tsv             # per-loop results
├── README.md               # this file
├── CLAUDE.md               # agent instructions for this loop
├── AGENTS.md               # operating guide for this loop
└── agent-flutter/          # build target → published to npm as agent-flutter-cli
```

Test fixture: `../../shared/e2e-flutter-app/` (Marionette-enabled Flutter app).

## Running evaluators

```bash
# Phase evaluator (build, typecheck, tests, phase gate)
bash loops/agent-flutter/eval.sh

# Direct e2e (requires running Flutter app)
AGENT_FLUTTER=loops/agent-flutter/agent-flutter \
VM_SERVICE_URI=ws://127.0.0.1:<port>/<token>/ws \
node --test loops/agent-flutter/e2e-test.ts
```

## Publish flow

After a phase completes:
1. Copy `agent-flutter/` → `beastoin/agent-flutter` product repo
2. `npm publish` from product repo

Do not edit the product repo directly.

## Adding a new phase

1. Write `program-phase<N>.md` with delta scope and acceptance criteria
2. Add phase sentinel to `eval.sh` (file-existence detection)
3. Add phase-specific gates (keep previous phase checks intact)
4. Run loop until `phase_complete: yes`
5. Update docs if CLI surface changed
