/**
 * IosSimTransport — iOS Simulator transport via xcrun simctl.
 */
import { execSync } from 'node:child_process';
import { readFileSync, unlinkSync } from 'node:fs';
import type { DeviceTransport, ScreenSize, DialogInfo, ToolCheck } from './types.ts';

export class IosSimTransport implements DeviceTransport {
  readonly platform = 'ios' as const;
  readonly deviceId: string;

  constructor(deviceId: string) {
    this.deviceId = deviceId;
  }

  private simctl(cmd: string, opts?: { timeout?: number; maxBuffer?: number }): string {
    return execSync(`xcrun simctl ${cmd}`, {
      encoding: 'utf8',
      timeout: opts?.timeout ?? 5000,
      maxBuffer: opts?.maxBuffer,
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
  }

  tap(x: number, y: number): void {
    // simctl doesn't have tap — use simctl io for newer Xcode, or AppleScript
    // For Xcode 16+: xcrun simctl io <device> tap <x> <y> is not available
    // Fallback: use simctl's sendpushnotification workaround or Python/swift helper
    // Most reliable: use the Dart VM Service (Marionette) for taps on iOS simulator
    // For coordinate taps, we use the private simctl extensions or fbsimctl
    try {
      // Try idb first (Facebook's iOS Development Bridge)
      execSync(`idb ui tap ${x} ${y} --udid ${this.deviceId}`, {
        encoding: 'utf8',
        timeout: 5000,
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    } catch {
      // Fallback: simctl io (Xcode 26+)
      try {
        this.simctl(`io ${this.deviceId} tap ${x} ${y}`);
      } catch {
        throw new Error('Cannot tap on iOS simulator. Install idb: brew install idb-companion');
      }
    }
  }

  swipe(x1: number, y1: number, x2: number, y2: number, durationMs: number): void {
    try {
      execSync(`idb ui swipe ${x1} ${y1} ${x2} ${y2} --duration ${durationMs / 1000} --udid ${this.deviceId}`, {
        encoding: 'utf8',
        timeout: durationMs + 5000,
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    } catch {
      try {
        this.simctl(`io ${this.deviceId} swipe ${x1} ${y1} ${x2} ${y2}`);
      } catch {
        throw new Error('Cannot swipe on iOS simulator. Install idb: brew install idb-companion');
      }
    }
  }

  keyevent(key: 'back' | 'home'): void {
    if (key === 'home') {
      // xcrun simctl keyevent works for home
      this.simctl(`keyevent ${this.deviceId} home`);
    } else {
      // iOS has no back button — simulate swipe from left edge
      const screen = this.getScreenSize();
      this.swipe(5, screen.height / 2, screen.width / 2, screen.height / 2, 300);
    }
  }

  screenshot(): Buffer {
    const tmpPath = `/tmp/agent-flutter-ios-screenshot-${Date.now()}.png`;
    this.simctl(`io ${this.deviceId} screenshot ${tmpPath}`);
    const buf = readFileSync(tmpPath);
    try { unlinkSync(tmpPath); } catch { /* cleanup */ }
    return buf;
  }

  getScreenSize(): ScreenSize {
    // Query from device info
    try {
      const info = this.simctl(`list devices -j`);
      const parsed = JSON.parse(info);
      // Find our device in the runtime lists
      for (const runtime of Object.values(parsed.devices) as any[][]) {
        for (const dev of runtime) {
          if (dev.udid === this.deviceId || (this.deviceId === 'booted' && dev.state === 'Booted')) {
            // Device type determines screen size
            const deviceType = dev.deviceTypeIdentifier ?? '';
            if (deviceType.includes('iPhone-16-Pro-Max') || deviceType.includes('iPhone-15-Pro-Max')) {
              return { width: 1290, height: 2796 };
            }
            if (deviceType.includes('iPhone-16-Pro') || deviceType.includes('iPhone-15-Pro')) {
              return { width: 1179, height: 2556 };
            }
            if (deviceType.includes('iPhone-16') || deviceType.includes('iPhone-15')) {
              return { width: 1170, height: 2532 };
            }
            if (deviceType.includes('iPhone-SE')) {
              return { width: 750, height: 1334 };
            }
            if (deviceType.includes('iPad-Pro-13')) {
              return { width: 2048, height: 2732 };
            }
            if (deviceType.includes('iPad-Pro-11') || deviceType.includes('iPad-Air')) {
              return { width: 1668, height: 2388 };
            }
          }
        }
      }
    } catch {
      // fallback
    }
    // Default: iPhone 15 Pro logical pixels * 3x
    return { width: 1179, height: 2556 };
  }

  getDensity(): number {
    // iOS simulators report in points — Flutter uses logical pixels
    // Most modern iPhones are 3x, SE is 2x
    try {
      const info = this.simctl(`list devices -j`);
      const parsed = JSON.parse(info);
      for (const runtime of Object.values(parsed.devices) as any[][]) {
        for (const dev of runtime) {
          if (dev.udid === this.deviceId || (this.deviceId === 'booted' && dev.state === 'Booted')) {
            const dt = dev.deviceTypeIdentifier ?? '';
            if (dt.includes('iPhone-SE') || dt.includes('iPhone-8')) return 2.0;
            if (dt.includes('iPad-mini') || dt.includes('iPad-Air-2')) return 2.0;
          }
        }
      }
    } catch {
      // fallback
    }
    return 3.0;
  }

  detectVmServiceUri(): string | null {
    // On iOS simulator, VM Service URI comes from flutter run stdout
    // Check AGENT_FLUTTER_LOG first, then try simctl spawn log
    // The host URI is directly accessible (simulator shares host network)
    return null; // Handled by auto-detect.ts via AGENT_FLUTTER_LOG
  }

  portForward(_port: number): void {
    // iOS simulator shares host network — no port forwarding needed
  }

  detectDialog(): DialogInfo {
    // iOS doesn't have Android-style system dialogs blocking Flutter
    // iOS permission dialogs are handled by the OS and appear as system alerts
    // We can't detect them via simctl — return not present
    return { present: false, window: 'n/a (iOS)' };
  }

  dismissDialog(): boolean {
    // Try to dismiss any iOS system alert by tapping common button locations
    // or sending home + reopen. For now, return false as iOS handles differently.
    return false;
  }

  checkToolInstalled(): ToolCheck {
    try {
      execSync('xcrun simctl help', { encoding: 'utf-8', timeout: 5000, stdio: 'pipe' });
      return { ok: true, message: 'Xcode Simulator tools installed' };
    } catch {
      return { ok: false, message: 'xcrun simctl not found. Install Xcode and Command Line Tools' };
    }
  }

  listDevices(): string[] {
    try {
      const output = this.simctl('list devices -j');
      const parsed = JSON.parse(output);
      const devices: string[] = [];
      for (const runtime of Object.values(parsed.devices) as any[][]) {
        for (const dev of runtime) {
          if (dev.state === 'Booted') {
            devices.push(dev.udid);
          }
        }
      }
      return devices;
    } catch {
      return [];
    }
  }
}
