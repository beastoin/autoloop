# Phase 14: Rename agent-flow → agent-flow

## Problem
The name "agent-flow" doesn't align with the `agent-*` naming convention used by our other tools (agent-flutter, agent-swift). Renaming to `agent-flow` makes the tool family consistent and discoverable.

## Scope

### 1. Package identity
- npm package name: `agent-flow-cli` → `agent-flow-cli`
- Binary name: `agent-flow` → `agent-flow`
- Version: bump to `0.6.0` (minor bump for rename)

### 2. Source code
- All user-facing strings: CLI name, help text, error messages, error class name
- `AgentFlowError` → `AgentFlowError`
- `FLOW_WALKER_*` constants/env vars → `AGENT_FLOW_*`
- Import paths remain internal (no rename needed for file paths within src/)

### 3. Autoloop structure
- Directory: `loops/agent-flow/` → `loops/agent-flow/`
- Build target: `loops/agent-flow/agent-flow/` → `loops/agent-flow/agent-flow/`
- All CLAUDE.md, AGENTS.md, README.md references updated
- Root CLAUDE.md project map updated

### 4. Worker
- wrangler.toml: name `agent-flow` → `agent-flow`
- Worker code: any "agent-flow" string references

### 5. Documentation
- All README.md, CLAUDE.md, SKILL.md files
- Reference docs (record-pipeline.md, event-types.md)
- Program and eval files (historical — update headers/comments only, not logic)

### 6. Product repo
- ~/agent-flow → ~/agent-flow (local clone)
- GitHub repo rename: beastoin/agent-flow → beastoin/agent-flow (manual by manager)

## Out of scope
- GitHub repo rename (needs manager to do via GitHub settings)
- npm publish under new name (separate step after merge)
- Worker subdomain change (separate Cloudflare config)
- Other team members' memory/docs (they update on their own)

## Acceptance criteria
1. `agent-flow --help` works and shows "agent-flow" not "agent-flow"
2. `agent-flow --version` returns `0.6.0`
3. No source file contains "agent-flow" as a user-facing string (internal file paths in loops/ don't count)
4. No source file contains "AgentFlowError" — replaced by "AgentFlowError"
5. package.json name is "agent-flow-cli", bin key is "agent-flow"
6. All tests pass (≥336 tests)
7. autoloop root CLAUDE.md references "agent-flow" not "agent-flow"
8. wrangler.toml name is "agent-flow"
9. Directory structure: `loops/agent-flow/agent-flow/`

## Target
- Version: 0.6.0
- Tests: ≥336 (no test count regression)
