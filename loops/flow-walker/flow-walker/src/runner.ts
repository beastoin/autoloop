// Flow executor: runs YAML flows via agent-flutter

import { join, dirname } from 'node:path';
import { writeFileSync, existsSync } from 'node:fs';
import type { Flow, FlowStep, SnapshotElement } from './types.ts';
import { parseFlowFile } from './flow-parser.ts';
import { AgentBridge } from './agent-bridge.ts';
import { generateRunId, type RunResult, type StepResult } from './run-schema.ts';
import { screenshot as captureScreenshot, startRecording, stopRecording, startLogcat, stopLogcat, getDeviceName, ensureDir } from './capture.ts';

export interface RunOptions {
  outputDir: string;
  noVideo?: boolean;
  noLogs?: boolean;
  json?: boolean;
  agentFlutterPath?: string;
  flowFilePath?: string; // original flow file path (for resolving setup/ directory)
}

/** Execute a flow and produce a RunResult */
export async function runFlow(flow: Flow, options: RunOptions): Promise<RunResult> {
  const bridge = new AgentBridge(options.agentFlutterPath ?? 'agent-flutter');
  const runId = generateRunId();

  // Append run ID to output dir so multiple runs don't overwrite each other
  const outputDir = join(options.outputDir, runId);
  ensureDir(outputDir);

  const device = getDeviceName();
  const startedAt = new Date().toISOString();
  const t0 = Date.now();
  const steps: StepResult[] = [];

  // Start video recording
  let videoHandle: ReturnType<typeof startRecording> | null = null;
  if (!options.noVideo) {
    try {
      videoHandle = startRecording();
    } catch { /* warn but continue */ }
  }

  // Start logcat
  let logHandle: ReturnType<typeof startLogcat> | null = null;
  if (!options.noLogs) {
    try {
      logHandle = startLogcat();
    } catch { /* warn but continue */ }
  }

  // Check prerequisites before running steps
  if (flow.prerequisites && flow.prerequisites.length > 0) {
    const preCheck = checkPrerequisites(flow.prerequisites, bridge);
    if (!preCheck.met) {
      // Try to resolve by running setup flow
      let setupResolved = false;
      if (preCheck.failed && options.flowFilePath) {
        setupResolved = await tryRunSetupFlow(preCheck.failed, options.flowFilePath, bridge, options);
      }

      if (!setupResolved) {
        // Skip entire flow — prerequisites not met and no setup flow available
        for (let i = 0; i < flow.steps.length; i++) {
          steps.push({
            index: i,
            name: flow.steps[i].name,
            action: getStepAction(flow.steps[i]),
            status: 'skip',
            timestamp: Date.now() - t0,
            duration: 0,
            elementCount: 0,
            error: `prerequisite not met: ${preCheck.failed}`,
          });
        }

        if (!options.json) {
          console.log(`  ✗ Prerequisites not met: ${preCheck.failed}`);
          for (const s of steps) {
            console.log(`  ○ Step ${s.index + 1}: ${s.name} [skip]`);
          }
        }

        // Skip to cleanup (video/logcat/write result)
        const duration = Date.now() - t0;
        let videoPath: string | undefined;
        if (videoHandle) {
          const localVideo = join(outputDir, 'recording.mp4');
          if (stopRecording(videoHandle, localVideo)) videoPath = 'recording.mp4';
        }
        let logPath: string | undefined;
        if (logHandle) {
          const logLines = stopLogcat(logHandle);
          if (logLines.length > 0) {
            writeFileSync(join(outputDir, 'device.log'), logLines.join('\n'));
            logPath = 'device.log';
          }
        }
        const runResult: RunResult = {
          id: runId,
          flow: flow.name,
          ...(flow.app ? { app: flow.app } : {}),
          ...(flow.appUrl ? { appUrl: flow.appUrl } : {}),
          device,
          startedAt,
          duration,
          result: 'fail',
          steps,
          video: videoPath,
          log: logPath,
        };
        writeFileSync(join(outputDir, 'run.json'), JSON.stringify(runResult, null, 2));
        return runResult;
      }

      if (!options.json) {
        console.log(`  ✓ Setup flow resolved prerequisite: ${preCheck.failed}`);
      }
    }
  }

  // Execute each step
  let bailedAt = -1; // index of step that caused bail, -1 = no bail
  for (let i = 0; i < flow.steps.length; i++) {
    // If a prior step failed, skip remaining steps
    if (bailedAt >= 0) {
      steps.push({
        index: i,
        name: flow.steps[i].name,
        action: getStepAction(flow.steps[i]),
        status: 'skip',
        timestamp: Date.now() - t0,
        duration: 0,
        elementCount: 0,
        error: `skipped: step ${bailedAt + 1} failed`,
      });
      if (!options.json) {
        console.log(`  ○ Step ${i + 1}: ${flow.steps[i].name} [skip] (step ${bailedAt + 1} failed)`);
      }
      continue;
    }

    const step = flow.steps[i];
    const stepStart = Date.now();
    const timestamp = stepStart - t0;

    try {
      const result = await executeStep(step, bridge, outputDir, i + 1);
      steps.push({
        ...result,
        index: i,
        timestamp,
        duration: Date.now() - stepStart,
      });
    } catch (err) {
      const snapshot = await safeSnapshot(bridge);
      steps.push({
        index: i,
        name: step.name,
        action: getStepAction(step),
        status: 'fail',
        timestamp,
        duration: Date.now() - stepStart,
        elementCount: snapshot.length,
        error: String(err),
      });
    }

    const lastStep = steps[steps.length - 1];
    if (!options.json) {
      const icon = lastStep.status === 'pass' ? '✓' : lastStep.status === 'fail' ? '✗' : '○';
      console.log(`  ${icon} Step ${i + 1}: ${lastStep.name} [${lastStep.status}] (${lastStep.duration}ms, ${lastStep.elementCount} elements)`);
    }

    // Bail on failure — except for non-navigation actions that don't affect screen state
    if (lastStep.status === 'fail') {
      const action = lastStep.action;
      const safeToContinue = action === 'back' || action === 'screenshot' || action === 'assert';
      if (!safeToContinue) {
        bailedAt = i;
      }
    }
  }

  const duration = Date.now() - t0;

  // Stop video
  let videoPath: string | undefined;
  if (videoHandle) {
    const localVideo = join(outputDir, 'recording.mp4');
    if (stopRecording(videoHandle, localVideo)) {
      videoPath = 'recording.mp4';
    }
  }

  // Stop logcat
  let logPath: string | undefined;
  if (logHandle) {
    const logLines = stopLogcat(logHandle);
    if (logLines.length > 0) {
      const localLog = join(outputDir, 'device.log');
      writeFileSync(localLog, logLines.join('\n'));
      logPath = 'device.log';
    }
  }

  const overallResult = steps.every(s => s.status !== 'fail') ? 'pass' as const : 'fail' as const;

  const runResult: RunResult = {
    id: runId,
    flow: flow.name,
    ...(flow.app ? { app: flow.app } : {}),
    ...(flow.appUrl ? { appUrl: flow.appUrl } : {}),
    device,
    startedAt,
    duration,
    result: overallResult,
    steps,
    video: videoPath,
    log: logPath,
  };

  // Write run.json
  const runJsonPath = join(outputDir, 'run.json');
  writeFileSync(runJsonPath, JSON.stringify(runResult, null, 2));

  return runResult;
}

