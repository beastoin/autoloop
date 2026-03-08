# autoloop

Autonomous loop system for building agent-grade CLIs from objectives.

## Design references

- [Andrej Karpathy: autoresearch](https://github.com/karpathy/autoresearch) — autonomous research loop pattern: immutable eval + editable code + keep/revert cycle. We adapted his scalar-metric optimization loop into a phase-gated construction loop for building software.
- [callstackincubator/agent-device](https://github.com/callstackincubator/agent-device) — the `@ref` system, `snapshot`-based interaction, daemon architecture, CLI-first design
- [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) — same UX patterns for web (`snapshot → @ref → press/fill/wait/is`)
- [Justin Poehnelt: Rewrite Your CLI for AI Agents](https://justin.poehnelt.com/posts/rewrite-your-cli-for-ai-agents/) — agent-friendliness principles: schema discovery, input validation, deterministic output, defense-in-depth

## Objectives

Build the best comprehensive tool for AI agents to test and develop Flutter apps — and the system to build more tools like it autonomously.

### Production objectives (agent-flutter)

1. **npm publish** — `npx agent-flutter` should just work
2. **Real-device validation** — test against Omi app on Pixel 7a (Mac Mini)
3. **CI/CD** — GitHub Actions: typecheck, unit tests, contract tests on every push
4. **iOS support** — same VM Service/Marionette, replace ADB commands with iOS equivalents
5. **Multi-device** — handle multiple emulators/devices gracefully
6. **Gap close vs references** — cherry-pick missing patterns: `open`, `close`, `clipboard`, `alert`, `long-press`, `batch`, `eval`

### Research journey

1. **Problem**: Flutter renders to a canvas — opaque to UIAutomator (Android) and XCTest (iOS). Native accessibility tools can't see Flutter widgets.
2. **Discovery**: Omi app already has [Marionette](https://pub.dev/packages/marionette_flutter) (`MarionetteBinding` in main.dart, debug mode) — gives widget-level control via Dart VM Service extensions.
3. **Gap analysis**: Surveyed agent-device, mobile-mcp, droidrun, mobile-use, Maestro. None handles Flutter's canvas rendering.
4. **Solution**: Build `agent-flutter` — a standalone CLI that speaks Marionette's wire protocol (`ext.flutter.marionette.*` via JSON-RPC 2.0 over WebSocket), with the same `@ref + snapshot` UX as agent-device/agent-browser.
5. **Method**: Adapted Karpathy's autoresearch pattern (scalar-metric optimization loop) into a phase-gated construction loop for building software.

## What this repo contains

- `autoresearch/standalone/` — phase programs + immutable evaluator
- `autoresearch/standalone/agent-flutter/` — complete CLI built by this system (also at [beastoin/agent-flutter](https://github.com/beastoin/agent-flutter))
- `autoresearch/e2e-flutter-app/` — Marionette-enabled Flutter test app
- `autoresearch/e2e-eval.sh` — full integration evaluator

## Autoloop pattern

Phase-gated autonomous build loop. An agent goes from objective to working code with no human in the loop.

Each phase needs 3 immutable files:

1. `program*.md` — objective, acceptance criteria, hard rules
2. `eval.sh` — pass/fail gate (build, tests, contracts, e2e)
3. `e2e-test.ts` — real end-to-end validation against live target

Loop: read program → implement → run eval → pass: keep, fail: revert → repeat until `phase_complete=yes`.

`eval.sh` auto-detects current phase from sentinel files — one harness gates all phases.

## How agent-flutter was built (5 phases, 0 reverts)

| Phase | Objective | Result |
|-------|-----------|--------|
| 1-3 | Core CLI matching agent-device/agent-browser UX | `connect`, `snapshot`, `press`, `fill`, `get`, `find`, `screenshot`, `reload`, `logs` |
| 4a | Autonomy-grade (agent can test without human) | `wait`, `is`, `scroll`, `swipe`, `back`, `home`, `--device`, exit-code contract |
| 5 | Agent-friendliness (Justin Poehnelt principles) | `schema`, input validation, `--dry-run`, TTY-aware JSON, `diagnosticId`, env vars |

Final: 2103 lines, 18 commands, 25 source files, 36 e2e + 43 unit tests.

## Repo layout

```text
.
├── autoresearch/
│   ├── e2e-eval.sh                       # build/install/launch/e2e harness
│   ├── e2e-test.ts                       # Flutter VM integration tests
│   ├── e2e-flutter-app/                  # Marionette test app
│   └── standalone/
│       ├── program*.md                   # phase instructions (Phase 1-3, 4a, 5)
│       ├── eval.sh                       # phase evaluator (immutable, 431 lines)
│       ├── e2e-test.ts                   # standalone CLI e2e suite (514 lines)
│       └── agent-flutter/                # standalone CLI target (2103 lines)
├── README.md
├── AGENTS.md
├── CLAUDE.md
└── LICENSE
```

## Quick start

```bash
# Run phase evaluator
bash autoresearch/standalone/eval.sh

# Run full Flutter integration gate
bash autoresearch/e2e-eval.sh
```

## Building a new agent CLI with autoloop

1. Define the objective and acceptance criteria in `program.md`
2. Write immutable `eval.sh` with objective pass/fail gates
3. Write immutable `e2e-test.ts` for real runtime validation
4. Run autonomous keep/revert loop until all gates pass
5. Each new phase: add `program-phaseX.md`, extend eval sentinel, run loop

Reference implementation: `autoresearch/standalone/agent-flutter/`

## Related

- [beastoin/agent-flutter](https://github.com/beastoin/agent-flutter) — standalone agent-flutter CLI repo (product)
- [callstackincubator/agent-device](https://github.com/callstackincubator/agent-device) — design reference (mobile)
- [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) — design reference (web)
