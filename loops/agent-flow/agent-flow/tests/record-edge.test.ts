/**
 * Edge case tests for the recording pipeline: init, stream, finish, verify.
 * Covers error paths, malformed input, partial recordings, and boundary conditions.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { recordInit, recordStream, recordFinish } from '../src/record.ts';
import { verifyRun } from '../src/verify.ts';
import { parseFlowFile } from '../src/flow-parser.ts';

function makeTmpDir(): string {
  return mkdtempSync(join(tmpdir(), 'fw-edge-'));
}

function writeFlow(dir: string, content: string): string {
  const p = join(dir, 'flow.yaml');
  writeFileSync(p, content);
  return p;
}

const MINIMAL_FLOW = 'version: 2\nname: test\nsteps:\n  - id: S1\n    do: test step\n';
const TWO_STEP_FLOW = 'version: 2\nname: two-step\nsteps:\n  - id: S1\n    do: first\n  - id: S2\n    do: second\n';
const EXPECT_FLOW = 'version: 2\nname: expect\nsteps:\n  - id: S1\n    do: verify\n    expect:\n      - milestone: home\n        kind: text_visible\n        values: [Home]\n  - id: S2\n    do: check\n    expect:\n      - milestone: done\n        kind: text_visible\n';

// ═══════════════════════════════════════════
// recordInit edge cases
// ═══════════════════════════════════════════

describe('recordInit: error cases', () => {
  it('throws on missing flow file', () => {
    const tmp = makeTmpDir();
    assert.throws(() => recordInit({ flowPath: join(tmp, 'nonexistent.yaml'), outputDir: tmp }));
  });

  it('creates nested output directory if needed', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const nested = join(tmp, 'deep', 'nested', 'output');
    const r = recordInit({ flowPath, outputDir: nested });
    assert.ok(existsSync(r.dir));
    assert.ok(existsSync(join(r.dir, 'run.meta.json')));
  });

  it('custom runId preserved exactly', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp, runId: 'MyCustom-1' });
    assert.equal(r.id, 'MyCustom-1');
  });

  it('noVideo flag prevents video fields', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp, noVideo: true });
    assert.equal(r.video, false);
    const meta = JSON.parse(readFileSync(join(r.dir, 'run.meta.json'), 'utf-8'));
    assert.ok(!meta.videoPid);
  });

  it('init returns evidence instructions', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    assert.ok(r.evidence);
    assert.ok(r.evidence!.length > 0);
    assert.ok(r.evidence!.some(e => e.includes('log')));
  });
});

// ═══════════════════════════════════════════
// recordStream edge cases
// ═══════════════════════════════════════════

describe('recordStream: error and edge cases', () => {
  it('throws on non-existent run directory', () => {
    const tmp = makeTmpDir();
    assert.throws(() => recordStream({ runId: 'fakeid1234', runDir: tmp }, ['{"type":"step.start","step_id":"S1"}']));
  });

  it('skips malformed JSON lines, accepts valid ones', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    const count = recordStream({ runId: r.id, runDir: tmp }, [
      'not valid json',
      '{"truncated": true',
      '{"type":"step.start","step_id":"S1"}',
      '',
      '{"type":"step.end","step_id":"S1","status":"pass"}',
    ]);
    assert.equal(count, 2); // only 2 valid events
  });

  it('appends to existing events (not overwrite)', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });

    // First batch
    recordStream({ runId: r.id, runDir: tmp }, ['{"type":"step.start","step_id":"S1"}']);
    let lines = readFileSync(join(r.dir, 'events.jsonl'), 'utf-8').trim().split('\n').filter(Boolean);
    assert.equal(lines.length, 1);

    // Second batch appends
    recordStream({ runId: r.id, runDir: tmp }, ['{"type":"step.end","step_id":"S1","status":"pass"}']);
    lines = readFileSync(join(r.dir, 'events.jsonl'), 'utf-8').trim().split('\n').filter(Boolean);
    assert.equal(lines.length, 2);

    // Sequence numbers are continuous
    const ev0 = JSON.parse(lines[0]);
    const ev1 = JSON.parse(lines[1]);
    assert.equal(ev0.seq, 0);
    assert.equal(ev1.seq, 1);
  });

  it('skips events with invalid type', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    const count = recordStream({ runId: r.id, runDir: tmp }, [
      '{"type":"unknown_event","step_id":"S1"}',
      '{"missing_type": true}',
    ]);
    assert.equal(count, 0);
  });

  it('adds timestamps when missing', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    recordStream({ runId: r.id, runDir: tmp }, ['{"type":"step.start","step_id":"S1"}']);
    const lines = readFileSync(join(r.dir, 'events.jsonl'), 'utf-8').trim().split('\n');
    const ev = JSON.parse(lines[0]);
    assert.ok(ev.ts, 'event should have ts');
    assert.ok(ev.ts.match(/^\d{4}-\d{2}-\d{2}T/), 'ts should be ISO format');
  });

  it('preserves existing timestamp', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    const customTs = '2026-01-01T12:00:00.000Z';
    recordStream({ runId: r.id, runDir: tmp }, [`{"type":"step.start","step_id":"S1","ts":"${customTs}"}`]);
    const lines = readFileSync(join(r.dir, 'events.jsonl'), 'utf-8').trim().split('\n');
    const ev = JSON.parse(lines[0]);
    assert.equal(ev.ts, customTs);
  });

  it('empty lines array produces zero events', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    const count = recordStream({ runId: r.id, runDir: tmp }, []);
    assert.equal(count, 0);
  });
});

// ═══════════════════════════════════════════
// recordFinish edge cases
// ═══════════════════════════════════════════

describe('recordFinish: edge cases', () => {
  it('throws on non-existent run directory', () => {
    const tmp = makeTmpDir();
    assert.throws(() => recordFinish({ runId: 'fakeid1234', runDir: tmp, status: 'pass' }));
  });

  it('records fail status', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    recordFinish({ runId: r.id, runDir: tmp, status: 'fail' });
    const meta = JSON.parse(readFileSync(join(r.dir, 'run.meta.json'), 'utf-8'));
    assert.equal(meta.status, 'fail');
    assert.ok(meta.finishedAt);
  });

  it('eventCount is 0 for empty recording', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    recordFinish({ runId: r.id, runDir: tmp, status: 'pass' });
    const meta = JSON.parse(readFileSync(join(r.dir, 'run.meta.json'), 'utf-8'));
    assert.equal(meta.eventCount, 0);
  });

  it('finishedAt is after startedAt', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    recordStream({ runId: r.id, runDir: tmp }, ['{"type":"step.start","step_id":"S1"}']);
    recordFinish({ runId: r.id, runDir: tmp, status: 'pass' });
    const meta = JSON.parse(readFileSync(join(r.dir, 'run.meta.json'), 'utf-8'));
    assert.ok(new Date(meta.finishedAt) >= new Date(meta.startedAt));
  });
});

// ═══════════════════════════════════════════
// verify edge cases
// ═══════════════════════════════════════════

describe('verify: edge cases', () => {
  it('empty events.jsonl produces fail result', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, EXPECT_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    // Don't stream any events — just finish
    recordFinish({ runId: r.id, runDir: tmp, status: 'pass' });

    const flow = parseFlowFile(flowPath);
    const result = verifyRun({ flow, runDir: r.dir, mode: 'balanced' });
    assert.equal(result.result, 'fail');
  });

  it('missing step reports which step failed', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, TWO_STEP_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    // Only stream events for S1, skip S2
    recordStream({ runId: r.id, runDir: tmp }, [
      '{"type":"step.start","step_id":"S1"}',
      '{"type":"step.end","step_id":"S1","status":"pass"}',
    ]);
    recordFinish({ runId: r.id, runDir: tmp, status: 'pass' });

    const flow = parseFlowFile(flowPath);
    const result = verifyRun({ flow, runDir: r.dir, mode: 'balanced' });
    assert.equal(result.steps.length, 2);
    const s1 = result.steps.find(s => s.id === 'S1');
    const s2 = result.steps.find(s => s.id === 'S2');
    assert.ok(s1);
    assert.equal(s1!.outcome, 'pass');
    assert.ok(s2);
    assert.equal(s2!.outcome, 'fail'); // no events = fail
  });

  it('all steps passing produces pass result', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, TWO_STEP_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    recordStream({ runId: r.id, runDir: tmp }, [
      '{"type":"step.start","step_id":"S1"}',
      '{"type":"step.end","step_id":"S1","status":"pass"}',
      '{"type":"step.start","step_id":"S2"}',
      '{"type":"step.end","step_id":"S2","status":"pass"}',
    ]);
    recordFinish({ runId: r.id, runDir: tmp, status: 'pass' });

    const flow = parseFlowFile(flowPath);
    const result = verifyRun({ flow, runDir: r.dir, mode: 'balanced' });
    assert.equal(result.result, 'pass');
    assert.equal(result.steps.every(s => s.outcome === 'pass'), true);
  });

  it('verify with expect checks automated tier', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, EXPECT_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    recordStream({ runId: r.id, runDir: tmp }, [
      '{"type":"step.start","step_id":"S1"}',
      '{"type":"assert","step_id":"S1","expect":"text_visible","values":["Home"],"passed":true,"milestone":"home"}',
      '{"type":"step.end","step_id":"S1","status":"pass"}',
      '{"type":"step.start","step_id":"S2"}',
      '{"type":"assert","step_id":"S2","expect":"text_visible","passed":true,"milestone":"done"}',
      '{"type":"step.end","step_id":"S2","status":"pass"}',
    ]);
    recordFinish({ runId: r.id, runDir: tmp, status: 'pass' });

    const flow = parseFlowFile(flowPath);
    const result = verifyRun({ flow, runDir: r.dir, mode: 'balanced' });
    assert.equal(result.result, 'pass');
    assert.equal(result.automatedResult, 'pass');
  });

  it('verify schema field is set', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, MINIMAL_FLOW);
    const r = recordInit({ flowPath, outputDir: tmp });
    recordStream({ runId: r.id, runDir: tmp }, [
      '{"type":"step.start","step_id":"S1"}',
      '{"type":"step.end","step_id":"S1","status":"pass"}',
    ]);
    recordFinish({ runId: r.id, runDir: tmp, status: 'pass' });

    const flow = parseFlowFile(flowPath);
    const result = verifyRun({ flow, runDir: r.dir, mode: 'balanced' });
    assert.ok(result.schema);
    assert.ok(result.schema.includes('agent-flow'));
  });
});

// ═══════════════════════════════════════════
// Full pipeline round-trip
// ═══════════════════════════════════════════

describe('full pipeline round-trip', () => {
  it('init → stream → finish → verify → all pass', () => {
    const tmp = makeTmpDir();
    const flowPath = writeFlow(tmp, TWO_STEP_FLOW);

    // Init
    const r = recordInit({ flowPath, outputDir: tmp, noVideo: true });
    assert.ok(r.id);
    assert.ok(r.dir);

    // Stream
    const count = recordStream({ runId: r.id, runDir: tmp }, [
      '{"type":"step.start","step_id":"S1","name":"first"}',
      '{"type":"action","step_id":"S1","action":"press","target":"btn1"}',
      '{"type":"step.end","step_id":"S1","status":"pass"}',
      '{"type":"step.start","step_id":"S2","name":"second"}',
      '{"type":"action","step_id":"S2","action":"press","target":"btn2"}',
      '{"type":"step.end","step_id":"S2","status":"pass"}',
    ]);
    assert.equal(count, 6);

    // Finish
    const finishResult = recordFinish({ runId: r.id, runDir: tmp, status: 'pass', flowPath });
    const meta = JSON.parse(readFileSync(join(r.dir, 'run.meta.json'), 'utf-8'));
    assert.equal(meta.status, 'pass');
    assert.equal(meta.eventCount, 6);

    // Verify
    const flow = parseFlowFile(flowPath);
    const result = verifyRun({ flow, runDir: r.dir, mode: 'balanced' });
    assert.equal(result.result, 'pass');
    assert.equal(result.steps.length, 2);
  });
});
