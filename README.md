# autoloop

Autonomous loop system for building agent-grade CLIs from objectives.

## Design references

- [Andrej Karpathy: autoresearch](https://github.com/karpathy/autoresearch) — autonomous research loop pattern: immutable eval + editable code + keep/revert cycle. We adapted his scalar-metric optimization loop into a phase-gated construction loop for building software.
- [callstackincubator/agent-device](https://github.com/callstackincubator/agent-device) — the `@ref` system, `snapshot`-based interaction, daemon architecture, CLI-first design
- [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) — same UX patterns for web (`snapshot → @ref → press/fill/wait/is`)
- [Justin Poehnelt: Rewrite Your CLI for AI Agents](https://justin.poehnelt.com/posts/rewrite-your-cli-for-ai-agents/) — agent-friendliness principles: schema discovery, input validation, deterministic output, defense-in-depth

## Repo layout

```text
.
├── loops/                              # one directory per build loop
│   ├── agent-flutter/                  # loop 1: Flutter testing CLI
│   │   ├── program*.md                 # phase instructions
│   │   ├── eval.sh                     # phase evaluator (immutable)
│   │   ├── e2e-test.ts                 # e2e test suite (immutable)
│   │   ├── README.md                   # loop overview + phase history
│   │   ├── CLAUDE.md                   # agent instructions for this loop
│   │   ├── AGENTS.md                   # operating guide for this loop
│   │   └── agent-flutter/              # build target (→ beastoin/agent-flutter)
│   ├── agent-swift/                    # loop 2: macOS Accessibility CLI
│   │   ├── program*.md                 # phase instructions
│   │   ├── eval.sh                     # phase evaluator (immutable)
│   │   ├── AGENTS.md                   # operating guide for this loop
│   │   └── agent-swift/                # build target (→ beastoin/agent-swift)
│   └── flow-walker/                    # loop 3: YAML flow discovery + execution
│       ├── program*.md                 # phase instructions
│       ├── eval*.sh                    # phase evaluators (immutable)
│       ├── README.md                   # loop overview + phase history
│       ├── CLAUDE.md                   # agent instructions for this loop
│       └── flow-walker/                # build target (→ beastoin/flow-walker)
├── shared/                             # resources shared across loops
│   └── e2e-flutter-app/                # Marionette-enabled Flutter test app
├── README.md                           # this file (shared principles)
├── AGENTS.md                           # shared agent operating guide
├── CLAUDE.md                           # shared agent instructions
└── LICENSE
```

## Autoloop pattern

Phase-gated autonomous build loop. An agent goes from objective to working code with no human in the loop.

Each phase needs 3 immutable files:

1. `program*.md` — objective, acceptance criteria, hard rules
2. `eval.sh` — pass/fail gate (build, tests, contracts, e2e)
3. `e2e-test.ts` — real end-to-end validation against live target

Loop: read program → implement → run eval → pass: keep, fail: revert → repeat until `phase_complete=yes`.

`eval.sh` auto-detects current phase from sentinel files — one harness gates all phases.

## Active loops

| Loop | Build target | Product repo | Status |
|------|-------------|--------------|--------|
| `loops/agent-flutter/` | Flutter testing CLI | [beastoin/agent-flutter](https://github.com/beastoin/agent-flutter) | Phase 9 complete (v1.4.0) |
| `loops/agent-swift/` | macOS Accessibility CLI | [beastoin/agent-swift](https://github.com/beastoin/agent-swift) | Phase 7 complete (v0.2.1) |
| `loops/flow-walker/` | YAML flow discovery + execution | [beastoin/flow-walker](https://github.com/beastoin/flow-walker) | Phase 3 complete |

## Publish flow

autoloop is the **source of truth**. Product repos are publish targets only.

1. Write `program-phaseX.md` with objectives in the loop directory
2. Agent builds/iterates code in `loops/<project>/<build-target>/`
3. Eval passes → copy to product repo → publish

**Do not edit product repos directly.** Every change goes through a phase program + eval gate first.

## Creating a new loop

1. Create loop directory: `loops/<project-name>/`
2. Write `README.md` with loop overview and objectives
3. Write `CLAUDE.md` with agent instructions for this loop
4. Write `AGENTS.md` with operating guide for this loop
5. Write `program.md` with scope, acceptance criteria, hard rules
6. Write immutable `eval.sh` with phase detection + pass/fail gates
7. Write immutable `e2e-test.ts` for real target behavior
8. Create build target directory: `loops/<project-name>/<build-target>/`
9. Run autonomous keep/revert loop until all gates pass
10. On phase complete: copy build target to its product repo and publish

Shared test fixtures go in `shared/`.

Reference implementation: `loops/agent-flutter/`

## Related

- [beastoin/agent-flutter](https://github.com/beastoin/agent-flutter) — Flutter testing CLI (transport layer)
- [beastoin/agent-swift](https://github.com/beastoin/agent-swift) — macOS Accessibility CLI (transport layer)
- [beastoin/flow-walker](https://github.com/beastoin/flow-walker) — YAML flow discovery + execution (flow layer)
- [callstackincubator/agent-device](https://github.com/callstackincubator/agent-device) — design reference (mobile)
- [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) — design reference (web)
