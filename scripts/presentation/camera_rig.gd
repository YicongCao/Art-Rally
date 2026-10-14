class_name RallyCameraRig
extends RefCounted

var dashboard := Node3D.new()
var steering_wheel := Node3D.new()
var display: Label3D
var chase_position := Vector3.ZERO
var history_valid: bool = false
var last_mode: int = -1
var elapsed: float = 0


func build(camera: Camera3D) -> void:
	dashboard.name = "SimplifiedCockpit"
	dashboard.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.add_child(dashboard)
	GrayboxGeometry.box(dashboard,"Dash",Vector3(1.5,0.22,0.16),Vector3(0,-0.43,-0.76),Color("1b2925"))
	GrayboxGeometry.box(dashboard,"InstrumentPlate",Vector3(0.39,0.17,0.015),Vector3(0.20,-0.30,-0.64),Color("0e1a16"))
	steering_wheel.position = Vector3(-0.24,-0.27,-0.55)
	dashboard.add_child(steering_wheel)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.12
	ring.outer_radius = 0.15
	ring.rings = 16
	ring.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("26342d")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material = material
	var wheel := MeshInstance3D.new()
	wheel.mesh = ring
	wheel.rotation.x = PI/2
	steering_wheel.add_child(wheel)
	GrayboxGeometry.box(steering_wheel,"Hub",Vector3(0.06,0.06,0.03),Vector3.ZERO,Color("c39653"))
	for angle: float in [0,TAU/3,TAU*2/3]:
		GrayboxGeometry.box(steering_wheel,"Spoke",Vector3(0.026,0.10,0.025),Vector3(sin(angle)*0.06,cos(angle)*0.06,0),Color("536455"),false,Vector3(0,0,-rad_to_deg(angle)))
	display = Label3D.new()
	display.position = Vector3(0.20,-0.285,-0.62)
	display.font_size = 28
	display.pixel_size = 0.0010
	display.modulate = Color("f0c37a")
	dashboard.add_child(display)
	dashboard.visible = false


func reset() -> void:
	history_valid = false


func update(camera: Camera3D,car: RallyVehicle,mode: int,motion: bool,paused: bool,dt: float) -> void:
	if not paused: elapsed += dt
	if mode!=last_mode:
		reset()
		last_mode = mode
	var pose := car.get_global_transform_interpolated()
	if mode==0:
		var forward := Vector3(-pose.basis.z.x,0,-pose.basis.z.z).normalized()
		var target := pose.origin-forward*6.6+Vector3.UP*2.55
		chase_position = chase_position.lerp(target,1-exp(-9*dt)) if history_valid else target
		camera.position = chase_position
		camera.look_at(pose.origin+forward*9+Vector3.UP*1.3)
		history_valid = true
	else:
		var offset := Vector3(0,0.74,-0.80) if mode==2 else Vector3(0,0.72,-1.40)
		if motion: offset.y += sin(elapsed*37)*minf(car.linear_velocity.length()/20,1)*0.005
		camera.position = pose*offset
		camera.look_at(camera.position-pose.basis.z*40,pose.basis.y)
	dashboard.visible = mode==2
	steering_wheel.rotation.z = -car.command.steer*1.4
	var gear := "R" if car.drivetrain.gear<0 else ("N" if car.drivetrain.gear==0 else str(car.drivetrain.gear))
	display.text = "%03d  %s\n%04d RPM"%[car.linear_velocity.length()*3.6,gear,car.drivetrain.rpm()]
