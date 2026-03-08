# autoresearch: Marionette Integration for agent-device

This is an autonomous build loop. You are jin, implementing Flutter/Marionette
widget-level control for agent-device. You work in phases (PR1 → PR2 → PR3),
each building on the last.

## Setup

1. **Read context**: Read these files for full understanding:
   - `INTEGRATION_DESIGN.md` — architecture, wire protocol, file plan
   - `src/daemon/types.ts` — SessionState type you'll extend
   - `src/utils/snapshot.ts` — SnapshotNode/RawSnapshotNode types
   - `src/daemon/handlers/snapshot.ts` — existing snapshot handler
   - `src/daemon/handlers/interaction.ts` — existing interaction handler
   - `src/daemon/selectors.ts` — existing selector system
   - `src/platforms/android/` — reference platform implementation
2. **Create branch**: `git checkout -b autoresearch/marionette` from current HEAD.
3. **Initialize results.tsv**: Create `autoresearch/results.tsv` with header row.
4. **Confirm phase**: Start with Phase 1. Confirm and begin.

## Phases

### Phase 1: VM Service Client + Flutter Connect (PR 1)

**Goal**: Connect to a Flutter app's Dart VM Service and retrieve interactive elements.

**Files to create**:
- `src/platforms/flutter/index.ts` — public exports
- `src/platforms/flutter/vm-service-client.ts` — WebSocket JSON-RPC 2.0 client
- `src/daemon/handlers/flutter.ts` — flutter connect/disconnect/status/elements handlers

**Files to modify**:
- `src/daemon/types.ts` — add `flutterVmServiceUri?: string; flutterConnected?: boolean` to SessionState

**Tests to create**:
- `src/platforms/flutter/__tests__/vm-service-client.test.ts` — mock WebSocket, test connect/disconnect/getInteractiveElements/error handling

**Acceptance criteria** (all must pass to advance):
1. `pnpm build` succeeds (zero errors)
2. `pnpm run typecheck` succeeds (zero type errors)
3. All existing tests pass: `pnpm test:unit` exits 0
4. New flutter tests pass: `node --test src/platforms/flutter/__tests__/*.test.ts` exits 0
5. VmServiceClient implements: connect(), disconnect(), getInteractiveElements(), tap(), enterText()
6. flutter.ts handler responds to: `flutter connect`, `flutter disconnect`, `flutter status`, `flutter elements`

**Wire protocol reference** (from INTEGRATION_DESIGN.md):
```
WebSocket → ws://127.0.0.1:PORT/ws
1. connect
2. call getVM() → list isolates
3. find isolate with ext.flutter.marionette.* in extensionRPCs
4. store isolateId
5. call ext.flutter.marionette.interactiveElements with {isolateId}
```

### Phase 2: Merged Snapshot (PR 2)
Unlocks after Phase 1 passes all criteria.

**Goal**: When Flutter is connected, snapshot merges native + Flutter elements.

**Files to create**:
- `src/platforms/flutter/element-converter.ts` — Marionette elements → RawSnapshotNode

**Files to modify**:
- `src/utils/snapshot.ts` — add `source?: 'native' | 'flutter'`, `flutterKey?: string`, `flutterType?: string` to SnapshotNode
- `src/daemon/handlers/snapshot.ts` — when flutter connected, fetch Marionette elements, convert, merge by Y-position, dedupe Flutter region

**Tests to create**:
- `src/platforms/flutter/__tests__/element-converter.test.ts` — conversion correctness, bounds mapping, type mapping

**Acceptance criteria**:
1. `pnpm build` succeeds
2. `pnpm run typecheck` succeeds
3. All existing tests pass: `pnpm test:unit` exits 0
4. All flutter tests pass (Phase 1 + Phase 2)
5. element-converter correctly maps Marionette element fields to RawSnapshotNode
6. SnapshotNode has `source` field
7. Snapshot handler detects FlutterSurfaceView/FlutterView in native tree

### Phase 3: Smart Routing (PR 3)
Unlocks after Phase 2 passes all criteria.

