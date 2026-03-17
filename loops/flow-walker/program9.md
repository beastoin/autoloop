# Phase 9: Migrate + Pipeline Adaptation

## Goal
Implement the `migrate` command to convert v1 flows to v2 format, and adapt the report/push pipeline to work with v2 verify results.

## Context
Phase 8 established record/verify. Phase 9 closes the remaining stubs:
- `migrate` converts existing v1 YAML flows to v2 agent-first format
- `report` adapts to generate HTML from v2 verify results
- `push` adapts to upload v2 data

## Architecture

### Migrate module (`src/migrate.ts`)
**`migrate <v1-flow.yaml> [--output <path>] [--json]`**
- Reads v1 flow using existing parseFlow()
- Converts to FlowV2 format:
  - Auto-generates step IDs (S1, S2, S3...)
  - Converts action fields (press, fill, scroll, back, adb, wait) to natural language `do:` instructions
  - Preserves metadata: name, description, app, appUrl, covers, prerequisites→preconditions
  - Converts v1 assert to v2 expect milestones
  - Converts v1 screenshot to v2 evidence
- Outputs v2 YAML via toYamlV2()
- Validates output passes v2 schema

### Report adaptation
- `report` command reads v2 run.json (VerifyResult format)
- Generates a self-contained HTML page showing verify results
- Simpler than v1 report (no video/logcat embeds — v2 evidence is file references)

### Push adaptation
- `push` command uploads v2 run.json to hosted service
- Works with existing Cloudflare Worker endpoint (data format is JSON regardless)

## Files to create
- `src/migrate.ts` — v1→v2 migration logic
- `tests/migrate.test.ts` — migration tests

## Files to modify
- `src/cli.ts` — wire migrate, report, push (replace NOT_IMPLEMENTED stubs)
- `src/reporter.ts` — adapt for v2 VerifyResult format
- `tests/reporter.test.ts` — update for v2 format

## Acceptance criteria (10 gates)
1. AC1: `src/migrate.ts` exists and exports `migrateFlowV1toV2`
2. AC2: migrate converts v1 flow to valid v2 (passes validateFlowV2)
3. AC3: migrate auto-generates step IDs (S1, S2, ...)
4. AC4: migrate converts press/fill/scroll/back to do: natural language
5. AC5: migrate preserves metadata (name, description, covers)
6. AC6: migrate CLI writes v2 YAML file with --output
7. AC7: report generates HTML from v2 run.json
8. AC8: push/report/migrate no longer return NOT_IMPLEMENTED
9. AC9: typecheck passes
10. AC10: all tests pass, count >= 260

## What NOT to do
- Do not break existing v1 walker output (generateFlows + toYaml still produce v1)
- Do not add external dependencies
- Do not modify eval7.sh or eval8.sh
