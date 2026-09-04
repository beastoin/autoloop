/**
 * Shared reconnection logic for Marionette commands.
 * Connects using the session's stored URI. Does NOT fall back to auto-detect
 * to avoid picking up the wrong URI (e.g., development-service proxy port).
 * If the session URI is stale, the user must run `connect` explicitly.
 */
import { VmServiceClient } from './vm-client.ts';
import { AgentFlutterError, ErrorCodes } from './errors.ts';
import type { SessionData } from './session.ts';

/**
 * Connect a VmServiceClient to the session's stored URI.
 * Returns the connected client.
 * Throws NOT_CONNECTED if the URI is stale — user must re-run `connect`.
 */
export async function connectWithReconnect(session: SessionData): Promise<VmServiceClient> {
  const client = new VmServiceClient();
  try {
    await client.connect(session.vmServiceUri);
    return client;
  } catch {
    throw new AgentFlutterError(
      ErrorCodes.NOT_CONNECTED,
      'Connection failed — app may have restarted',
      'Run: agent-flutter connect',
    );
  }
}
