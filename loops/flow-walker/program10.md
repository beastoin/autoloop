# Phase 10: Desktop App Support (agent-swift)

## Goal
Add agent-swift support to flow-walker so it can test macOS desktop apps alongside mobile Flutter apps, with proper transport abstraction, schema discovery, and agent-friendly design.

## Context
flow-walker currently only works with agent-flutter (mobile). agent-swift provides the same interaction model (snapshot → @ref → action) for macOS desktop apps via Accessibility APIs. Both agents share the same CLI contract: `connect`, `disconnect`, `snapshot -i --json`, `press @ref`, `fill @ref text`, `back`, `scroll`, `text`, `status --json`. Key differences:
- agent-swift uses `label` (not `text`) in snapshot elements
- agent-swift uses `click 960,540` for coordinate taps (not `press 960,540`)
- agent-swift uses `find text X press` (not `text X --press`)
- agent-swift uses `AGENT_SWIFT_JSON=1` env var (not `AGENT_FLUTTER_JSON=1`)
- agent-swift has no ADB — no `adb shell`, no `screenrecord`, no foreground detection via dumpsys
- Desktop foreground: `open -b <bundleId>` to bring to foreground, osascript to check

## Architecture

### AgentType and transport abstraction
- New type: `AgentType = 'flutter' | 'swift'`
- `AgentBridge` constructor takes optional `agentType?: AgentType`
- `detectAgentType(agentPath: string): AgentType` — checks binary name/path
- Platform-specific behaviors abstracted in AgentBridge methods:
  - `exec()` — sets `AGENT_SWIFT_JSON` or `AGENT_FLUTTER_JSON` env
  - `textPress()` — uses `find text X press` for swift, `text X --press` for flutter
  - `bringToForeground()` — uses `open -b` for swift, `adb shell am start` for flutter
  - `isAppInForeground()` — uses osascript for swift, dumpsys for flutter
  - `adbExec()` — no-op for swift (returns false)

### CLI changes
- New `--agent` flag: `--agent flutter|swift` (default: auto-detect from `--agent-path`)
- Rename `--agent-flutter-path` to `--agent-path` (keep old name as alias)
- New env: `FLOW_WALKER_AGENT` — default agent type
- Walk command passes `agentType` to WalkerConfig and AgentBridge

### Schema changes
- Schema version bump to `2.1.0`
- Walk command adds `--agent` flag (type: string, enum: [flutter, swift])
- Walk command adds `--agent-path` flag (replaces `--agent-flutter-path`)
- Record command aware of platform for video skip (no video on desktop)

### Types changes
- `WalkerConfig` gets `agentType: AgentType` and `agentPath: string` (replaces `agentFlutterPath`)
- `RecordInitOptions` gets `platform?: 'mobile' | 'desktop'`

### Package changes
- Bump version to `0.3.0`
- Update description to mention both agent-flutter and agent-swift

## Files to modify
- `src/agent-bridge.ts` — transport abstraction
- `src/types.ts` — new AgentType, WalkerConfig changes
- `src/cli.ts` — new flags, dispatch
- `src/command-schema.ts` — schema version bump, new flags
- `src/walker.ts` — use agentType from config
- `src/record.ts` — platform-aware video
- `package.json` — version bump, description update

## Files to create
- `tests/agent-bridge.test.ts` — transport abstraction tests

## Acceptance criteria (12 gates)

### Transport abstraction
1. AC1: `AgentType` type exported from `types.ts`
2. AC2: `detectAgentType()` exported from `agent-bridge.ts`, returns 'swift' for agent-swift paths
3. AC3: `AgentBridge` constructor accepts `agentType` parameter
4. AC4: `AgentBridge.exec()` sets `AGENT_SWIFT_JSON=1` when agentType is 'swift'
5. AC5: `AgentBridge.textPress()` uses 'find text X press' for swift agent

### CLI and schema
6. AC6: `--agent flutter|swift` flag accepted by walk command
7. AC7: `--agent-path` flag works (replacing `--agent-flutter-path`)
8. AC8: Schema version is `2.1.0` with new agent/agent-path flags in walk
9. AC9: Usage text mentions both agent-flutter and agent-swift

### Quality
10. AC10: Package version is `0.3.0`
11. AC11: TypeScript typecheck passes (`npx tsc --noEmit`)
12. AC12: All tests pass, count >= 290

## What NOT to do
- Do not break existing agent-flutter workflows
- Do not add external dependencies
- Do not modify eval9.sh or earlier eval files
- Do not change exit code semantics
- Do not remove `--agent-flutter-path` (keep as alias)
