# AGENTS.md

Operating guide for AI agents working in `beastoin/autoloop`.

## Purpose

This repo is the **source of truth** for building agent-grade CLIs via autonomous loops.

- `loops/` — one directory per build loop, each with its own control files and build target
- `shared/` — test fixtures and resources shared across loops
- Product repos (e.g. `beastoin/agent-flutter`) are **publish targets only** — do not edit them directly

All code changes go through autoloop: write phase program → implement → eval → keep/revert → copy to product repo → publish.

## Repo structure

```text
loops/<project>/           # loop workspace
  program*.md              # phase objectives (immutable during loops)
  eval.sh                  # evaluator harness (immutable during loops)
  e2e-test.ts              # e2e tests (immutable during loops)
  README.md                # loop overview + phase history
  CLAUDE.md                # agent instructions for this loop
  AGENTS.md                # operating guide for this loop
  <build-target>/          # the code being built (mutable)
shared/                    # shared test fixtures
```

## Roles and delegation model

### `geni` (designer/evaluator)

- defines phase scope and success criteria
- writes immutable loop control files
- sets gating metrics and pass/fail conditions
- reviews results and advances phase

### `jin` (builder/executor — autonomous)

- writes his own loop control files (program.md, eval.sh, e2e-test.ts)
- implements code changes
- runs evaluator loops
- keeps only passing iterations
- reports evidence and blockers

## Core control files (the loop contract)

Each phase must have these 3 files:

1. `program*.md` — immutable instructions and acceptance criteria
2. `eval.sh` — immutable scoring harness (build/test/contract/e2e + phase gate)
3. `e2e-test.ts` — end-to-end runtime validation against a real target

Rule: builder agents do not mutate these files mid-loop unless explicitly instructed to start a new phase definition.

## Creating a new loop

1. Create `loops/<project-name>/`
2. Write per-loop docs: `README.md`, `CLAUDE.md`, `AGENTS.md`
3. Write `program.md` with scope, acceptance criteria, hard rules
4. Write immutable `eval.sh` with phase detection + pass/fail gates
5. Write immutable `e2e-test.ts` for real target behavior
6. Create build target: `loops/<project-name>/<build-target>/`
7. Run autonomous loop until all gates pass
8. On complete: copy build target → product repo → publish

Shared test fixtures go in `shared/`.

## Adding a new phase to an existing loop

1. Add new program file (`program-phaseX.md`) with exact delta scope
2. Extend evaluator with one new phase sentinel (file-based)
3. Add only phase-relevant gates (avoid broad unrelated criteria)
4. Keep previous phase checks intact unless intentionally superseded
5. Run evaluator until `phase_complete: yes`
6. Update loop docs if CLI surface changed

## Expected working style

1. Read the loop's `README.md`, `CLAUDE.md`, and `AGENTS.md` first
2. Read current `program*.md` and `eval.sh`
3. Implement minimal phase-scoped changes
4. Run evaluator
5. Pass → keep changes
6. Fail → revert failed direction and retry
7. Repeat until phase gate passes
8. Report what passed, what failed, and any blockers

## Guardrails

- Keep scope phase-local
- Avoid speculative features outside current phase
- Preserve deterministic CLI output and exit contract
- Do not weaken evaluator thresholds to force pass
- Do not skip e2e when phase gate requires e2e
- Keep logs/evidence reproducible

## Blocked protocol (mandatory)

If blocked by device/network/permissions:

1. State blocker
2. State why it prevents completion
3. State exact next command or action needed to unblock

## Definition of done for a phase

- Evaluator reaches passing gate for active phase
- Required e2e checks pass
- Docs updated if CLI surface changed
- No unresolved blocker remains
