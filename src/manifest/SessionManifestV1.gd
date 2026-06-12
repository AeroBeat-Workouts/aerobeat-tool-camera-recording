class_name SessionManifestV1
extends RefCounted

const SCHEMA_VERSION := 1
const SOURCE_KINDS := ["live_camera", "video_file", "fixture_replay"]
const REPLAY_MODES := ["saved_tracking_frames", "video_reinference"]
const REQUIRED_TOP_LEVEL_KEYS := [
	"schema_version",
	"session_id",
	"take_id",
	"created_at",
	"source_kind",
	"artifacts",
	"tracking_contract",
	"replay_contract",
]

static func normalize(manifest: Dictionary) -> Dictionary:
	var normalized: Dictionary = {
		"schema_version": int(manifest.get("schema_version", SCHEMA_VERSION)),
		"session_id": str(manifest.get("session_id", "")),
		"take_id": str(manifest.get("take_id", "")),
		"created_at": str(manifest.get("created_at", "")),
		"source_kind": str(manifest.get("source_kind", "")),
		"artifacts": _normalize_artifacts(manifest.get("artifacts", {}) if manifest.get("artifacts", {}) is Dictionary else {}),
		"tracking_contract": _normalize_tracking_contract(manifest.get("tracking_contract", {}) if manifest.get("tracking_contract", {}) is Dictionary else {}),
		"source_contract": (manifest.get("source_contract", {}) if manifest.get("source_contract", {}) is Dictionary else {}).duplicate(true),
		"truth_contract": (manifest.get("truth_contract", {}) if manifest.get("truth_contract", {}) is Dictionary else {}).duplicate(true),
		"debug_contract": (manifest.get("debug_contract", {}) if manifest.get("debug_contract", {}) is Dictionary else {}).duplicate(true),
		"replay_contract": _normalize_replay_contract(manifest.get("replay_contract", {}) if manifest.get("replay_contract", {}) is Dictionary else {}),
	}
	return normalized

static func validate(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_TOP_LEVEL_KEYS:
		if not manifest.has(key):
			errors.append("session_manifest.json: missing required field `%s`" % key)

	if manifest.has("schema_version") and int(manifest.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("session_manifest.json: `schema_version` must be %d" % SCHEMA_VERSION)
	if str(manifest.get("session_id", "")) == "":
		errors.append("session_manifest.json: `session_id` must be a non-empty string")
	if str(manifest.get("take_id", "")) == "":
		errors.append("session_manifest.json: `take_id` must be a non-empty string")
	if not _looks_like_iso8601(str(manifest.get("created_at", ""))):
		errors.append("session_manifest.json: `created_at` must look like an ISO-8601 UTC timestamp")
	if not SOURCE_KINDS.has(str(manifest.get("source_kind", ""))):
		errors.append("session_manifest.json: `source_kind` must be one of %s" % [", ".join(SOURCE_KINDS)])

	var artifacts: Dictionary = manifest.get("artifacts", {}) if manifest.get("artifacts", {}) is Dictionary else {}
	if str(artifacts.get("pose_frames", "")) == "":
		errors.append("session_manifest.json: `artifacts.pose_frames` is required")
	else:
		errors.append_array(_validate_relative_path(str(artifacts.get("pose_frames", "")), "session_manifest.json: `artifacts.pose_frames`"))

	for optional_artifact in ["source_video", "source_info", "timing_truth", "labels", "tracking_summary", "export_summary", "operator_notes", "hand_frames"]:
		if artifacts.has(optional_artifact):
			errors.append_array(_validate_relative_path(str(artifacts.get(optional_artifact, "")), "session_manifest.json: `artifacts.%s`" % optional_artifact))

	var tracking_contract: Dictionary = manifest.get("tracking_contract", {}) if manifest.get("tracking_contract", {}) is Dictionary else {}
	if str(tracking_contract.get("backend_id", "")) == "":
		errors.append("session_manifest.json: `tracking_contract.backend_id` is required")
	if int(tracking_contract.get("normalized_schema_version", -1)) != PoseFrameRecord.SCHEMA_VERSION:
		errors.append("session_manifest.json: `tracking_contract.normalized_schema_version` must be %d" % PoseFrameRecord.SCHEMA_VERSION)
	if int(tracking_contract.get("frame_count", -1)) < 0:
		errors.append("session_manifest.json: `tracking_contract.frame_count` must be >= 0")
	if str(tracking_contract.get("timestamp_mode", "")) == "":
		errors.append("session_manifest.json: `tracking_contract.timestamp_mode` is required")

	var replay_contract: Dictionary = manifest.get("replay_contract", {}) if manifest.get("replay_contract", {}) is Dictionary else {}
	var replay_mode := str(replay_contract.get("replay_mode", ""))
	if not REPLAY_MODES.has(replay_mode):
		errors.append("session_manifest.json: `replay_contract.replay_mode` must be one of %s" % [", ".join(REPLAY_MODES)])
	var entrypoint := str(replay_contract.get("entrypoint", ""))
	if entrypoint == "":
		errors.append("session_manifest.json: `replay_contract.entrypoint` is required")
	else:
		errors.append_array(_validate_relative_path(entrypoint, "session_manifest.json: `replay_contract.entrypoint`"))
	if replay_mode == "saved_tracking_frames" and entrypoint != str(artifacts.get("pose_frames", "")):
		errors.append("session_manifest.json: `replay_contract.entrypoint` must match `artifacts.pose_frames` for `saved_tracking_frames`")
	if replay_mode == "video_reinference" and str(artifacts.get("source_video", "")) == "":
		errors.append("session_manifest.json: `artifacts.source_video` is required when `replay_contract.replay_mode` is `video_reinference`")

	return errors

static func to_json(manifest: Dictionary) -> String:
	return JSON.stringify(normalize(manifest), "\t") + "\n"

static func _normalize_artifacts(artifacts: Dictionary) -> Dictionary:
	var normalized := artifacts.duplicate(true)
	if not normalized.has("pose_frames"):
		normalized["pose_frames"] = "tracking/pose_frames.jsonl"
	return normalized

static func _normalize_tracking_contract(contract: Dictionary) -> Dictionary:
	return {
		"backend_id": str(contract.get("backend_id", "")),
		"normalized_schema_version": int(contract.get("normalized_schema_version", PoseFrameRecord.SCHEMA_VERSION)),
		"frame_count": int(contract.get("frame_count", 0)),
		"timestamp_mode": str(contract.get("timestamp_mode", "")),
	}

static func _normalize_replay_contract(contract: Dictionary) -> Dictionary:
	return {
		"replay_mode": str(contract.get("replay_mode", "saved_tracking_frames")),
		"entrypoint": str(contract.get("entrypoint", "tracking/pose_frames.jsonl")),
	}

static func _looks_like_iso8601(value: String) -> bool:
	return value.length() >= 20 and value.ends_with("Z") and value.contains("T")

static func _validate_relative_path(path: String, label: String) -> Array[String]:
	var errors: Array[String] = []
	if path == "":
		errors.append(label + " must be a non-empty relative path")
		return errors
	if path.begins_with("/"):
		errors.append(label + " must be relative, not absolute")
	if path.contains("../") or path == "..":
		errors.append(label + " must not escape the session root")
	return errors
