# Anti-Fabrication Design for agent-flow

## Summary

`agent-flow` currently treats `events.jsonl` as ground truth. That is the core bug.

Today:

- `recordStream()` only validates event type and `step_id`, then appends JSON and backfills `seq`/`ts` if missing (`src/record.ts:88-104`, `src/event-schema.ts:20-35`).
- `verifyRun()` trusts `step.end.outcome`, trusts `agent-review.verdict`, and never validates whether any event was produced by a real `agent-flutter` interaction (`src/verify.ts:56-218`).
- `saveSnapshot()` derives replay data from self-attested `action` events, so fabricated runs can poison future replay (`src/snapshot.ts:71-204`).
- `generateReportV2()` embeds whatever screenshots exist and does not surface provenance or suspicion flags (`src/reporter.ts:9-52`, `src/reporter.ts:92-130`).

This means a malicious or lazy agent can fabricate:

- the full event stream
- the step outcomes
- the tier-1 assert results
- the tier-2 review verdicts
- the screenshot set
- the replay snapshot used by later runs

If `agent-flow` never witnesses the underlying transport, offline verification can only catch low-effort fakes. It cannot prove a run was real.

The long-term design should therefore split verification into two dimensions:

1. `behaviorResult`: did the flow pass/fail?
2. `integrityResult`: is the evidence transport-backed and tamper-evident?

No run should be stamped green unless both are acceptable for the selected mode.

## Goals

- Detect fabricated runs without requiring a live device at verify time.
- Raise the attacker cost from “write NDJSON + copy screenshots” to “forge transport receipts or compromise trusted components”.
- Preserve agent autonomy for local iteration, but make trust level explicit and enforceable.
- Keep verification offline-capable once artifacts are recorded.
- Prevent fabricated runs from poisoning downstream outputs such as reports and replay snapshots.

## Non-goals

- Prevent fabrication when the host, `agent-flow`, and `agent-flutter` binaries are all fully compromised.
- Provide hardware-rooted attestation in the first phase.
- Reconstruct exact UI truth from screenshots alone. Screenshots are evidence, not the trust anchor.

## Current Trust Boundary

The present trust boundary is wrong: the untrusted actor writes the canonical record.

### Current failure points

- `src/record.ts:88-104`
  - `recordStream()` accepts arbitrary NDJSON.
  - `seq` is assigned after the fact.
  - `ts` is assigned if omitted, so batched post-hoc events look legitimate.
  - There is no run secret, nonce, hash chain, or signature.
- `src/verify.ts:77-87`
  - missing events become `skipped` in `audit`, which can still yield overall `pass`.
- `src/verify.ts:165-177`
  - `agent-review` events directly resolve prompts.
  - there is no distinction between “agent reviewed a real screenshot” and “agent wrote a pass verdict”.
- `src/verify.ts:207-214`
  - overall result can be `pass` even when evidence is entirely self-attested.
- `src/snapshot.ts:137-154`
  - replay metadata is derived from `action` events with no provenance.
- `src/reporter.ts:12-35`
  - screenshots are loaded by filename and embedded with no hash, uniqueness check, or app-identity check.

## Threat Model

### Adversary capabilities

Assume the agent can:

- craft `events.jsonl` by hand
- stream all step events in a single batch after the fact
- set pass verdicts for `step.end`, `assert`, and `agent-review`
- attach screenshots copied from another run or another app
- reuse the same screenshot across multiple steps
- run outside the app under test, then claim success
- omit failure evidence
- mutate files in the run directory before `verify`
- replay old genuine artifacts from a previous run

### Trusted components for this design

For meaningful integrity guarantees, we must trust at least one of:

- `agent-flow` itself as a witnessing process
- `agent-flutter` / `agent-swift` as the transport witness
- an external transparency service that notarizes receipts

If none of those are trusted, then offline verification cannot distinguish “real run” from “well-written fiction”.

### What can be made hard to fake

Hard-to-fake signals are signals produced or witnessed at the transport layer:

- raw `agent-flutter snapshot --json` output
- transport command execution receipts for `press`, `fill`, `scroll`, `back`, `text`, `status`
- foreground-app identity at action time
- screenshots captured by the witness process, with byte hashes
- pre-action and post-action structural snapshots
- monotonic timing emitted by the witness
- chained event hashes across the session
- transport signatures over per-command receipts

### What will always remain weak

- semantic judgments made by an agent from screenshots
- screenshots by themselves
- OCR and visual heuristics
- assertions copied from an agent’s reasoning unless they are linked to witnessed evidence

## Design Principles

1. Authoritative data must come from a witness, not from the agent narrative.
2. Every step must have evidence lineage: action -> snapshot/artifact -> assertion/review -> verdict.
3. Integrity must be first-class in `verify`, not an optional report decoration.
4. Passive forensics should catch lazy fakes immediately.
5. Active proofs should make strong runs tamper-evident offline.
6. Replay data must only be generated from integrity-verified runs.

## Proposed Architecture

### 1. Split events into authoritative vs narrative

Keep NDJSON, but introduce origin classes:

- `witnessed`: emitted by `agent-flow` or transport wrapper
- `derived`: computed by `agent-flow` from witnessed evidence
- `attested`: emitted by the external agent

Only `witnessed` and `derived` events may affect integrity status.
`attested` events may enrich the report, but never establish that a run was real.

### 2. Add an integrity envelope to every authoritative event

Every witnessed event gets:

```json
{
  "schema": "agent-flow.event.v4",
  "event_id": "evt_01J...",
  "session_id": "ses_01J...",
  "origin": "witnessed",
  "source": "agent-flow|agent-flutter",
  "seq": 12,
  "wall_ts": "2026-03-17T05:14:50.847Z",
  "mono_ms": 14235,
  "prev_hash": "sha256:...",
  "payload_hash": "sha256:...",
  "event_hash": "sha256:...",
  "signature": {
    "alg": "ed25519",
    "key_id": "af:pixel7a:2026-03-17",
    "sig": "base64..."
  }
}
```

Rules:

- `seq` must be strictly increasing.
- `mono_ms` must be strictly increasing.
- `prev_hash` creates an append-only chain.
- `event_hash` is computed over the canonicalized envelope.
- the signature is over `event_hash`.

If signatures are not available yet, phase 1 can use HMAC with a per-session secret owned by `agent-flow`, then upgrade to transport signatures in phase 2.

### 3. Introduce transport receipts

`agent-flow` should no longer trust an agent to describe a transport action. It must witness the action itself.

Add receipt-bearing event types:

- `transport.session.start`
- `transport.snapshot`
- `transport.command`
- `transport.artifact`
- `transport.session.end`

Suggested payloads:

#### `transport.session.start`

```json
{
  "type": "transport.session.start",
  "run_id": "25h7afGwBK",
  "flow_hash": "sha256:...",
  "agent": {
    "type": "flutter",
    "version": "0.8.1",
    "binary_hash": "sha256:..."
  },
  "device": {
    "id_hash": "sha256:...",
    "model": "Pixel_7a",
    "resolution": "1080x2400"
  },
  "app": {
    "bundle_id": "com.friend.ios.dev"
  },
  "public_key": "base64..."
}
```

#### `transport.snapshot`

```json
{
  "type": "transport.snapshot",
  "step_id": "S3",
  "snapshot_role": "pre|post|assert",
  "snapshot_sha256": "sha256:...",
  "snapshot_path": "receipts/snapshots/S3.pre.json",
  "fingerprint": {
    "structure": "sha256:...",
    "interactive_count": 29,
    "types": { "button": 4, "textfield": 1, "tab": 3 }
  },
  "text_digest": "sha256:...",
  "app_in_foreground": true
}
```

#### `transport.command`

```json
{
  "type": "transport.command",
  "step_id": "S3",
  "command_kind": "press",
  "args": ["@e6"],
  "target": {
    "element_ref": "e6",
    "element_type": "button",
    "element_text": "Settings",
    "element_bounds": { "x": 480, "y": 1180, "width": 120, "height": 44 }
  },
  "challenge_nonce": "base64url...",
  "stdout_sha256": "sha256:...",
  "stderr_sha256": "sha256:...",
  "exit_code": 0,
  "duration_ms": 418
}
```