**Goal**: press/fill commands route to Flutter or native based on element source.

**Files to create**:
- `src/platforms/flutter/matcher-builder.ts` — build WidgetMatcher from SnapshotNode (key > text > coordinates)

**Files to modify**:
- `src/daemon/handlers/interaction.ts` — check node.source, route flutter elements to VmServiceClient
- `src/daemon/selectors.ts` — add `key`, `widget-type`, `source` selector fields

**Tests to create**:
- `src/platforms/flutter/__tests__/matcher-builder.test.ts` — matcher priority (key > text > coords)
- Selector tests for new fields

**Acceptance criteria**:
1. `pnpm build` succeeds
2. `pnpm run typecheck` succeeds
3. All existing tests pass: `pnpm test:unit` exits 0
4. All flutter tests pass (Phase 1 + 2 + 3)
5. Matcher builder prioritizes: key > text > coordinates
6. Interaction handler routes flutter-sourced nodes to VmServiceClient
7. Selectors support `key`, `widget-type`, `source`

## The Build Loop

Each iteration follows this cycle:

1. **Plan**: Decide what to implement next within the current phase. Work incrementally — one logical unit per iteration (e.g., one class, one handler, one test file).
2. **Implement**: Write or modify code.
3. **Commit**: `git add` changed files and commit with descriptive message.
4. **Evaluate**: Run the eval script: `bash autoresearch/eval.sh > autoresearch/run.log 2>&1`
5. **Check results**: `cat autoresearch/run.log | tail -20`
6. **Record**: Append results to `autoresearch/results.tsv`.
7. **Decide**:
   - If build+typecheck+tests pass → **keep** the commit, continue to next unit.
   - If build or typecheck fails → **fix** (attempt up to 3 times), then keep or revert.
   - If existing tests broke → **revert** (`git reset --hard HEAD~1`) and try different approach.
   - If only new tests fail → **fix** the new code (not the tests), attempt up to 3 times.
8. **Phase gate**: After all acceptance criteria for the current phase are met, log `PHASE_COMPLETE` in results.tsv, then advance to the next phase.

## Eval Output Format

The eval script prints:

```
---
phase:            1
build:            pass|fail
typecheck:        pass|fail
existing_tests:   pass|fail (count)
flutter_tests:    pass|fail (count)
total_files:      N
new_lines:        N
---
```

## Results TSV Schema

Tab-separated, 6 columns:

```
commit	phase	build	tests	status	description
```

- `commit`: short git hash (7 chars)
- `phase`: 1, 2, or 3
- `build`: pass or fail
- `tests`: pass or fail (or "N/A" for crash before tests)
- `status`: `keep`, `revert`, `fix`, or `PHASE_COMPLETE`
- `description`: what was implemented/attempted

## Rules

- **NEVER STOP**: Keep iterating until manually interrupted. If you finish Phase 3, go back and improve test coverage, add edge cases, refactor for simplicity.
- **No device needed**: All tests use mocked WebSocket/JSON-RPC. You cannot run integration tests.
- **No new dependencies**: Only use what's in `pyproject.toml` / `package.json`. Node built-in `ws` is NOT available — implement WebSocket client using Node's built-in capabilities or the existing patterns in the codebase.
- **Node TS support**: Set `export NODE_OPTIONS="--experimental-strip-types"` before running tests. Node 22 needs this to run `.ts` files directly.
- **PATH**: Set `export PATH="/home/claude/tools/node/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"` to find pnpm.
- **Match existing patterns**: Look at `src/platforms/android/` and `src/platforms/ios/` for coding style, test patterns, and handler structure.
- **Simplicity criterion**: Simpler code that works > clever code. Delete over add when possible.
- **Incremental commits**: One logical change per commit. Never combine unrelated changes.
- **Existing tests are sacred**: If `pnpm test:unit` breaks, your change is wrong — revert.
- **When stuck**: Re-read INTEGRATION_DESIGN.md, look at existing platform implementations for patterns, try a simpler approach. Do NOT ask for help — figure it out.
