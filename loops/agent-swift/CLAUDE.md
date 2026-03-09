# CLAUDE.md — agent-swift loop

Instructions for Claude Code instances working in the agent-swift build loop.

## Loop location

- Loop workspace: `loops/agent-swift/`
- Build target: `loops/agent-swift/agent-swift/`
- Product repo: `beastoin/agent-swift` (publish target only)

## Build and test

```bash
cd loops/agent-swift/agent-swift
swift build
swift test
```

```bash
# Phase evaluator (from repo root)
bash loops/agent-swift/eval.sh
```

## Runtime model

- Language/runtime: native Swift (Swift Package Manager)
- Platform: macOS 13+
- Transport: `AXUIElement` (local Accessibility IPC)
- Session file: `~/.agent-swift/session.json`
- CLI contract: deterministic output, `--json`, exit codes `0/1/2`

## Loop contract

3 immutable files control each phase:

1. `program*.md` — requirements and acceptance criteria
2. `eval.sh` — pass/fail gate (build/test/contract/phase)
3. `e2e-test.ts` or `e2e-test.sh` — real runtime validation (when present)

Do not modify these files during an active loop iteration. Only modify when starting a new phase definition.

## Phase detection (eval.sh)

`eval.sh` detects phase using file sentinels:

- phase 1: default (`program.md`)
- phase 2: `program-phase2.md` exists
- phase 3: `program-phase3.md` exists

## AXUIElement implementation notes

- AX requires Accessibility trust (TCC) for the process running `agent-swift`.
- AX tree shape differs from SwiftUI/AppKit view hierarchies; rely on role/title/value/identifier, not internal view types.
- Snapshot refs (`@eN`) are ephemeral and can become stale after mutating actions.
- `press`/`fill`/other mutations should require a recent snapshot and clear errors on stale refs.

## Common pitfalls

- Missing TCC permission causes silent action failures unless checked in `doctor`.
- Treating AX identifier/title/value as always present.
- Breaking JSON envelope shape between commands.
- Breaking exit-code contract (`0/1/2`).
- Editing control files during loop execution.

## Publish rule

autoloop is the source of truth. Do not edit `beastoin/agent-swift` directly.
After a phase completes: copy build target -> product repo -> release binary/Homebrew.

## If blocked

Report: (1) blocker, (2) why it blocks, (3) exact next action needed.
