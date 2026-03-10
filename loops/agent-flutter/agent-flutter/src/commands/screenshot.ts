/**
 * screenshot [path] — Capture screenshot via Marionette or platform fallback.
 */
import { writeFileSync } from 'node:fs';
import { VmServiceClient } from '../vm-client.ts';
import { loadSession } from '../session.ts';
import { resolveTransport } from '../transport/index.ts';
import { AgentFlutterError, ErrorCodes } from '../errors.ts';

const HELP = `Usage: agent-flutter screenshot [path]

  Capture screenshot. Default: screenshot.png
  Uses Marionette first, falls back to platform screencap.`;

export async function screenshotCommand(args: string[]): Promise<void> {
  if (args.includes('--help') || args.includes('-h')) {
    console.log(HELP);
    return;
  }

  const outPath = args[0] ?? 'screenshot.png';

  const session = loadSession();
  if (!session) throw new AgentFlutterError(ErrorCodes.NOT_CONNECTED, 'Not connected', 'Run: agent-flutter connect');

  // Try Marionette screenshot first, fall back to platform
  const client = new VmServiceClient();
  await client.connect(session.vmServiceUri);
  try {
    const buf = await client.takeScreenshot();
    if (buf) {
      writeFileSync(outPath, buf);
      console.log(`Screenshot saved: ${outPath}`);
      return;
    }
  } catch {
    // Marionette screenshot not available, fall back
  } finally {
    await client.disconnect();
  }

  // Platform fallback
  const transport = resolveTransport();
  try {
    const raw = transport.screenshot();
    writeFileSync(outPath, raw);
    console.log(`Screenshot saved (via ${transport.platform}): ${outPath}`);
  } catch {
    throw new AgentFlutterError(ErrorCodes.COMMAND_FAILED, 'Failed to capture screenshot via both Marionette and platform tools');
  }
}
