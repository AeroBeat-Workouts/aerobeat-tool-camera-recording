class_name CameraRecordingManager
extends Node

signal initialized

const VERSION := "0.1.0"
const DEFAULT_SESSION_ID := "boxing_straight_left_take_01"
const DEFAULT_TAKE_ID := "take_01"

var _is_initialized := false

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	initialized.emit()

static func build_example_manifest() -> Dictionary:
	return SessionManifestV1.normalize({
		"schema_version": SessionManifestV1.SCHEMA_VERSION,
		"session_id": DEFAULT_SESSION_ID,
		"take_id": DEFAULT_TAKE_ID,
		"created_at": "2026-06-11T16:00:00Z",
		"source_kind": "fixture_replay",
		"artifacts": {
			"pose_frames": "tracking/pose_frames.jsonl",
			"timing_truth": "truth/timing_truth.yaml"
		},
		"tracking_contract": {
			"backend_id": "mediapipe_python",
			"normalized_schema_version": PoseFrameRecord.SCHEMA_VERSION,
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
	})

static func build_example_pose_frames() -> Array[Dictionary]:
	return [
		PoseFrameRecord.normalize({
			"frame_index": 0,
			"timestamp_ms": 1833,
			"timestamp_seconds": 1.833,
			"tracking_state": "tracked",
			"frame_size": {"width": 1280, "height": 720},
			"landmarks": [
				{"id": "left_shoulder", "x": 0.42, "y": 0.31, "z": -0.12, "v": 0.98},
				{"id": "left_elbow", "x": 0.46, "y": 0.35, "z": -0.10, "v": 0.97},
				{"id": "left_wrist", "x": 0.52, "y": 0.34, "z": -0.04, "v": 0.96}
			]
		}),
		PoseFrameRecord.normalize({
			"frame_index": 1,
			"timestamp_ms": 1866,
			"timestamp_seconds": 1.866,
			"tracking_state": "tracked",
			"frame_size": {"width": 1280, "height": 720},
			"landmarks": [
				{"id": "left_shoulder", "x": 0.42, "y": 0.31, "z": -0.12, "v": 0.98},
				{"id": "left_elbow", "x": 0.47, "y": 0.36, "z": -0.09, "v": 0.97},
				{"id": "left_wrist", "x": 0.56, "y": 0.34, "z": -0.02, "v": 0.95}
			]
		}),
		PoseFrameRecord.normalize({
			"frame_index": 2,
			"timestamp_ms": 1900,
			"timestamp_seconds": 1.9,
			"tracking_state": "tracked",
			"frame_size": {"width": 1280, "height": 720},
			"landmarks": [
				{"id": "left_shoulder", "x": 0.43, "y": 0.31, "z": -0.11, "v": 0.98},
				{"id": "left_elbow", "x": 0.47, "y": 0.36, "z": -0.09, "v": 0.97},
				{"id": "left_wrist", "x": 0.56, "y": 0.34, "z": -0.02, "v": 0.95}
			]
		})
	]

static func create_saved_session_package(session_root: String, manifest: Dictionary = {}, pose_frames: Array = [], timing_truth_text: String = "") -> Dictionary:
	var resolved_manifest := build_example_manifest() if manifest.is_empty() else SessionManifestV1.normalize(manifest)
	var resolved_pose_frames := build_example_pose_frames() if pose_frames.is_empty() else pose_frames
	var required_directories := [
		session_root,
		"%s/tracking" % session_root,
	]
	var artifacts: Dictionary = resolved_manifest.get("artifacts", {}) if resolved_manifest.get("artifacts", {}) is Dictionary else {}
	if str(artifacts.get("timing_truth", "")) != "":
		required_directories.append("%s/truth" % session_root)
	if str(artifacts.get("source_video", "")) != "" or str(artifacts.get("source_info", "")) != "":
		required_directories.append("%s/source" % session_root)
	if str(artifacts.get("export_summary", "")) != "":
		required_directories.append("%s/debug" % session_root)
	if str(artifacts.get("operator_notes", "")) != "":
		required_directories.append("%s/notes" % session_root)
	for directory_path in required_directories:
		var make_error := DirAccess.make_dir_recursive_absolute(directory_path)
		if make_error != OK:
			return {"ok": false, "errors": ["failed to create directory: %s" % directory_path]}

	resolved_manifest["tracking_contract"]["frame_count"] = resolved_pose_frames.size()
	var manifest_errors := SessionManifestV1.validate(resolved_manifest)
	if not manifest_errors.is_empty():
		return {"ok": false, "errors": manifest_errors}

	var manifest_write := _write_text_file("%s/session_manifest.json" % session_root, SessionManifestV1.to_json(resolved_manifest))
	if not manifest_write.get("ok", false):
		return manifest_write

	var pose_lines: PackedStringArray = []
	for pose_frame_variant in resolved_pose_frames:
		if pose_frame_variant is Dictionary:
			pose_lines.append(PoseFrameRecord.to_json_line(pose_frame_variant))
	var pose_write := _write_text_file("%s/%s" % [session_root, str(artifacts.get("pose_frames", "tracking/pose_frames.jsonl"))], "\n".join(pose_lines) + "\n")
	if not pose_write.get("ok", false):
		return pose_write

	if str(artifacts.get("timing_truth", "")) != "":
		var truth_text := timing_truth_text
		if truth_text == "":
			truth_text = "events:\n  - label: straight_left\n    start_ms: 1833\n    end_ms: 1900\n"
		var truth_write := _write_text_file("%s/%s" % [session_root, str(artifacts.get("timing_truth", ""))], truth_text)
		if not truth_write.get("ok", false):
			return truth_write

	return SavedSessionValidator.validate_session_root(session_root)

static func validate_saved_session_package(session_root: String) -> Dictionary:
	return SavedSessionValidator.validate_session_root(session_root)

static func _write_text_file(path: String, content: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["failed to open file for write: %s" % path]}
	file.store_string(content)
	return {"ok": true}
