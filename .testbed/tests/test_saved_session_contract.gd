extends GutTest

const README_PATH := "../README.md"
const PLUGIN_CFG_PATH := "../plugin.cfg"
const ADDONS_MANIFEST_PATH := "addons.jsonc"
const CONTRACT_DOC_PATH := "../docs/saved-session-contract.md"
const EXAMPLE_SESSION_ROOT := "../examples/saved_sessions/boxing_straight_left_take_01"
const GENERATED_SESSION_ROOT := "user://generated_saved_session"
const EXPECTED_PLUGIN_DESCRIPTION := "Saved-session package contract and validation layer for AeroBeat camera-recording artifacts, including manifest and pose-frame schema truth."

func before_each() -> void:
	_delete_recursive(ProjectSettings.globalize_path(GENERATED_SESSION_ROOT))

func after_each() -> void:
	_delete_recursive(ProjectSettings.globalize_path(GENERATED_SESSION_ROOT))

func _read_repo_file(relative_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path("res://%s" % relative_path)
	assert_true(FileAccess.file_exists(absolute_path), "Expected repo file to exist: %s" % absolute_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	assert_true(file != null, "Expected repo file to open: %s" % absolute_path)
	return file.get_as_text()

func test_readme_states_saved_session_contract_scope() -> void:
	var readme_text := _read_repo_file(README_PATH)
	assert_true(readme_text.contains("durable saved-session artifact contract"), "README should explain the repo mission")
	assert_true(readme_text.contains("package/bootstrap truth"), "README should state that Slice 1 stops at package truth")
	assert_true(readme_text.contains("session_manifest.json"), "README should call out the manifest entrypoint")
	assert_true(readme_text.contains("tracking/pose_frames.jsonl"), "README should call out the pose frame stream")
	assert_true(readme_text.contains("validate_saved_session.gd"), "README should expose the validation helper")

func test_plugin_cfg_is_repo_specific() -> void:
	var config := ConfigFile.new()
	var error := config.load(ProjectSettings.globalize_path("res://%s" % PLUGIN_CFG_PATH))
	assert_eq(error, OK, "plugin.cfg should parse cleanly")
	assert_eq(config.get_value("plugin", "name", ""), "AeroBeat Tool Camera Recording", "plugin name should reflect the real repo")
	assert_eq(config.get_value("plugin", "description", ""), EXPECTED_PLUGIN_DESCRIPTION, "plugin description should reflect the saved-session contract scope")

func test_addons_manifest_mounts_real_repo_name() -> void:
	var manifest_text := _read_repo_file(ADDONS_MANIFEST_PATH)
	assert_true(manifest_text.contains('"aerobeat-tool-camera-recording"'), "addons manifest should mount the recording repo under its real package name")
	assert_true(manifest_text.contains('"aerobeat-tool-core"'), "addons manifest should preserve the tool-core dependency")
	assert_true(manifest_text.contains('"aerobeat-vendor-godot-unit-test"'), "addons manifest should preserve the GUT dependency")
	assert_false(manifest_text.contains('"aerobeat-template-tool"'), "addons manifest should not keep the stale template package name")

func test_contract_doc_freezes_slice_1_assumptions() -> void:
	var doc_text := _read_repo_file(CONTRACT_DOC_PATH)
	assert_true(doc_text.contains("saved_tracking_frames"), "Contract doc should freeze the B-mode replay value")
	assert_true(doc_text.contains("video_reinference"), "Contract doc should preserve the later A-mode replay value")
	assert_true(doc_text.contains("semantic landmark name string"), "Contract doc should freeze semantic landmark IDs")
	assert_true(doc_text.contains("frame_index must advance by exactly `1`"), "Contract doc should freeze frame sequencing rules")

func test_example_saved_session_validates() -> void:
	var example_session_root := ProjectSettings.globalize_path(EXAMPLE_SESSION_ROOT)
	var result := SavedSessionValidator.validate_session_root(example_session_root)
	assert_true(result.get("ok", false), "Canonical example saved session should validate cleanly")
	assert_eq((result.get("summary", {}) as Dictionary).get("frame_count"), 3, "Example saved session should report the frozen frame count")

func test_generator_creates_valid_saved_session_package() -> void:
	var generated_root := ProjectSettings.globalize_path(GENERATED_SESSION_ROOT)
	var result := CameraRecordingManager.create_saved_session_package(generated_root)
	assert_true(result.get("ok", false), "Generator should create a structurally valid saved-session package")
	assert_true(FileAccess.file_exists("%s/session_manifest.json" % generated_root), "Generator should write session_manifest.json")
	assert_true(FileAccess.file_exists("%s/tracking/pose_frames.jsonl" % generated_root), "Generator should write tracking/pose_frames.jsonl")
	assert_eq((result.get("summary", {}) as Dictionary).get("frame_count"), 3, "Generated package should keep manifest frame_count in sync")

func test_validator_rejects_frame_count_drift() -> void:
	var generated_root := ProjectSettings.globalize_path(GENERATED_SESSION_ROOT)
	var created := CameraRecordingManager.create_saved_session_package(generated_root)
	assert_true(created.get("ok", false), "Generator should succeed before the drift check")
	var manifest_path := "%s/session_manifest.json" % generated_root
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	assert_true(file != null, "Generated manifest should open for mutation test")
	var json := JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "Generated manifest should parse during mutation test")
	var manifest: Dictionary = json.data
	manifest["tracking_contract"]["frame_count"] = 99
	file = FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	var result := SavedSessionValidator.validate_session_root(generated_root)
	assert_false(result.get("ok", true), "Validator should reject mismatched manifest frame counts")
	assert_gt((result.get("errors", []) as Array).size(), 0, "Validator should emit at least one explicit error for frame count drift")

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
