# Phase 13: Screen Video Recording

## Objective

Add screen video recording capability to agent-swift so agents can:
1. Start recording when connecting to a device/app
2. Extract video frames at any timestamp during or after recording
3. Stop recording and get the video file
4. Use recordings for verification, evidence, and debugging

## Commands

### `record start`
Start a screen recording session.
- Returns: session ID, start timestamp, video path
- Simulator mode: `xcrun simctl io <udid> recordVideo --codec h264 --force <path>`
- Desktop/Mirror mode: `screencapture -v <path>`
- Stores recording metadata in session store
- Only one recording at a time per session
- `--json` returns structured output

### `record stop`
Stop the active recording session.
- Returns: video path, duration, file size
- Sends SIGINT to the recording process
- Waits for video finalization
- Updates session with recording info
- `--json` returns structured output

### `record frame --at <seconds>`
Extract a frame from the recording at a specific timestamp.
- `--at 4.0` extracts the frame at the 4th second
- Uses `ffmpeg -ss <time> -i <video> -frames:v 1 <output.png>`
- During active recording: uses `screenshot` for live capture (video not finalized yet)
- After stop: extracts from finalized video at exact timestamp
- `--output <path>` to specify output path (default: auto-generated in session dir)
- Returns: frame image path, timestamp, source (live/video)
- `--json` returns structured output

### `record status`
Show the current recording state.
- Returns: active/inactive, session ID, start time, elapsed time, video path
- `--json` returns structured output

## Acceptance Criteria

1. `record start` begins recording and returns session info in JSON
2. `record stop` stops recording and returns video metadata in JSON
3. `record frame --at <seconds>` extracts frame at specified timestamp
4. `record status` shows recording state
5. All 4 subcommands appear in `record --help`
6. All subcommands support `--json` flag
7. All subcommands follow exit code contract (0/1/2)
8. Recording works in simulator mode (simctl recordVideo)
9. Recording works in desktop mode (screencapture -v)
10. Only one active recording at a time — `record start` when recording active returns error
11. `record stop` when no recording active returns error
12. `record frame --at <time>` when recording stopped extracts from finalized video
13. RecordingSession stored in session store with pid, path, startTime
14. RecordingTests.swift with ≥ 15 assertions
15. Version bumped to 0.8.0
16. Total tests ≥ 165 (155 existing + 10 new minimum)
17. `record` appears in schema output
18. ffmpeg availability checked (graceful error if missing)

## Version

0.8.0

## Test Count Target

≥ 165
