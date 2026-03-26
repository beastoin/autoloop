# Phase 11: Verify Correctness + Desktop Video + YAML Multi-line

## Goal
Fix 5 flow-walker flaws found during desktop flow cross-check, plus add macOS screen recording support for desktop flows.

## Context
Phase 10 added desktop support (agent-swift bridge). Sora ran 6 desktop flows through the pipeline and cross-checking revealed:
1. Audit mode always returns `result: "pass"` even when steps fail
2. Non-milestone expectations rubber-stamped as `met: true`
3. Invalid outcome values silently coerced with no diagnostics
4. YAML folded/literal scalars (`>`, `|`) not parsed
5. No video recording on macOS (only ADB screenrecord)
6. Event schema doesn't validate step.end outcome values

## Architecture

### Fix 1: Audit mode result reflects step outcomes (verify.ts)
- Audit mode should still determine `result` based on step outcomes
- `result: "fail"` if any step has `outcome: "fail"`
- `result: "pass"` only if all steps are pass/skipped/recovered
- Audit mode difference from balanced: missing steps default to 'skipped' not 'fail', no order enforcement

### Fix 2: Verify checks non-milestone expectations (verify.ts)
- For `kind: text_visible`: look for matching assert event with `kind === 'text_visible'` and check `passed` field
- For `kind: interactive_count`: look for matching assert event with `kind === 'interactive_count'` and check `passed` field
- If no matching assert event found in events: mark `met: true` in audit/balanced (trust agent), `met: false` in strict
- If assert event found with `passed: false`: mark `met: false` in all modes

### Fix 3: Outcome normalization + diagnostics (verify.ts)
- Normalize common variants: `"skip"` → `"skipped"`, `"partial"` → `"fail"`
- Add issues for failed/skipped steps in audit mode too (currently only strict)
- Issue format: `Step S3: outcome "skip" (normalized to skipped)`

### Fix 4: YAML multi-line scalar support (flow-parser.ts)
- Handle folded scalar (`>`): join continuation lines with spaces
- Handle literal scalar (`|`): join continuation lines with newlines
- Detect when `do:`, `note:`, `description:` values are `>` or `|`
- Read subsequent indented lines as continuation

### Fix 5: macOS screen recording (record.ts)
- When platform is desktop (or agent type is swift): use `screencapture -v <path>` instead of ADB screenrecord
- Auto-detect platform from agent type if not explicitly set
- `recordFinish`: kill screencapture with SIGINT, no ADB pull needed (file is local)
- Add `platform` to RecordInitOptions and run.meta.json

### Fix 6: Event schema validates step.end outcome (event-schema.ts)
- Add optional validation for step.end events: outcome must be a valid StepOutcome
- Warn (don't reject) for non-standard values to avoid breaking existing events

## Files to modify
- `src/verify.ts` — Fixes 1, 2, 3
- `src/flow-parser.ts` — Fix 4
- `src/record.ts` — Fix 5
- `src/event-schema.ts` — Fix 6
- `src/types.ts` — Add platform type
- `src/cli.ts` — Pass platform to record init
- `src/command-schema.ts` — Add --platform flag to record

## Files to create
- `tests/verify-audit.test.ts` — Audit mode correctness tests
- `tests/flow-parser-multiline.test.ts` — YAML multi-line scalar tests

## Acceptance criteria (14 gates)

### Verify correctness
1. AC1: Audit mode returns `result: "fail"` when a step has `outcome: "fail"`
2. AC2: Audit mode returns `result: "pass"` when all steps pass or are skipped
3. AC3: text_visible expectation marked `met: false` when assert event has `passed: false`
4. AC4: interactive_count expectation marked `met: false` when assert event has `passed: false`
5. AC5: Outcome "skip" normalized to "skipped", "partial" normalized to "fail"
6. AC6: Issues array populated for failed steps in audit mode

### YAML parsing
7. AC7: Folded scalar `>` joins continuation lines with spaces
8. AC8: Literal scalar `|` joins continuation lines with newlines

### Desktop video
9. AC9: RecordInitOptions has `platform` field
10. AC10: record.ts contains `screencapture` for macOS video recording
11. AC11: Auto-skip ADB video when platform is desktop

### Event schema
12. AC12: validateEvent warns on non-standard step.end outcome values

### Quality
13. AC13: TypeScript typecheck passes
14. AC14: All tests pass, count >= 310

## What NOT to do
- Do not break existing mobile workflows
- Do not add external dependencies
- Do not modify eval10.sh or earlier
- Do not change exit code semantics
- Do not reject events with non-standard outcomes (warn only)