/** Execute a single step */
async function executeStep(
  step: FlowStep,
  bridge: AgentBridge,
  outputDir: string,
  stepNum: number,
): Promise<StepResult> {
  const action = getStepAction(step);
  let elements = await safeSnapshot(bridge);

  // Execute the action
  if (step.press) {
    if (step.press.text) {
      // Text-based press via UIAutomator (works on system UI)
      const ok = bridge.textPress(step.press.text);
      if (!ok) {
        return {
          index: 0,
          name: step.name,
          action,
          status: 'fail',
          timestamp: 0,
          duration: 0,
          elementCount: elements.length,
          error: `Text press target not found: "${step.press.text}"`,
        };
      }
      await delay(1500);
      elements = await safeSnapshot(bridge);
    } else {
      const target = resolvePress(step.press, elements);
      if (target) {
        await bridge.press(target.ref);
        await delay(1500); // wait for transition
        elements = await safeSnapshot(bridge);
      } else {
        return {
          index: 0, // filled by caller
          name: step.name,
          action,
          status: 'fail',
          timestamp: 0,
          duration: 0,
          elementCount: elements.length,
          error: `Could not resolve press target: ${JSON.stringify(step.press)}`,
        };
      }
    }
  } else if (step.scroll) {
    await bridge.scroll(step.scroll);
    await delay(1000);
    elements = await safeSnapshot(bridge);
  } else if (step.fill) {
    const fillValue = substituteEnvVars(step.fill.value);
    if (step.fill.focused) {
      // Type into currently focused field (no text matching)
      const ok = bridge.textFillFocused(fillValue);
      if (!ok) {
        return {
          index: 0,
          name: step.name,
          action,
          status: 'fail',
          timestamp: 0,
          duration: 0,
          elementCount: elements.length,
          error: 'Failed to fill focused field',
        };
      }
      await delay(500);
      elements = await safeSnapshot(bridge);
    } else if (step.fill.text) {
      // Text-based fill via UIAutomator (works on system UI)
      const ok = bridge.textFill(step.fill.text, fillValue);
      if (!ok) {
        return {
          index: 0,
          name: step.name,
          action,
          status: 'fail',
          timestamp: 0,
          duration: 0,
          elementCount: elements.length,
          error: `Text fill target not found: "${step.fill.text}"`,
        };
      }
      await delay(500);
      elements = await safeSnapshot(bridge);
    } else {
      const target = resolveFill(step.fill, elements);
      if (target) {
        await bridge.fill(target.ref, fillValue);
        await delay(500);
        elements = await safeSnapshot(bridge);
      } else {
        return {
          index: 0, // filled by caller
          name: step.name,
          action,
          status: 'fail',
          timestamp: 0,
          duration: 0,
          elementCount: elements.length,
          error: `Could not resolve fill target: ${JSON.stringify(step.fill)}`,
        };
      }
    }
  } else if (step.back) {
    await bridge.back();
    await delay(1500);
    elements = await safeSnapshot(bridge);
  } else if (step.adb) {
    const adbCommand = substituteEnvVars(step.adb);
    const ok = bridge.adbExec(adbCommand);
    if (!ok) {
      return {
        index: 0,
        name: step.name,
        action,
        status: 'fail',
        timestamp: 0,
        duration: 0,
        elementCount: elements.length,
        error: `ADB command failed: ${adbCommand}`,
      };
    }
    await delay(2000); // ADB commands often need time (app restart, clear data)
    elements = await safeSnapshot(bridge);
  }

  // Wait step (explicit delay, e.g. for OAuth redirects)
  if (step.wait) {
    await delay(step.wait * 1000);
    elements = await safeSnapshot(bridge);
  }

  // Take screenshot
  let screenshotPath: string | undefined;
  if (step.screenshot) {
    const filename = `step-${stepNum}-${step.screenshot}.png`;
    const fullPath = join(outputDir, filename);
    if (captureScreenshot(fullPath)) {
      screenshotPath = filename;
    }
  }

  // Check assertions
  let status: 'pass' | 'fail' = 'pass';
  let assertion: StepResult['assertion'];

  if (step.assert) {
    assertion = {};
    if (step.assert.interactive_count) {
      const actual = elements.length;
      const min = step.assert.interactive_count.min;
      assertion.interactive_count = { min, actual };
      if (actual < min) status = 'fail';
    }
    if (step.assert.bottom_nav_tabs) {
      const navTabs = elements.filter(e =>
        e.flutterType === 'InkWell' && e.bounds && e.bounds.y > 780
      );
      const actual = navTabs.length;
      const min = step.assert.bottom_nav_tabs.min;
      assertion.bottom_nav_tabs = { min, actual };
      if (actual < min) status = 'fail';
    }
    if (step.assert.has_type) {
      const searchType = step.assert.has_type.type.toLowerCase();
      const matching = elements.filter(e =>
        e.type === searchType || e.flutterType?.toLowerCase().includes(searchType)
      );
      const actual = matching.length;
      const min = step.assert.has_type.min ?? 1;
      assertion.has_type = { type: step.assert.has_type.type, min, actual };
      if (actual < min) status = 'fail';
    }
    if (step.assert.text_visible || step.assert.text_not_visible) {
      // Fetch all visible text from UIAutomator accessibility layer
      const screenTexts = bridge.text();
      const dumpEmpty = screenTexts.length === 0;

      if (step.assert.text_visible) {
        const missing: string[] = [];
        const found: string[] = [];
        for (const query of step.assert.text_visible) {
          const lowerQuery = query.toLowerCase();
          const match = screenTexts.find(t => t.toLowerCase().includes(lowerQuery));
          if (match) {
            found.push(query);
          } else {
            missing.push(query);
            status = 'fail';
          }
        }
        assertion.text_visible = {
          expected: step.assert.text_visible, found, missing,
          ...(dumpEmpty ? { warning: 'UIAutomator dump returned empty (animated page?)' } : {}),
        };
      }

      if (step.assert.text_not_visible) {
        const unexpected: string[] = [];
        const absent: string[] = [];
        for (const query of step.assert.text_not_visible) {
          const lowerQuery = query.toLowerCase();
          const match = screenTexts.find(t => t.toLowerCase().includes(lowerQuery));
          if (match) {
            unexpected.push(query);
            status = 'fail';
          } else {
            absent.push(query);
          }
        }
        assertion.text_not_visible = { expected_absent: step.assert.text_not_visible, absent, unexpected };
      }
    }
  }

  return {
    index: 0, // filled by caller
    name: step.name,
    action,
    status,
    timestamp: 0, // filled by caller
    duration: 0,  // filled by caller
    elementCount: elements.length,
    screenshot: screenshotPath,
    assertion,
  };
}

