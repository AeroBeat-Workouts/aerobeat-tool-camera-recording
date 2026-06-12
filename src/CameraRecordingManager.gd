class_name CameraRecordingManager
extends Node

signal initialized

const VERSION := "0.2.0"
const DEFAULT_SESSION_ID := "boxing_straight_left_take_01"
const DEFAULT_TAKE_ID := "take_01"
const DEFAULT_SOURCE_INFO_ARTIFACT := "source/source_info.json"

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

static func build_example_pose_frames() -> Array:
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

static func create_saved_session_package(session_root: String, manifest: Dictionary = {}, pose_frames: Array = [], timing_truth_text: String = "", extra_artifact_text: Dictionary = {}) -> Dictionary:
	var resolved_manifest := build_example_manifest() if manifest.is_empty() else SessionManifestV1.normalize(manifest)
	var resolved_pose_frames: Array = build_example_pose_frames() if pose_frames.is_empty() else pose_frames
	var required_directories := [
		session_root,
		"%s/tracking" % session_root,
	]
	var artifacts: Dictionary = resolved_manifest.get("artifacts", {}) if resolved_manifest.get("artifacts", {}) is Dictionary else {}
	if str(artifacts.get("timing_truth", "")) != "":
		required_directories.append("%s/truth" % session_root)
	if str(artifacts.get("source_video", "")) != "" or str(artifacts.get("source_info", "")) != "":
		required_directories.append("%s/source" % session_root)
	if str(artifacts.get("export_summary", "")) != "" or str(artifacts.get("tracking_summary", "")) != "":
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

	for artifact_key in extra_artifact_text.keys():
		var relative_path := str(artifacts.get(str(artifact_key), "")).strip_edges()
		if relative_path == "":
			continue
		var artifact_text := str(extra_artifact_text.get(artifact_key, ""))
		var artifact_write := _write_text_file("%s/%s" % [session_root, relative_path], artifact_text)
		if not artifact_write.get("ok", false):
			return artifact_write

	return SavedSessionValidator.validate_session_root(session_root)

static func validate_saved_session_package(session_root: String) -> Dictionary:
	return SavedSessionValidator.validate_session_root(session_root)

static func pose_frame_record_from_tracking_frame(tracking_frame: Dictionary) -> Dictionary:
	var record := {
		"frame_index": int(tracking_frame.get("frame_index", 0)),
		"timestamp_ms": int(tracking_frame.get("timestamp_ms", 0)),
		"timestamp_seconds": float(tracking_frame.get("timestamp_seconds", 0.0)),
		"tracking_state": str(tracking_frame.get("tracking_state", "idle")),
		"landmarks": [],
	}
	if tracking_frame.has("source_timestamp_ms"):
		record["source_timestamp_ms"] = int(tracking_frame.get("source_timestamp_ms", 0))
	if tracking_frame.has("source_id"):
		record["source_id"] = str(tracking_frame.get("source_id", ""))
	var frame_size: Dictionary = tracking_frame.get("frame_size", {}) if tracking_frame.get("frame_size", {}) is Dictionary else {}
	if not frame_size.is_empty():
		record["frame_size"] = {
			"width": int(frame_size.get("width", frame_size.get("x", 0))),
			"height": int(frame_size.get("height", frame_size.get("y", 0))),
		}
	var landmarks: Array = tracking_frame.get("landmarks", []) if tracking_frame.get("landmarks", []) is Array else []
	for landmark_variant in landmarks:
		if landmark_variant is Dictionary:
			var landmark: Dictionary = landmark_variant
			record["landmarks"].append({
				"id": str(landmark.get("id", "")),
				"x": float(landmark.get("x", 0.0)),
				"y": float(landmark.get("y", 0.0)),
				"z": float(landmark.get("z", 0.0)),
				"v": float(landmark.get("v", landmark.get("visibility", 0.0))),
			})
	return PoseFrameRecord.normalize(record)

static func export_saved_session_from_tracking_frames(session_root: String, tracking_config: Dictionary, tracking_frames: Array, options: Dictionary = {}) -> Dictionary:
	var pose_frames: Array = []
	for tracking_frame_variant in tracking_frames:
		if tracking_frame_variant is Dictionary:
			pose_frames.append(pose_frame_record_from_tracking_frame(tracking_frame_variant))
	if pose_frames.is_empty():
		return {"ok": false, "errors": ["no tracking frames were provided for saved-session export"]}

	var manifest := _build_manifest_for_tracking_export(tracking_config, pose_frames, options)
	var source_info := _build_source_info_for_tracking_export(tracking_config, pose_frames, options)
	var extra_artifacts: Dictionary = {}
	if str((manifest.get("artifacts", {}) as Dictionary).get("source_info", "")) != "":
		extra_artifacts["source_info"] = JSON.stringify(source_info, "\t") + "\n"
	return create_saved_session_package(
		session_root,
		manifest,
		pose_frames,
		str(options.get("timing_truth_text", "")),
		extra_artifacts
	)

