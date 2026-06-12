extends GutTest

const CameraTracking = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTracking.gd")
const CameraTrackingBackend = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTrackingBackend.gd")

const GENERATED_EXPORT_ROOT := "user://tracking_export_saved_session"

class ExportFakeBackend extends CameraTrackingBackend:
	var _tracking_frame: Dictionary = {}
	var _state := CameraTracking.STATE_IDLE

	func get_backend_id() -> String:
		return "export_fake"

	func start(config: Dictionary) -> void:
		_tracking_frame = {
			"timestamp_ms": 1000,
			"timestamp_seconds": 1.0,
			"frame_index": 0,
			"backend": "export_fake",
			"source_kind": str(config.get("source", {}).get("kind", "live_camera")),
			"source_id": str(config.get("source", {}).get("path", config.get("source", {}).get("camera_id", ""))),
			"tracking_state": "tracked",
			"frame_size": {"x": 640, "y": 480},
			"landmarks": [
				{"id": 15, "x": 0.2, "y": 0.3, "z": -0.1, "v": 0.9}
			]
		}
		_state = CameraTracking.STATE_RUNNING
		emit_signal("tracking_updated", _tracking_frame.duplicate(true))
		emit_signal("state_changed", _state, CameraTrackingConfig.make_state_detail({
			"backend_ready": true,
			"preview_ready": true,
			"tracking_ready": true,
			"source_ready": true,
		}))

	func stop() -> void:
		_state = CameraTracking.STATE_IDLE
		emit_signal("state_changed", _state, CameraTrackingConfig.make_state_detail())

	func change(config: Dictionary) -> void:
		start(config)

	func get_state() -> Dictionary:
		return {"state": _state, "detail": CameraTrackingConfig.make_state_detail({
			"backend_ready": _state == CameraTracking.STATE_RUNNING,
			"preview_ready": _state == CameraTracking.STATE_RUNNING,
			"tracking_ready": _state == CameraTracking.STATE_RUNNING,
			"source_ready": _state == CameraTracking.STATE_RUNNING,
		})}

	func get_tracking_frame() -> Dictionary:
		return _tracking_frame.duplicate(true)

	func emit_second_frame() -> void:
		_tracking_frame = {
			"timestamp_ms": 1033,
			"timestamp_seconds": 1.033,
			"frame_index": 1,
			"backend": "export_fake",
			"source_kind": str(_tracking_frame.get("source_kind", "live_camera")),
			"source_id": str(_tracking_frame.get("source_id", "")),
			"tracking_state": "tracked",
			"frame_size": {"x": 640, "y": 480},
			"landmarks": [
				{"id": 15, "x": 0.25, "y": 0.32, "z": -0.08, "v": 0.91}
			]
		}
		emit_signal("tracking_updated", _tracking_frame.duplicate(true))

func before_each() -> void:
	_delete_recursive(ProjectSettings.globalize_path(GENERATED_EXPORT_ROOT))

func after_each() -> void:
	_delete_recursive(ProjectSettings.globalize_path(GENERATED_EXPORT_ROOT))

func test_camera_recording_manager_initializes_truthfully() -> void:
	var manager := CameraRecordingManager.new()
	assert_eq(CameraRecordingManager.VERSION, "0.2.0", "Manager version should reflect the real export slice")
	assert_false(manager._is_initialized, "Manager should start uninitialized")
	manager._initialize()
	assert_true(manager._is_initialized, "Manager initialize path should mark the manager initialized")
	manager.free()

func test_example_manifest_is_structurally_valid() -> void:
	var manifest := CameraRecordingManager.build_example_manifest()
	assert_eq(manifest.get("schema_version"), 1, "Example manifest should lock schema_version=1")
	assert_eq(manifest.get("source_kind"), "fixture_replay", "Example manifest should preserve fixture replay truth")
	assert_eq((manifest.get("artifacts", {}) as Dictionary).get("pose_frames"), "tracking/pose_frames.jsonl", "Example manifest should point pose frames at the tracking JSONL")
	assert_eq((manifest.get("replay_contract", {}) as Dictionary).get("replay_mode"), "saved_tracking_frames", "Example manifest should freeze B-mode replay truth")
	assert_true(SessionManifestV1.validate(manifest).is_empty(), "Example manifest should pass structural validation")

