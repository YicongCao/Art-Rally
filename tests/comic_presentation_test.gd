extends "res://tests/test_suite.gd"

func _run() -> void:
	for id: String in RallyContentCatalog.STAGES:
		var definition := RallyContentCatalog.stage(id)
		var route := RallyStageRoute.new()
		route.build(definition)
		var covered := 0
		for i: int in range(10000):
			if RallyBreakablePosts.covers(route.length*(i+.5)/10000.0,route.length):covered+=1
		check(covered==3000,id+" posts cover exactly 30% of distance")
		var stations := RallyBreakablePosts.stations(route.length)
		check(stations==RallyBreakablePosts.stations(route.length),id+" post positions repeat deterministically")
		check(stations.size()>60 and stations.size()<95,id+" paired post budget stays bounded")
	var size := Vector3(1.8,1.2,4.0)
	var pose := Transform3D(Basis.IDENTITY,Vector3(0,1,0))
	check(RallyBreakablePosts.intersects_post(Vector3(.7,0,0),pose,pose,size),"A body corner can snap a post")
	check(not RallyBreakablePosts.intersects_post(Vector3(1.1,0,0),pose,pose,size),"Nearby post outside car envelope stays intact")
	check(not RallyBreakablePosts.intersects_post(Vector3(0,4,0),pose,pose,size),"Post at different height cannot be hit")
	var before := Transform3D(Basis.IDENTITY,Vector3(0,1,6))
	var after := Transform3D(Basis.IDENTITY,Vector3(0,1,-6))
	check(RallyBreakablePosts.intersects_post(Vector3.ZERO,before,after,size),"Swept body catches fast crossing without tunnelling")
	before.origin.z=60
	check(not RallyBreakablePosts.intersects_post(Vector3.ZERO,before,after,size),"Recovery teleport does not mow down posts")
	var turn := Transform3D(Basis(Vector3.UP,PI/2),Vector3(0,1,0))
	check(RallyBreakablePosts.intersects_post(Vector3(1.7,0,0),turn,turn,size),"Rotated body uses longitudinal rather than lateral extent")
	var slots: Array[int]=[]
	for degrees: float in [20,40,60,90,130,170]:
		var left := RallyComicHUDArt.turn("LEFT_TIGHT",degrees)
		var right := RallyComicHUDArt.turn("RIGHT_TIGHT",degrees)
		slots.append(left.sprite)
		check(left.sprite==right.sprite and not left.right and right.right,"Left/right use identical mirrored artwork at "+str(degrees))
		var texture := RallyComicHUDArt.sprite(left.sprite)
		check(texture.region.end.x<=texture.atlas.get_width() and texture.region.end.y<=texture.atlas.get_height(),"Arrow region fits native atlas")
	check(slots==[4,5,6,7,9,10],"Six bend severities have distinct silhouettes")
	var font := RallyHUD._racing_font()
	check(font.has_meta("comic_italic"),"Driving digits use the screen-space italic renderer")
	check(font.get_string_size("12:34.567",HORIZONTAL_ALIGNMENT_LEFT,-1,32).x<210,"Timer fits beside the red slash")
	var posts := RallyBreakablePosts.new()
	root.add_child(posts)
	posts.batch=MultiMesh.new()
	posts.batch.transform_format=MultiMesh.TRANSFORM_3D
	posts.batch.mesh=BoxMesh.new()
	posts.batch.instance_count=12
	for i: int in range(12):posts.poses.append(Transform3D(Basis.IDENTITY,Vector3(i,0,0)))
	posts.piece_mesh=BoxMesh.new()
	posts.band_mesh=BoxMesh.new()
	posts.break_post(0,Vector3.FORWARD*25)
	posts.break_post(0,Vector3.FORWARD*25)
	check(posts.hits==1 and posts.debris.size()==3,"A post fractures once into three pieces")
	check(posts.debris[0].body.collision_mask==1 and posts.debris[0].body.collision_layer==0,"Debris falls on terrain without snagging the car")
	for i: int in range(1,12):posts.break_post(i,Vector3.FORWARD*25)
	check(posts.debris.size()==24,"Repeated impacts keep a bounded debris pool")
	posts.queue_free()
	await process_frame
	finish()
