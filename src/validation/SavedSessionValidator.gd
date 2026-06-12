class_name SavedSessionValidator
extends RefCounted

const MANIFEST_FILE_NAME := "session_manifest.json"
const REQUIRED_DIRECTORIES := ["tracking"]
const OPTIONAL_DIRECTORIES := ["source", "truth", "debug", "notes"]

static func validate_session_root(session_root: String) -> Dictionary:
	var result := {
		"ok": true,
		"session_root": session_root,
		"errors": [],
		"warnings": [],
		"summary": {},
	}

	if session_root == "":
		_push_error(result, "session root path must be non-empty")
		return _finalize(result)
	if not DirAccess.dir_exists_absolute(session_root):
		_push_error(result, "session root does not exist: %s" % session_root)
		return _finalize(result)

	for directory_name in REQUIRED_DIRECTORIES:
		var directory_path := "%s/%s" % [session_root, directory_name]
		if not DirAccess.dir_exists_absolute(directory_path):
			_push_error(result, "missing required directory: %s" % directory_name)

	var manifest_path := "%s/%s" % [session_root, MANIFEST_FILE_NAME]
	if not FileAccess.file_exists(manifest_path):
		_push_error(result, "missing required file: %s" % MANIFEST_FILE_NAME)
		return _finalize(result)

	var manifest_parse := _read_json_file(manifest_path)
	if not manifest_parse.get("ok", false):
		_push_error(result, "session_manifest.json parse error: %s" % manifest_parse.get("error", "unknown error"))
		return _finalize(result)

	var manifest: Dictionary = manifest_parse.get("data", {})
	for error_text in SessionManifestV1.validate(manifest):
		_push_error(result, error_text)

	var artifacts: Dictionary = manifest.get("artifacts", {}) if manifest.get("artifacts", {}) is Dictionary else {}
	for artifact_key in artifacts.keys():
		var artifact_path := str(artifacts.get(artifact_key, ""))
		if artifact_path == "":
			continue
			
		var absolute_artifact_path := "%s/%s" % [session_root, artifact_path]
		if not FileAccess.file_exists(absolute_artifact_path):
			_push_error(result, "manifest artifact missing on disk: %s -> %s" % [artifact_key, artifact_path])

	var pose_frames_path := "%s/%s" % [session_root, str(artifacts.get("pose_frames", "tracking/pose_frames.jsonl"))]
	if FileAccess.file_exists(pose_frames_path):
		var pose_result := _validate_pose_frames_file(pose_frames_path)
		for error_text in pose_result.get("errors", []):
			_push_error(result, error_text)
		result["summary"]["pose_frame_count"] = int(pose_result.get("frame_count", 0))
		var manifest_frame_count := int((manifest.get("tracking_contract", {}) if manifest.get("tracking_contract", {}) is Dictionary else {}).get("frame_count", -1))
		if manifest_frame_count != int(pose_result.get("frame_count", 0)):
			_push_error(result, "session_manifest.json: `tracking_contract.frame_count` (%d) does not match pose frame count on disk (%d)" % [manifest_frame_count, int(pose_result.get("frame_count", 0))])
	else:
		_push_error(result, "missing pose frame stream: %s" % pose_frames_path)

	var replay_contract: Dictionary = manifest.get("replay_contract", {}) if manifest.get("replay_contract", {}) is Dictionary else {}
	var replay_mode := str(replay_contract.get("replay_mode", ""))
	if replay_mode == "video_reinference":
		var source_video_path := str(artifacts.get("source_video", ""))
		if source_video_path == "":
			_push_error(result, "video_reinference sessions must declare `artifacts.source_video`")
		elif not FileAccess.file_exists("%s/%s" % [session_root, source_video_path]):
			_push_error(result, "video_reinference source video is missing on disk: %s" % source_video_path)

	result["summary"]["manifest_path"] = manifest_path
	result["summary"]["replay_mode"] = replay_mode
	result["summary"]["source_kind"] = str(manifest.get("source_kind", ""))
	result["summary"]["frame_count"] = int((manifest.get("tracking_contract", {}) if manifest.get("tracking_contract", {}) is Dictionary else {}).get("frame_count", 0))

	return _finalize(result)

static func _validate_pose_frames_file(pose_frames_path: String) -> Dictionary:
	var result := {
		"ok": true,
		"errors": [],
		"frame_count": 0,
	}
	var file := FileAccess.open(pose_frames_path, FileAccess.READ)
	if file == null:
		result["ok"] = false
		result["errors"] = ["unable to open pose frame stream: %s" % pose_frames_path]
		return result

	var previous_frame_index := -1
	while not file.eof_reached():
		var raw_line := file.get_line()
		if raw_line.strip_edges() == "":
			continue
		var json := JSON.new()
		var parse_error := json.parse(raw_line)
		if parse_error != OK:
			result["errors"].append("pose_frames.jsonl line %d: invalid JSON (%s)" % [result["frame_count"] + 1, json.get_error_message()])
			continue
		if not json.data is Dictionary:
			result["errors"].append("pose_frames.jsonl line %d: root value must be an object" % [result["frame_count"] + 1])
			continue
		var record: Dictionary = json.data
		result["errors"].append_array(PoseFrameRecord.validate(record, result["frame_count"] + 1))
		var frame_index := int(record.get("frame_index", -1))
		if previous_frame_index >= 0 and frame_index != previous_frame_index + 1:
			result["errors"].append("pose_frames.jsonl line %d: `frame_index` must advance sequentially by 1 (expected %d, got %d)" % [result["frame_count"] + 1, previous_frame_index + 1, frame_index])
		previous_frame_index = frame_index
		result["frame_count"] = int(result["frame_count"]) + 1

	result["ok"] = (result["errors"] as Array).is_empty()
	return result

static func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "unable to open file", "data": {}}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		return {"ok": false, "error": json.get_error_message(), "data": {}}
	if not json.data is Dictionary:
		return {"ok": false, "error": "root value must be an object", "data": {}}
	return {"ok": true, "data": json.data}

static func _push_error(result: Dictionary, message: String) -> void:
	var errors: Array = result.get("errors", [])
	errors.append(message)
	result["errors"] = errors

static func _finalize(result: Dictionary) -> Dictionary:
	var errors: Array = result.get("errors", [])
	result["ok"] = errors.is_empty()
	return result