func test_example_pose_frames_pass_record_validation() -> void:
	for pose_frame in CameraRecordingManager.build_example_pose_frames():
		assert_true(PoseFrameRecord.validate(pose_frame).is_empty(), "Example pose frame should match the frozen v1 writer contract")

func test_pose_frame_record_from_tracking_frame_preserves_tracker_truth() -> void:
	var record := CameraRecordingManager.pose_frame_record_from_tracking_frame({
		"frame_index": 7,
		"timestamp_ms": 1450,
		"timestamp_seconds": 1.45,
		"tracking_state": "tracked",
		"source_timestamp_ms": 1444,
		"source_id": "/dev/video0",
		"frame_size": {"x": 960, "y": 540},
		"landmarks": [
			{"id": 15, "x": 0.3, "y": 0.4, "z": -0.2, "v": 0.95}
		]
	})
	assert_eq(record.get("frame_index"), 7)
	assert_eq(record.get("source_timestamp_ms"), 1444)
	assert_eq(record.get("source_id"), "/dev/video0")
	assert_eq((record.get("frame_size", {}) as Dictionary).get("width"), 960)
	assert_eq((record.get("landmarks", [])[0] as Dictionary).get("id"), "15")
	assert_true(PoseFrameRecord.validate(record).is_empty())

func test_export_saved_session_from_live_camera_tracking_frames_writes_source_info_artifact() -> void:
	var tracker := CameraTracking.new()
	var backend := ExportFakeBackend.new()
	var captured_frames: Array = []
	tracker.tracking_updated.connect(func(frame: Dictionary): captured_frames.append(frame.duplicate(true)))
	tracker.set_backend(backend, "export_fake")
	tracker.start({
		"backend": "export_fake",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
	})
	backend.emit_second_frame()

	var export_root := ProjectSettings.globalize_path(GENERATED_EXPORT_ROOT)
	var result := CameraRecordingManager.export_saved_session_from_tracking_frames(export_root, tracker.get_active_config(), captured_frames, {
		"session_id": "live_take",
		"take_id": "take_live_01",
		"backend_id": "export_fake"
	})
	assert_true(result.get("ok", false), "Live-camera tracking export should produce a valid saved-session package")
	assert_true(FileAccess.file_exists(export_root.path_join("source/source_info.json")))
	var manifest_file := FileAccess.open(export_root.path_join("session_manifest.json"), FileAccess.READ)
	var parsed := JSON.new()
	assert_eq(parsed.parse(manifest_file.get_as_text()), OK)
	var manifest: Dictionary = parsed.data
	assert_eq(manifest.get("source_kind"), "live_camera")
	assert_eq((manifest.get("artifacts", {}) as Dictionary).get("source_info"), "source/source_info.json")
	assert_eq(int((manifest.get("tracking_contract", {}) as Dictionary).get("frame_count", 0)), captured_frames.size())
	tracker.free()

func test_export_saved_session_from_video_file_tracking_frames_preserves_video_time_replay_contract() -> void:
	var tracking_frames := [
		{
			"frame_index": 0,
			"timestamp_ms": 500,
			"timestamp_seconds": 0.5,
			"tracking_state": "tracked",
			"source_id": "res://clips/demo.mp4",
			"frame_size": {"x": 960, "y": 540},
			"landmarks": [{"id": 0, "x": 0.1, "y": 0.2, "z": 0.0, "v": 0.9}]
		},
		{
			"frame_index": 1,
			"timestamp_ms": 533,
			"timestamp_seconds": 0.533,
			"tracking_state": "tracked",
			"source_id": "res://clips/demo.mp4",
			"frame_size": {"x": 960, "y": 540},
			"landmarks": [{"id": 0, "x": 0.15, "y": 0.22, "z": 0.0, "v": 0.91}]
		}
	]
	var export_root := ProjectSettings.globalize_path(GENERATED_EXPORT_ROOT)
	var result := CameraRecordingManager.export_saved_session_from_tracking_frames(export_root, {
		"backend": "mediapipe_python",
		"source": {"kind": "video_file", "path": "res://clips/demo.mp4"}
	}, tracking_frames, {
		"session_id": "video_take",
		"take_id": "take_video_01"
	})
	assert_true(result.get("ok", false), "Video-file tracking export should produce a valid saved-session package")
	var manifest := _read_json_file(export_root.path_join("session_manifest.json"))
	assert_eq(manifest.get("source_kind"), "video_file")
	assert_eq((manifest.get("tracking_contract", {}) as Dictionary).get("timestamp_mode"), "video_time_ms")
	assert_eq((manifest.get("replay_contract", {}) as Dictionary).get("replay_mode"), "saved_tracking_frames")
	assert_eq((manifest.get("truth_contract", {}) as Dictionary).get("timing_truth_path"), "")
	assert_eq((manifest.get("source_contract", {}) as Dictionary).get("camera_id"), "")
	assert_eq((manifest.get("source_contract", {}) as Dictionary).get("selected_path"), "res://clips/demo.mp4")

