# Phase 3: Interaction Commands for `agent-swift`

**Key Result: `fill`, `get`, `find`, and `screenshot` commands implemented with full test coverage.**

Build on the existing standalone CLI in `loops/agent-swift/agent-swift` (Phase 1 core + Phase 2 widget coverage complete).

## Before You Start

Read these files:
- `Sources/agent-swift/main.swift` — current 6 commands (doctor, connect, disconnect, status, snapshot, press), PressCommand pattern
- `Sources/AgentSwiftLib/AX/AXClient.swift` — AXUIElement operations (walkTree, flattenTree, performPress, collectElements)
- `Sources/AgentSwiftLib/Session/SessionStore.swift` — SessionData model, refs persistence
- `Sources/AgentSwiftLib/Output/JsonEnvelope.swift` — Output helpers, error formatting

### Study agent-flutter interaction commands:
- `loops/agent-flutter/agent-flutter/src/commands/fill.ts` — fill pattern (resolve ref, clear, enter text)
- `loops/agent-flutter/agent-flutter/src/commands/get.ts` — get pattern (property read by ref)
- `loops/agent-flutter/agent-flutter/src/commands/find.ts` — find pattern (locator search + optional chained action)
- `loops/agent-flutter/agent-flutter/src/commands/screenshot.ts` — screenshot pattern

## Context

agent-swift Phase 1 provides the core loop: `connect → snapshot → press → disconnect`. Phase 2 added full widget coverage (66 AX roles, ROLE_MAP, INTERACTIVE_ROLES). This phase adds the remaining interaction commands to match agent-flutter's workflow.

**Critical bug fix needed:** The `PressCommand` uses a flawed `useInteractive` heuristic — it compares session ref count with current interactive node count, which fails when the AX tree changes between snapshot and action (e.g. menu items appearing). Fix: store `interactiveSnapshot: Bool` in SessionData, set it during snapshot, read it in press/fill/find.

## Scope

### Track 1: Fix Interactive Snapshot Heuristic (P0)

Add `interactiveSnapshot: Bool?` to `SessionData`. Set it in `SnapshotCommand` based on the `-i` flag. Use it in `PressCommand` (and new commands) instead of the current count-based guess.

### Track 2: `fill` Command (P0)

```bash
agent-swift fill @e1 "hello world"
agent-swift fill @e1 "hello" --json
```

Implementation:
1. Resolve ref from session (same pattern as PressCommand)
2. Re-walk AX tree, find element at index
3. Focus element: `AXUIElementSetAttributeValue(element, kAXFocusedAttribute, true)`
4. Set value: `AXUIElementSetAttributeValue(element, kAXValueAttribute, text)`
5. Return success/error with JSON support

Add `performFill(element: AXUIElement, text: String) -> Bool` to `AXClient`.

Applicable to: `AXTextField`, `AXTextArea`, `AXComboBox`, `AXSearchField`.

### Track 3: `get` Command (P0)

```bash
agent-swift get text @e1      # Read label/title/value
agent-swift get type @e1      # Read display type (from ROLE_MAP)
agent-swift get role @e1      # Read raw AX role
agent-swift get identifier @e1 # Read accessibility identifier
agent-swift get attrs @e1     # Read all attributes as JSON
```

Implementation:
1. Resolve ref from session
2. Re-walk AX tree, find element at index
3. Read requested property from AXNode
4. Output as plain text (human) or JSON (`--json`)

`attrs` returns: `{ role, type, label, identifier, value, enabled, focused, bounds, actions }`.

### Track 4: `find` Command (P0)

```bash
agent-swift find role button                          # Find first button
agent-swift find identifier "saveButton" press        # Find by identifier + press
agent-swift find text "Submit" press                  # Find by text/label + press
agent-swift find role textfield fill "hello"           # Find by role + fill
agent-swift find identifier "name_field" get text     # Find + read
```

Implementation:
1. Load last snapshot elements from session
2. Search by locator type (`role`, `text`, `identifier`)
3. If no chained action: print matching element with ref
4. If chained action: execute `press`, `fill`, or `get` on the matched element

