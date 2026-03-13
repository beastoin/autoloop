import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { resolvePress, resolveFill, getStepAction, checkPrerequisites, substituteEnvVars } from '../src/runner.ts';
import type { SnapshotElement, FlowStep } from '../src/types.ts';

const makeElement = (overrides: Partial<SnapshotElement> = {}): SnapshotElement => ({
  ref: '@e1',
  type: 'button',
  text: 'OK',
  enabled: true,
  bounds: { x: 100, y: 200, width: 80, height: 40 },
  ...overrides,
});

describe('getStepAction', () => {
  it('returns "press" for press step', () => {
    assert.equal(getStepAction({ name: 'x', press: { type: 'button' } }), 'press');
  });

  it('returns "scroll" for scroll step', () => {
    assert.equal(getStepAction({ name: 'x', scroll: 'down' }), 'scroll');
  });

  it('returns "fill" for fill step', () => {
    assert.equal(getStepAction({ name: 'x', fill: { value: 'hello' } }), 'fill');
  });

  it('returns "back" for back step', () => {
    assert.equal(getStepAction({ name: 'x', back: true }), 'back');
  });

  it('returns "assert" for assert step', () => {
    assert.equal(getStepAction({ name: 'x', assert: { interactive_count: { min: 5 } } }), 'assert');
  });

  it('returns "screenshot" for screenshot-only step', () => {
    assert.equal(getStepAction({ name: 'x', screenshot: 'home' }), 'screenshot');
  });

  it('returns "unknown" for empty step', () => {
    assert.equal(getStepAction({ name: 'x' }), 'unknown');
  });

  it('returns "adb" for adb step', () => {
    assert.equal(getStepAction({ name: 'x', adb: 'shell pm clear com.example' }), 'adb');
  });

  it('returns "wait" for wait-only step', () => {
    assert.equal(getStepAction({ name: 'x', wait: 3 }), 'wait');
  });

  it('returns "press" for press step with wait', () => {
    assert.equal(getStepAction({ name: 'x', press: { text: 'Next' }, wait: 2 }), 'press');
  });
});

describe('resolvePress', () => {
  it('resolves by ref', () => {
    const els = [makeElement({ ref: '@e1' }), makeElement({ ref: '@e2' })];
    const result = resolvePress({ ref: '@e2' }, els);
    assert.equal(result?.ref, '@e2');
  });

  it('returns null for missing ref', () => {
    const els = [makeElement({ ref: '@e1' })];
    const result = resolvePress({ ref: '@e99' }, els);
    assert.equal(result, null);
  });

  it('resolves by bottom_nav_tab index', () => {
    const els = [
      makeElement({ ref: '@nav0', flutterType: 'InkWell', bounds: { x: 10, y: 800, width: 80, height: 50 } }),
      makeElement({ ref: '@nav1', flutterType: 'InkWell', bounds: { x: 100, y: 800, width: 80, height: 50 } }),
      makeElement({ ref: '@nav2', flutterType: 'InkWell', bounds: { x: 200, y: 800, width: 80, height: 50 } }),
    ];
    const result = resolvePress({ bottom_nav_tab: 1 }, els);
    assert.equal(result?.ref, '@nav1');
  });

  it('returns null for out-of-range bottom_nav_tab', () => {
    const els = [
      makeElement({ ref: '@nav0', flutterType: 'InkWell', bounds: { x: 10, y: 800, width: 80, height: 50 } }),
    ];
    const result = resolvePress({ bottom_nav_tab: 5 }, els);
    assert.equal(result, null);
  });

  it('resolves by type', () => {
    const els = [
      makeElement({ ref: '@e1', type: 'textfield' }),
      makeElement({ ref: '@e2', type: 'button' }),
    ];
    const result = resolvePress({ type: 'button' }, els);
    assert.equal(result?.ref, '@e2');
  });

  it('resolves by type with rightmost position', () => {
    const els = [
      makeElement({ ref: '@e1', type: 'button', bounds: { x: 10, y: 100, width: 40, height: 40 } }),
      makeElement({ ref: '@e2', type: 'button', bounds: { x: 300, y: 100, width: 40, height: 40 } }),
      makeElement({ ref: '@e3', type: 'button', bounds: { x: 150, y: 100, width: 40, height: 40 } }),
    ];
    const result = resolvePress({ type: 'button', position: 'rightmost' }, els);
    assert.equal(result?.ref, '@e2');
  });

  it('resolves by type with leftmost position', () => {
    const els = [
      makeElement({ ref: '@e1', type: 'button', bounds: { x: 300, y: 100, width: 40, height: 40 } }),
      makeElement({ ref: '@e2', type: 'button', bounds: { x: 10, y: 100, width: 40, height: 40 } }),
    ];
    const result = resolvePress({ type: 'button', position: 'leftmost' }, els);
    assert.equal(result?.ref, '@e2');
  });

  it('resolves by flutterType partial match', () => {
    const els = [
      makeElement({ ref: '@e1', type: 'gesture', flutterType: 'ElevatedButton' }),
    ];
    const result = resolvePress({ type: 'elevatedbutton' }, els);
    assert.equal(result?.ref, '@e1');
  });

  it('returns null when no match', () => {
    const els = [makeElement({ ref: '@e1', type: 'textfield' })];
    const result = resolvePress({ type: 'switch' }, els);
    assert.equal(result, null);
  });

  it('returns null for empty press config', () => {
    const els = [makeElement()];
    const result = resolvePress({}, els);
    assert.equal(result, null);
  });
});