func test_live_and_video_file_exports_keep_the_same_saved_session_contract_shape() -> void:
	var tracking_frames := [
		{
			"frame_index": 0,
			"timestamp_ms": 1000,
			"timestamp_seconds": 1.0,
			"tracking_state": "tracked",
			"source_id": "/dev/video0",
			"frame_size": {"x": 640, "y": 480},
			"landmarks": [{"id": 15, "x": 0.2, "y": 0.3, "z": -0.1, "v": 0.9}]
		},
		{
			"frame_index": 1,
			"timestamp_ms": 1033,
			"timestamp_seconds": 1.033,
			"tracking_state": "tracked",
			"source_id": "/dev/video0",
			"frame_size": {"x": 640, "y": 480},
			"landmarks": [{"id": 15, "x": 0.25, "y": 0.32, "z": -0.08, "v": 0.91}]
		}
	]
	var live_root := ProjectSettings.globalize_path(GENERATED_EXPORT_ROOT.path_join("live_parity"))
	var live_result := CameraRecordingManager.export_saved_session_from_tracking_frames(live_root, {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"}
	}, tracking_frames, {
		"session_id": "live_parity",
		"take_id": "take_live_01"
	})
	assert_true(live_result.get("ok", false), "Live parity export should succeed")
	var video_root := ProjectSettings.globalize_path(GENERATED_EXPORT_ROOT.path_join("video_parity"))
	var video_result := CameraRecordingManager.export_saved_session_from_tracking_frames(video_root, {
		"backend": "mediapipe_python",
		"source": {"kind": "video_file", "path": "res://clips/demo.mp4"}
	}, tracking_frames, {
		"session_id": "video_parity",
		"take_id": "take_video_01"
	})
	assert_true(video_result.get("ok", false), "Video parity export should succeed")

	var live_manifest := _read_json_file(live_root.path_join("session_manifest.json"))
	var video_manifest := _read_json_file(video_root.path_join("session_manifest.json"))
	assert_eq(_manifest_contract_signature(live_manifest), _manifest_contract_signature(video_manifest), "Live and video-file exports should keep the same saved-session contract shape; only metadata values should differ")
	assert_ne(live_manifest.get("source_kind"), video_manifest.get("source_kind"), "Source type difference should live in metadata, not schema drift")
	assert_eq((live_manifest.get("tracking_contract", {}) as Dictionary).get("timestamp_mode"), "capture_time_ms")
	assert_eq((video_manifest.get("tracking_contract", {}) as Dictionary).get("timestamp_mode"), "video_time_ms")