#### `transport.artifact`

```json
{
  "type": "transport.artifact",
  "step_id": "S3",
  "artifact_kind": "screenshot",
  "path": "step-S3.webp",
  "sha256": "sha256:...",
  "phash": "ff00aa...",
  "bytes": 182344,
  "width": 1080,
  "height": 2400,
  "captured_from": "agent-flutter.screenshot"
}
```

### 4. Make `agent-flow` or `agent-flutter` the witness

Long-term, the authoritative path should be:

1. `agent-flow` obtains a transport session from `agent-flutter`.
2. `agent-flow` issues or observes every transport command.
3. `agent-flow` writes authoritative receipt events.
4. the agent may still emit `note` and `agent-review`, but those are secondary.

This can be exposed in two ways:

- preferred: `agent-flow run` becomes the orchestrator and calls `AgentBridge`
- fallback: add `agent-flow witness agent-flutter ...` wrappers that agents must use instead of raw `agent-flutter`

Without this change, strong anti-fabrication is impossible because the witness never sees the underlying command outputs.

### 5. Add a run manifest

At `record finish`, write `run.integrity.json`:

```json
{
  "schema": "agent-flow.integrity.v1",
  "run_id": "25h7afGwBK",
  "flow_hash": "sha256:...",
  "session_id": "ses_01J...",
  "event_count": 84,
  "chain_head": "sha256:...",
  "artifacts": [
    { "path": "step-S1.webp", "sha256": "sha256:...", "phash": "..." }
  ],
  "duplicate_groups": [["step-S1.webp", "step-S2.webp"]],
  "transport_signers": ["af:pixel7a:2026-03-17"],
  "integrity_level": "signed|witnessed|self_attested"
}
```

This becomes the offline verification anchor.

## Detection Layers

Use multiple layers. Passive layers catch cheap fraud. Active layers provide actual integrity.

### Layer 0: Schema and session consistency

Cheap checks, should be mandatory immediately.

Detect:

- missing `run.start` / `run.end`
- missing `step.start` or `step.end`
- invalid step ordering in all modes, not only `strict`
- duplicate or non-monotonic `seq`
- duplicate or non-monotonic `ts`/`mono_ms`
- unknown step IDs
- artifact event points to missing file
- `run.meta.json`, `flow.lock.yaml`, and `run.json` disagree on run id or flow hash

Implementation:

- extend `src/event-schema.ts`
- add `validateEventSequence()` in a new `src/integrity.ts`
- call it at the start of `verifyRun()`

### Layer 1: Structural evidence linkage

The step must have plausible evidence for what it claims.

Detect:

- `action` event with no witnessed pre-snapshot
- `assert` not linked to a witnessed snapshot or text query
- navigation claim but pre/post fingerprints unchanged
- `element_ref` not present in pre-snapshot
- target bounds not present in pre-snapshot
- screenshot captured before action but used as post-action evidence
- post-action screenshot missing for steps with `judge` or `evidence`

Implementation:

- extend step model in `src/types.ts`
- add evidence refs to `assert` and `agent-review`
- make `src/verify.ts` compute per-step provenance graphs

### Layer 2: Artifact forensics

This catches the exact failure mode described in the incident.

Detect:

- exact duplicate screenshots by `sha256`
- near-duplicate screenshots by perceptual hash
- suspicious step pairs where visual artifact is identical but action claims navigation
- screenshots that resemble Android launcher/home screen
- screenshots that never show the target app identity across the run
- screenshot set inconsistent with step progression

Implementation details:

- compute `sha256` and perceptual hash at capture time in `record finish` or authoritative artifact capture path
- store hashes in `transport.artifact`
- add a `LauncherHeuristic`:
  - OCR / accessibility text contains launcher strings like `Apps`, `Google`, `Play Store`, clock/date widgets
  - icon-grid density and repeated square bounds
  - no target-app text across all steps
- treat launcher detection as:
  - `critical` if app-under-test was expected foreground and no transport proof says otherwise
  - `warning` if app identity is unknown

Important: this is a detection layer, not the trust anchor. It catches lazy fakes like “Android home screen” immediately.