/** Resolve a press target from the snapshot */
export function resolvePress(
  press: NonNullable<FlowStep['press']>,
  elements: SnapshotElement[],
): SnapshotElement | null {
  if (press.ref) {
    return elements.find(e => e.ref === press.ref) ?? null;
  }

  if (press.bottom_nav_tab !== undefined) {
    const navItems = elements
      .filter(e => e.flutterType === 'InkWell' && e.bounds && e.bounds.y > 780)
      .sort((a, b) => (a.bounds?.x ?? 0) - (b.bounds?.x ?? 0));
    return navItems[press.bottom_nav_tab] ?? null;
  }

  if (press.type) {
    const typeMatches = elements.filter(e =>
      e.type === press.type || e.flutterType?.toLowerCase().includes(press.type!.toLowerCase())
    );

    if (press.position === 'rightmost') {
      return typeMatches.sort((a, b) => (b.bounds?.x ?? 0) - (a.bounds?.x ?? 0))[0] ?? null;
    }
    if (press.position === 'leftmost') {
      return typeMatches.sort((a, b) => (a.bounds?.x ?? 0) - (b.bounds?.x ?? 0))[0] ?? null;
    }

    return typeMatches[0] ?? null;
  }

  return null;
}

/** Resolve a fill target from the snapshot */
export function resolveFill(
  fill: NonNullable<FlowStep['fill']>,
  elements: SnapshotElement[],
): SnapshotElement | null {
  if (fill.type) {
    return elements.find(e =>
      e.type === fill.type || e.type === 'textfield' || e.flutterType === 'TextField'
    ) ?? null;
  }
  return elements.find(e => e.type === 'textfield' || e.flutterType === 'TextField') ?? null;
}

