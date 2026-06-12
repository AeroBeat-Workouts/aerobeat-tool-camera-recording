# Saved Session Contract v1

This document freezes the Slice 1 package contract for `aerobeat-tool-camera-recording`.

## Scope

This contract is intentionally about **saved-session package truth only**:
- package layout
- manifest semantics
- pose-frame JSONL semantics
- validation rules
- bootstrap/generation expectations

It does **not** yet define replay behavior, transport controls, or live-recording orchestration.

## Canonical entrypoint

Every saved-session package is rooted by:
- `session_manifest.json`

Consumers must resolve package artifacts from that manifest rather than hardcoding filenames.

## Folder layout

```text
<session-root>/
  session_manifest.json
  source/
    source_video.mp4
    source_info.json
  tracking/
    pose_frames.jsonl
    hand_frames.jsonl
    tracking_summary.json
  truth/
    timing_truth.yaml
    labels.yaml
  debug/
    export_summary.json
  notes/
    operator_notes.md
```

### Required now

- `session_manifest.json`
- `tracking/pose_frames.jsonl`
- `tracking/` directory

### Optional now

- `source/`
- `truth/`
- `debug/`
- `notes/`
- every file inside those directories unless the manifest references it

## Manifest contract

Required fields:

- `schema_version` — must be `1`
- `session_id` — stable saved-session identifier
- `take_id` — stable per-take identifier
- `created_at` — ISO-8601 UTC timestamp string
- `source_kind` — `live_camera` | `video_file` | `fixture_replay`
- `artifacts.pose_frames` — relative path to the JSONL frame stream
- `tracking_contract.backend_id` — upstream tracking backend ID, for example `mediapipe_python`
- `tracking_contract.normalized_schema_version` — must be `1` for Slice 1
- `tracking_contract.frame_count` — total JSONL frame count
- `tracking_contract.timestamp_mode` — timestamp basis, for example `video_time_ms`
- `replay_contract.replay_mode` — `saved_tracking_frames` | `video_reinference`
- `replay_contract.entrypoint` — relative path used by the later replay reader

Normalized metadata fields preserved across live, replay/video-file, and fixture-replay exports:
- `source_contract.source_path`
- `source_contract.camera_id`
- `source_contract.selected_path`
- `source_contract.fixture_id`
- `truth_contract.timing_truth_path`
- `truth_contract.timing_truth_source_path`
- `truth_contract.label_context`

### Path rules

Artifact paths must:
- be relative to the session root
- not be absolute
- not contain `../`

### Replay rules frozen now

- `saved_tracking_frames` packages must use `replay_contract.entrypoint == artifacts.pose_frames`
- `video_reinference` packages must declare `artifacts.source_video`
- if `artifacts.timing_truth` is declared, `truth_contract.timing_truth_path` must be present and match it exactly
- if `truth_contract.timing_truth_path` is set, `artifacts.timing_truth` must also be declared
- Slice 1 validates those structural rules without implementing replay

## Pose-frame JSONL contract

One line = one JSON object.

Required record fields:
- `frame_index` — zero-based sequential integer
- `timestamp_ms` — non-negative integer timestamp
- `timestamp_seconds` — non-negative float timestamp
- `tracking_state` — one of `idle`, `tracked`, `tracking_lost`, `reacquiring`, `error`
- `landmarks` — array of canonical landmarks

Optional record fields:
- `frame_size.width`
- `frame_size.height`
- `source_timestamp_ms`
- `source_id`
- `hands`

### Landmark contract

Each landmark object requires:
- `id` — semantic landmark name string, for example `left_shoulder`
- `x` — normalized 0..1 horizontal coordinate
- `y` — normalized 0..1 vertical coordinate
- `z` — depth-like value preserved from the normalized tracking contract
- `v` — visibility/confidence-like value normalized to 0..1

### Frame sequencing rules

- `frame_index` must advance by exactly `1` per JSONL line
- frame_index must advance by exactly `1` across the saved-session stream
- when `tracking_state == tracked`, `landmarks` must contain at least one landmark object
- `tracking_contract.frame_count` must match the JSONL line count on disk

## Canonical example manifest

```json
{
  "schema_version": 1,
  "session_id": "boxing_straight_left_take_01",
  "take_id": "take_01",
  "created_at": "2026-06-11T16:00:00Z",
  "source_kind": "fixture_replay",
  "artifacts": {
    "pose_frames": "tracking/pose_frames.jsonl",
    "timing_truth": "truth/timing_truth.yaml"
  },
  "tracking_contract": {
    "backend_id": "mediapipe_python",
    "normalized_schema_version": 1,
    "frame_count": 3,
    "timestamp_mode": "video_time_ms"
  },
  "source_contract": {
    "source_path": "fixtures/boxing/straight_left/straight_left_take_01.mp4"
  },
  "truth_contract": {
    "timing_truth_path": "truth/timing_truth.yaml",
    "label_context": "boxing_side_aware_punches_v1"
  },
  "debug_contract": {},
  "replay_contract": {
    "replay_mode": "saved_tracking_frames",
    "entrypoint": "tracking/pose_frames.jsonl"
  }
}
```

## Canonical example pose-frame line

```json
{"frame_index":1,"timestamp_ms":1866,"timestamp_seconds":1.866,"tracking_state":"tracked","frame_size":{"width":1280,"height":720},"landmarks":[{"id":"left_shoulder","x":0.42,"y":0.31,"z":-0.12,"v":0.98},{"id":"left_elbow","x":0.47,"y":0.36,"z":-0.09,"v":0.97},{"id":"left_wrist","x":0.56,"y":0.34,"z":-0.02,"v":0.95}]}
```

## Validation helpers

Machine-check helpers live in:
- `src/validation/SavedSessionValidator.gd`
- `scripts/validate_saved_session.gd`
- `scripts/write_example_saved_session.gd`

The validator currently checks:
- required package layout exists
- manifest parses and matches the frozen v1 contract
- manifest artifact paths exist on disk
- pose-frame JSONL lines parse and match the frozen record shape
- `frame_index` increments sequentially
- manifest frame count matches the JSONL line count
- `video_reinference` manifests only validate when `artifacts.source_video` is declared and present
- timing-truth linkage stays internally consistent between `artifacts.timing_truth` and `truth_contract.timing_truth_path`

## Slice 2 coder assumptions now frozen

A separate Slice 2 coder should be able to assume:
- the saved-session package entrypoint is always `session_manifest.json`
- B-mode replay consumes `tracking/pose_frames.jsonl` through `replay_contract.entrypoint`
- A-mode replay will be opt-in via `replay_contract.replay_mode == video_reinference`
- semantic landmark IDs, not vendor-private blobs, are the saved contract surface
- optional artifacts may grow, but the package shape should not fork by source kind
