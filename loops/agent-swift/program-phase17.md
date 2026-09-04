# Phase 17: Fix Recording + Interaction Bugs

## Source
Field bug reports from sui (2026-09-04) during VoxBoard testing on Mac Mini M4, iOS 26.2 Simulator.

## Problem
1. **Recording auto-stops**: Any agent-swift command (screenshot, press, click) during active recording kills the recording silently. `record stop` then returns NO_RECORDING error and video has no moov atom (corrupt). Standalone `record start → sleep → stop` works fine.
2. **Low simulator framerate**: Recording in simulator mode captures at 0.07-0.13 fps (~2 frames per 15-second recording). Essentially a slideshow.
3. **Press vs custom gestures**: `agent-swift press` (AX action) does not trigger SwiftUI `onTapGesture` handlers. Only triggers standard `Button` action. `click` with coordinates also fails in simulator mode.

## Acceptance Criteria

### AC1: Commands don't kill recordings
- `record start` → `press @e1` → `screenshot /tmp/test.png` → `record stop` produces valid video
- The recording process must survive concurrent agent-swift commands
- Root cause: likely the recording subprocess getting killed or its file descriptors getting clobbered

### AC2: Simulator recording framerate ≥ 1fps
- 15-second recording in simulator mode produces ≥ 15 frames
- If screencapture-based recording can't achieve this, switch to simctl io recordVideo or ffmpeg screen capture

### AC3: Click coordinates work in simulator mode
- `click x y` in simulator mode must send events to the correct coordinates
- For AX-inaccessible elements (custom gesture recognizers), click-by-coordinates must be the fallback
- Test: connect --sim → snapshot → click at element center coordinates → verify action occurred

## Implementation Notes
- Recording is in `Sources/agent-swift/main.swift` (record command) and likely uses screencapture or ffmpeg
- Simulator tap goes through IdbBridge (`Sources/AgentSwiftLib/Simulator/IdbBridge.swift`)
- Click coordinates in sim mode may need to go through idb tap instead of AX

## Out of Scope
- Adding new gesture types (long-press, drag)
- Mirror mode recording fixes (separate issue)
