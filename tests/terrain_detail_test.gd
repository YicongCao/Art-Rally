extends "res://tests/test_suite.gd"

func _run() -> void:
	for id: String in RallyContentCatalog.STAGES:
		var generator := RallyStageGenerator.new()
		generator.definition=RallyContentCatalog.stage(id)
		root.add_child(generator)
		var land := RallyStageScenery.new()
		root.add_child(land)
		land.build(generator)
		await ticks(2)
		var route := generator.route
		var active := 0
		var loose := 0
		var max_bump := 0.0
		var asphalt_flat := true
		var bridges_flat := true
		for s: int in range(60,int(route.length)-100):
			var bump := absf(route.definition.bumps_at(s,.8))
			max_bump=maxf(max_bump,bump)
			if route.definition.surface_weights(s).x<.01:
				loose+=1
				if bump>.005: active+=1
			if route.definition.surface_weights(s).x>.999:
				asphalt_flat=asphalt_flat and absf(route.road_relief(s,2))<.0001
		for bridge: Vector3 in route.definition.river_crossings:
			for s: int in range(int(bridge.x-bridge.y*.5-20),int(bridge.x+bridge.y*.5+20)):
				bridges_flat=bridges_flat and absf(route.road_relief(s,1))<.0001
		check(max_bump>.015 and max_bump<.061,id+" contains centimetre-scale relief")
		check(float(active)/loose<.35 and float(active)/loose>.02,id+" relief is sparse rather than continuous")
		check(asphalt_flat and bridges_flat,id+" asphalt and bridge approaches stay smooth")
		var positive := false
		var negative := false
		for bank: Vector3 in route.definition.bank_sections:
			var middle := (bank.x+bank.y)*.5
			var outside := signf(route.tangent_at(middle-10).signed_angle_to(route.tangent_at(middle+10),Vector3.UP))
			var half := route.width_at(middle)*.5
			var diff := route.road_relief(middle,outside*half)-route.road_relief(middle,-outside*half)
			positive=positive or diff>.08
			negative=negative or diff<-.08
		check(positive and negative,id+" has helpful and adverse physical camber")
		var space := generator.get_world_3d().direct_space_state
		var mismatch := 0
		for patch: Vector3 in route.definition.rough_patches:
			for offset: float in [-1.1,0,1.1]:
				var at := generator.surface_position_at(patch.x+3.1,offset)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP,1))
				if hit.is_empty() or absf(hit.position.y-at.y)>.002: mismatch+=1
		check(mismatch==0,id+" visible roughness and road collision coincide")
		check(land.log_piles.size()==(0 if id=="sunlit_cape" else 4),id+" has authored timber obstacles only where intended")
		for pile: Node3D in land.log_piles:
			check(pile.find_children("*","CollisionShape3D",false,false).size()==10,"Timber pile has ten solid logs in 4/3/2/1 rows")
			var station: float=pile.get_meta("station")
			check(route.notes.any(func(n: Dictionary): return n.code=="LOGS" and absf(n.s-station)<1),"Every pile has an obstacle / no-cut pacenote")
			check(not route.notes.any(func(n: Dictionary): return n.code=="CUT" and absf(n.s-station)<65),"No contradictory cut instruction near timber")
			var probe := CharacterBody3D.new()
			probe.collision_layer=2
			probe.collision_mask=4
			var collision := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size=Vector3(.7,.6,.7)
			collision.shape=box
			probe.add_child(collision)
			root.add_child(probe)
			probe.transform=pile.transform*Transform3D(Basis.IDENTITY,Vector3(0,.6,4))
			await ticks(1)
			var contact := probe.move_and_collide(-pile.basis.z*4)
			check(contact!=null and contact.get_collider()==pile,"Vehicle-layer body cannot pass through log ends")
			probe.free()
		# Independent ray checks against a collider built from the rendered terrain.
		var terrain_body := StaticBody3D.new()
		terrain_body.collision_layer=8
		var terrain_shape := CollisionShape3D.new()
		terrain_shape.shape=land.dressing.get_node("StageTerrain").mesh.create_trimesh_shape()
		terrain_body.add_child(terrain_shape)
		root.add_child(terrain_body)
		await ticks(2)
		var ray_misses := 0
		var cliff_trees := 0
		var trees := 0
		var floating := 0
		var old_error := 0.0
		for placement: Dictionary in land.foliage.placements:
			if placement.kind not in ["pine","umbrella"] or absf(placement.lateral)<22: continue
			trees+=1
			var p: Vector3=placement.point
			var actual := land.rendered_height_at(p.x,p.z)
			if land.terrain_slope_at(p)>1.15001: cliff_trees+=1
			if absf(p.y-actual)>.001: floating+=1
			old_error=maxf(old_error,land.height_at(p.x,p.z)-actual)
			if trees%17==0:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP*2,8))
				if hit.is_empty() or absf(hit.position.y-p.y)>.003: ray_misses+=1
		check(trees>30 and floating==0,id+" distant tree roots match rendered terrain triangles")
		check(ray_misses==0 and cliff_trees==0,id+" terrain rays meet tree roots and sheer cliffs stay bare")
		terrain_body.free()
		print("TERRAIN DETAIL: ",id," rough_fraction=",float(active)/loose," max_bump=",max_bump," trees=",trees," previous_height_error=",old_error)
		land.free()
		generator.free()
		await process_frame
	finish()
