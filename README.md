# AeroBeat Tool Camera Recording

This repo owns the **durable saved-session artifact contract** for AeroBeat camera-tracking exports.

It owns the current saved-session writer flow for tracker-produced normalized frames: live-camera and video-file sessions can be exported into truthful `session_manifest.json` + `tracking/pose_frames.jsonl` packages, with manifest-declared `source/source_info.json` metadata for the real export path. This repo still does **not** own replay execution or A-mode video re-inference.

## Current contract scope

- repo-specific `CameraRecordingManager` entry surface for saved-session package bootstrap and truthful tracker-frame export work
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
- tracker-frame export helpers that write truthful saved-session artifacts from supported live-camera and video-file tracking flows

This repo **does not own yet**:
- replay execution
- vendor inference
- A-mode `video_reinference` implementation
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
- `id` — stable landmark identifier string as written by the export flow (for real tracker exports this is the tracker landmark ID serialized as text, for example `"15"`)
- `x`
- `y`
- `z`
- `v`

This intentionally freezes the saved-session recording format around tool-owned normalized landmark IDs instead of raw vendor-private payloads.

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

### Truthful Slice 2 export API

`CameraRecordingManager.export_saved_session_from_tracking_frames(session_root, tracking_config, tracking_frames, options := {})` now writes a real saved-session package from normalized tracker output.

Current supported real export flows:
- `source.kind = live_camera`
- `source.kind = video_file`
- fixture-linked replay exports via `options.source_kind = fixture_replay`

Current real export artifacts:
- `session_manifest.json`
- `tracking/pose_frames.jsonl`
- `source/source_info.json`
- optional `truth/timing_truth.yaml` when timing truth is linked

Slice 3 parity rule now enforced in code/tests:
- live-camera and replay/video-file exports keep the same saved-session contract shape
- source differences stay in manifest/source metadata (`source_kind`, `source_contract`, `source_info`)
- fixture-linked replay can attach timing truth through `truth_contract` + `artifacts.timing_truth` without forking the package layout

The replay contract remains manifest-driven and B-first:
- `replay_contract.replay_mode = saved_tracking_frames`
- `replay_contract.entrypoint = artifacts.pose_frames`

## Additional contract docs

- `docs/saved-session-contract.md` — frozen Slice 1 contract details, required/optional files, and validation rules
