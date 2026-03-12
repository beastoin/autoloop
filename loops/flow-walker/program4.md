# Phase 4: Hosted reports — `flow-walker push`

## Objective

Add `flow-walker push <run-dir>` command that uploads a report to Cloudflare R2 and returns a shareable URL. One command, one file, one URL.

## Architecture

```
flow-walker push <run-dir>
  → generates report.html (if not already present)
  → uploads to R2: flow-walker-runs/<run-id>/report.html
  → returns URL: https://<domain>/runs/<run-id>

Cloudflare Worker (GET /runs/:id)
  → serves report.html from R2
```

## Requirements

### R1: CLI `push` command
- `flow-walker push <run-dir>` — uploads report and returns URL
- Generates report.html first if run-dir has run.json but no report.html
- Uses run ID from run.json as the storage key
- Prints URL to stdout (human mode: formatted, JSON mode: `{"url", "id", "expiresAt"}`)
- Exit codes: 0 = success, 2 = error

### R2: Cloudflare Worker
- `GET /runs/:id` — serves report.html from R2
- `POST /runs` — accepts report.html upload, stores in R2
- Simple rate limiting (100 uploads/day per IP)
- CORS headers for browser access
- Returns JSON response with URL and expiry

### R3: Storage
- R2 bucket: flow-walker-runs
- Key format: `runs/<run-id>/report.html`
- 30-day TTL via R2 lifecycle rules (or Worker-based expiry)
- Single file per run (report.html has embedded video/screenshots)

### R4: CLI integration
- `push` appears in `flow-walker schema` output
- Input validation: run-dir must exist, must contain run.json
- Structured errors (FlowWalkerError) for upload failures
- Env var: `FLOW_WALKER_API_URL` for custom server URL

### R5: No auth, no billing
- Anonymous uploads — no accounts, no API keys for users
- No billing in v1
- Rate limit by IP only

## Acceptance criteria

1. `flow-walker push ./run-output/<id>/` uploads and returns a URL
2. URL serves the self-contained HTML report in a browser
3. `flow-walker push --json` returns `{"url", "id", "expiresAt"}`
4. `flow-walker schema` includes push command
5. Worker deployed to Cloudflare
6. All existing tests still pass (189+)
7. New tests for push command logic
8. Typecheck passes

## Hard rules

- Do not add external runtime dependencies to the CLI
- Do not require user auth or API keys
- Report.html is the ONLY file uploaded (no separate video/screenshot files)
- All uploads are anonymous
- Follow autoloop phase-gated flow
