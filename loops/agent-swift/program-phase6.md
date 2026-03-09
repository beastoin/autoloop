# Phase 6: Click Command for `agent-swift`

**Key Result: `agent-swift click @e1` sends CGEvent mouse clicks, enabling interaction with SwiftUI NavigationLink and other elements that ignore AXPress.**

Build on the existing CLI in `loops/agent-swift/agent-swift` (all prior phases complete, 63 tests, 15 commands after this phase).

## Before You Start

Read these files:
- `Sources/agent-swift/main.swift` — ScrollCommand (CGEvent pattern), PressCommand (ref resolution), resolveRef helper
- `Sources/AgentSwiftLib/AX/AXClient.swift` — AXNode (position/size), performPress
- `Sources/AgentSwiftLib/Session/SessionStore.swift` — RefEntry.Bounds, SessionData

## Context

`press` uses AXPress action via the Accessibility API. SwiftUI NavigationLink (sidebar items) ignores AXPress — it only responds to real mouse events. The `scroll` command already uses CGEvent for mouse wheel events. `click` applies the same pattern for mouse down/up.

## Scope

### Track 1: Add `performClick` to AXClient (P0)

Add a static method to `AXClient`:

```swift
public static func performClick(at point: CGPoint) -> Bool {
    guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
          let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
        return false
    }
    mouseDown.post(tap: .cgSessionEventTap)
    Thread.sleep(forTimeInterval: 0.05)
    mouseUp.post(tap: .cgSessionEventTap)
    return true
}
```

### Track 2: Add ClickCommand to main.swift (P0)

```
agent-swift click @e1          # Click at center of element bounds
agent-swift click 100 200      # Click at absolute coordinates
```

Implementation:
1. Register `ClickCommand.self` in subcommands array
2. Takes 1-2 arguments: `@ref` OR `x y` coordinates
3. For `@ref`: resolve ref, get node bounds, compute center point `(x + width/2, y + height/2)`
4. For coordinates: parse x,y as Double
5. Bring app to front first (`NSRunningApplication.activate()`, sleep 0.1)
6. Call `AXClient.performClick(at: point)`
7. JSON output: `{"clicked": "@e1", "x": 150.0, "y": 300.0, "success": true}`
8. Human output: `Clicked @e1 at (150, 300)`

Error cases:
- No session → exit 2
- Element not found → exit 2
- Element has no bounds → exit 2, hint: "Element has no position/size"
- Click event creation failed → exit 2

### Track 3: Update Schema (P0)

Add click to `allSchemas()`:
```swift
CommandSchema(name: "click", description: "Click element or coordinates",
    args: [.init(name: "target", type: "string", required: true),
           .init(name: "y", type: "number", required: false)],
    flags: [.init(name: "--json", type: "bool", defaultValue: "false")],
    exitCodes: ["0": "success", "2": "error"]),
```

Update schema count check in eval: 15 commands.

### Track 4: Update AGENTS.md (P0)

Add click to:
- Command table
- Idempotency table (click = no, side-effectful)
- Recipe: `click @e1` for NavigationLink/sidebar navigation
- Note: "Use `click` for SwiftUI NavigationLink; `press` for standard AX controls"

### Track 5: Tests (P0)

Add tests to a new `ClickTests.swift` or extend `AutonomyTests.swift`:

1. `performClick` returns Bool
2. Click schema has correct args
3. Click schema has correct exit codes
4. Schema count = 15 (14 existing + 1 click)
5. Click command in help output (verified via allSchemas)

**Minimum: 5 new XCTAssert* calls.**

### Track 6: Bump Version to 0.2.1 (P0)

Update version string in `AgentSwift` configuration.

---

## Acceptance Criteria

1. `agent-swift click @e1` sends CGEvent mouse click at element center
2. `agent-swift click 100 200` sends CGEvent mouse click at (100, 200)
3. Click brings app to front before clicking
4. `--json` flag produces structured JSON output
5. Exit code 0 on success, 2 on error
6. Schema lists 15 commands including click
7. Version is 0.2.1
8. `swift build` succeeds
9. `swift test` succeeds with ≥ 68 tests
10. All existing tests still pass

---

## Build Loop Protocol

1. Add `performClick` to AXClient.swift (Track 1)
2. Add ClickCommand to main.swift (Track 2)
3. Update schema (Track 3)
4. Update AGENTS.md (Track 4)
5. Add tests (Track 5)
6. Bump version (Track 6)
7. Run eval

---

## Rules

- **Existing tests are sacred**: do not weaken or delete passing tests.
- **Follow established patterns**: same CGEvent usage as ScrollCommand, same ref resolution as PressCommand.
- **No regressions in snapshot format, exit codes, or --json output.**
- **Keep scope phase-local**: only click command, no other new commands.
- **macOS build required**: all changes must compile and test on macOS.
