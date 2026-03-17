# Phase 8: Record + Verify

## Goal
Implement the `record` and `verify` commands that let an AI agent record its execution of a v2 flow and verify recorded events against flow expectations.

## Context
Phase 7 established the v2 contract core (types, parser, schema, scaffold). Phase 8 adds the two key commands that bridge agent execution and flow verification:
- `record` — the agent initializes a run, streams events as it executes, and finishes with a status
- `verify` — checks recorded events against flow expectations and produces a run.json

## Architecture

### Record module (`src/record.ts`)
Three subcommands operating on a run directory:

**`record init --flow <path> [--output-dir <dir>] [--run-id <id>] [--json]`**
- Creates `<output-dir>/<run-id>/` directory
- Copies flow YAML as `flow.lock.yaml` (snapshot of flow at recording time)
- Creates `run.meta.json` with: `{ id, flow, startedAt, status: "recording" }`
- Creates empty `events.jsonl`
- Outputs: `{ id, dir, flow }` (JSON) or human-readable confirmation

**`record stream --run-id <id> [--run-dir <dir>] [--json]`**
- Reads JSONL events from stdin (one event per line)
- Validates each event has required fields: `type`, `step_id`
- Injects `seq` (auto-incrementing) and `ts` (ISO 8601) if not present
- Appends to `events.jsonl`
- Canonical event types: `run.start`, `step.start`, `action`, `assert`, `artifact`, `step.end`, `run.end`, `note`

**`record finish --run-id <id> [--run-dir <dir>] [--status pass|fail|aborted] [--json]`**
- Updates `run.meta.json` with: `finishedAt`, `status`, `eventCount`
- Outputs summary

### Verify module (`src/verify.ts`)
**`verify <flow.yaml> [--run-dir <dir>] [--events <path>] [--mode strict|balanced|audit] [--json] [--output <path>]`**

Three verification modes:
- **strict**: All steps must have step.start + step.end in flow order. All expect assertions must have matching assert events with passing outcomes. No unknown step_ids.
- **balanced** (default): All steps must be present but order flexibility allowed (recovery/retry). Assertions checked but skipped steps with reason accepted.
- **audit**: Logs mismatches but always returns pass. For exploratory runs.

Verify produces a `run.json` compatible with the existing `RunResult` type structure (for report/push compatibility), but with v2 fields:
- `id`, `flow`, `startedAt`, `duration`, `result` (pass/fail), `mode`
- `steps[]` with: `id`, `name`, `do`, `outcome` (pass/fail/skipped/recovered), `events[]`, `expectations[]`

Exit codes:
- 0: verification pass
- 1: verification failed
- 2: error (invalid input, missing files)

### Event schema (`src/event-schema.ts`)
- Type definitions for recording events
- Validation function for event shape
- Event type enum

## Files to create
- `src/record.ts` — record init/stream/finish logic
- `src/verify.ts` — verification engine with 3 modes
- `src/event-schema.ts` — event type definitions and validation
- `tests/record.test.ts` — record module tests
- `tests/verify.test.ts` — verify module tests
- `tests/event-schema.test.ts` — event schema tests

## Files to modify
- `src/cli.ts` — wire record and verify commands (replace NOT_IMPLEMENTED stubs)
- `src/types.ts` — add RecordEvent, VerifyResult types if needed

## Acceptance criteria (12 gates)
1. AC1: `src/record.ts` exists and exports `recordInit`, `recordStream`, `recordFinish`
2. AC2: `src/verify.ts` exists and exports `verifyRun`
3. AC3: `src/event-schema.ts` exists and exports `validateEvent`, `EVENT_TYPES`
4. AC4: `record init` creates run directory with flow.lock.yaml, run.meta.json, events.jsonl
5. AC5: `record stream` validates and appends events with auto-seq/ts to events.jsonl
6. AC6: `record finish` updates run.meta.json with finishedAt, status, eventCount
7. AC7: `verify` in strict mode checks step order, all expects, no unknowns
8. AC8: `verify` in balanced mode accepts skipped steps with reason
9. AC9: `verify` in audit mode always passes (logs issues but exit 0)
10. AC10: CLI wires record and verify (no more NOT_IMPLEMENTED for these commands)
11. AC11: typecheck passes (`npx tsc --noEmit`)
12. AC12: all tests pass, test count >= 220 (was 183)

## What NOT to do
- Do not implement report or push changes (Phase 9)
- Do not implement migrate (Phase 9)
- Do not add external dependencies
- Do not modify eval7.sh or program7.md
