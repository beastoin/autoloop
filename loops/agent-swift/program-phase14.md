# Phase 15: Token-Efficient Video Analysis

## Objective

Reduce agent token costs for video verification by 80-90%. Currently agents extract full-resolution frames and send them as images (~1600 tokens each). This phase adds smart keyframe detection (send fewer frames) and OCR text extraction (replace images with text at ~100 tokens), plus grayscale and JPEG output for faster uploads.

## Origin

Manager request: optimize token spending on video verification workflows. Agents using `record frame`/`record frames` for UI verification spend excessive tokens on visually redundant full-color screenshots.

## Key Insight

API image tokens are based on resolution, not file size. Grayscale/JPEG reduce upload time but NOT API cost. The real token savers are:
1. **Fewer frames** — keyframe detection skips visually identical scenes
2. **Text instead of images** — OCR returns structured text (100 tokens vs 1600 tokens per frame)

## Commands

### `record frame` — new flags

#### `--ocr`
Extract text from the frame using Vision framework (VNRecognizeTextRequest) instead of returning the image.
- Returns JSON with text blocks + bounding boxes: `{"texts": [{"text": "Settings", "x": 10, "y": 200, "width": 100, "height": 20, "confidence": 0.98}]}`
- Can combine with `--at` to extract text at a specific timestamp
- When combined with `--max-width`, resizes first then OCRs (faster)
- Uses `.accurate` recognition level for UI text
- Default: disabled (returns image as before)

#### `--grayscale`
Convert the extracted frame to grayscale before output.
- Uses `sips --matchTo` with Generic Gray Profile
- Reduces file size ~3x (fewer bytes to upload/process)
- Can combine with `--max-width`, `--crop` (grayscale applied last)
- Default: disabled (full color)

#### `--format <png|jpeg>`
Output format for the extracted frame.
- Default: `png` (lossless, current behavior)
- `jpeg` reduces file size 3-5x vs PNG for photos/screenshots
- Requires `--quality` when format is jpeg (default: 80)

#### `--quality <1-100>`
JPEG quality level. Only valid with `--format jpeg`.
- Lower = smaller file, more artifacts
- Recommended: 60-80 for verification screenshots
- Default: 80

### `record frames` — new flags

#### `--keyframes`
Automatically detect scene changes and only extract frames where the UI visually changed.
- Uses the existing thumbnail comparison infrastructure (resize to 32x32, compute pixel diff)
- Threshold: 0.92 similarity (configurable via `--dedup-threshold`)
- Scans at 0.5s intervals, extracts only when scene change detected
- Returns `{"keyframes": [...], "totalScanned": 60, "extracted": 4, "skipped": 56}`
- Mutually exclusive with `--every` and `--at` (keyframes replaces fixed intervals)

All existing flags (`--max-width`, `--dedup-threshold`, `--ocr`, `--grayscale`, `--format`, `--quality`) work with `--keyframes`.

### `record frame` / `record frames` — combined example

```bash
# Before: 30s video, 15 frames × 1600 tokens = 24,000 tokens
record frames --video /tmp/rec.mp4 --every 2.0

# After: 30s video, 4 keyframes × 100 tokens = 400 tokens (60x reduction)
record frames --video /tmp/rec.mp4 --keyframes --ocr --max-width 800
```

## Implementation Notes

### OCR (Vision framework)
- Import `Vision` framework in Package.swift / main.swift
- Create `VNRecognizeTextRequest` with `.accurate` level
- Process frame image via `VNImageRequestHandler`
- Extract recognized text observations with bounding boxes
- Normalize bounding box coordinates from Vision (0-1 range) to pixel coordinates
- Return as structured JSON array sorted top-to-bottom, left-to-right

### Grayscale (sips)
- `sips --matchTo "/System/Library/ColorSync/Profiles/Generic Gray Profile.icc" <path>`
- Applied after crop, before resize (smaller file for resize to process)

### JPEG (sips)
- `sips --setProperty format jpeg --setProperty formatOptions <quality> <path>`
- Converts PNG to JPEG in-place

### Keyframes
- Extend existing `computeSimilarity` from dedup
- Scan at fixed sub-second intervals (0.5s)
- Extract frame only when similarity to last extracted < threshold
- First frame always extracted
- Last frame always extracted (captures final state)

## Session Changes

None (uses existing `lastFramePath` from phase 14).

## Acceptance Criteria

1. `record frame --ocr --at 4 --video <path>` returns JSON with `texts` array containing text + bounding boxes
2. `record frame --ocr` returns empty `texts` array on frame with no readable text
3. OCR bounding boxes are in pixel coordinates (not 0-1 range)
4. `record frame --grayscale` produces a grayscale image (1-channel or gray profile)
5. `record frame --format jpeg --quality 60` produces a JPEG file
6. `record frame --format jpeg` without `--quality` defaults to quality 80
7. `--quality` without `--format jpeg` produces an error
8. `record frames --keyframes --video <path>` extracts only visually distinct frames
9. `--keyframes` extracts first frame and last frame always
10. `--keyframes` is mutually exclusive with `--every` and `--at`
11. `--keyframes` + `--ocr` returns text for each keyframe
12. All new flags appear in `schema` output
13. All new flags appear in help text
14. Error messages follow agent-friendly contract (code + message + hint)
15. Backward compatible — no flags = identical to v0.9.0 behavior
16. `Vision` framework imported for OCR
17. ≥ 20 new tests for token optimization features
18. ≥ 220 total tests
19. Version 0.10.0

## Design Constraints

- OCR uses macOS-native Vision framework (no external deps)
- Grayscale and JPEG use macOS-native `sips` (no external deps)
- Keyframe detection reuses existing thumbnail comparison infrastructure
- All processing happens in-process after frame extraction
- `--video` flag required on `record frames` (consistent with v0.9.0 solid design)
- OCR recognition level `.accurate` for reliable UI text extraction
