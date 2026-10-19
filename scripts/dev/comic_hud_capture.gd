# Isolated layout fixture: representative values, not driving or performance evidence.
extends SceneTree
var viewport: SubViewport
var hud: RallyHUD
func _initialize() -> void:_run.call_deferred()
func snap(label: String) -> void:
	for i: int in range(4):await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://docs/art-direction/comic-hud/"+label+".png")
func _run() -> void:
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background:=ColorRect.new()
	background.color=Color("263139")
	background.size=Vector2(1280,720)
	viewport.add_child(background)
	hud=RallyHUD.new()
	viewport.add_child(hud)
	var car:=RallyVehicle.new()
	root.add_child(car)
	var route:=RallyStageRoute.new()
	route.build(RallyContentCatalog.stage("sunset_ridge"))
	var session:=RallyStageSession.new()
	session.setup(route)
	session.phase=RallyStageSession.Phase.RUNNING
	session.elapsed=754.567
	session.progress=800
	hud.set_route(route)
	var data:=RallyHUD.data_for(car,session,false)
	data.speed=188
	data.rpm=7000
	data.gear="5"
	data.note="LEFT_TIGHT"
	data.note_distance=65
	data.position=Vector2(route.position_at(800).x,route.position_at(800).z)
	data.ghost_position=Vector2(route.position_at(850).x,route.position_at(850).z)
	data.ghost_progress=850
	for degrees: int in [20,40,60,90,130,170]:
		data.bend_degrees=degrees
		hud.refresh(data)
		await snap("fixture-left-%d"%degrees)
	data.note="RIGHT_TIGHT"
	hud.refresh(data)
	await snap("fixture-right-hairpin")
	car.queue_free()
	viewport.queue_free()
	await process_frame
	print("COMIC HUD FIXTURES PASSED")
	quit()
