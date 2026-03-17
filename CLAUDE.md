# CLAUDE.md

Practical guide for Claude Code instances working in `beastoin/autoloop`.

## Core design principles

Every CLI built in autoloop follows these references:

1. **Immutable eval + keep/revert loop** ([Karpathy: autoresearch](https://github.com/karpathy/autoresearch)) — program defines objective, eval.sh is the gate, code is the only mutable part. Never modify eval during an active loop.
2. **Snapshot → @ref → action** ([agent-device](https://github.com/callstackincubator/agent-device), [agent-browser](https://github.com/vercel-labs/agent-browser)) — all interaction follows: take snapshot, get refs, act by ref. This is the UX contract for agent-flutter, agent-swift, and flow-walker.
3. **Agent-friendly CLI design** ([Justin Poehnelt](https://justin.poehnelt.com/posts/rewrite-your-cli-for-ai-agents/)) — every command must have: schema discovery (`schema` command), input validation, deterministic output, structured errors with codes + hints, JSON mode, defense-in-depth.

These are non-negotiable. When adding commands or features, check: does it have schema? Is output deterministic? Is input validated? Does it follow snapshot → @ref → action?

## Project map

- `loops/` — one directory per build loop (each has its own README, CLAUDE.md, AGENTS.md)
- `shared/` — test fixtures shared across loops
- See each loop's `CLAUDE.md` for loop-specific instructions

### Active loops

| Loop | Path | Build target |
|------|------|-------------|
| agent-flutter | `loops/agent-flutter/` | `loops/agent-flutter/agent-flutter/` |
| agent-swift | `loops/agent-swift/` | `loops/agent-swift/agent-swift/` |
| flow-walker | `loops/flow-walker/` | `loops/flow-walker/flow-walker/` |

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

## Publish rule

autoloop is the source of truth. Do not edit product repos directly.
After a phase completes: copy build target → product repo → publish.
Every code change must go through a phase program + eval gate.

## Creating a new loop

1. Create `loops/<project-name>/`
2. Write per-loop docs: `README.md`, `CLAUDE.md`, `AGENTS.md`
3. Write loop control files: `program.md`, `eval.sh`, `e2e-test.ts`
4. Create build target directory
5. Shared fixtures go in `shared/`

See `loops/agent-flutter/` as reference implementation.

## If blocked

Report:

1. blocker
2. why it blocks completion
3. exact next action/command needed to unblock
