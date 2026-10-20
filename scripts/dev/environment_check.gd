extends Node3D

@onready var status: Label = $HUD/Panel/Padding/Status
@onready var probe: RigidBody3D = $Probe


func _ready() -> void:
	print("Brushline Rally environment started | Godot %s | %s | physics %d Hz" % [
		Engine.get_version_info()["string"],
		ProjectSettings.get_setting("physics/3d/physics_engine"),
		Engine.physics_ticks_per_second,
	])


func _process(_delta: float) -> void:
	status.text = (
		"BRUSHLINE RALLY / DEVELOPMENT ENVIRONMENT\n"
		+ "Godot %s | %s\n" % [Engine.get_version_info()["string"], ProjectSettings.get_setting("physics/3d/physics_engine")]
		+ "Physics: %d Hz | FPS: %d\n" % [Engine.physics_ticks_per_second, Engine.get_frames_per_second()]
		+ "Collision probe height: %.3f m\n" % probe.position.y
		+ "Gamepads connected: %d\n" % Input.get_connected_joypads().size()
		+ "Setup scene only - vehicle simulation comes next."
	)