static func _build_manifest_for_tracking_export(tracking_config: Dictionary, pose_frames: Array, options: Dictionary) -> Dictionary:
	var config := tracking_config.duplicate(true)
	var source: Dictionary = config.get("source", {}) if config.get("source", {}) is Dictionary else {}
	var source_kind := str(options.get("source_kind", source.get("kind", "live_camera"))).strip_edges()
	var artifacts: Dictionary = {
		"pose_frames": "tracking/pose_frames.jsonl",
		"source_info": str(options.get("source_info_path", DEFAULT_SOURCE_INFO_ARTIFACT))
	}
	var timing_truth_path := str(options.get("timing_truth_path", "")).strip_edges()
	if timing_truth_path != "":
		artifacts["timing_truth"] = timing_truth_path
	var source_contract := {
		"source_path": str(options.get("source_path", source.get("path", source.get("camera_id", ""))))
	}
	if str(source.get("camera_id", "")) != "":
		source_contract["camera_id"] = str(source.get("camera_id", ""))
	if str(source.get("path", "")) != "":
		source_contract["selected_path"] = str(source.get("path", ""))
	var truth_contract := {}
	if timing_truth_path != "":
		truth_contract["timing_truth_path"] = timing_truth_path
	if str(options.get("label_context", "")).strip_edges() != "":
		truth_contract["label_context"] = str(options.get("label_context", ""))

	return SessionManifestV1.normalize({
		"schema_version": SessionManifestV1.SCHEMA_VERSION,
		"session_id": str(options.get("session_id", DEFAULT_SESSION_ID)),
		"take_id": str(options.get("take_id", DEFAULT_TAKE_ID)),
		"created_at": str(options.get("created_at", _current_utc_iso8601())),
		"source_kind": source_kind,
		"artifacts": artifacts,
		"tracking_contract": {
			"backend_id": _resolve_backend_id_for_export(config, options),
			"normalized_schema_version": PoseFrameRecord.SCHEMA_VERSION,
			"frame_count": pose_frames.size(),
			"timestamp_mode": str(options.get("timestamp_mode", _infer_timestamp_mode_from_source_kind(source_kind)))
		},
		"source_contract": source_contract,
		"truth_contract": truth_contract,
		"debug_contract": {},
		"replay_contract": {
			"replay_mode": "saved_tracking_frames",
			"entrypoint": "tracking/pose_frames.jsonl"
		}
	})

static func _build_source_info_for_tracking_export(tracking_config: Dictionary, pose_frames: Array, options: Dictionary) -> Dictionary:
	var config := tracking_config.duplicate(true)
	var source: Dictionary = config.get("source", {}) if config.get("source", {}) is Dictionary else {}
	var first_frame: Dictionary = pose_frames[0] if not pose_frames.is_empty() else {}
	var last_frame: Dictionary = pose_frames[-1] if not pose_frames.is_empty() else {}
	return {
		"source_kind": str(options.get("source_kind", source.get("kind", "live_camera"))),
		"backend_id": _resolve_backend_id_for_export(config, options),
		"camera_id": str(source.get("camera_id", "")),
		"source_path": str(options.get("source_path", source.get("path", source.get("camera_id", "")))),
		"frame_count": pose_frames.size(),
		"first_frame_index": int(first_frame.get("frame_index", 0)),
		"last_frame_index": int(last_frame.get("frame_index", 0)),
		"first_timestamp_ms": int(first_frame.get("timestamp_ms", 0)),
		"last_timestamp_ms": int(last_frame.get("timestamp_ms", 0)),
		"replay_mode": "saved_tracking_frames",
	}

static func _resolve_backend_id_for_export(tracking_config: Dictionary, options: Dictionary) -> String:
	if str(options.get("backend_id", "")).strip_edges() != "":
		return str(options.get("backend_id", ""))
	if str(tracking_config.get("backend_impl", "")).strip_edges() != "":
		return str(tracking_config.get("backend_impl", ""))
	if str(tracking_config.get("backend", "")).strip_edges() != "":
		return str(tracking_config.get("backend", ""))
		
	return "camera_tracking_default"

static func _infer_timestamp_mode_from_source_kind(source_kind: String) -> String:
	match source_kind:
		"video_file", "fixture_replay":
			return "video_time_ms"
		_:
			return "capture_time_ms"

static func _current_utc_iso8601() -> String:
	var parts := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		int(parts.get("year", 1970)),
		int(parts.get("month", 1)),
		int(parts.get("day", 1)),
		int(parts.get("hour", 0)),
		int(parts.get("minute", 0)),
		int(parts.get("second", 0)),
	]

static func _write_text_file(path: String, content: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["failed to open file for write: %s" % path]}
	file.store_string(content)
	return {"ok": true}
