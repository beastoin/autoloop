/**
 * text [query] [--json] — Extract visible text from the running app.
 *
 * Strategy:
 * 1. UIAutomator dump (Android-only, no session needed)
 * 2. Flutter semantics tree fallback (any platform, needs active session)
 *
 * The fallback handles animated pages where UIAutomator's waitForIdle() hangs,
 * plus iOS where UIAutomator doesn't exist.
 *
 * Exit codes: 0 = success/found, 1 = not found (search mode), 2 = error.
 */
import { resolveTransport } from '../transport/index.ts';
import { extractVisibleTexts } from '../text-parser.ts';
import { parseSemanticsTree, extractSemanticsTexts, type SemanticsTextEntry } from '../semantics-parser.ts';
import { loadSession } from '../session.ts';
import { VmServiceClient } from '../vm-client.ts';
import type { TextEntry } from '../transport/types.ts';

const HELP = `Usage: agent-flutter text [query] [options]

  List all visible text on screen.
  With query: check if text is visible (exit 0=found, 1=not found).

  Sources (tried in order):
    1. UIAutomator accessibility dump (Android, no session needed)
    2. Flutter semantics tree (any platform, needs active session)

  Options:
    --json    JSON output
    --all     Include source/metadata (with --json)`;

export async function textCommand(args: string[]): Promise<void> {
  if (args.includes('--help') || args.includes('-h')) {
    console.log(HELP);
    return;
  }

  const isJson = args.includes('--json') || process.env.AGENT_FLUTTER_JSON === '1';
  const isAll = args.includes('--all');

  // Filter out flags to get the query
  const query = args.filter(a => !a.startsWith('--')).join(' ').trim() || null;

  const transport = resolveTransport();

  // Phase 1: UIAutomator (Android-only, no session needed)
  let uiEntries: TextEntry[] = [];
  if (transport.platform === 'android') {
    uiEntries = transport.dumpText();
  }

  // Phase 2: If UIAutomator empty, try Flutter semantics via VM Service
  let texts: string[];
  let method: 'uiautomator' | 'semantics' = 'uiautomator';
  let semEntries: SemanticsTextEntry[] = [];

  if (uiEntries.length > 0) {
    texts = extractVisibleTexts(uiEntries);
  } else {
    const fallback = await trySemanticsFallback();
    if (fallback) {
      texts = fallback.texts;
      semEntries = fallback.entries;
      method = 'semantics';
    } else {
      texts = [];
    }
  }

  // Search mode
  if (query) {
    const lowerQuery = query.toLowerCase();
    const matches = texts.filter(t => t.toLowerCase().includes(lowerQuery));
    const found = matches.length > 0;

    if (isJson) {
      console.log(JSON.stringify({ found, matches, method }));
    } else {
      if (found) {
        console.log(`Found: ${matches.join(', ')}`);
      } else {
        console.log(`Not found: "${query}"`);
      }
    }

    if (!found) process.exit(1);
    return;
  }

  // List mode
  if (isJson) {
    if (isAll) {
      if (method === 'uiautomator') {
        console.log(JSON.stringify({ method, entries: uiEntries }));
      } else {
        console.log(JSON.stringify({ method, entries: semEntries }));
      }
    } else {
      console.log(JSON.stringify(texts));
    }
  } else {
    if (method === 'semantics' && texts.length > 0) {
      console.log('(via Flutter semantics tree)');
    }
    if (texts.length === 0) {
      console.log('(no text found — is a Flutter app running with an active session?)');
    }
    for (const t of texts) {
      console.log(t);
    }
  }
}

async function trySemanticsFallback(): Promise<{ texts: string[]; entries: SemanticsTextEntry[] } | null> {
  const session = loadSession();
  if (!session) return null;

  let client: VmServiceClient | null = null;
  try {
    client = new VmServiceClient();
    await client.connect(session.vmServiceUri);
    const dump = await client.dumpSemanticsTree();
    if (!dump) return null;
    const entries = parseSemanticsTree(dump);
    const texts = extractSemanticsTexts(entries);
    return texts.length > 0 ? { texts, entries } : null;
  } catch {
    return null;
  } finally {
    if (client) {
      try { await client.disconnect(); } catch { /* ignore */ }
    }
  }
}
