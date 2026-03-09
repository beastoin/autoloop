# Phase 5: Polish for `agent-swift`

**Key Result: env-var config, TTY-aware JSON, consistent help text, AGENTS.md updated, version 0.2.0.**

Build on the existing CLI in `loops/agent-swift/agent-swift` (Phase 1 core + Phase 2 widget coverage + Phase 3 interaction + Phase 4 autonomy complete).

## Before You Start

Read these files:
- `Sources/agent-swift/main.swift` — 14 commands, custom main() entry, GlobalOptions
- `Sources/AgentSwiftLib/Output/JsonEnvelope.swift` — error format (diagnosticId already exists)
- `Sources/AgentSwiftLib/Session/SessionStore.swift` — session path
- `AGENTS.md` — current agent guide (update with env vars, scroll recipe, full command table)

### Study agent-flutter polish patterns:
- `loops/agent-flutter/agent-flutter/src/cli.ts` — `resolveJsonMode()` precedence: flag > env > TTY
- `loops/agent-flutter/agent-flutter/AGENTS.md` — env vars section, JSON-first usage section

## Context

agent-swift Phase 4 delivered all 14 commands with working --json, error shapes, and exit codes. This phase adds the production polish layer:
- Environment variable configuration (matching `AGENT_SWIFT_*` pattern from agent-flutter's `AGENT_FLUTTER_*`)
- TTY-aware JSON mode (non-TTY defaults to JSON, just like agent-flutter)
- Consistent help text style across all commands
- AGENTS.md updated with env vars, all commands, and new recipes
- Version bump to 0.2.0

## Scope

### Track 1: Environment Variables (P0)

Add support for these env vars with CLI-flag-takes-precedence rule:

| Variable | Purpose | Default | CLI override |
|----------|---------|---------|-------------|
| `AGENT_SWIFT_JSON` | Force JSON output when `=1` | unset | `--json` flag |
| `AGENT_SWIFT_TIMEOUT` | Default wait timeout in ms | `5000` | `--timeout` flag |
| `AGENT_SWIFT_HOME` | Session directory path | `~/.agent-swift` | none |

Implementation:
1. In `GlobalOptions` or the custom main() entry, check `AGENT_SWIFT_JSON=1` as a fallback for `--json`
2. In `WaitCommand`, read `AGENT_SWIFT_TIMEOUT` as default when `--timeout` is not explicitly set
3. In `SessionStore`, accept `AGENT_SWIFT_HOME` to override session directory
4. Precedence: CLI flag > env var > built-in default

### Track 2: TTY-Aware JSON Mode (P0)

Match agent-flutter's `resolveJsonMode()` pattern:
1. If `--json` flag → JSON mode
2. If `AGENT_SWIFT_JSON=1` → JSON mode
3. If stdout is not a TTY (`!isatty(STDOUT_FILENO)`) → JSON mode
4. Otherwise → human mode

Implementation: Add a `resolveJsonMode(flag:)` function. Apply it in the custom main() before dispatching to subcommands. Propagate via environment or a global.

**Note:** ArgumentParser's `@Flag` for `--json` won't auto-detect TTY. The resolution must happen in the custom main() block before `command.run()`.

### Track 3: Help Text Consistency (P1)

Standardize all command abstracts to consistent style — present tense, lowercase start:

| Command | Current | Target |
|---------|---------|--------|
| doctor | "Check prerequisites and diagnose issues" | OK |
| connect | "Connect to a macOS app" | OK |
| disconnect | "Disconnect from app" | "Disconnect from the connected app" |
| status | "Show connection state" | "Show connection status" |
| snapshot | "Capture element tree with refs" | OK |
| press | "Press element by ref" | OK |
| fill | "Enter text into element by ref" | OK |
| get | "Read element property by ref" | OK |
| find | "Find element by locator" | OK |
| screenshot | "Capture app screenshot" | OK |
| is | "Assert element condition" | OK |
| wait | "Wait for condition or delay" | OK |
| scroll | "Scroll element or direction" | "Scroll by direction or element ref" |
| schema | "Show command schema" | OK |

### Track 4: AGENTS.md Update (P0)

Update `AGENTS.md` to include:
1. **Environment variables** section (table of AGENT_SWIFT_* vars)
2. **Scroll recipe** (up/down + ref-based)
3. **Wait/is recipe** (assertion-based flow)
4. **Full command table** in idempotency section (add `scroll`)
5. **JSON-first usage** section explaining TTY auto-detection
6. **CLAUDE.md snippet** for macOS projects that use agent-swift

### Track 5: Version Bump (P0)

1. Update version to `0.2.0` in `AgentSwift.configuration`
2. Verify `agent-swift --version` shows `0.2.0`

### Track 6: Test Coverage (P0)

Add tests to `AutonomyTests.swift` or create `PolishTests.swift`:

1. Env var precedence: AGENT_SWIFT_TIMEOUT parsed correctly
2. SessionStore respects custom home directory
3. CommandSchema includes all 14 commands
4. Version string is `0.2.0`

**Minimum: 8 new XCTAssert* calls.**

---

## Acceptance Criteria

1. `AGENT_SWIFT_JSON=1 agent-swift status` outputs JSON (no --json flag needed).
2. Non-TTY pipe: `agent-swift status | cat` outputs JSON automatically.
3. `AGENT_SWIFT_TIMEOUT=2000 agent-swift wait exists @e1` uses 2s timeout.
4. `AGENT_SWIFT_HOME=/tmp/test-session agent-swift status` reads session from custom dir.
5. `agent-swift --version` shows `0.2.0`.
6. All 14 commands have consistent help text style.
7. AGENTS.md has environment variables section with all AGENT_SWIFT_* vars.
8. AGENTS.md has scroll and wait/is recipes.
9. AGENTS.md has JSON-first usage section mentioning TTY auto-detection.
10. AGENTS.md has CLAUDE.md snippet section.
11. All 14 commands listed in AGENTS.md idempotency table (scroll included).
12. `swift build` succeeds.
13. `swift test` succeeds with ≥ 59 tests (51 existing + 8 new).
14. All existing tests still pass.
15. Eval phase_complete=yes.

---

## Build Loop Protocol

1. Implement env vars (Track 1). Run eval.
2. Implement TTY-aware JSON (Track 2). Run eval.
3. Fix help text (Track 3). Run eval.
4. Update AGENTS.md (Track 4). Run eval.
5. Version bump (Track 5). Run eval.
6. Add tests (Track 6). Run eval — all gates green.
7. Commit only when green.

---

## Rules

- **Existing tests are sacred**: do not weaken or delete passing tests.
- **Follow established patterns**: use GlobalOptions, Output.printError, Codable result structs.
- **No regressions in snapshot format, exit codes, or --json output.**
- **Keep scope phase-local**: no new commands, no interaction changes.
- **macOS build required**: all changes must compile and test on macOS.
