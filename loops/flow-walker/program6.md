# Phase 6: Agent-friendly run data + app metadata

## Objective

Let AI agents pull structured run data from hosted reports. Add app metadata to flows for landing page context.

## Part A: Agent-friendly run data (high value)

### Architecture

```
flow-walker push <run-dir>
  → uploads report.html (existing)
  → uploads run.json to PUT /runs/:id/data (new)

GET /runs/:id/data → returns run.json
GET /runs/:id (Accept: application/json) → returns run.json
GET /runs/:id (default) → returns report.html
```

### Requirements

**A1: CLI uploads run.json on push**
- After uploading report.html, PUT run.json to `/runs/:id/data`
- Strip local file paths from screenshots/video/log fields (not useful remotely)
- Best-effort: if run.json upload fails, push still succeeds (report was already uploaded)

**A2: Worker serves run data**
- `PUT /runs/:id/data` — stores run.json in R2 at `runs/<id>/run.json`
- `GET /runs/:id/data` — serves run.json from R2
- Content negotiation: `GET /runs/:id` with `Accept: application/json` → run.json
- `GET /runs/:id` default (no Accept or text/html) → report.html (unchanged)

**A3: Stats API enhanced**
- `GET /api/stats` recentRuns includes all metadata (flow name, steps, pass count, app info)

## Part B: App metadata (nice-to-have)

### Requirements

**B1: Flow YAML fields**
- Optional `app` and `app_url` fields in flow header
- Parsed by flow-parser, included in run.json as top-level fields
- Not required — flows without them still work

**B2: Push sends app metadata**
- CLI sends `X-App-Name` / `X-App-URL` headers on push (from run.json)
- Worker stores in stats recentRuns

**B3: Landing page shows app info**
- Recent reports show "flow-name (App Name)" with app_url as link
- If no app metadata, show flow name only (current behavior)

## Acceptance criteria

1. `GET /runs/:id/data` returns run.json with full step data
2. `flow-walker push` uploads both report.html and run.json
3. Agent can `curl .../runs/:id/data | jq '.steps[] | select(.status == "fail")'`
4. `Accept: application/json` on `/runs/:id` returns run.json
5. Flow YAML supports optional `app` and `app_url` fields
6. Landing page shows app name + link for flows that have it
7. All Phase 5 eval gates still pass
8. Typecheck passes, tests > 199

## Hard rules

- Do not break existing push or report functionality
- run.json upload is best-effort (push succeeds even if data upload fails)
- App metadata fields are optional — never required
- Do not upload video, screenshots, or logs to /data (too large)
- Do not add authentication
