# Phase 4: Autonomy Commands for `agent-swift`

**Key Result: `wait`, `is`, `scroll`, and `schema` commands implemented with full test coverage.**

Build on the existing CLI in `loops/agent-swift/agent-swift` (Phase 1 core + Phase 2 widget coverage + Phase 3 interaction commands complete).

## Before You Start

Read these files:
- `Sources/agent-swift/main.swift` — current 10 commands, `resolveRef` helper, result struct patterns
- `Sources/AgentSwiftLib/AX/AXClient.swift` — walkTree, flattenTree, collectElements, performPress, performFill
- `Sources/AgentSwiftLib/Session/SessionStore.swift` — SessionData model with interactiveSnapshot

### Study agent-flutter autonomy commands:
- `loops/agent-flutter/agent-flutter/src/commands/wait.ts` — polling loop with timeout/interval, condition types
- `loops/agent-flutter/agent-flutter/src/commands/is.ts` — assertion with exit code 1 for false
- `loops/agent-flutter/agent-flutter/src/commands/scroll.ts` — scroll by ref or direction
- `loops/agent-flutter/agent-flutter/src/command-schema.ts` — schema introspection for all commands

### Study design references:
- agent-device `wait` — `wait <condition> [target] [--timeout]`
- agent-browser `is` — `is visible @e1`, `is enabled @e1`, `is checked @e1`
- agent-flutter `schema` — returns JSON array of command schemas with name, description, args, flags, exitCodes

## Context

agent-swift Phase 3 added fill, get, find, screenshot. This phase adds the autonomy commands that let AI agents run deterministic, self-checking workflows:
- `wait` — poll for a condition before proceeding
- `is` — assert a condition with exit code 1 for false (not error)
- `scroll` — navigate scrollable containers
- `schema` — machine-readable CLI introspection

## Scope

### Track 1: `is` Command (P0)

```bash
agent-swift is exists @e1          # exit 0 if exists, exit 1 if not
agent-swift is visible @e1         # exit 0 if visible (has position/size), exit 1 if not
agent-swift is enabled @e1         # exit 0 if enabled, exit 1 if disabled
agent-swift is focused @e1         # exit 0 if focused, exit 1 if not
```

Implementation:
1. Load session, get PID
2. Re-walk AX tree, check condition on the element matching the ref
3. Exit 0 if condition true, exit 1 if condition false
4. Exit 2 only for real errors (not connected, invalid args)
5. `--json` outputs `{"ref":"@e1","condition":"exists","result":true/false}`

**Critical**: exit code 1 means "assertion false" NOT "error". This is the contract from agent-flutter.

### Track 2: `wait` Command (P0)

```bash
agent-swift wait exists @e1                    # Wait for element to exist
agent-swift wait visible @e1                   # Wait for element to be visible
agent-swift wait text "Welcome"                # Wait for text to appear anywhere
agent-swift wait gone @e1                      # Wait for element to disappear
agent-swift wait 2000                          # Wait N milliseconds
agent-swift wait exists @e1 --timeout 10000    # Custom timeout (default: 5000ms)
agent-swift wait exists @e1 --interval 500     # Custom poll interval (default: 250ms)
```

Implementation:
1. Parse condition and target
2. Poll loop: re-walk AX tree every `interval` ms, check condition
3. If condition met: exit 0
4. If timeout exceeded: exit 2 with TIMEOUT error
5. Special case: `wait <number>` is a simple delay (sleep N ms)
6. For `text` condition: search all nodes' displayLabel for the text

Default timeout: 5000ms. Default interval: 250ms.

### Track 3: `scroll` Command (P1)

```bash
agent-swift scroll @e1              # Scroll element into view
agent-swift scroll up               # Scroll active window up
agent-swift scroll down             # Scroll active window down
```

Implementation for macOS:
1. `scroll @ref` — find the element, use `AXScrollArea` parent's `AXScrollToVisible` action
2. `scroll up/down` — find the focused/main scroll area, use `CGEventCreateScrollWheelEvent` or AX scroll actions

Fallback: If `AXScrollToVisible` is not supported, use coordinate-based `CGEventCreateScrollWheelEvent`.

### Track 4: `schema` Command (P0)

```bash
agent-swift schema                 # List all commands with schemas (JSON)
agent-swift schema press           # Schema for specific command
```

Implementation:
1. Define a static schema registry with all commands
2. Each schema: `{ name, description, args: [{name, type, required}], flags: [{name, type, default}], exitCodes: {0: "success", 1: "assertion false", 2: "error"} }`
3. `schema` with no arg: output array of all schemas
4. `schema <command>`: output single schema object

### Track 5: Test Coverage (P0)

Add/extend `Tests/agent-swiftTests/InteractionTests.swift` or create `AutonomyTests.swift`:

1. `is` condition evaluation on AXNode (exists/visible/enabled/focused)
2. `wait` timeout behavior (mock or unit-level)
3. `schema` output structure validation
4. Exit code contract: `is` returns 1 for false assertions
5. `scroll` direction parsing

**Minimum: 20 new XCTAssert* calls.**

---

## Acceptance Criteria

1. `agent-swift is exists @e1` exits 0 when element exists.
2. `agent-swift is exists @e99999` exits 1 (assertion false, not error).
3. `agent-swift is visible @e1` exits 0 when element has bounds.
4. `agent-swift is enabled @e1` exits 0 when element is enabled.
5. `agent-swift is exists @e1 --json` returns `{"ref":"@e1","condition":"exists","result":true}`.
6. `agent-swift wait 1000` sleeps 1 second and exits 0.
7. `agent-swift wait exists @e1` polls and exits 0 when found.
8. `agent-swift wait exists @e99999 --timeout 1000` exits 2 with TIMEOUT error after 1s.
9. `agent-swift wait text "some text"` polls all nodes for text match.
10. `agent-swift scroll down` scrolls the active window.
11. `agent-swift schema` returns JSON array of all command schemas.
12. `agent-swift schema press` returns valid schema object with name, description, args, flags, exitCodes.
13. Schema lists all commands: doctor, connect, disconnect, status, snapshot, press, fill, get, find, screenshot, is, wait, scroll, schema.
14. All new commands registered in `AgentSwift.subcommands`.
15. `--help` works for is, wait, scroll, schema.
16. `--json` works for is, wait, scroll, schema.
17. Exit code contract: is=1 for false, wait=2 for timeout, all others=0/2.
18. ≥ 20 new XCTAssert* calls.
19. All existing tests (40) still pass.
20. `swift build` succeeds.
21. `swift test` succeeds.

---

## Build Loop Protocol

1. Implement `is` command (Track 1). Run eval.
2. Implement `wait` command (Track 2). Run eval.
3. Implement `scroll` command (Track 3). Run eval.
4. Implement `schema` command (Track 4). Run eval.
5. Add tests (Track 5). Run eval — all gates green.
6. Commit only when green.

---

## Rules

- **Exit code 1 is NOT an error**: `is` command uses exit 1 for false assertions. Do not treat exit 1 as failure in the command itself.
- **Existing tests are sacred**: do not weaken or delete passing tests.
- **Follow established patterns**: use resolveRef helper, Codable result structs, Output.printError for errors.
- **No regressions in snapshot format or exit codes.**
- **Keep scope phase-local**: no polish/env-vars in this phase.
- **macOS build required**: all changes must compile and test on macOS.
