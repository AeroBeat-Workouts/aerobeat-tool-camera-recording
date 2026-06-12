extends SceneTree

func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var output_root := str(args.get("output-root", ""))
	if output_root == "":
		printerr("Usage: --output-root <path>")
		quit(2)
		return

	var absolute_output_root := ProjectSettings.globalize_path(output_root)
	var result := CameraRecordingManager.create_saved_session_package(absolute_output_root)
	print(JSON.stringify(result, "\t"))
	quit(0 if bool(result.get("ok", false)) else 1)

func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {}
	var index := 0
	while index < raw_args.size():
		var token := String(raw_args[index])
		if token.begins_with("--"):
			var key := token.trim_prefix("--")
			var value := "true"
			if index + 1 < raw_args.size() and not String(raw_args[index + 1]).begins_with("--"):
				value = String(raw_args[index + 1])
				index += 1
			parsed[key] = value
		index += 1
	return parsed
