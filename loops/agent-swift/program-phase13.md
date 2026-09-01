# Phase 14: Frame Processing (resize, dedup, crop)

## Objective

Extend `record frame` with processing flags so agents spend fewer tokens reviewing full-resolution screenshots. Currently agents extract 1206×2622 frames and send them to LLMs at full size. Adding resize, crop, and dedup reduces payload 60-90% per frame without manual ffmpeg pipelines.

## Origin

mio (Design Engineer, VoxBoard UX audit workflow) — feature request from real-world usage.

## Commands

### `record frame` — new flags

#### `--max-width <pixels>`
Downscale the extracted frame so its width ≤ max-width, preserving aspect ratio.
- Uses `sips -Z <max-width>` (macOS native, no extra deps)
- If frame width is already ≤ max-width, no resize
- Applied after extraction, before output
- Default: no resize (full resolution)
- Example: `record frame --at 4 --max-width 800` → 800×1740 from 1206×2622

#### `--crop <x>,<y>,<w>,<h>`
Crop the extracted frame to a region before output.
- Uses `sips --cropToHeightWidth <h> <w> --cropOffset <y> <x>` or ffmpeg crop filter
- Coordinates are in the frame's pixel space (after extraction, before resize)
- If crop region exceeds frame bounds, clamp to valid area
- Example: `record frame --at 4 --crop 0,200,1206,800` → captures status area only

#### `--dedup-threshold <0.0-1.0>`
Skip extraction if the frame would be near-identical to the previous extracted frame.
- Compares against the last extracted frame's path (tracked in session as `lastFramePath`)
- Uses pixel-level comparison: resize both to 64×64 thumbnail, compute mean absolute difference
- If similarity ≥ threshold → return `{"skipped": true, "reason": "duplicate", "similarity": 0.97}`
- Default: disabled (always extract)
- Example: `record frame --at 4 --dedup-threshold 0.95`

### `record frames` — new subcommand (batch extraction)
Extract multiple frames from a video in one call.
- `--video <path>` — source video (required, or from session)
- `--every <seconds>` — extract one frame every N seconds (e.g. `--every 2.0`)
- `--at <t1>,<t2>,<t3>` — extract at specific timestamps
- `--max-width <pixels>` — resize all frames
- `--dedup-threshold <0.0-1.0>` — skip near-duplicate frames
- `--output-dir <dir>` — where to write frames (default: session dir)
- Returns JSON array of extracted frames with paths, timestamps, skipped status
- Example: `record frames --video /tmp/rec.mp4 --every 2.0 --max-width 800 --dedup-threshold 0.90`

## Session Changes

- Add `lastFramePath: String?` to SessionData — tracks last extracted frame for dedup comparison

## Acceptance Criteria

1. `record frame --max-width 800` produces a frame ≤ 800px wide
2. `record frame --max-width 800` on a 600px-wide frame is a no-op (no upscale)
3. `record frame --crop 0,0,400,400` produces a 400×400 frame
4. `record frame --crop` with out-of-bounds coords clamps to valid area
5. `record frame --dedup-threshold 0.95` returns `skipped: true` for near-identical frames
6. `record frame --dedup-threshold 0.95` extracts normally when frames differ
7. `record frame` with no processing flags behaves exactly like v0.8.2 (backward compat)
8. `record frames --every 2.0` extracts frames at 0, 2, 4, 6... up to video duration
9. `record frames --at 1.0,5.0,10.0` extracts exactly those 3 timestamps
10. `record frames` returns JSON array with per-frame status
11. `--max-width` + `--crop` can be combined: crop first, then resize
12. All new flags appear in `schema` output
13. All new flags appear in `record frame --help`
14. `record frames` appears as a subcommand of `record`
15. Error messages follow agent-friendly contract (code + message + hint)
16. ≥ 15 new tests for frame processing
17. ≥ 195 total tests
18. Version 0.9.0

## Design Constraints

- Use macOS-native `sips` for resize/crop where possible (no new deps)
- Fall back to ffmpeg filter flags when sips can't express the operation
- dedup comparison must be fast (thumbnail-based, not full-resolution pixel comparison)
- All processing happens in-process after frame extraction — no separate pipeline
- `--video` flag is required on `record frames` (consistent with v0.8.2 solid design)
