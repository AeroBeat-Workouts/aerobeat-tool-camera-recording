class_name PoseFrameRecord
extends RefCounted

const SCHEMA_VERSION := 1
const ALLOWED_TRACKING_STATES := [
	"idle",
	"tracked",
	"tracking_lost",
	"reacquiring",
	"error"
]

static func normalize(record: Dictionary) -> Dictionary:
	var normalized: Dictionary = {
		"frame_index": int(record.get("frame_index", 0)),
		"timestamp_ms": int(record.get("timestamp_ms", 0)),
		"timestamp_seconds": float(record.get("timestamp_seconds", 0.0)),
		"tracking_state": str(record.get("tracking_state", "idle")),
		"landmarks": [],
	}

	if record.get("frame_size") is Dictionary:
		normalized["frame_size"] = _normalize_frame_size(record.get("frame_size", {}))
	if record.has("source_timestamp_ms"):
		normalized["source_timestamp_ms"] = int(record.get("source_timestamp_ms", 0))
	if record.has("source_id"):
		normalized["source_id"] = str(record.get("source_id", ""))
	if record.get("hands") is Array:
		normalized["hands"] = _normalize_hands(record.get("hands", []))

	var landmarks_variant: Variant = record.get("landmarks", [])
	if landmarks_variant is Array:
		for landmark_variant in landmarks_variant:
			if landmark_variant is Dictionary:
				normalized["landmarks"].append(_normalize_landmark(landmark_variant))

	return normalized

static func validate(record: Dictionary, line_number: int = -1) -> Array[String]:
	var errors: Array[String] = []
	var prefix := ""
	if line_number >= 0:
		prefix = "pose_frames.jsonl line %d: " % line_number

	if not record.has("frame_index"):
		errors.append(prefix + "missing required field `frame_index`")
	elif int(record.get("frame_index", -1)) < 0:
		errors.append(prefix + "`frame_index` must be >= 0")

	if not record.has("timestamp_ms"):
		errors.append(prefix + "missing required field `timestamp_ms`")
	elif int(record.get("timestamp_ms", -1)) < 0:
		errors.append(prefix + "`timestamp_ms` must be >= 0")

	if not record.has("timestamp_seconds"):
		errors.append(prefix + "missing required field `timestamp_seconds`")
	elif float(record.get("timestamp_seconds", -1.0)) < 0.0:
		errors.append(prefix + "`timestamp_seconds` must be >= 0")

	if not record.has("tracking_state"):
		errors.append(prefix + "missing required field `tracking_state`")
	else:
		var tracking_state := str(record.get("tracking_state", ""))
		if tracking_state == "":
			errors.append(prefix + "`tracking_state` must be a non-empty string")
		elif not ALLOWED_TRACKING_STATES.has(tracking_state):
			errors.append(prefix + "`tracking_state` must be one of %s" % [", ".join(ALLOWED_TRACKING_STATES)])

	if not record.has("landmarks"):
		errors.append(prefix + "missing required field `landmarks`")
	elif not record.get("landmarks") is Array:
		errors.append(prefix + "`landmarks` must be an array")
	else:
		var landmarks: Array = record.get("landmarks", [])
		if str(record.get("tracking_state", "idle")) == "tracked" and landmarks.is_empty():
			errors.append(prefix + "`landmarks` must contain at least one entry when `tracking_state` is `tracked`")
		for index in range(landmarks.size()):
			var landmark_variant: Variant = landmarks[index]
			if not landmark_variant is Dictionary:
				errors.append(prefix + "landmark %d must be an object" % index)
				continue
			errors.append_array(_validate_landmark(landmark_variant, prefix + "landmark %d: " % index))

	if record.has("frame_size"):
		if not record.get("frame_size") is Dictionary:
			errors.append(prefix + "`frame_size` must be an object when present")
		else:
			errors.append_array(_validate_frame_size(record.get("frame_size", {}), prefix + "frame_size: "))

	if record.has("hands"):
		if not record.get("hands") is Array:
			errors.append(prefix + "`hands` must be an array when present")
		else:
			var hands: Array = record.get("hands", [])
			for index in range(hands.size()):
				if not hands[index] is Dictionary:
					errors.append(prefix + "hand %d must be an object" % index)

	return errors

static func to_json_line(record: Dictionary) -> String:
	return JSON.stringify(normalize(record))

static func _normalize_landmark(landmark: Dictionary) -> Dictionary:
	return {
		"id": str(landmark.get("id", "")),
		"x": float(landmark.get("x", 0.0)),
		"y": float(landmark.get("y", 0.0)),
		"z": float(landmark.get("z", 0.0)),
		"v": float(landmark.get("v", 0.0)),
	}

static func _validate_landmark(landmark: Dictionary, prefix: String) -> Array[String]:
	var errors: Array[String] = []
	if str(landmark.get("id", "")) == "":
		errors.append(prefix + "missing required field `id`")
	for field_name in ["x", "y", "z", "v"]:
		if not landmark.has(field_name):
			errors.append(prefix + "missing required field `%s`" % field_name)
			continue
		if typeof(landmark.get(field_name)) not in [TYPE_FLOAT, TYPE_INT]:
			errors.append(prefix + "`%s` must be numeric" % field_name)
	if landmark.has("x") and (float(landmark.get("x")) < 0.0 or float(landmark.get("x")) > 1.0):
		errors.append(prefix + "`x` must be between 0.0 and 1.0")
	if landmark.has("y") and (float(landmark.get("y")) < 0.0 or float(landmark.get("y")) > 1.0):
		errors.append(prefix + "`y` must be between 0.0 and 1.0")
	if landmark.has("v") and (float(landmark.get("v")) < 0.0 or float(landmark.get("v")) > 1.0):
		errors.append(prefix + "`v` must be between 0.0 and 1.0")
	return errors

static func _normalize_frame_size(frame_size: Dictionary) -> Dictionary:
	return {
		"width": int(frame_size.get("width", 0)),
		"height": int(frame_size.get("height", 0)),
	}

static func _validate_frame_size(frame_size: Dictionary, prefix: String) -> Array[String]:
	var errors: Array[String] = []
	for field_name in ["width", "height"]:
		if not frame_size.has(field_name):
			errors.append(prefix + "missing required field `%s`" % field_name)
		elif int(frame_size.get(field_name, 0)) <= 0:
			errors.append(prefix + "`%s` must be > 0" % field_name)
	return errors

static func _normalize_hands(hands: Array) -> Array:
	var normalized: Array = []
	for hand_variant in hands:
		if hand_variant is Dictionary:
			normalized.append(hand_variant.duplicate(true))
	return normalized
