# Phase 10: iPhone Mirroring Bridge

## Goal

Add real iOS device control through macOS iPhone Mirroring (`com.apple.ScreenContinuity`). The approach is coordinate-based: capture the mirror window screenshot, click/drag at iOS coordinates mapped to macOS screen positions. No AX element discovery of iOS content — the mirror window is opaque.

## Tracks

### Track 1: MirrorBridge module

New file: `Sources/AgentSwiftLib/Mirror/MirrorBridge.swift`

- `MirrorError` enum with codes: `MIRROR_NOT_RUNNING`, `MIRROR_WINDOW_NOT_FOUND`, `MIRROR_CLICK_FAILED`, `MIRROR_SCREENSHOT_FAILED`, `MIRROR_SWIPE_FAILED`
- `MirrorWindowInfo` struct: `windowOrigin`, `contentOrigin`, `contentSize`, `iosScreenSize` (logical), `scale` factor
- `MirrorBridge` struct:
  - `static func isRunning() -> Bool` — check if iPhone Mirroring app is running
  - `static func launch() throws` — open iPhone Mirroring app if not running
  - `func windowInfo() throws -> MirrorWindowInfo` — find mirror window via AX, calculate content area (subtract title bar/chrome)
  - `func screenshot(to path: String) throws` — capture mirror window content via CGWindowListCreateImage
  - `func tap(x: Double, y: Double) throws` — map iOS point to macOS screen point, CGEvent click
  - `func swipe(fromX: Double, fromY: Double, toX: Double, toY: Double, duration: Double?) throws` — CGEvent mouse down + move + up
  - `static func iosPointToScreen(_ point: CGPoint, windowInfo: MirrorWindowInfo) -> CGPoint` — coordinate mapping

### Track 2: Screenshot via mirror

- Capture mirrored iOS content using `CGWindowListCreateImage` on the mirror window
- Save as PNG to specified path
- Return dimensions in JSON output

### Track 3: Click via mirror

- Map iOS logical coordinates to macOS screen coordinates using MirrorWindowInfo scale factor
- CGEvent mouseDown + mouseUp at the mapped position
- Activate iPhone Mirroring window before clicking

### Track 4: Swipe/drag via mirror

- CGEvent mouse drag: mouseDown at start, mouseMoved through path, mouseUp at end
- Support directional swipe (up/down/left/right) using same directionToSwipeCoords pattern as IdbBridge
- Duration parameter controls swipe speed

### Track 5: Connect --mirror mode

- `connect --mirror` flag to connect to iPhone Mirroring
- Session stores `mirrorMode: true` in session.json
- `doctor` checks mirror app running status in mirror mode
- `screenshot` captures mirror window in mirror mode
- `click x y` maps iOS coordinates and clicks via CGEvent in mirror mode
- `scroll up/down/left/right` swipes via CGEvent drag in mirror mode
- `status` shows mirror mode info

### Track 6: Tests

- `MirrorTests.swift` with >= 15 assertions
- Test coordinate mapping (iosPointToScreen)
- Test MirrorError codes
- Test MirrorWindowInfo scale calculation
- Test directionToSwipeCoords for mirror mode
- Test isRunning detection logic

## Acceptance criteria

1. `MirrorBridge.swift` exists in `Sources/AgentSwiftLib/Mirror/`
2. `connect --mirror` connects to iPhone Mirroring and saves mirror session
3. `screenshot` captures mirrored iOS content via CGWindowListCreateImage
4. `click x y` maps iOS coordinates to macOS screen and clicks via CGEvent
5. `scroll up/down/left/right` performs swipe gestures via CGEvent drag
6. `doctor` checks mirror prerequisites in mirror mode
7. `status` shows mirror mode when connected via mirror
8. Version bumped to 0.5.0
9. `MirrorTests.swift` exists with >= 15 assertions
10. All tests pass (>= 110 total)
11. All prior phase gates continue to pass
12. JSON output contract maintained for all commands in mirror mode