export function getStepAction(step: FlowStep): string {
  if (step.press) return 'press';
  if (step.scroll) return 'scroll';
  if (step.fill) return 'fill';
  if (step.back) return 'back';
  if (step.adb) return 'adb';
  if (step.assert) return 'assert';
  if (step.screenshot) return 'screenshot';
  if (step.wait && !step.press && !step.fill && !step.scroll && !step.back) return 'wait';
  return 'unknown';
}

/** Dry-run: parse flow and resolve step targets without executing */
export async function dryRunFlow(flow: Flow, agentFlutterPath: string = 'agent-flutter'): Promise<{
  flow: string;
  steps: { index: number; name: string; action: string; target: unknown; resolved: boolean; reason?: string }[];
  dryRun: true;
}> {
  const bridge = new AgentBridge(agentFlutterPath);
  let elements: SnapshotElement[] = [];
  try {
    elements = await safeSnapshot(bridge);
  } catch { /* no device = empty snapshot */ }

  const hasDevice = elements.length > 0;

  const steps = flow.steps.map((step, i) => {
    const action = getStepAction(step);
    let target: unknown = null;
    let resolved = true;
    let reason: string | undefined;

    if (step.press) {
      const el = resolvePress(step.press, elements);
      target = el ? { ref: el.ref, type: el.type, text: el.text } : step.press;
      resolved = el !== null;
      if (!resolved) reason = hasDevice ? 'element not found in current snapshot' : 'no device connected for snapshot';
    } else if (step.fill) {
      const el = resolveFill(step.fill, elements);
      target = el ? { ref: el.ref, type: el.type } : step.fill;
      resolved = el !== null;
      if (!resolved) reason = hasDevice ? 'textfield not found in current snapshot' : 'no device connected for snapshot';
    } else if (step.scroll) {
      target = { direction: step.scroll };
    } else if (step.back) {
      target = { back: true };
    } else if (step.assert) {
      target = step.assert;
      // Assertions always "resolve" — they check conditions at runtime
    }

    return { index: i, name: step.name, action, target, resolved, ...(reason ? { reason } : {}) };
  });

  return { flow: flow.name, steps, dryRun: true };
}

