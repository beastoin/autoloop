# agent-flutter Phase 9: Cross-Platform Support (iOS + Android)

## Problem

agent-flutter is Android-only. All device interaction commands (press coordinates,
back, home, screenshot, scroll, swipe, dismiss, doctor) use ADB directly. Flutter
apps run on both iOS and Android — agent-flutter should work on both.

The Marionette/VM Service layer is already platform-agnostic. Only the device
transport layer (ADB) needs abstraction.

## Architecture

### Platform transport abstraction

Introduce a `DeviceTransport` interface that encapsulates all platform-specific
device operations. Two implementations: `AdbTransport` (Android) and
`IosTransport` (iOS simulator + physical device).

```typescript
interface DeviceTransport {
  // Identity
  platform: 'android' | 'ios';
  deviceId: string;

  // Input
  tap(x: number, y: number): void;
  swipe(x1: number, y1: number, x2: number, y2: number, durationMs: number): void;
  keyevent(key: 'back' | 'home'): void;

  // Query
  screenshot(): Buffer;
  getScreenSize(): { width: number; height: number };
  getDensity(): number;

  // VM Service discovery
  detectVmServiceUri(): string | null;
  portForward(port: number): void;

  // Dialog (Android-specific, iOS returns no-op)
  detectDialog(): { present: boolean; window: string };
  dismissDialog(): boolean;

  // Doctor checks
  checkToolInstalled(): { ok: boolean; message: string };
  listDevices(): string[];
}
```

### Platform detection

Auto-detect platform from device ID format:
- `emulator-*` or serial number → Android (ADB)
- UUID or `booted` → iOS simulator (xcrun simctl)
- UDID (40-char hex or `00008...`) → iOS physical device (idb/devicectl)

Override via `--platform android|ios` flag or `AGENT_FLUTTER_PLATFORM` env var.

### iOS tooling

Simulator:
- `xcrun simctl` — boot, screenshot, keyevent, openurl
- `xcrun simctl io <device> screenshot` — capture screenshot
- VM Service URI: parse from `flutter run` stdout or `xcrun simctl spawn log`
- Port forwarding: not needed (simulator shares host network)
- Home: `xcrun simctl keyevent <device> home`
- No back button equivalent — use swipe-from-edge or app-level navigation

Physical device:
- `idb` (Facebook's iOS Development Bridge) or `xcrun devicectl`
- `iproxy` from libimobiledevice for port forwarding
- `idb tap`, `idb swipe`, `idb screenshot`

### Command changes

| Command | Android | iOS Simulator | iOS Device |
|---------|---------|---------------|------------|
| press x y | `adb shell input tap` | `xcrun simctl io tap` | `idb tap` |
| back | keyevent 4 | swipe-from-left-edge | swipe-from-left-edge |
| home | keyevent 3 | `simctl keyevent home` | `idb home` |
| screenshot | `adb shell screencap` | `simctl io screenshot` | `idb screenshot` |
| scroll dir | `adb shell input swipe` | `simctl io swipe` | `idb swipe` |
| swipe | `adb shell input swipe` | `simctl io swipe` | `idb swipe` |
| dismiss | `dumpsys window` + back | no-op (iOS handles differently) | no-op |
| doctor | `adb version/devices` | `xcrun simctl list` | `idb list-targets` |
| auto-detect | `adb logcat` | flutter run stdout | `idevicesyslog` |
| density | `adb shell wm density` | device model lookup | device model lookup |
| screen size | hardcoded → `adb shell wm size` | `simctl io` | `idb describe` |

### Hardcoded values to fix

- Screen dimensions: replace 1080x1920 with dynamic `getScreenSize()`
- Center coords in scroll.ts: derive from screen size
- Density fallback 2.625: per-platform defaults (iOS: 2x/3x based on device)
- Device ID default: per-platform (`emulator-5554` for Android, `booted` for iOS sim)

## Implementation plan

### Step 1: DeviceTransport interface + AdbTransport

Extract all ADB calls into `src/transport/adb.ts` implementing `DeviceTransport`.
No behavior change — pure refactor of existing Android code.

### Step 2: Transport resolution

Add `resolveTransport()` in `src/transport/index.ts` that picks ADB or iOS
based on device ID format, `--platform` flag, or env var.

### Step 3: IosSimulatorTransport

Implement `src/transport/ios-simulator.ts` using `xcrun simctl`.

### Step 4: IosDeviceTransport (stretch)

Implement `src/transport/ios-device.ts` using `idb` or `xcrun devicectl`.

### Step 5: Update all commands

Replace direct ADB calls in all command files with `transport.method()` calls.
Fix hardcoded screen dimensions.

### Step 6: Update docs, schema, help text

- Remove "Android" from command descriptions (now cross-platform)
- Add `--platform` flag to schema
- Update AGENTS.md, README.md
- Update doctor checks for iOS tooling

## Acceptance Criteria

- [ ] `DeviceTransport` interface defined in `src/transport/types.ts`
- [ ] `AdbTransport` implements all methods (extracted from current code)
- [ ] `IosSimulatorTransport` implements all methods via `xcrun simctl`
- [ ] Platform auto-detected from device ID or `--platform` flag
- [ ] `agent-flutter press 540 1200` works on both Android and iOS simulator
- [ ] `agent-flutter back` works on both (swipe-from-edge on iOS)
- [ ] `agent-flutter home` works on both
- [ ] `agent-flutter screenshot` works on both
- [ ] `agent-flutter swipe` works on both
- [ ] `agent-flutter doctor` checks correct tooling per platform
- [ ] Screen dimensions queried dynamically (no more hardcoded 1080x1920)
- [ ] Existing Android behavior unchanged (no regressions)
- [ ] All tests pass
- [ ] Help text and schema updated to reflect cross-platform support

## Non-goals

- Windows/Linux desktop Flutter support
- Web Flutter support
- Auto-installing iOS tooling (just detect and report in doctor)
- Physical iOS device support in this phase (stretch goal)
