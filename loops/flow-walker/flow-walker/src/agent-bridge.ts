import { execFileSync } from 'node:child_process';
import type { SnapshotElement, ScreenSnapshot } from './types.ts';

/**
 * Thin wrapper around the agent-flutter CLI.
 * All device interaction goes through this bridge.
 */
export class AgentBridge {
  private bin: string;
  private timeout: number;

  constructor(agentFlutterPath: string = 'agent-flutter', timeout: number = 10000) {
    this.bin = agentFlutterPath;
    this.timeout = timeout;
  }

  /** Connect to a Flutter app by VM Service URI */
  connect(uri: string): void {
    this.exec(['connect', uri]);
  }

  /** Connect to a Flutter app by bundle ID */
  connectBundle(bundleId: string): void {
    this.exec(['connect', '--bundle-id', bundleId]);
  }

  /** Disconnect from the current app */
  disconnect(): void {
    this.exec(['disconnect']);
  }

  /** Take a snapshot of interactive elements */
  snapshot(): ScreenSnapshot {
    const raw = this.exec(['snapshot', '-i', '--json']);
    const parsed = JSON.parse(raw);

    // agent-flutter returns { elements: [...] } or an array directly
    const rawElements = Array.isArray(parsed) ? parsed : (parsed.elements || []);

    const elements: SnapshotElement[] = rawElements.map((el: Record<string, unknown>) => ({
      ref: String(el.ref || ''),
      type: String(el.type || ''),
      text: String(el.text || el.label || ''),
      flutterType: el.flutterType ? String(el.flutterType) : undefined,
      enabled: el.enabled !== false,
      bounds: el.bounds as SnapshotElement['bounds'],
    }));

    return { elements, raw };
  }

  /** Press an element by ref */
  press(ref: string): string {
    return this.exec(['press', ref, '--json']);
  }

  /** Navigate back */
  back(): string {
    return this.exec(['back', '--json']);
  }

  /** Get connection status */
  status(): string {
    return this.exec(['status', '--json']);
  }

  private exec(args: string[]): string {
    try {
      const result = execFileSync(this.bin, args, {
        encoding: 'utf8',
        timeout: this.timeout,
        env: { ...process.env, AGENT_FLUTTER_JSON: '1' },
      });
      return result.trim();
    } catch (err: unknown) {
      const error = err as { stderr?: string; message?: string };
      throw new Error(
        `agent-flutter ${args[0]} failed: ${error.stderr || error.message}`,
      );
    }
  }
}
