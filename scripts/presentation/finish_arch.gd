class_name RallyFinishArch
extends RefCounted

static func logo_texture(parent: Node3D) -> ViewportTexture:
	var viewport := SubViewport.new()
	viewport.name="ArchWordmark"
	viewport.size=Vector2i(1024,210)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	parent.add_child(viewport)
	var background := ColorRect.new()
	background.color=Color("17342f")
	background.size=Vector2(1024,210)
	viewport.add_child(background)
	var logo := RallyTitleLogo.new()
	logo.crop_bottom=false
	logo.position=Vector2(42,10)
	logo.size=Vector2(940,190)
	viewport.add_child(logo)
	return viewport.get_texture()

static func build(parent: Node3D,route: RallyStageRoute,station: float,wordmark: Texture2D,title: String) -> Node3D:
	var node := Node3D.new()
	node.name=title
	parent.add_child(node)
	node.position=route.position_at(station)
	node.rotation.y=route.pose_at(station).basis.get_euler().y
	var half := route.width_at(station)*.5+1.05
	var path: Array[Vector2]=[]
	for i: int in range(9): path.append(Vector2(-half,i*.55))
	for i: int in range(1,9):
		var angle := PI-i*PI*.5/8
		path.append(Vector2(-half+1.3+cos(angle)*1.3,4.4+sin(angle)*1.3))
	for i: int in range(1,13): path.append(Vector2(lerpf(-half+1.3,half-1.3,i/12.0),5.7))
	for i: int in range(1,9):
		var angle := PI*.5-i*PI*.5/8
		path.append(Vector2(half-1.3+cos(angle)*1.3,4.4+sin(angle)*1.3))
	for i: int in range(1,9): path.append(Vector2(half,4.4-i*.55))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := 0.0
	for segment: int in range(path.size()-1):
		var next_length := length+path[segment].distance_to(path[segment+1])
		for ring: int in range(16):
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var index := segment+corner.x
				var tangent := (path[mini(index+1,path.size()-1)]-path[maxi(index-1,0)]).normalized()
				var normal := Vector3(-tangent.y,tangent.x,0)
				var angle := (ring+corner.y)*TAU/16
				tool.set_uv(Vector2((length if corner.x==0 else next_length)/.65,(ring+corner.y)/16.0))
				tool.add_vertex(Vector3(path[index].x,path[index].y,0)+normal*cos(angle)*.55+Vector3.BACK*sin(angle)*.55)
		length=next_length
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name="SoftCheckeredArch"
	mesh.mesh=tool.commit()
	var material := ShaderMaterial.new()
	material.shader=preload("res://assets/shaders/inflatable_arch.gdshader")
	mesh.material_override=material
	node.add_child(mesh)
	# Two faces remain readable from either direction; no reversed lettering.
	for side: float in [-1,1]:
		var sign := Sprite3D.new()
		sign.texture=wordmark
		sign.pixel_size=(half*2-1.3)/1024
		sign.position=Vector3(0,5.12,side*.59)
		sign.rotation.y=PI if side<0 else 0
		sign.shaded=true
		sign.double_sided=false
		node.add_child(sign)
	return node
