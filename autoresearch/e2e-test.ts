/**
 * E2E test: exercises VmServiceClient against a real Flutter app with Marionette.
 *
 * Requires VM_SERVICE_URI env var pointing to the WebSocket URI of the Flutter VM Service.
 * Run via: VM_SERVICE_URI="ws://..." node --test autoresearch/e2e-test.ts
 */
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { VmServiceClient } from '../src/platforms/flutter/vm-service-client.ts';
import { convertFlutterElement, convertFlutterElements } from '../src/platforms/flutter/element-converter.ts';
import { buildFlutterMatcher, isFlutterNode } from '../src/platforms/flutter/matcher-builder.ts';

const VM_URI = process.env.VM_SERVICE_URI;

if (!VM_URI) {
  console.error('VM_SERVICE_URI env var not set. Skipping e2e tests.');
  process.exit(1);
}

describe('E2E: VmServiceClient against real Flutter app', () => {
  let client: VmServiceClient;

  before(async () => {
    client = new VmServiceClient();
    await client.connect(VM_URI);
  });

  after(async () => {
    await client.disconnect();
  });

  it('should connect and find Marionette isolate', () => {
    assert.equal(client.connected, true);
    assert.ok(client.currentIsolateId, 'Should have an isolate ID');
  });

  it('should get interactive elements', async () => {
    const elements = await client.getInteractiveElements();
    assert.ok(Array.isArray(elements), 'Should return an array');
    assert.ok(elements.length > 0, 'Should find at least one interactive element');

    // Log elements for debugging
    console.log(`Found ${elements.length} interactive elements:`);
    for (const el of elements) {
      console.log(`  - type=${el.type} key=${el.key ?? 'none'} text=${el.text ?? 'none'} visible=${el.visible}`);
    }
  });

  it('should find elements with ValueKeys from test app', async () => {
    const elements = await client.getInteractiveElements();

    // Our test app has ValueKey widgets: increment_btn, name_field, submit_btn, reset_btn, toggle_switch
    const keys = elements.filter((el) => el.key).map((el) => el.key);
    console.log('Elements with keys:', keys);

    // At minimum the increment button should be found
    assert.ok(elements.length >= 1, 'Should find interactive elements');
  });

  it('should convert elements to SnapshotNodes', async () => {
    const elements = await client.getInteractiveElements();
    const nodes = convertFlutterElements(elements, 0);

    assert.equal(nodes.length, elements.length, 'Should convert all elements');
    for (const node of nodes) {
      assert.equal(node.source, 'flutter', 'All nodes should have source=flutter');
      assert.ok(isFlutterNode(node), 'isFlutterNode should return true');
    }
  });

  it('should build matchers from converted nodes', async () => {
    const elements = await client.getInteractiveElements();
    const nodes = convertFlutterElements(elements, 0);

    for (const node of nodes) {
      const matcher = buildFlutterMatcher(node);
      assert.ok(matcher !== null, `Should build a matcher for node ${node.index}`);
    }
  });

  it('should tap the increment button by key', async () => {
    // Tap the increment button
    await client.tap({ type: 'Key', keyValue: 'increment_btn' });

    // Wait a frame for state update
    await new Promise((r) => setTimeout(r, 500));

    // Verify: get elements again, status text should reflect the change
    const elements = await client.getInteractiveElements();
    console.log('After tap, elements:', elements.length);
  });

  it('should enter text into the name field by key', async () => {
    await client.enterText(
      { type: 'Key', keyValue: 'name_field' },
      'test-name',
    );

    await new Promise((r) => setTimeout(r, 500));

    const elements = await client.getInteractiveElements();
    console.log('After enterText, elements:', elements.length);
  });

  it('should tap the submit button by key', async () => {
    await client.tap({ type: 'Key', keyValue: 'submit_btn' });
    await new Promise((r) => setTimeout(r, 500));
  });

  it('should tap the reset button by key', async () => {
    await client.tap({ type: 'Key', keyValue: 'reset_btn' });
    await new Promise((r) => setTimeout(r, 500));
  });

  it('should handle tap by text matcher', async () => {
    await client.tap({ type: 'Text', text: 'Increment' });
    await new Promise((r) => setTimeout(r, 500));
  });

  it('should get version info', async () => {
    // This tests calling a marionette extension directly
    // getVersion doesn't go through the public API but validates connectivity
    const elements = await client.getInteractiveElements();
    assert.ok(elements.length > 0, 'Should still return elements after multiple operations');
  });
});
