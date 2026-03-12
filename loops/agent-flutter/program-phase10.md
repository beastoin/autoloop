# agent-flutter Phase 10: UIAutomator Text Extraction

## Problem

Marionette snapshots return widget type, bounds, and refs — but text labels are often null or incomplete. Agents need to verify visible text on screen ("does the app show 'Featured'?") for production-quality flow assertions.

Android's UIAutomator accessibility layer has rich text in `text` and `content-desc` attributes across all visible UI, including system UI and non-Flutter overlays. agent-flutter should expose this as a new `text` command.

## Design

### Command: `agent-flutter text`

```bash
# List all visible text (one per line, deduped)
agent-flutter text

# JSON array of text entries with metadata
agent-flutter text --json

# Check if specific text is visible (exit 0=found, 1=not found)
agent-flutter text "Featured"
agent-flutter text "Featured" --json    # {"found":true,"match":"Featured"}
```

### Implementation

1. Run `adb shell uiautomator dump /dev/tty` (dumps XML to stdout)
2. Parse XML: extract `text` and `content-desc` attributes from all `<node>` elements
3. Filter: skip empty strings, deduplicate
4. For search mode: substring match (case-insensitive)

### Output format

Human (default):
```
Featured
Create Your Own App
Google Drive
Productivity
3.6
Install
```

JSON (`--json`):
```json
[
  { "text": "Featured", "source": "text", "class": "android.widget.TextView", "bounds": [0,150,1080,210] },
  { "text": "Create Your Own App", "source": "content-desc", "class": "android.view.View", "bounds": [50,300,500,350] }
]
```

Search result JSON:
```json
{ "found": true, "matches": ["Featured"] }
```

### Transport integration

Add `dumpText(): TextEntry[]` to `DeviceTransport` interface.
- Android: `adb shell uiautomator dump /dev/tty` → parse XML
- iOS: stub returning empty array (UIAutomator is Android-only; future: XCUITest accessibility)

### New files

- `src/commands/text.ts` — command implementation
- `src/text-parser.ts` — UIAutomator XML parser (no external XML deps — regex/split on attributes)

## Acceptance Criteria

- [ ] `agent-flutter text` lists visible text strings from UIAutomator dump
- [ ] `agent-flutter text --json` returns structured JSON with text, source, class, bounds
- [ ] `agent-flutter text "query"` exits 0 when found, 1 when not found
- [ ] `agent-flutter text "query" --json` returns `{found, matches}`
- [ ] No session required — works without `connect` (uses ADB directly)
- [ ] XML parsing handles malformed/empty dumps gracefully
- [ ] Empty text and content-desc values are filtered out
- [ ] Command added to schema (command-schema.ts) with args, flags, exit codes
- [ ] Help text follows existing patterns
- [ ] Transport: `dumpText()` method on `DeviceTransport`
- [ ] iOS transport returns empty array (not an error)
- [ ] All existing tests pass (no regressions)
- [ ] New unit tests for XML parser
- [ ] Typecheck passes

## Non-goals

- iOS accessibility text (future phase)
- Text OCR from screenshots
- Semantic grouping of text entries
- External XML parser dependency
