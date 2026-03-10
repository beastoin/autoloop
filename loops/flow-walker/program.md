# flow-walker — Automatic App Flow Extraction via agent-flutter

Build a CLI tool called `flow-walker` that connects to a running Flutter app via
agent-flutter, systematically walks every reachable screen, and outputs YAML flow
files describing the app's navigation structure.

## Problem

Manually mapping app flows is slow and incomplete. sora manually created 20 flows
for the Omi app (~1053 lines of YAML) by combining code analysis and live
exploration. This tool automates the exploration phase.

## Approach

Recursive screen walker using agent-flutter as the transport layer:

1. Connect to running Flutter app via agent-flutter
2. Snapshot current screen → compute screen fingerprint
3. For each interactive element, evaluate safety, then press it
4. Snapshot the result → is this a new screen or the same screen?
5. Record transition: (source_screen, element, target_screen)
6. Navigate back to source screen
7. Repeat recursively with cycle detection and depth limit

## Phase 1: Screen Walker Core

### Requirements

1. **CLI entry point** — `flow-walker walk` command that accepts:
   - `--app-uri <uri>` — VM Service URI (passed to agent-flutter connect)
   - `--bundle-id <id>` — alternative: connect by bundle ID (Android)
   - `--max-depth <n>` — max navigation depth (default: 5)
   - `--output-dir <dir>` — where to write YAML flows (default: `./flows/`)
   - `--blocklist <words>` — comma-separated dangerous keywords (default: `delete,sign out,remove,reset,unpair,logout,clear all`)
   - `--json` — machine-readable progress output
   - `--dry-run` — snapshot and plan but don't press anything

2. **Screen fingerprinting** — identify "which screen am I on" by hashing:
   - Element types/roles from snapshot (NOT text content — text is dynamic)
   - Element count per type
   - Flutter widget types from snapshot metadata
   - Fingerprint must be stable across runs for the same screen
   - Similar screens with minor differences (e.g., different list lengths) should
     produce the same fingerprint (fuzzy matching)

3. **Navigation graph** — build a directed graph as the walker explores:
   - Nodes = unique screens (by fingerprint)
   - Edges = transitions (element pressed, source screen, target screen)
   - Detect cycles: skip screens already visited
   - Track navigation stack for back-navigation

4. **Safe exploration** — before pressing any element:
   - Check element text and nearby text elements for blocklist keywords
   - Skip elements matching blocklist (log as skipped)
   - Skip elements that are disabled or non-interactive
   - Press timeout: if no screen change after 3 seconds, treat as no-op

5. **Back navigation** — return to previous screen after exploring a branch:
   - Use ADB back button (agent-flutter back command)
   - Verify we returned to the expected screen (re-snapshot and compare fingerprint)
   - If back didn't work (e.g., modal closed to wrong screen), attempt recovery:
     re-navigate from root

6. **YAML output** — for each unique navigation path, generate a YAML flow file:
   - Match the format used in `~/omi/omi-sora/app/e2e/flows/*.yaml`
   - Fields: `name`, `description`, `setup: normal`, `steps[]`
   - Each step: `name`, `press`/`scroll`/`back`, `assert` (interactive_count),
     `screenshot` reference
   - File naming: kebab-case derived from the screen name or path
   - One flow per top-level navigation branch (tab, settings section, etc.)

7. **Progress reporting** — during walk:
   - Print current depth, screen fingerprint, elements found, elements skipped
   - Print navigation path (breadcrumb)
   - Summary at end: screens found, flows generated, elements skipped

### Acceptance Criteria

- [ ] `flow-walker walk --dry-run` connects, snapshots home screen, lists
      interactive elements and their safety status, exits without pressing
- [ ] `flow-walker walk --max-depth 1` explores one level deep: presses each
      safe element on home screen, records transitions, generates YAML
- [ ] Screen fingerprint is deterministic: same screen produces same hash
      across multiple snapshots (ignoring dynamic text)
- [ ] Blocklist prevents pressing dangerous elements (delete, sign out, etc.)
- [ ] Back navigation returns to the correct screen after each branch
- [ ] Cycle detection: visiting screen A → B → A does not loop forever
- [ ] Generated YAML is valid and parseable
- [ ] Generated YAML matches the structure of sora's reference flows
- [ ] Navigation graph is dumped as JSON alongside YAML flows
- [ ] Works against a real Flutter app via agent-flutter on Android device

### Non-goals (Phase 1)

- Code analysis for `covers:` field (defer to Phase 2)
- Scroll-to-reveal discovery (defer to Phase 2)
- Multiple setup modes (signed_out, etc.) — Phase 1 assumes logged-in state
- Fill/input exploration — Phase 1 only presses, doesn't fill text fields
- Screenshot capture — Phase 1 records screenshot references but doesn't
  capture actual PNGs (agent-flutter screenshot can be added in Phase 2)

## Architecture

```
flow-walker/
  src/
    cli.ts              — CLI entry point, arg parsing
    walker.ts           — recursive screen walker algorithm
    fingerprint.ts      — screen fingerprinting (hash from element types)
    graph.ts            — navigation graph (nodes, edges, cycle detection)
    safety.ts           — blocklist checking, element safety evaluation
    yaml-writer.ts      — YAML flow file generation
    agent-bridge.ts     — thin wrapper around agent-flutter CLI commands
  tests/
    fingerprint.test.ts
    safety.test.ts
    graph.test.ts
    yaml-writer.test.ts
  package.json
  tsconfig.json
```

## Runtime

- Language: TypeScript (ESM), Node.js 22+
- Dependencies: agent-flutter CLI (must be in PATH or specified via `--agent-flutter-path`)
- Transport: shells out to `agent-flutter` commands (connect, snapshot, press, back, disconnect)
- No direct VM Service access — agent-flutter is the abstraction layer

## Validation

Ground truth: sora's 20 flows at `~/omi/omi-sora/app/e2e/flows/*.yaml`

The walker's output can be compared against these reference flows:
- Screen coverage: did the walker find the same screens sora documented?
- Navigation paths: do the transitions match?
- Element counts: are interactive_count assertions in the right ballpark?

This comparison is manual in Phase 1, automated in Phase 2.

## Build and test

```bash
cd loops/flow-walker/flow-walker
npm install
npm test          # unit tests (fingerprint, safety, graph, yaml-writer)
npm run build     # typecheck
```

```bash
# Phase evaluator (from repo root)
bash loops/flow-walker/eval.sh
```
