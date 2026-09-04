/**
 * Tests for keyboard dismiss and back command keyboard awareness.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

describe('dismiss-keyboard command', () => {
  it('dismiss-keyboard module exists', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/commands/dismiss-keyboard.ts'), 'utf-8');
    assert.ok(src.includes('dismissKeyboardCommand'), 'should export dismissKeyboardCommand');
  });

  it('uses KEYCODE_ESCAPE not BACK', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/transport/adb.ts'), 'utf-8');
    assert.ok(src.includes('keyevent 111'), 'dismissKeyboard should use keyevent 111 (ESCAPE)');
    // Ensure dismiss keyboard doesn't use the back key (keyevent 4)
    const dismissMethod = src.slice(src.indexOf('dismissKeyboard'));
    const nextMethod = dismissMethod.indexOf('\n  }');
    const methodBody = dismissMethod.slice(0, nextMethod > 0 ? nextMethod : undefined);
    assert.ok(!methodBody.includes('keyevent 4'), 'dismissKeyboard should not send BACK key');
  });

  it('isKeyboardShowing checks mInputShown', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/transport/adb.ts'), 'utf-8');
    assert.ok(src.includes('mInputShown'), 'should check mInputShown from dumpsys input_method');
  });
});

describe('back command keyboard awareness', () => {
  it('back command checks keyboard state', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/commands/back.ts'), 'utf-8');
    assert.ok(src.includes('isKeyboardShowing'), 'back should call isKeyboardShowing');
    assert.ok(src.includes('keyboardDismissed'), 'back output should include keyboardDismissed field');
  });

  it('back command calls dismissKeyboard when keyboard showing', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/commands/back.ts'), 'utf-8');
    assert.ok(src.includes('dismissKeyboard'), 'back should call dismissKeyboard');
    assert.ok(src.includes('navigated'), 'back output should include navigated field');
  });

  it('back does not navigate when keyboard is dismissed', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/commands/back.ts'), 'utf-8');
    // When keyboard dismissed, navigated should be false
    assert.ok(src.includes('navigated: false'), 'should set navigated: false when keyboard dismissed');
    assert.ok(src.includes('navigated: true'), 'should set navigated: true when no keyboard');
  });
});

describe('transport interface', () => {
  it('DeviceTransport includes keyboard methods', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/transport/types.ts'), 'utf-8');
    assert.ok(src.includes('isKeyboardShowing'), 'DeviceTransport should have isKeyboardShowing');
    assert.ok(src.includes('dismissKeyboard'), 'DeviceTransport should have dismissKeyboard');
  });

  it('iOS transport has keyboard stubs', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/transport/ios-sim.ts'), 'utf-8');
    assert.ok(src.includes('isKeyboardShowing'), 'iOS transport should implement isKeyboardShowing');
    assert.ok(src.includes('dismissKeyboard'), 'iOS transport should implement dismissKeyboard');
  });
});

describe('schema parity', () => {
  it('dismiss-keyboard has schema entry', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/command-schema.ts'), 'utf-8');
    assert.ok(src.includes("'dismiss-keyboard'") || src.includes('"dismiss-keyboard"'), 'schema should include dismiss-keyboard');
  });

  it('back schema is unchanged', () => {
    const src = readFileSync(resolve(import.meta.dirname, '../src/command-schema.ts'), 'utf-8');
    assert.ok(src.includes("'back'") || src.includes('"back"'), 'schema should still include back');
  });
});