/** Check if flow prerequisites are met */
export function checkPrerequisites(
  prerequisites: string[],
  bridge: AgentBridge,
): { met: boolean; failed?: string } {
  for (const prereq of prerequisites) {
    if (prereq === 'auth_ready') {
      // auth_ready: app should be past sign-in, on the home/main screen
      // Check for home screen indicators via text extraction
      const texts = bridge.text();
      const homeIndicators = ['today', 'home', 'featured', 'memories', 'chats'];
      const hasHomeText = texts.some(t => {
        const lower = t.toLowerCase();
        return homeIndicators.some(ind => lower.includes(ind));
      });
      if (hasHomeText) continue;

      // Also check for bottom nav presence (≥3 interactive elements near bottom)
      try {
        const snapshot = bridge.snapshot();
        const bottomNav = snapshot.elements.filter(
          e => e.bounds && e.bounds.y > 780 && e.bounds.height < 100
        );
        if (bottomNav.length >= 3) continue;
      } catch { /* snapshot failed */ }

      return { met: false, failed: prereq };
    }

    // Unknown prerequisite — skip (don't block on unrecognized names)
  }
  return { met: true };
}

/** Try to run a setup flow for a failed prerequisite */
async function tryRunSetupFlow(
  prereq: string,
  flowFilePath: string,
  bridge: AgentBridge,
  options: RunOptions,
): Promise<boolean> {
  // Look for setup/{prereq}.yaml relative to the flow file's directory
  const flowDir = dirname(flowFilePath);
  const setupPath = join(flowDir, 'setup', `${prereq}.yaml`);

  if (!existsSync(setupPath)) return false;

  if (!options.json) {
    console.log(`  → Running setup flow: ${setupPath}`);
  }

  try {
    const setupFlow = parseFlowFile(setupPath);

    // Execute setup flow steps directly (no video/logs, just actions)
    for (const step of setupFlow.steps) {
      await executeStep(step, bridge, options.outputDir, 0);
    }

    // Re-check prerequisite after setup
    const recheck = checkPrerequisites([prereq], bridge);
    return recheck.met;
  } catch {
    return false;
  }
}

async function safeSnapshot(bridge: AgentBridge): Promise<SnapshotElement[]> {
  try {
    const snapshot = await bridge.snapshot();
    return snapshot.elements;
  } catch {
    return [];
  }
}

function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/** Substitute $ENV_VAR references in a string with values from process.env */
export function substituteEnvVars(value: string): string {
  return value.replace(/\$([A-Z_][A-Z0-9_]*)/g, (_match, name) => {
    return process.env[name] ?? '';
  });
}
