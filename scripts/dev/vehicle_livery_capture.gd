extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1440,720)
	DisplayServer.window_set_size(root.size)
	var grid := HBoxContainer.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(grid)
	for id: String in RallyContentCatalog.VEHICLES:
		var container := SubViewportContainer.new()
		container.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		container.stretch=true
		grid.add_child(container)
		var viewport := SubViewport.new()
		viewport.size=Vector2i(480,720)
		viewport.own_world_3d=true
		viewport.msaa_3d=Viewport.MSAA_4X
		container.add_child(viewport)
		var definition := RallyContentCatalog.vehicle(id)
		var body := Node3D.new()
		viewport.add_child(body)
		body.add_child(RallyVehicleAppearance.build(definition))
		RallyVehiclePlate.attach(body,definition,"BRUSHLINE")
		for i: int in range(4):
			var pivot := Node3D.new()
			pivot.position=RallyVehicleAppearance.mount(body,"WheelMount%d"%i,Vector3.ZERO)
			body.add_child(pivot)
			var tire := MeshInstance3D.new()
			tire.mesh=RallyWheelMeshes.tire(.34)
			tire.rotation.z=PI/2
			pivot.add_child(tire)
			for side: float in [-1,1]:
				var hub := MeshInstance3D.new()
				hub.mesh=RallyWheelMeshes.five_spoke()
				hub.position.y=side*.125
				hub.rotation.x=PI if side<0 else 0
				tire.add_child(hub)
		var environment := WorldEnvironment.new()
		environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color("26343e")
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color=Color("dce7ef")
		environment.environment.ambient_light_energy=.6
		viewport.add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees=Vector3(-45,-150,0)
		sun.light_energy=1.7
		viewport.add_child(sun)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.position=Vector3(-2.5,2.0,5)
		camera.look_at(Vector3(0,.3,.3))
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=6.8
		camera.current=true
	for frame: int in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/brushline/vehicle-polish/rear-liveries.png")
	grid.free()
	await process_frame
	quit()
