class_name RallyLogPiles
extends RefCounted

const RADIUS := .32
const LENGTH := 4.8

static func build(land: RallyStageScenery) -> void:
	var log_mesh := pile_mesh()
	for station: float in land.generator.definition.log_pile_stations:
		var outside := signf(land.route.tangent_at(station-10).signed_angle_to(land.route.tangent_at(station+10),Vector3.UP))
		var lateral := outside*(land.route.width_at(station)*.5+1.05+RADIUS*4)
		var node := StaticBody3D.new()
		node.name = "TimberStack%d"%station
		node.collision_layer=4
		node.collision_mask=2
		land.dressing.add_child(node)
		var at := land.ground_at(station,lateral)
		var across := (land.ground_at(station,lateral+.3)-land.ground_at(station,lateral-.3)).normalized()
		var forward := (land.ground_at(station+1,lateral)-land.ground_at(station-1,lateral)).normalized()
		var up := across.cross(forward).normalized()
		node.transform=Transform3D(Basis(across,up,-forward).orthonormalized(),at-Vector3.UP*.06)
		node.set_meta("station",station)
		node.set_meta("outside",outside)
		var visual := MeshInstance3D.new()
		visual.mesh=log_mesh
		node.add_child(visual)
		for row: int in range(4):
			for column: int in range(4-row):
				var shape := CylinderShape3D.new()
				shape.radius=RADIUS
				shape.height=LENGTH
				var collision := CollisionShape3D.new()
				collision.shape=shape
				collision.position=log_center(row,column)
				collision.rotation.x=PI*.5
				node.add_child(collision)
		land.log_piles.append(node)
		land.obstacles.append(node)

static func log_center(row: int,column: int) -> Vector3:
	return Vector3((column-(3-row)*.5)*RADIUS*2,RADIUS+row*RADIUS*sqrt(3),0)

static func pile_mesh() -> ArrayMesh:
	var b := RallySampleMeshes.new()
	for row: int in range(4):
		for column: int in range(4-row):
			var center := log_center(row,column)
			var seed := row*4+column
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=RADIUS
			cylinder.bottom_radius=RADIUS
			cylinder.height=LENGTH
			cylinder.radial_segments=12
			b.append(cylinder,Transform3D(Basis(Vector3.RIGHT,PI*.5),center),Color("73503a").lightened((seed%3)*.035))
			# Broken bark ridges and contrasting end grain retain the faceted art style.
			for ridge: int in range(9):
				var angle := ridge*TAU/9+.2
				var offset := Vector3(cos(angle)*.316,sin(angle)*.316,0)
				b.beam(center+offset+Vector3(0,0,-2.25),center+offset+Vector3(0,0,2.25),.014,Color("483b2c"))
			for side: float in [-1,1]:
				var face := center+Vector3(0,0,side*(LENGTH*.5+.003))
				for ring: int in range(12):
					var inner := ring/12.0*.297
					var outer := (ring+1)/12.0*.297
					var color := Color("bf8e56") if ring%2 else Color("e2b77d")
					for segment: int in range(32):
						var a := segment*TAU/32
						var c := (segment+1)*TAU/32
						var p := face+grain(a,inner,seed)
						var q := face+grain(c,inner,seed)
						var r := face+grain(a,outer,seed)
						var t := face+grain(c,outer,seed)
						b.triangle(p,r,q,color)
						b.triangle(q,r,t,color)
				# A short radial drying crack makes the cut ends less diagrammatic.
				b.beam(face+Vector3(.15,-.02,side*.003),face+Vector3(.285,-.04,side*.003),.008,Color("624934"))
	return b.finish()

static func grain(angle: float,radius: float,seed: int) -> Vector3:
	var warped := radius*(1+.022*sin(angle*5+seed)+.015*cos(angle*3+seed))
	return Vector3(cos(angle)*warped,sin(angle)*warped,0)