Locator priority (for agents): `identifier > text > role`.

### Track 5: `screenshot` Command (P0)

```bash
agent-swift screenshot                          # Default: /tmp/agent-swift-screenshot.png
agent-swift screenshot /tmp/screen.png          # Custom path
agent-swift screenshot --json                   # JSON output with path
```

Implementation:
1. Load session, get PID
2. Find app's window via `CGWindowListCopyWindowInfo`
3. Capture window image via `CGWindowListCreateImage`
4. Write PNG via `CGImageDestinationCreateWithURL`

Add `captureScreenshot(pid: Int, path: String) -> Bool` to `AXClient`.

### Track 6: Test Coverage (P0)

Add tests in `Tests/agent-swiftTests/`:

1. **InteractionTests.swift**:
   - `performFill` returns true for settable elements (mock or AXNode-level test)
   - `interactiveSnapshot` flag persisted in session
   - `get` property extraction from AXNode
   - `find` locator matching (role, text, identifier)
   - `find` with chained action resolution

2. **Existing test preservation**: All 30 existing tests must continue passing.

**Minimum: 20 new XCTAssert* calls across interaction tests.**

---

## Acceptance Criteria

1. `agent-swift fill @e1 "text"` sets value on AXTextField/AXTextArea element.
2. `agent-swift fill @e1 "text" --json` returns `{"filled":"@e1","text":"text","success":true}`.
3. `agent-swift fill` on non-fillable element returns structured error, exit 2.
4. `agent-swift get text @e1` returns element's display label.
5. `agent-swift get type @e1` returns display type from ROLE_MAP.
6. `agent-swift get role @e1` returns raw AX role.
7. `agent-swift get identifier @e1` returns accessibility identifier.
8. `agent-swift get attrs @e1 --json` returns full attribute object.
9. `agent-swift find role button` prints matching element with ref.
10. `agent-swift find identifier "id" press` finds and presses element.
11. `agent-swift find text "Submit" press` finds by text and presses.
12. `agent-swift find role textfield fill "hello"` finds and fills.
13. `agent-swift find` with no match returns structured error, exit 2.
14. `agent-swift screenshot` captures PNG to default path.
15. `agent-swift screenshot /tmp/test.png --json` returns `{"path":"/tmp/test.png","success":true}`.
16. `interactiveSnapshot` field added to SessionData.
17. SnapshotCommand sets `interactiveSnapshot` based on `-i` flag.
18. PressCommand uses `session.interactiveSnapshot` instead of count heuristic.
19. FillCommand uses `session.interactiveSnapshot` for element resolution.
20. All new commands registered in `AgentSwift.subcommands`.
21. `--help` works for fill, get, find, screenshot.
22. `--json` works for fill, get, find, screenshot.
23. Exit code contract preserved (0/1/2).
24. ≥ 20 new XCTAssert* calls in interaction tests.
25. All existing tests (30) still pass.
26. `swift build` succeeds.
27. `swift test` succeeds.
28. No regressions in snapshot format or session persistence.

---

## Build Loop Protocol

1. Fix the `interactiveSnapshot` heuristic first (Track 1). Run eval.
2. Implement `fill` command (Track 2). Run eval after.
3. Implement `get` command (Track 3). Run eval after.
4. Implement `find` command (Track 4). Run eval after.
5. Implement `screenshot` command (Track 5). Run eval after.
6. Add interaction tests (Track 6). Run eval — all gates green.
7. Commit only when green.

Each iteration:
1. Implement one scoped change.
2. Run evaluator: `bash loops/agent-swift/eval.sh`
3. Keep only passing iterations; revert failed direction and retry.

---

## Rules

- **Existing tests are sacred**: do not weaken or delete passing tests.
- **Follow PressCommand pattern**: all new commands share the same session/ref/element resolution flow.
- **No regressions in snapshot format or exit codes.**
- **Single source of truth**: `interactiveSnapshot` replaces the count-based heuristic everywhere.
- **Keep scope phase-local**: no wait/is/schema in this phase (those are Phase 4).
- **macOS build required**: all changes must compile and test on macOS (Mac Mini).
