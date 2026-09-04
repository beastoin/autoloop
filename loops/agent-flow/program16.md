# Phase 16: Recording Pipeline Edge Case Tests

## Source
E2E test suite development (2026-09-04). The pipeline works end-to-end but lacks unit tests for error paths and edge cases.

## Problem
The recording pipeline (`record init → stream → finish → verify → report`) has minimal unit test coverage for:
- Invalid/missing run IDs
- Duplicate stream events
- Partial/interrupted recordings
- Verify with missing events
- Report with failed runs

## Acceptance Criteria

### AC1: record init error tests (3+ tests)
- Test: init with missing --flow returns error
- Test: init with non-existent flow file returns FILE_NOT_FOUND
- Test: init with custom --run-id preserves the ID

### AC2: record stream error tests (3+ tests)
- Test: stream with invalid --run-id returns error
- Test: stream with malformed JSON lines skips bad lines, accepts good ones
- Test: stream appends to existing events.jsonl (not overwrite)

### AC3: record finish error tests (3+ tests)
- Test: finish with non-existent run dir returns error
- Test: finish writes run.meta.json with correct status
- Test: finish with --status fail records failure

### AC4: verify edge case tests (3+ tests)
- Test: verify with empty events.jsonl returns fail
- Test: verify with missing step reports which steps are missing
- Test: verify with all steps passing returns pass

### AC5: report edge case tests (2+ tests)
- Test: report with failed run generates HTML with failure indicators
- Test: report without run.json returns error

## Implementation Notes
- Tests go in `loops/agent-flow/agent-flow/tests/`
- Use existing test patterns from `record.test.ts`, `yaml-writer.test.ts`
- Mock filesystem operations where needed
- All tests must pass with `npm test`

## Out of Scope
- Changing pipeline behavior
- Adding new commands
- Worker/API integration tests
