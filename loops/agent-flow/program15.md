# Phase 15: Audit Remediation — Bugs, Rename Cleanup, Docs

## Source
Independent Codex audit (2026-09-04), 5-turn adversarial debate. 10 findings, 3 HIGH / 5 MEDIUM / 2 LOW.

## Fixes

### HIGH
1. **Run ID length bug** — `record.ts:18` uses `randomBytes(5)` (7 chars). Change to `randomBytes(7)` to match run-schema.ts (10 chars). Add test asserting run ID length === 10
2. **Verify milestone+kind assertion** — Audit verify.ts:101-108. If milestone branch marks pass without checking `passed:false`, fix. Add test for combined milestone+kind expectation with failed assertion
3. **agentResult can't fail** — verify.ts:209 returns only `pending` or `pass`. Add `fail` path when any step has outcome `fail`. Add test

### MEDIUM
4. **AGENTS.md stale `run` command** — Remove references to removed `run` command. Update command count and examples to match current CLI (walk, record, verify, report, push, get, snapshot, schema)
5. **Stale FLOW_WALKER_* env vars in README** — Replace all `FLOW_WALKER_*` with `AGENT_FLOW_*` in README
6. **Install docs** — Update README install from `agent-flow-cli` to `@beastoin/agent-flow`. Update SKILL.md version from 0.5.4 to 0.6.x
7. **Regenerate package-lock.json** — Run `npm install` to regenerate with correct @beastoin/agent-flow name and bin
8. **evidence.video round-trip** — Add flow-level evidence fields to toYamlV2() output so they survive parse→write

### LOW
9. **README step `name` field** — Change docs from required to optional (matches code: only id + do required)
10. **Dead code cleanup** — Remove unused `parseInlineObj`, legacy `FlowHints` type, unused `validateRunDir` import, stale `agentFlutterPath` config

## Acceptance Criteria
1. Run IDs from `record init` are exactly 10 characters
2. Verify correctly fails assertions with milestone+kind when passed:false
3. agentResult returns `fail` when any step has outcome fail
4. AGENTS.md does not reference `run` command
5. README has no `FLOW_WALKER_*` env vars
6. README install says `@beastoin/agent-flow`
7. package-lock.json name is `@beastoin/agent-flow`
8. toYamlV2 preserves evidence.video in round-trip
9. All tests pass (≥336 tests, expect new tests to bring to ≥345)
10. `npx tsc --noEmit` passes
11. No unused imports for parseInlineObj, FlowHints, validateRunDir

## Target
- Version: 0.6.1 (patch — bugs + docs)
- Tests: ≥345 (336 existing + ≥9 new for fixes)
