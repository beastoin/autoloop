import type { WalkerConfig, SnapshotElement } from './types.ts';
import { computeFingerprint, deriveScreenName } from './fingerprint.ts';
import { filterSafe } from './safety.ts';
import { NavigationGraph } from './graph.ts';
import { generateFlows, writeFlows } from './yaml-writer.ts';
import { AgentBridge } from './agent-bridge.ts';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';

interface WalkResult {
  screensFound: number;
  flowsGenerated: number;
  elementsSkipped: number;
  flowFiles: string[];
}

/**
 * Recursive screen walker.
 * Connects to a Flutter app, explores screens by pressing interactive elements,
 * builds a navigation graph, and outputs YAML flow files.
 */
export async function walk(config: WalkerConfig): Promise<WalkResult> {
  const bridge = new AgentBridge(config.agentFlutterPath);
  const graph = new NavigationGraph();
  let totalSkipped = 0;

  // Connect
  log(config, `Connecting...`);
  if (config.appUri) {
    bridge.connect(config.appUri);
  } else if (config.bundleId) {
    bridge.connectBundle(config.bundleId);
  } else {
    throw new Error('Either --app-uri or --bundle-id is required');
  }

  try {
    // Take initial snapshot
    const homeSnapshot = bridge.snapshot();
    const homeFingerprint = computeFingerprint(homeSnapshot.elements);
    const homeName = deriveScreenName(homeSnapshot.elements);
    const homeTypes = homeSnapshot.elements.map(e => e.flutterType || e.type).sort();

    graph.addScreen(homeFingerprint, homeName, homeTypes, homeSnapshot.elements.length);
    log(config, `Home screen: ${homeName} (${homeFingerprint}) — ${homeSnapshot.elements.length} elements`);

    // Filter safe elements
    const [safeElements, skipped] = filterSafe(homeSnapshot.elements, config.blocklist);
    totalSkipped += skipped.length;

    for (const s of skipped) {
      log(config, `  SKIP ${s.element.ref} "${s.element.text}" — ${s.reason}`);
    }

    if (config.dryRun) {
      log(config, `\nDry run — listing elements without pressing:`);
      for (const el of safeElements) {
        log(config, `  SAFE ${el.ref} [${el.type}] "${el.text}"`);
      }
      for (const s of skipped) {
        log(config, `  BLOCKED ${s.element.ref} [${s.element.type}] "${s.element.text}" — ${s.reason}`);
      }
      log(config, `\nSummary: ${safeElements.length} safe, ${skipped.length} blocked`);
      return { screensFound: 1, flowsGenerated: 0, elementsSkipped: totalSkipped, flowFiles: [] };
    }

    // Recursive walk
    await walkScreen(
      bridge, graph, config,
      homeFingerprint, safeElements,
      0, [homeName],
      { skipped: totalSkipped },
    );
    totalSkipped = totalSkipped; // updated via reference tracking

    // Generate YAML flows
    const flows = generateFlows(graph);
    const flowFiles = writeFlows(flows, config.outputDir);

    // Write navigation graph JSON
    const graphPath = join(config.outputDir, '_nav-graph.json');
    writeFileSync(graphPath, JSON.stringify(graph.toJSON(), null, 2));
    flowFiles.push(graphPath);

    log(config, `\n=== Walk complete ===`);
    log(config, `Screens: ${graph.screenCount()}`);
    log(config, `Flows: ${flows.length}`);
    log(config, `Files: ${flowFiles.join(', ')}`);

    return {
      screensFound: graph.screenCount(),
      flowsGenerated: flows.length,
      elementsSkipped: totalSkipped,
      flowFiles,
    };
  } finally {
    try { bridge.disconnect(); } catch { /* ignore disconnect errors */ }
  }
}

async function walkScreen(
  bridge: AgentBridge,
  graph: NavigationGraph,
  config: WalkerConfig,
  currentFingerprint: string,
  elements: SnapshotElement[],
  depth: number,
  breadcrumb: string[],
  counters: { skipped: number },
): Promise<void> {
  if (depth >= config.maxDepth) {
    log(config, `${'  '.repeat(depth)}MAX DEPTH reached at ${breadcrumb.join(' → ')}`);
    return;
  }

  for (const element of elements) {
    const indent = '  '.repeat(depth + 1);
    log(config, `${indent}Press ${element.ref} [${element.type}] "${element.text}"`);

    // Press the element
    try {
      bridge.press(element.ref);
    } catch {
      log(config, `${indent}  FAILED to press ${element.ref}, skipping`);
      continue;
    }

    // Small delay for screen transition
    await sleep(500);

    // Snapshot the result
    let newSnapshot;
    try {
      newSnapshot = bridge.snapshot();
    } catch {
      log(config, `${indent}  FAILED to snapshot after press, pressing back`);
      try { bridge.back(); } catch { /* ignore */ }
      await sleep(300);
      continue;
    }

    const newFingerprint = computeFingerprint(newSnapshot.elements);

    // Same screen? No-op transition
    if (newFingerprint === currentFingerprint) {
      log(config, `${indent}  Same screen (${newFingerprint}) — no-op`);
      continue;
    }

    // New screen discovered
    const newName = deriveScreenName(newSnapshot.elements);
    const newTypes = newSnapshot.elements.map(e => e.flutterType || e.type).sort();
    graph.addScreen(newFingerprint, newName, newTypes, newSnapshot.elements.length);
    graph.addEdge(currentFingerprint, newFingerprint, {
      ref: element.ref,
      type: element.type,
      text: element.text,
    });

    log(config, `${indent}  → ${newName} (${newFingerprint}) — ${newSnapshot.elements.length} elements`);

    // Cycle detection: only recurse into unvisited or low-visit screens
    if (graph.visitCount(newFingerprint) <= 1) {
      const [safeChildren, skippedChildren] = filterSafe(newSnapshot.elements, config.blocklist);
      counters.skipped += skippedChildren.length;

      await walkScreen(
        bridge, graph, config,
        newFingerprint, safeChildren,
        depth + 1, [...breadcrumb, newName],
        counters,
      );
    }

    // Navigate back
    log(config, `${indent}  Back`);
    try {
      bridge.back();
    } catch {
      log(config, `${indent}  FAILED to go back`);
    }
    await sleep(300);

    // Verify we're back on the expected screen
    try {
      const backSnapshot = bridge.snapshot();
      const backFingerprint = computeFingerprint(backSnapshot.elements);
      if (backFingerprint !== currentFingerprint) {
        log(config, `${indent}  WARNING: back landed on ${backFingerprint}, expected ${currentFingerprint}`);
        // Try one more back
        try { bridge.back(); } catch { /* ignore */ }
        await sleep(300);
      }
    } catch {
      // If snapshot fails after back, continue anyway
    }
  }
}

function log(config: WalkerConfig, message: string): void {
  if (config.json) {
    console.log(JSON.stringify({ type: 'log', message }));
  } else {
    console.error(message);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}
