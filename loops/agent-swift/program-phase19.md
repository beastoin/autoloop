# Phase 19: vphone iOS VM Support

## Source
Manager request via finn (2026-09-04). ivy needs agent-swift integration with vphone iOS VM for VoxBoard keyboard testing.

## Background
vphone-cli runs iOS VMs on Mac Mini. A VM named "voxtest" is already running. It exposes a unix domain socket for UI automation:
- Socket: `/Users/beastoinagents/.vphone/VMs/<vmname>/vphone.sock`
- Protocol: newline-delimited JSON over unix socket. One connection per command.
- No accessibility API — VM has no AX tree. Snapshot/find work via screenshot + OCR.

## Protocol
Send JSON + newline, read response JSON until newline or EOF, disconnect.

Commands:
- Screenshot: `{"t":"screenshot","path":"/tmp/s.png"}`
- Tap: `{"t":"tap","x":645,"y":1400}` (pixel coords 0-1290 x 0-2796, 3x retina)
- Swipe: `{"t":"swipe","x1":100,"y1":1800,"x2":100,"y2":800,"ms":300}`
- Key: `{"t":"key","name":"home"}` (home|power|volup|voldown)

Every response includes `{"ok": true/false}`. Screenshot response includes `"image"` field with base64 JPEG.

Reference implementation: `~/bin/vphone-ctl` (Python) and `~/bin/vphone_ctl.py`

## Acceptance Criteria

### AC1: connect --vphone
- `agent-swift connect --vphone` auto-detects running VM (scan ~/.vphone/VMs/*/vphone.sock)
- `agent-swift connect --vphone voxtest` connects to named VM
- Session stores `vphoneVM` field and socket path
- `status` shows mode: "vphone" with VM name

### AC2: VphoneBridge module
- New `Sources/AgentSwiftLib/Vphone/VphoneBridge.swift`
- Connects to unix socket, sends JSON command, reads response, disconnects
- Methods: `screenshot(to:)`, `tap(x:y:)`, `swipe(...)`, `key(name:)`
- Coordinates: pixel space (0-1290 × 0-2796 for 3x retina)
- Logical point conversion: divide by 3.0 for agent-facing coordinates (430×932)
- Socket error handling with structured error codes

### AC3: Command integration
- `screenshot` in vphone mode → VphoneBridge.screenshot
- `click x y` in vphone mode → convert logical points to pixels (×3), VphoneBridge.tap
- `swipe` in vphone mode → convert + VphoneBridge.swipe
- `press @ref` in vphone mode → resolve ref bounds center → tap at pixel coords
- `back` in vphone mode → VphoneBridge.key("home") (no back button in iOS)

### AC4: Snapshot via screenshot
- `snapshot` in vphone mode takes a screenshot (no AX tree available)
- Returns a single ref `@e0` representing the full screen with bounds
- Hint in output: "vphone mode — no element tree, use click x y for coordinates"
- Interactive snapshot (`-i`) saves screenshot file

### AC5: Unit tests
- VphoneBridge socket message serialization
- Coordinate conversion (logical ↔ pixel)
- Session vphone mode detection
- Auto-detect VM directory scanning
- At least 10 new test assertions

## Implementation Notes
- Pattern after SimulatorBridge/MirrorBridge: new module in AgentSwiftLib
- SessionData needs: `vphoneVM: String?`, `vphoneSocket: String?`
- `isVphoneMode` computed property
- `isConnected` must include vphone check
- Unix domain socket: `Foundation` has socket support via `FileHandle` or use `Darwin.connect`
- Screen dimensions: 1290×2796 pixels = 430×932 logical points at 3x
- Connect validation: check socket file exists and is connectable

## Out of Scope
- OCR-based find (future phase — would enable find text on vphone)
- Recording in vphone mode
- Multiple simultaneous VMs
