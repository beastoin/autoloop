# AGENTS.md

Operating guide for AI agents (`geni`, `jin`, and future agents) working in `beastoin/autoloop`.

## Purpose

This repo is the **source of truth** for building agent-grade CLIs via autonomous loops.

- `autoresearch/` — phase programs, evaluators, and build targets
- Product repos (e.g. `beastoin/agent-flutter`) are **publish targets only** — do not edit them directly

All code changes go through autoloop: write phase program → implement → eval → keep/revert → copy to product repo → publish.

## Roles and delegation model

### `geni` (designer/evaluator)

- defines phase scope and success criteria
- writes immutable loop control files
- sets gating metrics and pass/fail conditions
- reviews results and advances phase

### `jin` (builder/executor — now autonomous)

- writes his own loop control files (program.md, eval.sh, e2e-test.ts)
- implements code changes
- runs evaluator loops
- keeps only passing iterations
- reports evidence and blockers

Jin is fully autonomous — he designs AND builds.

## Core control files (the loop contract)

Each autoloop phase must have these 3 files:

1. `program*.md`
Role: immutable instructions and acceptance criteria for the builder.
2. `eval.sh`
Role: immutable scoring harness (build/test/contract/e2e + phase gate).
3. `e2e-test.ts`
Role: end-to-end runtime validation against a real target.

Rule: builder agents do not mutate these files mid-loop unless explicitly instructed to start a new phase definition.

## How `eval.sh` phase detection works (agent-flutter)

`autoresearch/standalone/eval.sh` auto-detects phase via file existence:

- phase 1: default
- phase 2: `src/commands/press.ts` exists
- phase 3: `src/commands/screenshot.ts` exists
- phase 4: `src/commands/wait.ts` exists
- phase 5: `src/command-schema.ts` exists

Then it applies phase-specific gates and prints `phase_complete: yes|no`.

## Create a new autoloop (new CLI tool)

1. Create target dir: `autoresearch/standalone/<tool-name>/`.
2. Write `program.md` with:
- scope and non-goals
- command surface
- architecture constraints
- acceptance criteria
- hard rules
3. Write immutable `eval.sh` with:
- phase detection sentinels
- build checks
- unit/contract checks
- CLI smoke checks
- real e2e checks
- phase completion gate
4. Write immutable `e2e-test.ts` for real target behavior.
5. Run autonomous build loop until all gates pass.
6. Record outcomes in `autoresearch/results.tsv` (or phase log).

## Add a new phase to an existing tool

1. Add new program file (`program-phaseX.md`) with exact delta scope.
2. Extend evaluator with one new phase sentinel (file-based).
3. Add only phase-relevant gates (avoid broad unrelated criteria).
4. Keep previous phase checks intact unless intentionally superseded.
5. Run evaluator until `phase_complete: yes`.
6. Update docs (`README.md`, tool `AGENTS.md`, tool `CLAUDE.md`) if CLI behavior changed.

## Running `agent-flutter` evaluators

### Standalone loop gate

```bash
bash autoresearch/standalone/eval.sh
```

### Full emulator/app integration gate

```bash
bash autoresearch/e2e-eval.sh
```

### Direct standalone e2e execution (manual URI)

```bash
AGENT_FLUTTER=autoresearch/standalone/agent-flutter \
VM_SERVICE_URI=ws://127.0.0.1:<port>/<token>/ws \
node --test autoresearch/standalone/e2e-test.ts
```

## Expected working style

1. Read current `program*.md` and `eval.sh` first.
2. Implement minimal phase-scoped changes.
3. Run evaluator.
4. If pass: keep changes.
5. If fail: revert failed direction and retry.
6. Repeat until phase gate passes.
7. Report what passed, what failed, and any blockers.

## Guardrails

- keep scope phase-local
- avoid speculative features outside current phase
- preserve deterministic CLI output and exit contract
- do not weaken evaluator thresholds to force pass
- do not skip e2e when phase gate requires e2e
- keep logs/evidence reproducible

## Blocked protocol (mandatory)

If blocked by device/network/permissions:

1. state blocker
2. state why it prevents completion
3. state exact next command or action needed to unblock

## Definition of done for a phase

- evaluator reaches passing gate for active phase
- required e2e checks pass
- docs updated if CLI surface changed
- no unresolved blocker remains
