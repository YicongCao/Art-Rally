class_name RallyUtilityLine
extends RefCounted

# One rural distribution line per stage, on the inland shoulder. Geometry only:
# the route, recovery corridor and road collision remain untouched.
var poles: Array[Dictionary] = []
var spans: Array[PackedVector3Array] = []
const STEP := 44.0
const SAG := 1.25

func plan(land: RallyStageScenery) -> void:
	poles.clear()
	spans.clear()
	var s := 60.0
	while s<land.route.length-100:
		var bank := false
		for river: Vector3 in land.generator.definition.river_crossings:
			if absf(s-river.x)<river.y*.5+12: bank=true
		if not bank:
			for offset: float in [30,38,24,46,54]:
				var at := land.ground_at(s,offset)
				at.y = land.rendered_height_at(at.x,at.z)
				var nearest := land.nearest(at)
				if float(nearest.distance)<land.route.width_at(nearest.s)*.5+15: continue
				var occupied := false
				for landmark: Dictionary in land.generator.definition.landmarks:
					if at.distance_to(land.ground_at(landmark.s,landmark.side*18))<24: occupied=true
				# Give the rock arch, medical station and scenic finish a clear silhouette.
				if absf(s-land.route.length*.52)<65 and offset<46: occupied=true
				if occupied: continue
				var right := land.route.rights[land.route.index_at(s)]
				right.y=0
				poles.append({"s":s,"base":at,"height":9.2+.35*sin(s*.031),"right":right.normalized()})
				break
		s+=STEP
	# Shorten spans over ridges rather than growing seventy-metre wooden poles.
	for iteration: int in range(8):
		var refined: Array[Dictionary] = []
		var inserted := false
		for i: int in range(poles.size()-1):
			var a: Dictionary=poles[i]
			var b: Dictionary=poles[i+1]
			refined.append(a)
			var lift := _span_lift(land,a,b)
			if lift>3.0 and a.base.distance_to(b.base)>6:
				var at: Vector3=(a.base+b.base)*.5
				var near := land.nearest(at)
				var right := land.route.rights[land.route.index_at(near.s)]
				var clearance := land.route.width_at(near.s)*.5+16
				if float(near.distance)<clearance:
					at=near.point+right*(1 if near.lateral>=0 else -1)*clearance
				at.y=land.rendered_height_at(at.x,at.z)
				refined.append({"s":near.s,"base":at,"height":9.2,"right":right})
				inserted=true
		refined.append(poles[-1])
		poles=refined
		if not inserted: break
	for i: int in range(poles.size()-1):
		var lift := maxf(0,_span_lift(land,poles[i],poles[i+1]))
		poles[i].height+=lift
		poles[i+1].height+=lift

func _span_lift(land: RallyStageScenery,a: Dictionary,b: Dictionary) -> float:
	var lift := 0.0
	for lane: float in [-1.15,0,1.15]:
		for sample: int in range(33):
			var t := sample/32.0
			var at: Vector3=(a.base+Vector3.UP*a.height+a.right*lane).lerp(b.base+Vector3.UP*b.height+b.right*lane,t)-Vector3.UP*4*SAG*t*(1-t)
			var ground := land.rendered_height_at(at.x,at.z)
			lift=maxf(lift,ground+4.2-at.y)
	return lift

func build(land: RallyStageScenery) -> void:
	var biome := land.generator.definition.environment_id
	var wood: Color = {"autumn":Color("80634b"),"coast":Color("8a9290"),"highland":Color("5d6861")}[biome]
	var ceramic: Color = {"autumn":Color("b4c8be"),"coast":Color("d6dfd0"),"highland":Color("93b7b5")}[biome]
	var structure: RallySampleMeshes
	var wires: SurfaceTool
	var chunk: Node3D
	for i: int in range(poles.size()):
		if i%8==0:
			chunk=Node3D.new()
			chunk.name="UtilityLine%02d"%(i/8)
			land.dressing.add_child(chunk)
			chunk.position=poles[i].base
			structure=RallySampleMeshes.new()
			wires=SurfaceTool.new()
			wires.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pole: Dictionary=poles[i]
		var base: Vector3=pole.base-chunk.position
		var top: Vector3=base+Vector3.UP*pole.height
		var right: Vector3=pole.right
		structure.cone(.21,.13,pole.height+.8,base+Vector3.UP*(pole.height*.5-.4),wood,7)
		structure.cone(.32,.27,.7,base,Color("9b9a88"),6)
		structure.beam(top-right*1.55-Vector3.UP*.45,top+right*1.55-Vector3.UP*.45,.12,wood.lightened(.12))
		for side: float in [-1,1]:
			structure.beam(top-Vector3.UP*1.65,top+right*side*1.2-Vector3.UP*.45,.045,Color("687774"))
		for lane: float in [-1.15,0,1.15]:
			var pin := top+right*lane
			structure.cone(.095,.075,.42,pin-Vector3.UP*.23,ceramic,6)
			structure.cone(.14,.14,.09,pin-Vector3.UP*.12,ceramic,6)
			if i+1<poles.size():
				var next: Dictionary=poles[i+1]
				var end: Vector3=next.base-chunk.position+Vector3.UP*next.height+next.right*lane
				var points := PackedVector3Array()
				for j: int in range(17):
					var t := j/16.0
					var point := pin.lerp(end,t)-Vector3.UP*4*SAG*t*(1-t)
					points.append(point+chunk.position)
				spans.append(points)
				_wire(wires,points,chunk.position)
		if i%8==7 or i==poles.size()-1:
			var body := RallyStageLandmarks._mesh(chunk,structure)
			body.visibility_range_end=850
			if i%8>0 or i<poles.size()-1:
				var wire_mesh := MeshInstance3D.new()
				wire_mesh.mesh=wires.commit()
				var material := ShaderMaterial.new()
				material.shader=preload("res://assets/shaders/utility_wire.gdshader")
				wire_mesh.material_override=material
				wire_mesh.extra_cull_margin=2
				chunk.add_child(wire_mesh)
				wire_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wire_mesh.visibility_range_end=850

func allows_tree(point: Vector3) -> bool:
	# A narrow service clearing keeps supports visible without thinning the forest.
	for i: int in range(poles.size()):
		var a: Vector3=poles[i].base
		if Vector2(point.x-a.x,point.z-a.z).length_squared()<25: return false
		if i+1==poles.size(): continue
		var b: Vector3=poles[i+1].base
		var delta := Vector2(b.x-a.x,b.z-a.z)
		var offset := Vector2(point.x-a.x,point.z-a.z)
		var t := clampf(offset.dot(delta)/maxf(delta.length_squared(),.01),0,1)
		if (offset-delta*t).length_squared()<12.25: return false
	return true

func _wire(tool: SurfaceTool,points: PackedVector3Array,origin: Vector3) -> void:
	for i: int in range(points.size()-1):
		for corner: int in [0,1,2,2,1,3]:
			var index := i+(0 if corner<2 else 1)
			var tangent := (points[mini(index+1,points.size()-1)]-points[maxi(index-1,0)]).normalized()
			tool.set_normal(tangent)
			tool.set_uv(Vector2(-1 if corner%2==0 else 1,0))
			tool.add_vertex(points[index]-origin)