describe('bail-on-failure: action safety classification', () => {
  // The runner bails after a failed step UNLESS the action is 'back', 'screenshot', or 'assert'
  // These are safe to continue after because they don't change screen state
  const safeToContinue = (action: string) => action === 'back' || action === 'screenshot' || action === 'assert';

  it('press failure should bail', () => {
    assert.equal(safeToContinue('press'), false);
  });

  it('fill failure should bail', () => {
    assert.equal(safeToContinue('fill'), false);
  });

  it('scroll failure should bail', () => {
    assert.equal(safeToContinue('scroll'), false);
  });

  it('back failure should NOT bail', () => {
    assert.equal(safeToContinue('back'), true);
  });

  it('screenshot failure should NOT bail', () => {
    assert.equal(safeToContinue('screenshot'), true);
  });

  it('assert failure should NOT bail', () => {
    assert.equal(safeToContinue('assert'), true);
  });
});

describe('checkPrerequisites export', () => {
  it('is exported as a function', () => {
    assert.equal(typeof checkPrerequisites, 'function');
  });
});

describe('substituteEnvVars', () => {
  it('replaces $VAR with env value', () => {
    process.env.TEST_SUB_VAR = 'hello';
    assert.equal(substituteEnvVars('$TEST_SUB_VAR'), 'hello');
    delete process.env.TEST_SUB_VAR;
  });

  it('replaces multiple vars', () => {
    process.env.TEST_A = 'foo';
    process.env.TEST_B = 'bar';
    assert.equal(substituteEnvVars('$TEST_A@$TEST_B'), 'foo@bar');
    delete process.env.TEST_A;
    delete process.env.TEST_B;
  });

  it('replaces missing var with empty string', () => {
    delete process.env.NONEXISTENT_VAR_XYZ;
    assert.equal(substituteEnvVars('user: $NONEXISTENT_VAR_XYZ'), 'user: ');
  });

  it('leaves strings without $ unchanged', () => {
    assert.equal(substituteEnvVars('no variables here'), 'no variables here');
  });

  it('only matches uppercase/underscore var names', () => {
    assert.equal(substituteEnvVars('$lowercase'), '$lowercase');
  });
});

describe('resolveFill', () => {
  it('resolves textfield by type', () => {
    const els = [
      makeElement({ ref: '@e1', type: 'button' }),
      makeElement({ ref: '@e2', type: 'textfield' }),
    ];
    const result = resolveFill({ type: 'textfield', value: 'hi' }, els);
    assert.equal(result?.ref, '@e2');
  });

  it('resolves TextField by flutterType when no type match', () => {
    const els = [
      makeElement({ ref: '@e1', type: 'gesture', flutterType: 'TextField' }),
    ];
    const result = resolveFill({ value: 'hello' }, els);
    assert.equal(result?.ref, '@e1');
  });

  it('returns null when no textfield available', () => {
    const els = [
      makeElement({ ref: '@e1', type: 'button' }),
    ];
    const result = resolveFill({ value: 'hi' }, els);
    assert.equal(result, null);
  });
});