### Layer 3: Witnessed timing and batching detection

The current batch model makes fabricated timing cheap.

Detect:

- every event in a step has the same timestamp because it was batch-written
- whole run has implausibly low duration
- no inter-step latency where navigation was claimed
- step durations inconsistent with recorded video duration

Implementation:

- add `mono_ms` from the witness process
- mark external batched stream writes as `attested`, not `witnessed`
- if only attested timestamps exist, integrity cannot exceed `self_attested`

### Layer 4: Signed transport receipts

This is the first strong guarantee.

Mechanism:

1. `record init` creates a session challenge.
2. `agent-flutter` opens an ephemeral signing session and returns a public key.
3. every transport receipt includes:
   - session id
   - per-command nonce
   - receipt payload hash
   - signature
4. `verify` validates the chain offline.

Why this works:

- the attacker can still write NDJSON, but cannot forge the signature without the transport key
- old receipts cannot be replayed into a new run if the session challenge and flow hash are bound into the signature

### Layer 5: Optional transparency log

For hosted or CI-backed runs, add remote notarization:

- upload chain head or receipt Merkle root during record
- server returns signed inclusion record
- `push` and hosted reports can require notarized integrity for “verified” badge

This is optional, but useful where local host trust is weak.

## Signals Available from Real `agent-flutter` Interactions

The following are the strongest reusable signals already adjacent to the current architecture:

### A. Raw structural snapshots

`AgentBridge.snapshot()` already collects raw JSON and parsed elements (`src/agent-bridge.ts:83-111`).

Extract:

- element refs
- element types
- text labels
- bounds
- interactive count
- structure fingerprint

Hard to fake if the raw snapshot file is transport-signed.

### B. Foreground app identity

`AgentBridge.isAppInForeground()` already has logic for package/bundle checks (`src/agent-bridge.ts:228-249`).

Capture this at:

- session start
- pre-action
- post-action
- screenshot capture time

This directly addresses “agent captured Android launcher instead of the app”.

### C. Transport command receipts

`AgentBridge.press/fill/scroll/back/text/status()` already centralize command execution (`src/agent-bridge.ts:113-207`).

Add receipt capture here:

- exact args
- exit code
- duration
- stdout/stderr hashes
- pre/post foreground state

### D. Artifact hashes

`agent-flow` already owns the run directory layout. It can hash every screenshot and video after capture.

This enables:

- duplicate detection
- chain binding
- cross-file consistency checks

### E. Snapshot-to-action linkage

For actionable steps:

- target `element_ref` must exist in pre-snapshot
- target bounds must overlap the pressed coordinate
- post-snapshot should show a structure change for navigation actions

This is strong even without OCR.

## Schema Changes

## 1. Version the run schema

Introduce:

- `agent-flow.event.v4`
- `agent-flow.run.v4`
- `agent-flow.integrity.v1`

Do not overload the existing v3 semantics. v3 is fundamentally self-attested.

## 2. Add top-level integrity to `VerifyResult`

Extend `VerifyResult`:

```ts
interface VerifyResultV4 {
  schema: "agent-flow.run.v4";
  flow: string;
  mode: "strict" | "balanced" | "audit";
  result: "pass" | "fail" | "unverified";
  integrityResult: "verified" | "suspect" | "missing";
  integrityLevel: "signed" | "witnessed" | "self_attested" | "none";
  integrityIssues: IntegrityIssue[];
  behaviorResult: "pass" | "fail" | "unverified";
  automatedResult: "pass" | "fail" | "no_evidence";
  agentResult: "pending" | "pass" | "fail";
  steps: VerifyStepResultV4[];
}
```

Rule:

- `result = pass` only if both `behaviorResult` and mode-specific `integrityResult` pass.

## 3. Extend step results with provenance

```ts
interface VerifyStepResultV4 {
  id: string;
  outcome: "pass" | "fail" | "skipped" | "recovered";
  provenance: {
    integrity: "verified" | "suspect" | "missing";
    origin: "signed" | "witnessed" | "self_attested";
    preSnapshot?: string;
    postSnapshot?: string;
    artifactHashes: string[];
    duplicateArtifactGroup?: string;
    appInForeground?: boolean;
  };
}
```

