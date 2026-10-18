class_name RallyCameraRig
extends RefCounted

var definition: RallyVehicleDefinition
var dashboard := Node3D.new()
var steering_wheel := Node3D.new()
var display: Label3D
var display_viewport: SubViewport
var racing_display: RallyCockpitDisplay
var shift_lights: Array[StandardMaterial3D] = []
var display_clock: float = 0
var chase_position := Vector3.ZERO
var history_valid: bool = false
var last_mode: int = -1
var elapsed: float = 0
var view_angles := Vector2.ZERO


func build(camera: Camera3D) -> void:
	dashboard.name = "SimplifiedCockpit"
	if definition!=null and definition.vehicle_id=="R200": dashboard.position.y = .16
	dashboard.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.add_child(dashboard)
	GrayboxGeometry.box(dashboard,"Dash",Vector3(definition.body_size.x*.88 if definition!=null else 1.5,0.16 if definition!=null and definition.vehicle_id=="R200" else .22,0.16),Vector3(0,-0.43,-0.76),definition.paint.darkened(.7) if definition!=null else Color("1b2925"))
	if definition!=null:
		GrayboxGeometry.box(dashboard,"CockpitAccent",Vector3(definition.body_size.x*.85,.025,.025),Vector3(0,-.31,-.67),definition.accent)
		for side: float in [-1,1]:
			var width := definition.body_size.x*.42
			var pillar := RallySampleMeshes.new()
			pillar.beam(Vector3(side*width,-.55,-.7),Vector3(side*width*.8,.52,-1.0),.035,definition.paint)
			var visual := MeshInstance3D.new()
			visual.mesh = pillar.finish()
			dashboard.add_child(visual)
	GrayboxGeometry.box(dashboard,"InstrumentBezel",Vector3(0.50,0.22,0.035),Vector3(0.17,-0.285,-0.65),Color("111c20"))
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
	GrayboxGeometry.box(steering_wheel,"CenterStripe",Vector3(0.03,0.04,0.035),Vector3(0,0.14,0),Color("e8aa4f"))
	GrayboxGeometry.box(steering_wheel,"Hub",Vector3(0.06,0.06,0.03),Vector3.ZERO,Color("c39653"))
	for angle: float in [0,TAU/3,TAU*2/3]:
		GrayboxGeometry.box(steering_wheel,"Spoke",Vector3(0.026,0.10,0.025),Vector3(sin(angle)*0.06,cos(angle)*0.06,0),Color("536455"),false,Vector3(0,0,-rad_to_deg(angle)))
	display = Label3D.new()
	display.position = Vector3(0.20,-0.285,-0.62)
	display.font_size = 28
	display.pixel_size = 0.0010
	display.modulate = Color("f0c37a")
	dashboard.add_child(display)
	display.visible = false
	display_viewport = SubViewport.new()
	display_viewport.size = Vector2i(768,300)
	display_viewport.disable_3d = true
	display_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	dashboard.add_child(display_viewport)
	racing_display = RallyCockpitDisplay.new()
	display_viewport.add_child(racing_display)
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.46,0.18)
	screen.mesh = quad
	screen.position = Vector3(0.17,-0.285,-0.625)
	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_texture = display_viewport.get_texture()
	screen.material_override = screen_material
	dashboard.add_child(screen)
	for i: int in range(12):
		var led := GrayboxGeometry.box(dashboard,"ShiftLED",Vector3(0.025,0.012,0.018),Vector3(-0.02+i*0.031,-0.159,-0.63),Color("24332c"))
		var led_material := StandardMaterial3D.new()
		led_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		led.get_child(0).material_override = led_material
		shift_lights.append(led_material)
	for x: float in [-0.064,0.404]:
		for y: float in [-0.375,-0.195]:
			GrayboxGeometry.box(dashboard,"Fastener",Vector3(0.012,0.012,0.012),Vector3(x,y,-0.625),Color("748078"))
	for i: int in range(3):
		GrayboxGeometry.box(dashboard,"SwitchHousing",Vector3(0.055,0.06,0.032),Vector3(0.44+i*0.067,-0.335,-0.64),Color("171f1d"))
		GrayboxGeometry.box(dashboard,"SwitchCap",Vector3(0.027,0.034,0.025),Vector3(0.44+i*0.067,-0.33,-0.615),Color("bc5941") if i==0 else Color("b7aa73"))
	dashboard.visible = false


func reset() -> void:
	history_valid = false
	view_angles=Vector2.ZERO


func update(camera: Camera3D,car: RallyVehicle,mode: int,motion: bool,paused: bool,dt: float,look: Vector2 = Vector2.ZERO) -> void:
	if not paused: elapsed += dt
	if mode!=last_mode:
		reset()
		last_mode = mode
	if not paused:
		view_angles.x=wrapf(view_angles.x+look.x*2.1*dt,-PI,PI)
		view_angles.y=clampf(view_angles.y-look.y*1.25*dt,-.20,.65)
	var pose := car.get_global_transform_interpolated()
	if mode==0:
		var forward := Vector3(-pose.basis.z.x,0,-pose.basis.z.z).normalized()
		var right := forward.cross(Vector3.UP)
		var target := pose.origin-forward*cos(view_angles.x)*6.6+right*sin(view_angles.x)*6.6+Vector3.UP*(2.55+sin(view_angles.y)*4)
		chase_position = chase_position.lerp(target,1-exp(-9*dt)) if history_valid else target
		camera.position = chase_position
		camera.look_at(pose.origin+forward*(9*(1-smoothstep(0,.9,absf(view_angles.x))))+Vector3.UP*1.3)
		history_valid = true
	else:
		var offset := Vector3(0,0.74,-0.80) if mode==2 else Vector3(0,0.72,-1.40)
		if definition!=null: offset = definition.cockpit_offset if mode==2 else definition.hood_offset
		if motion: offset.y += sin(elapsed*37)*minf(car.linear_velocity.length()/20,1)*0.005
		camera.position = pose*offset
		var head := pose.basis*Basis(Vector3.UP,-view_angles.x)*Basis(Vector3.RIGHT,view_angles.y)
		camera.look_at(camera.position-head.z*40,head.y)
		# Keep the dashboard attached to the car while the driver's head turns.
		dashboard.global_basis=pose.basis
	dashboard.visible = mode==2
	display_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if mode==2 else SubViewport.UPDATE_DISABLED
	display_clock += dt
	if mode==2 and display_clock>0.05:
		display_clock = 0
		racing_display.refresh(car)
		for i: int in range(shift_lights.size()):
			var lit := car.drivetrain.rpm()/car.drivetrain.config.redline_rpm > 0.30+i*0.055
			shift_lights[i].albedo_color = (Color("ef7250") if i>9 else (Color("f2bb62") if i>6 else Color("8bd8b0"))) if lit else Color("22392f")
	steering_wheel.rotation.z = -car.command.steer*1.4
	var gear := "R" if car.drivetrain.gear<0 else ("N" if car.drivetrain.gear==0 else str(car.drivetrain.gear))
	display.text = "%03d  %s\n%04d RPM"%[car.linear_velocity.length()*3.6,gear,car.drivetrain.rpm()]
