import { createRequire } from 'node:module';
if (!globalThis.require) {
  globalThis.require = createRequire(import.meta.url);
}
