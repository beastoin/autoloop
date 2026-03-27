# Phase 12 — Two-Tier Verification Reports

## Objective

Redesign flow-walker's verification and reporting to support two verification tiers:

- **Tier 1 (Automated)**: Deterministic checks re-runnable from stored artifacts, no device or AI needed
- **Tier 2 (Agent)**: Vision + reasoning checks requiring an AI agent to review screenshots

## Design (from Codex consultation)

### Flow YAML changes

Add `claim` and `judge` fields to steps. Keep `expect` for tier 1, add `judge` for tier 2.

```yaml
version: 2
name: settings-drawer

steps:
  - id: S2
    name: Open settings
    do: press the Settings button
    claim: settings drawer is open with menu items visible

    expect:                          # Tier 1 — automated
      - kind: text_visible
        values: [Settings]
      - kind: interactive_count
        min: 5

    judge:                           # Tier 2 — agent vision
      - prompt: Is the settings drawer open as an overlay?
        look_for: [side panel, settings options, dimmed backdrop]
        fail_if: [full-screen page, blank state, wrong screen]

    evidence:
      - screenshot: step-S2
```

### verify.ts changes

Replace `expectations: unknown[]` with typed results preserving actual values:

```ts
interface AutomatedCheck {
  kind: string;
  status: 'pass' | 'fail' | 'no_evidence';
  expected: Record<string, unknown>;
  actual: Record<string, unknown>;
}

interface AgentCheck {
  prompt: string;
  status: 'pending' | 'pass' | 'fail';
  look_for?: string[];
  fail_if?: string[];
  screenshot?: string;
}

// Per step: { automated: { result, checks[] }, agent: { result, prompts[] } }
```

Key rules:
- `actual` must contain real observed values from assert events
- If no assert event exists for an expect, status = `no_evidence` (not pass)
- `judge` prompts start as `pending` — filled later by a verifier agent

### reporter.ts changes

1. Show `claim` as step headline. Show `do` as secondary "Action performed" line.
2. Per step, two sections:
   - **Automated checks**: table with Kind | Expected | Actual | Status
   - **Agent verification**: prompt cards with screenshot, question, look_for, fail_if
3. Top summary shows automated result + agent review status separately
4. Embed full `run.json` as `<script type="application/json" id="report-data">`

### New: verify --recheck

`flow-walker verify <flow.yaml> --run-dir <dir> --recheck` re-runs tier 1 from stored artifacts without a device. Compares recorded vs rechecked results.

### New: verify --agent-prompt

`flow-walker verify <flow.yaml> --run-dir <dir> --agent-prompt` outputs structured JSON prompts for a verifier agent. The agent gets: claim, screenshot paths, look_for/fail_if rubric, expected answer format.

## Acceptance criteria

1. `claim` field parsed from flow YAML, shown as report headline
2. `judge` array parsed from flow YAML, stored in verify output
3. Automated checks show expected vs actual (not just met/unmet boolean)
4. `no_evidence` status when assert event missing (never fake a pass)
5. Report HTML has two sections per step: automated + agent
6. `<script type="application/json" id="report-data">` embedded in HTML
7. `verify --recheck` re-evaluates tier 1 from stored run data
8. `verify --agent-prompt` outputs JSON prompts for vision agent review
9. Report top summary shows `Automated: X/Y pass` and `Agent review: N pending`
10. Backward compatible: v2 flows without claim/judge still work (claim defaults to name or do)
11. All existing tests still pass
12. Schema version bumped to 3.0.0

## Files to modify

- `src/types.ts` — add claim, judge to FlowV2Step
- `src/flow-parser.ts` — parse claim and judge from YAML
- `src/verify.ts` — typed check results with actual values, agent prompts
- `src/reporter.ts` — two-tier report layout, embedded JSON
- `src/command-schema.ts` — add --recheck, --agent-prompt flags; bump schema version
- `src/cli.ts` — route --recheck and --agent-prompt
- `src/event-schema.ts` — extend assert events with expected/actual payloads
- Tests for all new functionality
