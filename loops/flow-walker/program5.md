# Phase 5: Landing page with live metrics

## Objective

Replace the `GET /` JSON status response with an HTML landing page showing live product metrics. Stats update on every `flow-walker push`. No frontend framework, no external deps.

## Architecture

```
flow-walker push <run-dir>
  → uploads report.html to R2
  → updates stats.json in R2 (increment counters)
  → returns URL

GET /
  → reads stats.json from R2
  → renders landing page HTML with live numbers
  → links to recent reports
```

## Requirements

### R1: Stats tracking
- `stats.json` stored in R2, updated atomically on every POST /runs
- Fields: totalRuns, totalReports, totalBytes, lastPushAt
- Recent runs list: last 10 pushes with {id, uploadedAt, sizeBytes}
- Stats survive Worker restarts (persisted in R2, not in-memory)

### R2: Landing page (GET /)
- Self-contained HTML (inline CSS, no external resources)
- Hero: headline + subheadline with value proposition
- Live metrics row: total reports pushed, total data served, last push time
- Recent reports: clickable links to last 10 pushed reports
- Pipeline section: walk → run → report → push
- Footer: npm install command, GitHub link, MIT license
- Mobile-responsive
- Fast: < 50KB page size

### R3: Metrics are real
- All numbers come from stats.json (computed from actual pushes)
- No hardcoded or fake metrics
- "Last updated" timestamp shows when stats were last computed
- GET /api/stats returns stats.json as JSON (for programmatic access)

### R4: Push still works
- POST /runs continues to work exactly as before
- Additionally updates stats.json after successful upload
- No breaking changes to push response format
- Stats update is best-effort (push succeeds even if stats update fails)

### R5: No new dependencies
- Landing page is pure HTML/CSS rendered by the Worker
- No React, no Tailwind CDN, no external fonts
- Stats stored in same R2 bucket as reports

## Acceptance criteria

1. `GET /` returns HTML landing page (not JSON)
2. Page shows live metrics from stats.json
3. Metrics update after each `flow-walker push`
4. Recent reports section links to real hosted reports
5. `GET /api/stats` returns raw stats JSON
6. All Phase 4 eval gates still pass
7. Page loads in < 1s, weighs < 50KB
8. Mobile-responsive layout

## Hard rules

- Do not add external dependencies or CDN links
- Do not hardcode metrics — all numbers from stats.json
- Do not break existing push functionality
- Stats update must not block the push response
