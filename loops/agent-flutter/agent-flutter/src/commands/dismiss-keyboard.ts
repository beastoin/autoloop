/**
 * dismiss-keyboard — Dismiss soft keyboard (Android: KEYCODE_ESCAPE, iOS: no-op).
 */
import { resolveTransport } from '../transport/index.ts';

export async function dismissKeyboardCommand(args: string[]): Promise<void> {
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`Usage: agent-flutter dismiss-keyboard

  Dismiss the soft keyboard if showing.
  On Android: sends KEYCODE_ESCAPE (doesn't navigate, only closes keyboard).
  On iOS: no-op.`);
    return;
  }

  const transport = resolveTransport();
  const wasShowing = transport.isKeyboardShowing();

  if (wasShowing) {
    transport.dismissKeyboard();
  }

  console.log(JSON.stringify({
    dismissed: wasShowing,
    platform: transport.platform,
  }));
}
