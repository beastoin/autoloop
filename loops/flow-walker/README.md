# Loop: flow-walker

Autonomous build loop for [`flow-walker`](https://github.com/beastoin/flow-walker) — a CLI that auto-explores Flutter apps, executes YAML flows, and generates HTML reports. Built on [agent-flutter](https://github.com/beastoin/agent-flutter).

## Status

**Phase 2 complete.** 126 tests, 25/25 eval gates, 12 source modules.

| Phase | Objective | Result |
|-------|-----------|--------|
| 1 Core | BFS explorer, fingerprinting, safety, YAML generation | `walk` command, 43 tests, 19/19 eval |
| 2 Execution | Flow executor, video/screenshots, HTML report | `run` + `report` commands, 126 tests, 25/25 eval |
| 3 Interaction | scroll-reveal, fill exploration, iOS support | Next |
| 4 Agent-grade | --json, structured errors, schema, CI mode, AGENTS.md polish | Planned |

## Design principles (from agent-flutter)

flow-walker follows the same phase-gated, agent-friendly model as agent-flutter:

1. **agent-flutter as transport** — flow-walker never touches VM Service directly. All device interaction through agent-flutter CLI
2. **Fingerprint by structure, not content** — screen identity uses element types/counts, ignoring dynamic text
3. **Safety first** — blocklist keywords prevent pressing destructive elements
4. **Self-contained output** — HTML reports embed video + screenshots as base64
5. **YAML as contract** — flows are the portable interface between exploration and execution
6. **Phase-gated quality** — each phase has immutable program.md + eval.sh. No eval modification during active loops

### Phase progression model (agent-flutter pattern)

```
agent-flutter:                    flow-walker:
1 Core: snapshot + press      →   1 Core: walk (BFS explorer)
2 Interaction: fill + scroll  →   2 Execution: run + report
3 Autonomy: wait + is         →   3 Interaction: scroll + fill + iOS
4 Polish: --json + schema     →   4 Agent-grade: --json + errors + CI
```

Each phase adds one capability layer. No broad refactors. Eval gates prevent regression.

## Layout

```text
loops/flow-walker/
├── program.md              # Phase 1 objectives
├── program2.md             # Phase 2 objectives
├── eval.sh                 # Phase 1 evaluator (immutable)
├── eval2.sh                # Phase 2 evaluator (immutable)
├── README.md               # this file
├── CLAUDE.md               # agent instructions for this loop
├── e2e-results/            # E2E run artifacts (run10, run11)
└── flow-walker/            # build target → published to npm as flow-walker-cli
    ├── src/                # 12 TypeScript modules
    ├── tests/              # 9 test files, 126 tests
    ├── AGENTS.md           # agent-facing workflow guide
    ├── CLAUDE.md           # publish-repo instructions
    ├── README.md           # public README
    ├── LICENSE             # MIT
    └── package.json
```

## Running evaluators

```bash
# Phase 1 evaluator
bash loops/flow-walker/eval.sh

# Phase 2 evaluator (includes Phase 1 regression)
bash loops/flow-walker/eval2.sh
```

## E2E validation

```bash
# Run on connected device (requires agent-flutter + ADB)
cd loops/flow-walker/flow-walker
node --experimental-strip-types src/cli.ts walk --app-uri ws://... --output-dir ./e2e/
node --experimental-strip-types src/cli.ts run flows/tab-navigation.yaml --output-dir ./e2e-run/
node --experimental-strip-types src/cli.ts report ./e2e-run/
```

## Publish flow

After a phase completes:
1. Copy `flow-walker/` → `beastoin/flow-walker` product repo
2. `npm publish` from product repo
