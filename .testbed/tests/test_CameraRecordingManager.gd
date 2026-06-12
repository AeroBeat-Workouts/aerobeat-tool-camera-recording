extends GutTest

func test_camera_recording_manager_initializes_truthfully() -> void:
	var manager := CameraRecordingManager.new()
	assert_eq(CameraRecordingManager.VERSION, "0.1.0", "Manager version should reflect the first saved-session contract slice")
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
