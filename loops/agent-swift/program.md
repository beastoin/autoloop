# agent-swift — Phase 1 Program (Core AX CLI)

Build `agent-swift`, a native Swift CLI for AI agents to control any macOS app via Accessibility (AXUIElement), with zero app-side instrumentation.

This phase is limited to the minimum vertical slice:

- `doctor`
- `connect` (`--pid` or `--bundle-id`)
- `status`
- `snapshot` (`-i`, `--json`)
- `press`
- `disconnect`
- session persistence at `~/.agent-swift/session.json`

## Learning Phase: Study Existing Family Contracts

Before implementing, study these references in this repo:

### Loop-level references
- `loops/agent-flutter/README.md` — loop structure, evaluator cadence, publish flow
- `loops/agent-flutter/program.md` — phase framing style and acceptance criteria shape
- `loops/agent-flutter/eval.sh` — build/test/contract/phase gate pattern
- `loops/agent-flutter/CLAUDE.md` — loop contract and immutable-file rules
- `loops/agent-flutter/AGENTS.md` — operating workflow and guardrails

### Build-target references
- `loops/agent-flutter/agent-flutter/AGENTS.md` — canonical workflow, state machine, output shapes
- `loops/agent-flutter/agent-flutter/CLAUDE.md` — architecture + non-regression guardrails

## UX Contract to Preserve

1. Snapshot-first workflow: `connect -> snapshot -> act -> snapshot`.
2. Stable ref format: `@eN [type] "label"` (machine and human friendly).
3. JSON mode for all commands via `--json`.
4. Deterministic exit codes:
   - `0` success
   - `1` assertion false
   - `2` error
5. File-backed session state between commands.

## Build Phase: Native Swift + AXUIElement

Use Swift Package Manager. No Node.js runtime in the CLI itself.

### Core architecture (phase 1 scope)

```text
agent-swift/
├── Package.swift
├── Sources/
│   └── agent-swift/
│       ├── main.swift
│       ├── CLI/
│       │   ├── RootCommand.swift
│       │   └── GlobalOptions.swift
│       ├── Commands/
│       │   ├── DoctorCommand.swift
│       │   ├── ConnectCommand.swift
│       │   ├── DisconnectCommand.swift
│       │   ├── StatusCommand.swift
│       │   ├── SnapshotCommand.swift
│       │   └── PressCommand.swift
│       ├── AX/
│       │   ├── AXClient.swift
│       │   ├── AXTreeWalker.swift
│       │   └── AXAction.swift
│       ├── Session/
│       │   └── SessionStore.swift
│       └── Output/
│           ├── SnapshotFormatter.swift
│           └── JsonEnvelope.swift
└── Tests/
```

### Connection model

- `connect --pid <pid>`: connect to target process AX root.
- `connect --bundle-id <id>`: resolve running app by bundle ID, then connect by PID.
- Store current target in session:
  - `pid`
  - `bundleId` (if known)
  - `connectedAt`

### Session model

Persist to `~/.agent-swift/session.json`:

```json
{
  "pid": 12345,
  "bundleId": "com.apple.TextEdit",
  "connectedAt": "2026-03-09T00:00:00Z",
  "refs": {
    "e1": {"role":"AXButton","label":"Save"}
  },
  "lastSnapshotAt": "2026-03-09T00:00:02Z"
}
```

### `doctor` scope (phase 1)

- Check Accessibility trust (TCC) for current process.
- Report whether target app is running when `--bundle-id` is provided.
- Return actionable fix hints when trust is missing.

### Snapshot format

Human format (must match family style):

```text
@e1 [button] "Save"
@e2 [textfield] "Name"
@e3 [statictext] "Ready"
```

Rules:
- refs are sequential per snapshot (`@e1`, `@e2`, ...).
- `-i` filters to interactive elements only.
- `--json` outputs structured array including `ref`, `type`, `label`, `role`, `identifier`, `enabled`, `focused`, `bounds`.

### `press` scope (phase 1)

- `press @eN` resolves ref from last snapshot and performs default AX press action (`AXPress` or equivalent fallback).
- stale/missing refs must return structured error and exit `2`.

## Phase 1 Acceptance Criteria

1. `agent-swift doctor` reports AX permission status and clear fix when unavailable.
2. `agent-swift connect --pid <pid>` establishes session.
3. `agent-swift connect --bundle-id <id>` resolves running app and establishes session.
4. `agent-swift status` reports connected/disconnected with target metadata.
5. `agent-swift snapshot` prints `@eN [type] "label"` lines.
6. `agent-swift snapshot -i` filters to interactive elements only.
7. `agent-swift snapshot --json` outputs valid JSON.
8. `agent-swift press @e1` attempts action on resolved AX element.
9. `agent-swift disconnect` clears session cleanly.
10. Session persists in `~/.agent-swift/session.json` and is reused across commands.
11. `--help` works for root and each phase-1 command.
12. Exit code contract is respected (`0/1/2`).
13. `swift build` and `swift test` run from package root.

## Eval Rules

Each loop iteration:

1. Implement a minimal scoped change.
2. Run evaluator:
   - `bash loops/agent-swift/eval.sh`
3. Keep only passing iterations; revert failed direction and retry.
4. Preserve deterministic CLI output and stable exit contract.
5. Do not mutate immutable control files during active execution:
   - `program*.md`
   - `eval.sh`
   - `e2e-test.ts` (when added)

## Hard Rules

- Keep scope phase-local (no speculative phase-2+ features in phase 1).
- No app-side instrumentation assumptions: AX only.
- Do not weaken evaluator thresholds to force pass.
- Do not break snapshot/ref format contract.
- Do not change exit-code semantics.
