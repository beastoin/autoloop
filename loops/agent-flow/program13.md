# Phase 13: Agent-Friendly Verification Pipeline

## Problem
Reports show "PASS" with 0/3 automated checks and all agent reviews pending. Agents don't know what events to stream, can't resolve agent reviews, and get no feedback when events are missing.

## Deliverables

### 1. Honest result semantics
- New result value: `unverified` — used when all automated checks are `no_evidence` AND all agent reviews are `pending`
- `pass` means: step.end said pass AND (automated checks all pass OR no checks defined) AND (agent reviews all pass OR no reviews defined)
- Reporter renders `unverified` with distinct amber badge (not green PASS, not red FAIL)
- Mode `audit` explicitly means "collect evidence only" — badge shows "AUDIT" not "PASS"

### 2. Step recipes in `record init --flow`
- When `--flow` is provided, `record init` includes `recipe` in output — per-step event sequence
- Recipe format: `{ steps: [{ id, events: ["step.start", "action", "artifact", "assert:text_visible:Counter: 2", "step.end"] }] }`
- Recipe is derived from flow YAML: expect → assert events, judge → artifact (screenshot)
- Agents become self-sufficient: follow the recipe, get green checks

### 3. `agent-review` event type
- New event type accepted by `record stream`: `{"type":"agent-review","step_id":"S1","prompt_idx":0,"verdict":"pass","reason":"..."}`
- `verify` processes agent-review events: matches by step_id + prompt_idx, updates agent prompt status
- Agent result changes from `pending` to `pass`/`fail` based on agent-review events

### 4. Event gap warnings in `record finish`
- `record finish` reads flow.lock.yaml + events.jsonl
- Warns when: step has `expect` but no `assert` event was streamed
- Warns when: step has `judge` but no `artifact` (screenshot) event was streamed
- Warnings are returned in finish result JSON and stored in meta

## Non-goals
- OCR / vision-based auto-assert (requires external deps — future phase)
- Renaming `--mode audit` (keep it, just fix the badge)

## Acceptance
- `npm test` passes with ≥ 280 tests
- `npx tsc --noEmit` clean
- eval13.sh gates pass
