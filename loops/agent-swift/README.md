# Loop: agent-swift

CLI for AI agents to control native macOS Swift apps (SwiftUI + AppKit) via the macOS Accessibility API (AXUIElement). Same `snapshot → @ref → press/fill/wait/is` workflow as agent-flutter and agent-browser.

## Project Objective

**Build `agent-swift` — a native Swift CLI that lets AI agents inspect and control any macOS app without app instrumentation.**

### Why this matters

agent-flutter requires Marionette (an in-app dependency). agent-swift uses the OS-level Accessibility API — it works on **any macOS app** out of the box. No code changes to the target app. This makes it the first truly zero-instrumentation agent CLI in the family.

### Transport: macOS Accessibility API (AXUIElement)

| Property | agent-flutter | agent-swift |
|----------|--------------|-------------|
| Transport | Dart VM Service + Marionette (WebSocket) | AXUIElement (local IPC) |
| Instrumentation | Required (add marionette_flutter) | None (OS-level) |
| Connection target | VM Service URI (auto-detect from logcat) | PID or bundle ID |
| Permission | None | TCC Accessibility trust |
| Element info | type, key, text, visible, bounds | role, subrole, identifier, title, value, enabled, focused, bounds, actions |
| Platforms | Android (Flutter apps) | macOS (any app) |

### Architecture: Native Swift CLI

Per Codex recommendation: native Swift CLI, not Node.js. Direct access to AX/AppKit APIs, better TCC handling, easier notarization. Can add a thin Node wrapper later for ecosystem parity.

```text
agent-swift              # Swift binary (compiled via swift build)
├── Sources/
│   ├── CLI/             # Argument parsing, command dispatch
│   ├── AXClient/        # AXUIElement wrapper (connect, traverse, act)
│   ├── Snapshot/        # Element tree → @ref mapping, output formatting
│   ├── Session/         # File-based session persistence (~/.agent-swift/session.json)
│   └── Commands/        # doctor, connect, disconnect, snapshot, press, fill, etc.
├── Tests/               # Unit + integration tests
└── Package.swift
```

### CLI Surface (matches agent-flutter)

```bash
# Setup
agent-swift doctor                    # Check AX permission, find target apps
agent-swift connect --bundle-id com.example.app   # Connect by bundle ID
agent-swift connect --pid 12345       # Connect by PID
agent-swift disconnect

# Inspection
agent-swift snapshot [-i] [--json]    # Widget tree with @refs
agent-swift status                    # Connection state
agent-swift get text @e1              # Read element properties

# Interaction
agent-swift press @e3                 # Click/press element
agent-swift fill @e5 "hello"          # Set value on text field
agent-swift find role button press    # Find by role + action

# Assertions
agent-swift wait text "Welcome"      # Wait for text to appear
agent-swift is exists @e3             # Assert element exists

# Utility
agent-swift screenshot [path]         # Window screenshot
agent-swift schema [command]          # JSON schema
```

### Output contract (identical to agent-flutter)

```text
@e1 [button] "Submit"                key=submit_btn
@e2 [textfield] "Email"              identifier=email_field
@e3 [statictext] "Welcome back"
```

Exit codes: 0 = success, 1 = assertion false, 2 = error.

### SwiftUI-specific considerations

- AX tree ≠ SwiftUI view tree — SwiftUI auto-generates accessibility elements
- `.accessibilityIdentifier("foo")` → stable targeting (like Flutter's `Key`)
- Decorative/container views get collapsed — "what user sees" ≠ "what AX sees"
- Hybrid SwiftUI + AppKit apps produce mixed role hierarchies
- State-driven updates need deterministic wait/retry around transitions

### Build environment

- Mac Mini M4 (beastoin-agents-f1-mac-mini) — SSH access, Xcode installed
- Swift toolchain available via Xcode
- Compile: `swift build` / `swift test`
- No npm/Node dependency for the core CLI

### Phased delivery

| Phase | Scope | Key deliverables |
|-------|-------|-----------------|
| 1 | Core: doctor + connect + snapshot + press | AX client, @ref system, session persistence, TCC check |
| 2 | Interaction: fill + get + find + scroll | Text input, property read, semantic locators, chained actions |
| 3 | Autonomy: wait + is + screenshot + schema | Polling assertions, exit-code contract, JSON schema, screenshot |
| 4 | Polish: error handling, --json, env vars, AGENTS.md | Agent-friendly output, diagnosticId, TTY-aware formatting |

### Success criteria

- `agent-swift doctor && agent-swift connect --bundle-id <app> && agent-swift snapshot -i && agent-swift press @e1` works end-to-end
- Same snapshot format as agent-flutter (`@eN [type] "label"`)
- Zero instrumentation — works on any macOS app with Accessibility enabled
- All tests pass (unit + e2e against a real macOS app)

## Status

**Loop 1 active** — control files and Swift package scaffold created; implementation not started.

## Layout

```text
loops/agent-swift/
├── README.md               # this file (project objective)
├── program.md              # phase 1 objectives (doctor/connect/snapshot/press)
├── eval.sh                 # evaluator harness (build/test/contract/phase gate)
├── agent-swift/            # build target (Swift package)
│   └── Package.swift       # manifest scaffold (sources/tests added in implementation loop)
├── CLAUDE.md               # loop-specific build instructions and guardrails
└── AGENTS.md               # loop operating guide (workflow, state machine, recipes)
```

No shared test fixtures needed — agent-swift targets any macOS app, no special test app required.

## Publish flow

After phases complete:
1. Copy `agent-swift/` → `beastoin/agent-swift` product repo
2. Distribute via Homebrew tap or GitHub releases (not npm — it's a Swift binary)
