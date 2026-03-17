# Phase 7: v2 contract core (clean cut)

## Objective

Reposition `flow-walker` from an action executor into an agent workflow contract tool. In this phase, the CLI must define and enforce the v2 YAML contract and generate v2 scaffold flows, while removing legacy auto-runner paths (`run`/`get` behavior backed by `runner.ts` and `capture.ts`). This is a hard cut: no dual v1/v2 compatibility in command behavior or step schema.

## Architecture

### What changes in Phase 7

```text
flow-walker walk --name <flow-name> --output <file.yaml>
  -> writes v2 scaffold YAML (contract-first, tool-agnostic)
  -> step schema requires: id + do + anchors + expect + evidence

flow-walker schema
  -> publishes v2 command surface + verify modes

flow-walker record|verify|report|push|migrate
  -> command surface present
  -> returns structured NOT_IMPLEMENTED in Phase 7
```

- CLI surface moves to v2 contract model: `walk`, `record`, `verify`, `report`, `push`, `migrate`, `schema`.
- Legacy executor files are removed (`runner.ts`, `capture.ts`) with corresponding tests.
- Flow schema validation rejects legacy step action keys (`press`, `fill`, `scroll`, `back`, `assert`) in parsed v2 flows.
- Type layer introduces explicit outcome states needed by later phases: `pass`, `fail`, `skipped`, `recovered`.

### What stays in Phase 7

- `agent-bridge.ts` remains as transport abstraction for future phases.
- Existing error/validation foundation remains (`errors.ts`, `validate.ts`) and is extended for v2.
- Existing traversal primitives (`fingerprint.ts`, `graph.ts`, `safety.ts`) may remain, but they must not be used to execute scripted actions in this phase.

## Exact file plan

### Create

- `loops/flow-walker/flow-walker/.phase7-contract-core`
- `loops/flow-walker/flow-walker/src/flow-v2-schema.ts`
- `loops/flow-walker/flow-walker/tests/flow-v2-schema.test.ts`
- `loops/flow-walker/flow-walker/tests/cli-v2-contract.test.ts`
- `loops/flow-walker/flow-walker/tests/walk-v2.test.ts`

### Modify

- `loops/flow-walker/flow-walker/src/cli.ts`
- `loops/flow-walker/flow-walker/src/command-schema.ts`
- `loops/flow-walker/flow-walker/src/errors.ts`
- `loops/flow-walker/flow-walker/src/types.ts`
- `loops/flow-walker/flow-walker/src/flow-parser.ts`
- `loops/flow-walker/flow-walker/src/walker.ts`
- `loops/flow-walker/flow-walker/src/yaml-writer.ts`
- `loops/flow-walker/flow-walker/tests/command-schema.test.ts`
- `loops/flow-walker/flow-walker/tests/flow-parser.test.ts`

### Delete

- `loops/flow-walker/flow-walker/src/runner.ts`
- `loops/flow-walker/flow-walker/src/capture.ts`
- `loops/flow-walker/flow-walker/tests/runner.test.ts`
- `loops/flow-walker/flow-walker/tests/capture.test.ts`

## Acceptance criteria (gates)

1. **Phase sentinel exists**: `flow-walker/.phase7-contract-core` exists and contains exactly `phase7_contract_core_complete=yes`.
2. **Legacy executor removed**: `src/runner.ts`, `src/capture.ts`, `tests/runner.test.ts`, and `tests/capture.test.ts` do not exist.
3. **v2 schema module added**: `src/flow-v2-schema.ts` exists and is covered by `tests/flow-v2-schema.test.ts`.
4. **CLI surface is v2-only**: `flow-walker schema` advertises exactly `walk, record, verify, report, push, migrate, schema`; `run` and `get` are not accepted subcommands.
5. **Phase-gated stubs are explicit**: `record`, `verify`, `report`, `push`, and `migrate` return structured `NOT_IMPLEMENTED` errors (exit code `2`) in this phase.
6. **Walk generates v2 scaffold offline**: `flow-walker walk --name <x> --output <path>` writes YAML containing `version: 2` and step fields `id`, `do`, `anchors`, `expect`, `evidence` without requiring device connectivity.
7. **Parser enforces v2 contract**: `flow-parser.ts` accepts valid v2 step format and rejects legacy action keys (`press`, `fill`, `scroll`, `back`, `assert`) with structured error.
8. **Verify modes reserved in schema**: `command-schema.ts` includes verify modes `strict`, `balanced`, `audit` for upcoming Phase 8 implementation.
9. **Outcome state model upgraded**: `types.ts` includes step outcome states `skipped` (with reason) and `recovered` (for later verify semantics), alongside `pass`/`fail`.
10. **No action-runner coupling remains in CLI/walker**: `cli.ts`/`walker.ts` do not import or call runner/capture execution paths.
11. **Type safety gate**: `npx tsc --noEmit` passes.
12. **Test gate with reset baseline**: `npm test` passes and total test count is at least `46` (reflecting replaced suite baseline after clean cut).

## What NOT to do in Phase 7

- Do not implement live `record` capture logic yet (Phase 8).
- Do not implement `verify` execution or scoring yet (Phase 8).
- Do not implement `report`, `push`, or `migrate` data pipelines yet (Phase 9).
- Do not keep backward-compatible v1 step execution paths (`press/fill/scroll/back/assert`) in active command flow.
- Do not call or reintroduce `runner.ts`/`capture.ts` via aliases, wrappers, or hidden imports.
- Do not modify prior phase evaluator files (`eval.sh` through `eval6.sh`).