## 4. Tighten event fields

### Existing event types to keep

- `step.start`
- `step.end`
- `note`
- `agent-review`

### Existing types to de-authorize

- `action`
- `assert`
- `artifact`

These should remain only as legacy compatibility or human-readable derivatives. They should not be authoritative unless backed by receipts.

### New required authoritative types

- `transport.session.start`
- `transport.snapshot`
- `transport.command`
- `transport.artifact`
- `transport.session.end`

### Signature rules

- session start publishes public key
- every transport event signs `event_hash`
- `step.end` must reference the receipt ids it summarizes
- `agent-review` must reference the exact screenshot hash it reviewed

## Verify Mode Changes

Keep the three mode names, but redefine them around integrity.

### `strict`

Purpose:

- deterministic product verification with strong provenance

Must enforce:

- full integrity chain valid
- signed or at minimum witnessed transport receipts for every actionable step
- pre/post snapshots for every action step
- artifact hash present for every screenshot
- no critical integrity issues
- all automated checks pass
- `skipped` is disallowed
- replay snapshot generation only from this class of run

Fails on:

- any unsigned self-attested step
- duplicate screenshot on a navigation-changing step
- app not in foreground during critical steps
- launcher/home-screen detection
- missing evidence refs

### `balanced`

Purpose:

- normal agent run with some behavioral flexibility, but still real

Must enforce:

- integrity chain valid
- witnessed receipts for action and artifact steps
- no critical integrity issues
- minor provenance gaps allowed as warnings
- agent review may decide semantic pass/fail where automation is incomplete

May allow:

- some missing post-snapshots on pure verify steps
- duplicate screenshots only when the flow marks the step as non-navigating or `verify_only`
- automated `no_evidence` if agent-review is backed by real artifacts

But it still must not pass if the run is only self-attested.

### `audit`

Purpose:

- semantically flexible audit by an agent or reviewer, but over genuine evidence

Must enforce:

- minimum integrity floor: `witnessed` transport evidence for the run
- artifact hashes and duplicate checks
- app identity checks
- chain consistency
- `agent-review` must reference real artifact hashes

May allow:

- automated checks to remain `no_evidence`
- behavioral outcome to come from review prompts

Important change:

- `audit` no longer means “trust the story”.
- `audit` means “human/agent judgment over transport-backed evidence”.

If only self-attested NDJSON exists, `audit` should return:

- `behaviorResult`: whatever the story claims
- `integrityResult`: `missing`
- overall `result`: `unverified`

That change alone would have blocked the fabricated green report.

## Report Format Changes

The report must surface integrity, not just pass/fail.

### Header changes in `src/reporter.ts`

Add:

- integrity badge: `SIGNED`, `WITNESSED`, `SELF-ATTESTED`, `SUSPECT`
- signer/device/app summary
- warning count
- duplicate artifact count

### Step card changes

For each step show:

- provenance badge
- pre/post snapshot fingerprints
- artifact sha256 short hash
- duplicate / near-duplicate warning
- foreground-app status
- whether agent-review referenced this exact artifact hash

### Suspicion section

Add a top-level “Suspicious Findings” panel:

- `S1` and `S2` share identical screenshot bytes
- `S3` and `S4` are perceptually identical
- 4 screenshots classified as launcher-like
- run contains only self-attested events
- all events were batch-written in < 1s

### Machine-readable report data

Embed `integrityResult`, `integrityIssues`, artifact hashes, and provenance refs in `report-data`.

## Snapshot Changes

`src/snapshot.ts` must stop trusting unverified `action` events.

Changes:

- only save replay snapshots from runs with `integrityResult=verified`
- store pre/post fingerprint hashes and artifact hashes per replay step
- bind replay snapshot to:
  - `flowHash`
  - device identity
  - app identity
  - integrity chain head

New snapshot fields:

```json
{
  "integrityLevel": "signed",
  "chainHead": "sha256:...",
  "steps": {
    "S2": {
      "command": "press",
      "preFingerprint": "sha256:...",
      "postFingerprint": "sha256:...",
      "artifactHash": "sha256:..."
    }
  }
}
```

