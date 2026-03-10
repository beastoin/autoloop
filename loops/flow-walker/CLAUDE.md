# CLAUDE.md — flow-walker loop

Instructions for Claude Code instances working in the flow-walker build loop.

## Loop location

- Loop workspace: `loops/flow-walker/`
- Build target: `loops/flow-walker/flow-walker/`
- Ground truth: `~/omi/omi-sora/app/e2e/flows/*.yaml` (sora's 20 reference flows)

## Build and test

```bash
cd loops/flow-walker/flow-walker
npm install
npm test
npx tsc --noEmit
```

```bash
# Phase evaluator (from repo root)
bash loops/flow-walker/eval.sh
```

## Loop contract

3 immutable files control each phase:

1. `program*.md` — requirements and acceptance criteria
2. `eval.sh` — pass/fail gate
3. Ground truth comparison against sora's reference flows

Do not modify these files during an active loop iteration.

## Runtime model

- Language/runtime: TypeScript (ESM), Node.js 22+
- Transport: shells out to `agent-flutter` CLI (must be in PATH)
- Device: Android phone with running Flutter app connected via ADB
- Output: YAML flow files + JSON navigation graph

## Key design decisions

- **agent-flutter as abstraction**: flow-walker never touches VM Service directly.
  All device interaction goes through `agent-flutter connect/snapshot/press/back`.
- **Fingerprint by structure, not content**: screen identity uses element
  types and counts, ignoring text (which is dynamic).
- **Safety first**: blocklist keywords prevent pressing destructive elements.
- **Depth-limited recursion**: default max-depth 5 prevents infinite exploration.

## Common pitfalls

- Running without agent-flutter in PATH
- Running against an app not in a logged-in state (Phase 1 assumes normal setup)
- Modifying eval.sh during active loop
- Testing without a real device connected

## If blocked

Report: (1) blocker, (2) why it blocks, (3) exact next action needed.
