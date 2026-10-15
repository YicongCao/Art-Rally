extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for i: int in range(120): await process_frame
	var devices: Array[Dictionary] = []
	for device: int in Input.get_connected_joypads():
		var axes := {}
		for axis: int in [JOY_AXIS_LEFT_X,JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			axes[str(axis)] = Input.get_joy_axis(device,axis)
		devices.append({
			"id":device,
			"name":Input.get_joy_name(device),
			"guid":Input.get_joy_guid(device),
			"known_mapping":Input.is_joy_known(device),
			"initial_axes":axes,
		})
	var report := {
		"timestamp":Time.get_datetime_string_from_system(),
		"display_server":DisplayServer.get_name(),
		"devices":devices,
		"note":"Enumeration only; trigger range, vibration and disconnect still require deliberate manual actions.",
	}
	var output := FileAccess.open("res://logs/controller_probe.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	print("CONTROLLER PROBE: ",report)
	quit()
