/**
 * back [--dry-run] — Navigate back (ADB keyevent on Android, swipe-from-edge on iOS).
 * If keyboard is showing, dismisses keyboard first and warns.
 */
import { resolveTransport } from '../transport/index.ts';

export async function backCommand(args?: string[]): Promise<void> {
  const isDryRun = args?.includes('--dry-run') || process.env.AGENT_FLUTTER_DRY_RUN === '1';
  const transport = resolveTransport();

  if (isDryRun) {
    console.log(JSON.stringify({ dryRun: true, command: 'back', device: transport.deviceId, platform: transport.platform }));
    return;
  }

  // Check if keyboard is visible — if so, dismiss it instead of navigating
  const keyboardShowing = transport.isKeyboardShowing();
  if (keyboardShowing) {
    transport.dismissKeyboard();
    console.log(JSON.stringify({
      action: 'back',
      keyboardDismissed: true,
      navigated: false,
      hint: 'Keyboard was dismissed. Run back again to navigate.',
    }));
    return;
  }

  transport.keyevent('back');
  console.log(JSON.stringify({
    action: 'back',
    keyboardDismissed: false,
    navigated: true,
  }));
}
