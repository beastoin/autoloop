# Phase 18: Simulator Recording Quality + Click Coordinates

## Source
Remaining items from sui's field report (2026-09-04). Phase 17 fixed AC1 (recording-safe screenshot). This phase addresses AC2 + AC3.

## Problem
1. **Low simulator framerate**: Recording in simulator mode via screencapture captures at 0.07-0.13 fps (~2 frames per 15-second recording). Essentially a slideshow. `simctl io recordVideo` should produce smooth video but may conflict with screenshot commands.
2. **Click coordinates in simulator mode**: `click x y` with raw iOS coordinates does not reliably hit the target element when custom SwiftUI gesture recognizers are used. `press` (AX action) works for standard Button but not for `onTapGesture` handlers.

## Acceptance Criteria

### AC1: Simulator recording ≥ 5fps
- `record start` in simulator mode produces video with ≥ 5fps over a 10-second recording
- Implementation should prefer `simctl io recordVideo` (native, smooth) for simulator mode
- Now that phase 17 prevents screenshot from killing recording via idb fallback, simctl io recordVideo is safe to use
- Verify: `ffprobe -v error -select_streams v -show_entries stream=r_frame_rate <video>` reports ≥ 5/1

### AC2: Coordinate click works for custom gesture elements
- `click 200 400` in simulator mode delivers tap event to the correct iOS coordinates
- Both idb tap and CGEvent fallback must map coordinates correctly
- For idb: coordinates are native iOS logical points (no transform needed)
- For CGEvent: coordinates must go through windowInfo scale transform
- Test: connect --sim → click at known element center → verify element receives tap

### AC3: Unit tests for coordinate mapping
- Add test verifying `iosPointToScreen` transform is correct for standard device sizes
- Add test verifying `directionToSwipeCoords` produces valid coordinate ranges
- At least 5 new test assertions

## Implementation Notes
- Simulator recording is in `RecordStartCommand` in main.swift — already uses `simctl io recordVideo` for sim mode
- The low framerate may actually come from `screencapture -v` being used in mirror/desktop mode, not sim mode
- If sim mode recording IS already using simctl io recordVideo and still gets low fps, investigate codec/resolution settings
- Click coordinate path: ref → bounds center → idb tap (iOS logical points) → CGEvent fallback (screen transform)
- IdbBridge.tap sends `idb ui tap --udid <udid> <x> <y>` — verify these are logical points, not physical pixels

## Out of Scope
- New gesture types (long-press, drag, pinch)
- Mirror mode recording improvements
- Desktop mode recording improvements
