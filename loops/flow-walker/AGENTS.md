# AGENTS.md — flow-walker

## What this project does

`flow-walker` automatically maps a Flutter app's navigation structure by
connecting via `agent-flutter`, recursively pressing interactive elements,
and generating YAML flow files describing every reachable screen and transition.

## How to use it

```bash
# Dry run — see what would be explored without pressing anything
flow-walker walk --app-uri ws://127.0.0.1:12345/ws --dry-run

# Walk one level deep
flow-walker walk --bundle-id com.friend.ios.dev --max-depth 1 --output-dir ./flows/

# Full recursive walk with custom blocklist
flow-walker walk --app-uri ws://... --max-depth 5 --blocklist "delete,sign out,reset"
```

## Architecture

```
src/
  cli.ts           — CLI entry point
  walker.ts        — recursive screen walker (core algorithm)
  fingerprint.ts   — screen identity from element types (not text)
  graph.ts         — directed navigation graph with cycle detection
  safety.ts        — blocklist evaluation before pressing elements
  yaml-writer.ts   — YAML flow file generation (matches sora's format)
  agent-bridge.ts  — thin wrapper: shells out to agent-flutter CLI
```

## Key concepts

- **Screen fingerprint**: hash of element types + counts (ignores dynamic text)
- **Navigation graph**: directed graph of screens connected by element presses
- **Blocklist**: keywords that prevent pressing destructive elements
- **Ground truth**: sora's 20 manually-created flows for comparison