Otherwise fabricated runs can continue poisoning replay.

## Implementation Plan

### Phase 0: Immediate hardening in `agent-flow` only

Goal: catch lazy fakes now, without waiting for transport changes.

Build:

- new `src/integrity.ts`
- verify-side checks for:
  - artifact file existence
  - screenshot sha256 and duplicate detection
  - timestamp monotonicity
  - batch-write heuristics
  - app launcher heuristics from screenshots
  - action/assert/artifact linkage checks
- change `audit` so self-attested-only runs become `unverified`
- block `snapshot save` unless integrity is at least `witnessed` or explicit override
- add integrity warnings to `report`

Files affected:

- `src/record.ts`
- `src/verify.ts`
- `src/reporter.ts`
- `src/snapshot.ts`
- `src/types.ts`
- `src/command-schema.ts`

This phase will not cryptographically prove reality, but it will catch the incident described.

### Phase 1: Witnessed recording path in agent-flow

Goal: move authority from external NDJSON to witnessed receipts.

Build:

- new witness API around `AgentBridge`
- new authoritative event types
- `record` path where `agent-flow` emits authoritative events for:
  - snapshot
  - command
  - screenshot
  - text query
- external stream remains allowed only for:
  - `note`
  - `agent-review`

Key rule:

- external agents may annotate, but they may not define the action history.

### Phase 2: Signed transport receipts in agent-flutter / agent-swift

Goal: offline cryptographic verification.

Build:

- transport session keypair
- per-command challenge/response signing
- receipt schema shared between transport and `agent-flow`
- offline verification in `src/verify.ts`

Recommended crypto:

- `ed25519`
- canonical JSON encoding
- signature over `event_hash`

### Phase 3: Transparency and CI-grade trust

Goal: strong hosted trust and auditability.

Build:

- notarize chain head during `record finish` or `push`
- hosted report distinguishes:
  - local witnessed
  - signed local
  - signed + notarized

### Phase 4: Optional device-bound attestation

Goal: further increase attacker cost where platform support exists.

Ideas:

- Android Keystore-backed key in transport layer
- simulator/device identity pinning
- signed app-foreground attestations

This is useful, but not necessary for the next phase.

## Trade-offs

### Storage and performance

- raw snapshots and artifact hashes increase run size
- pre/post snapshots add latency
- perceptual hashing and OCR cost CPU

These are acceptable for auditability. Verification quality matters more than marginal run speed.

### Agent autonomy

- agents lose the ability to invent the action record
- they keep autonomy over strategy and semantic review

That is the right boundary. Autonomy should exist above the transport log, not instead of it.

### Backward compatibility

- legacy v3 runs can still be read
- but they should never be labeled equivalent to signed/witnessed v4 runs
- reports must visibly mark them `SELF-ATTESTED`

### Residual limitation

If the attacker controls:

- the host
- the `agent-flow` witness
- the transport binary
- the signing key material

then no offline scheme in this repo can prove reality.

This design intentionally targets the realistic failure mode:

- untrusted agent narrative
- honest witness / transport
- offline verifier later

## Concrete Recommendations for the Next Phase Program

1. Add `integrityResult` and `integrityIssues` to `VerifyResult`.
2. Make `audit` return `unverified` when the run has no witnessed evidence.
3. Add screenshot hashing, duplicate detection, and launcher heuristics to `verify`.
4. Prevent `snapshot save` from consuming self-attested runs.
5. Add authoritative witness events for snapshots, commands, and artifacts.
6. Extend `AgentBridge` and `agent-flutter` to emit signed transport receipts.
7. Update `report` so integrity status is as visible as pass/fail.

## Bottom Line

The current system fails because it treats a self-written story as evidence.

The fix is not “more checks on the story”. The fix is:

- witness the transport
- chain and sign the receipts
- make integrity a first-class verification result
- degrade self-attested runs to `unverified`
- use passive artifact forensics to catch cheap fraud immediately

That combination gives `agent-flow` a credible long-term anti-fabrication model while preserving offline verification.
