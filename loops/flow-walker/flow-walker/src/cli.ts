#!/usr/bin/env node --experimental-strip-types
import { parseArgs } from 'node:util';
import type { WalkerConfig } from './types.ts';
import { walk } from './walker.ts';

const DEFAULT_BLOCKLIST = 'delete,sign out,remove,reset,unpair,logout,clear all';

function printUsage(): void {
  console.log(`flow-walker — Automatic app flow extraction via agent-flutter

Usage:
  flow-walker walk [options]

Options:
  --app-uri <uri>         VM Service URI (ws://...)
  --bundle-id <id>        Connect by bundle ID
  --max-depth <n>         Max navigation depth (default: 5)
  --output-dir <dir>      Output directory for YAML flows (default: ./flows/)
  --blocklist <words>     Comma-separated blocklist keywords
  --agent-flutter-path    Path to agent-flutter binary (default: agent-flutter)
  --json                  Machine-readable progress output
  --dry-run               Snapshot and plan without pressing
  --skip-connect          Use existing agent-flutter session (don't reconnect)
  --help                  Show this help
`);
}

async function main(): Promise<void> {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      'app-uri': { type: 'string' },
      'bundle-id': { type: 'string' },
      'max-depth': { type: 'string', default: '5' },
      'output-dir': { type: 'string', default: './flows/' },
      'blocklist': { type: 'string', default: DEFAULT_BLOCKLIST },
      'agent-flutter-path': { type: 'string', default: 'agent-flutter' },
      'json': { type: 'boolean', default: false },
      'dry-run': { type: 'boolean', default: false },
      'skip-connect': { type: 'boolean', default: false },
      'help': { type: 'boolean', default: false },
    },
  });

  if (values.help || positionals[0] !== 'walk') {
    printUsage();
    process.exit(positionals[0] === 'walk' ? 1 : 0);
  }

  if (!values['app-uri'] && !values['bundle-id'] && !values['skip-connect']) {
    console.error('Error: either --app-uri, --bundle-id, or --skip-connect is required');
    process.exit(2);
  }

  const config: WalkerConfig = {
    appUri: values['app-uri'],
    bundleId: values['bundle-id'],
    maxDepth: parseInt(values['max-depth']!, 10),
    outputDir: values['output-dir']!,
    blocklist: values['blocklist']!.split(',').map(s => s.trim()),
    json: values['json']!,
    dryRun: values['dry-run']!,
    skipConnect: values['skip-connect']!,
    agentFlutterPath: values['agent-flutter-path']!,
  };

  try {
    const result = await walk(config);

    if (config.json) {
      console.log(JSON.stringify({ type: 'result', ...result }));
    } else {
      console.log(`\nDone. ${result.screensFound} screens, ${result.flowsGenerated} flows, ${result.elementsSkipped} skipped.`);
    }

    process.exit(0);
  } catch (err) {
    if (config.json) {
      console.log(JSON.stringify({ type: 'error', message: String(err) }));
    } else {
      console.error(`Error: ${err}`);
    }
    process.exit(2);
  }
}

main();