func test_fixture_replay_export_links_timing_truth_without_forking_the_package_contract() -> void:
	var tracking_frames := [
		{
			"frame_index": 0,
			"timestamp_ms": 1833,
			"timestamp_seconds": 1.833,
			"tracking_state": "tracked",
			"source_id": "fixtures/boxing/straight_left/straight_left_take_01.mp4",
			"frame_size": {"x": 1280, "y": 720},
			"landmarks": [{"id": 15, "x": 0.42, "y": 0.31, "z": -0.12, "v": 0.98}]
		},
		{
			"frame_index": 1,
			"timestamp_ms": 1866,
			"timestamp_seconds": 1.866,
			"tracking_state": "tracked",
			"source_id": "fixtures/boxing/straight_left/straight_left_take_01.mp4",
			"frame_size": {"x": 1280, "y": 720},
			"landmarks": [{"id": 15, "x": 0.47, "y": 0.36, "z": -0.09, "v": 0.97}]
		}
	]
	var export_root := ProjectSettings.globalize_path(GENERATED_EXPORT_ROOT.path_join("fixture_parity"))
	var result := CameraRecordingManager.export_saved_session_from_tracking_frames(export_root, {
		"backend": "mediapipe_python",
		"source": {"kind": "video_file", "path": "fixtures/boxing/straight_left/straight_left_take_01.mp4"}
	}, tracking_frames, {
		"session_id": "fixture_take",
		"take_id": "take_fixture_01",
		"source_kind": "fixture_replay",
		"fixture_id": "straight_left_take_01",
		"timing_truth_path": "truth/timing_truth.yaml",
		"timing_truth_source_path": "fixtures/boxing/straight_left/straight_left_take_01.yaml",
		"timing_truth_text": "events:\n  - label: straight_left\n    start_ms: 1833\n    end_ms: 1900\n",
		"label_context": "boxing_side_aware_punches_v1"
	})
	assert_true(result.get("ok", false), "Fixture replay export should write a valid saved-session package with linked timing truth")
	assert_true(FileAccess.file_exists(export_root.path_join("truth/timing_truth.yaml")))
	var manifest := _read_json_file(export_root.path_join("session_manifest.json"))
	var source_info := _read_json_file(export_root.path_join("source/source_info.json"))
	assert_eq(manifest.get("source_kind"), "fixture_replay")
	assert_eq((manifest.get("artifacts", {}) as Dictionary).get("pose_frames"), "tracking/pose_frames.jsonl")
	assert_eq((manifest.get("artifacts", {}) as Dictionary).get("source_info"), "source/source_info.json")
	assert_eq((manifest.get("artifacts", {}) as Dictionary).get("timing_truth"), "truth/timing_truth.yaml")
	assert_eq((manifest.get("truth_contract", {}) as Dictionary).get("timing_truth_path"), "truth/timing_truth.yaml")
	assert_eq((manifest.get("truth_contract", {}) as Dictionary).get("timing_truth_source_path"), "fixtures/boxing/straight_left/straight_left_take_01.yaml")
	assert_eq((manifest.get("truth_contract", {}) as Dictionary).get("label_context"), "boxing_side_aware_punches_v1")
	assert_eq((manifest.get("source_contract", {}) as Dictionary).get("fixture_id"), "straight_left_take_01")
	assert_true(bool(source_info.get("timing_truth_linked", false)))
	assert_eq(source_info.get("timing_truth_path"), "truth/timing_truth.yaml")
	assert_eq(source_info.get("timing_truth_source_path"), "fixtures/boxing/straight_left/straight_left_take_01.yaml")
	assert_eq(source_info.get("label_context"), "boxing_side_aware_punches_v1")

func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Expected JSON file to exist at %s" % path)
	if file == null:
		return {}
	var parsed := JSON.new()
	assert_eq(parsed.parse(file.get_as_text()), OK, "Expected JSON parse to succeed for %s" % path)
	if parsed.data is Dictionary:
		return parsed.data
	return {}

func _manifest_contract_signature(manifest: Dictionary) -> Dictionary:
	var artifacts: Dictionary = manifest.get("artifacts", {}) if manifest.get("artifacts", {}) is Dictionary else {}
	var tracking_contract: Dictionary = manifest.get("tracking_contract", {}) if manifest.get("tracking_contract", {}) is Dictionary else {}
	var source_contract: Dictionary = manifest.get("source_contract", {}) if manifest.get("source_contract", {}) is Dictionary else {}
	var truth_contract: Dictionary = manifest.get("truth_contract", {}) if manifest.get("truth_contract", {}) is Dictionary else {}
	var replay_contract: Dictionary = manifest.get("replay_contract", {}) if manifest.get("replay_contract", {}) is Dictionary else {}
	return {
		"top_level_keys": manifest.keys(),
		"artifact_keys": artifacts.keys(),
		"tracking_contract_keys": tracking_contract.keys(),
		"source_contract_keys": source_contract.keys(),
		"truth_contract_keys": truth_contract.keys(),
		"replay_contract_keys": replay_contract.keys(),
		"pose_frames_path": artifacts.get("pose_frames", ""),
		"source_info_path": artifacts.get("source_info", ""),
		"replay_entrypoint": replay_contract.get("entrypoint", ""),
	}

func _delete_recursive(path: String) -> void:
	if path == "" or not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == "..":
			continue
		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_delete_recursive(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
