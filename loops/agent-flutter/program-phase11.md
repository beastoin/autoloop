# Phase 11: Audit Remediation — Docs, Contracts, Cleanup

## Source
Independent Codex audit (2026-09-04), 5-turn adversarial debate. 10 findings, 2 HIGH / 6 MEDIUM / 2 LOW.

## Fixes

### HIGH
1. **Package identity in README** — Update all install instructions from `agent-flutter-cli` to `@beastoin/agent-flutter`
2. **Regenerate package-lock.json** — Run `npm install` so lock file matches package.json name and version

### MEDIUM
3. **Node engine requirement** — Update `package.json` engines and README to `>=22` (global WebSocket dependency)
4. **README command table** — Add missing commands: `dismiss`, `text`, `diff snapshot`, `--platform` flag
5. **`--adb` → `--native` naming** — Update README to show `--native` as canonical flag name
6. **Remove WIDGET_SUPPORT.md reference** — Remove dead reference from AGENTS.md (file doesn't exist in agent-flutter)
7. **Loop README update** — Update phase count, command count, source file count to current values
8. **`text --json` contract** — Ensure JSON output includes `method` field per phase 10 schema spec

### LOW
9. **`text` error envelope** — Use standard `{code, message, diagnosticId}` error format
10. **Dead code cleanup** — Remove unused `clearSession` import, unused `refKey`, unreachable `ensureAccessibility()`

## Acceptance Criteria
1. README install command says `npm install -g @beastoin/agent-flutter`
2. package-lock.json name matches package.json (`@beastoin/agent-flutter`)
3. package.json engines says `>=22`
4. README command table has ≥19 entries (all current commands)
5. README shows `--native` not `--adb` as primary flag
6. No reference to `WIDGET_SUPPORT.md` in agent-flutter docs
7. Loop README shows current phase number and counts
8. All tests pass (≥75 tests)
9. `npm run typecheck` passes
10. No unused imports flagged by grep for known dead code items

## Target
- Version: 1.7.1 (patch — no behavior changes, only docs + cleanup)
- Tests: ≥75
