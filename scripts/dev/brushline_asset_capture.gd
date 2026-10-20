extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var grid := GridContainer.new()
	grid.columns=4
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(grid)
	root.size=Vector2i(1280,720)
	for kind: String in ["checkpoint","balloon","helicopter","sailboat","reindeer","bear","zebra","ostrich","kangaroo","service_station","marshal","spectator"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(column)
		var container := SubViewportContainer.new()
		container.custom_minimum_size=Vector2(300,200)
		container.stretch=true
		column.add_child(container)
		var viewport := SubViewport.new()
		viewport.size=Vector2i(300,200)
		viewport.own_world_3d=true
		container.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		var prop := RallyScreenprintProps.add(world,kind)
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
			var box: AABB=mesh.global_transform*mesh.get_aabb()
			bounds=box if first else bounds.merge(box)
			first=false
		var environment := WorldEnvironment.new()
		environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color("e2d8be")
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color=Color("dce7ef")
		environment.environment.ambient_light_energy=.6
		world.add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees=Vector3(-45,-35,0)
		sun.light_energy=1.7
		world.add_child(sun)
		var camera := Camera3D.new()
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=maxf(bounds.size.y,maxf(bounds.size.x,bounds.size.z)) *1.25
		world.add_child(camera)
		camera.position=bounds.get_center()+Vector3(-1,.5,1.3).normalized()*camera.size*2
		camera.look_at(bounds.get_center())
		camera.current=true
		var label := Label.new()
		label.text=kind
		label.add_theme_font_override("font",RallyFonts.DISPLAY)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	for i: int in range(25): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://docs/brushline/asset-lineup.jpg",.94)
	grid.queue_free()
	await process_frame
	quit()
