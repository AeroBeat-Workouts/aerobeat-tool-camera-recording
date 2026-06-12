# AeroBeat Tool Camera Recording

This repo owns the **durable saved-session artifact contract** for AeroBeat camera-tracking exports.

Slice 1 intentionally stops at **package/bootstrap truth**. It does **not** implement replay, live capture orchestration, or video re-inference yet. Instead, it freezes the saved-session package shape, the v1 `session_manifest.json` contract, the `tracking/pose_frames.jsonl` writer contract, and the minimal validation/generation helpers that later Slice 2 work will build on.

The contract here is driven by the frozen parent plan at:

- `/home/derrick/.openclaw/workspace/projects/aerobeat/.plans/2026-06-10-boxing-pose-classifier-and-recording-plan.md`

## Current contract scope

- repo-specific `CameraRecordingManager` entry surface for saved-session package bootstrap work
- v1 `session_manifest.json` normalization + validation helpers
- v1 `tracking/pose_frames.jsonl` normalization + validation helpers
- saved-session folder/layout validation for B-first `saved_tracking_frames` packages
- support for structurally validating A-second `video_reinference` manifests without implementing replay itself
- canonical example saved-session package under `examples/saved_sessions/`
- headless helper scripts for generating a package skeleton and validating a saved-session package

## Repo boundary

This repo **does own**:
- saved-session package layout and artifact manifest truth
- pose-frame persistence contract and machine checks
- source/truth/debug artifact path semantics inside the saved-session package
- bootstrap helpers that create a structurally valid package skeleton

This repo **does not own yet**:
- replay execution
- vendor inference
- `aerobeat-tool-camera-tracking` session lifecycle truth
- gameplay gesture interpretation
- prototype matching or learned classifier logic

## Frozen package layout

```text
<session-root>/
  session_manifest.json
  source/
    source_video.mp4                # optional for Slice 1; expected later for video_reinference packages
    source_info.json                # optional
  tracking/
    pose_frames.jsonl               # required
    hand_frames.jsonl               # optional, not required in Slice 1
    tracking_summary.json           # optional
  truth/
    timing_truth.yaml               # optional, expected for fixture-linked sessions when known
    labels.yaml                     # optional later/manual augmentation
  debug/
    export_summary.json             # optional
  notes/
    operator_notes.md               # optional
```

`session_manifest.json` is the only canonical entrypoint. Downstream work must resolve artifacts from the manifest instead of guessing by filename.

## Manifest highlights

Required top-level manifest fields:
- `schema_version`
- `session_id`
- `take_id`
- `created_at`
- `source_kind`
- `artifacts.pose_frames`
- `tracking_contract.backend_id`
- `tracking_contract.normalized_schema_version`
- `tracking_contract.frame_count`
- `tracking_contract.timestamp_mode`
- `replay_contract.replay_mode`
- `replay_contract.entrypoint`

Current supported `source_kind` values:
- `live_camera`
- `video_file`
- `fixture_replay`

Current supported `replay_contract.replay_mode` values:
- `saved_tracking_frames`
- `video_reinference`

## Pose-frame JSONL highlights

Each `tracking/pose_frames.jsonl` line is one JSON object with these required fields:
- `frame_index`
- `timestamp_ms`
- `timestamp_seconds`
- `tracking_state`
- `landmarks`

Each landmark object currently requires:
- `id` — canonical semantic landmark name string, for example `left_shoulder`
- `x`
- `y`
- `z`
- `v`

This intentionally freezes the saved-session recording format around semantic landmark IDs instead of raw vendor-private payloads.

## Canonical example package

See:
- `examples/saved_sessions/boxing_straight_left_take_01/session_manifest.json`
- `examples/saved_sessions/boxing_straight_left_take_01/tracking/pose_frames.jsonl`

These are the canonical Slice 1 examples used by tests and validation.

## GodotEnv development flow

This repo follows the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`

### Restore dev/test dependencies

From the repo root:

```bash
cd .testbed
godotenv addons install
```

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run repo-local tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

### Validate a saved-session package from the CLI

From the repo root:

```bash
godot --headless --path .testbed \
  --script res://addons/aerobeat-tool-camera-recording/scripts/validate_saved_session.gd \
  -- --session-root ../examples/saved_sessions/boxing_straight_left_take_01
```

### Generate a saved-session package skeleton from the CLI

From the repo root:

```bash
godot --headless --path .testbed \
  --script res://addons/aerobeat-tool-camera-recording/scripts/write_example_saved_session.gd \
  -- --output-root ../.tmp/generated_saved_session
```

## Additional contract docs

- `docs/saved-session-contract.md` — frozen Slice 1 contract details, required/optional files, and validation rules
