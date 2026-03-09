# CLAUDE.md

Practical guide for Claude Code instances working in `beastoin/autoloop`.

## Project map

- `loops/` — one directory per build loop (each has its own README, CLAUDE.md, AGENTS.md)
- `shared/` — test fixtures shared across loops
- See each loop's `CLAUDE.md` for loop-specific instructions

### Active loops

| Loop | Path | Build target |
|------|------|-------------|
| agent-flutter | `loops/agent-flutter/` | `loops/agent-flutter/agent-flutter/` |
| agent-swift | `loops/agent-swift/` | `loops/agent-swift/agent-swift/` |

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
