extends "res://tests/test_suite.gd"

func _run() -> void:
	RallyTerrainGeometryCache.clear()
	var definition := RallyContentCatalog.stage("sunset_ridge").duplicate(true) as RallyStageDefinition
	var generator := RallyStageGenerator.new()
	generator.definition=definition
	root.add_child(generator)
	var original_key := RallyTerrainGeometryCache.key_for(definition,generator.route.points)
	definition.road_width+=.5
	check(original_key!=RallyTerrainGeometryCache.key_for(definition,generator.route.points),"Stage property edits invalidate cached geometry")
	definition.road_width-=.5
	var moved := generator.route.points.duplicate()
	moved[0]+=Vector3.UP
	check(original_key!=RallyTerrainGeometryCache.key_for(definition,moved),"Changed sampled route invalidates cached geometry")
	var first := RallyStageScenery.new()
	root.add_child(first)
	first.build(generator)
	var terrain: MeshInstance3D=first.dressing.get_node("StageTerrain")
	var vertices: int = terrain.mesh.surface_get_array_len(0)
	for chunk: MeshInstance3D in terrain.get_children(): vertices+=chunk.mesh.surface_get_array_len(0)
	check(terrain.get_child_count()>1,"Terrain has independent culling bounds")
	check(vertices==first.terrain_count.x*first.terrain_count.y*6,"Chunking preserves all original terrain triangles")
	var second := RallyStageScenery.new()
	root.add_child(second)
	second.build(generator)
	var reused: MeshInstance3D=second.dressing.get_node("StageTerrain")
	check(first.terrain_vertices==second.terrain_vertices and terrain.mesh==reused.mesh,"Warm loading reuses identical immutable geometry")
	check(terrain.material_override!=reused.material_override,"Scene materials remain independent")
	check(first.foliage.placements==second.foliage.placements,"Cached vegetation preserves all deterministic placements")
	check(first.foliage.rng.state==second.foliage.rng.state,"Cached plan preserves later spectator random sequence")
	check(first.foliage.batches.size()==second.foliage.batches.size(),"Warm and cold render batching agree")
	var cached := RallyTerrainGeometryCache.fetch(original_key)
	RallyTerrainGeometryCache.remember("copy2",cached)
	RallyTerrainGeometryCache.remember("copy3",cached)
	check(RallyTerrainGeometryCache.entries.size()<=2 and RallyTerrainGeometryCache.bytes<=RallyTerrainGeometryCache.MAX_BYTES,"Geometry cache obeys entry and memory limits")
	check(RallyTerrainGeometryCache.fetch(original_key).is_empty(),"Least recently used terrain entry is evicted")
	first.free(); second.free(); generator.free()
	RallyTerrainGeometryCache.clear()
	await process_frame
	finish()
