extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 root.size=Vector2i(1280,720)
 DisplayServer.window_set_size(root.size)
 var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
 app.profile.path="user://screenprint-showcase/profile.json"
 root.add_child(app)
 AudioServer.set_bus_mute(0,true)
 app.profile.data=RallyProfileStore.fresh()
 app.profile.data.plate="ART-RALLY"
 for index: int in range(3):
  app.chosen_stage=RallyContentCatalog.STAGES[index]
  app.chosen_vehicle=RallyContentCatalog.VEHICLES[index]
  await app.start_race()
  var route: RallyStageRoute=app.race.generator.route
  var station: float=[430,1390,1580][index]
  var pose := route.pose_at(station)
  app.race.session.projection_hint=route.index_at(station)
  app.race.session.previous=pose.origin
  app.race.session.progress=station
  while app.race.session.gates[app.race.session.next_gate]<station:app.race.session.next_gate+=1
  app.race.session.phase=RallyStageSession.Phase.RUNNING
  app.race.vehicle.request_reset(pose)
  app.race._set_autopilot_mode_name("vgamepad")
  app.race.auto_driver.reset_navigation(route,pose.origin)
  app.race.camera_snap=true
  for frame: int in range(480):
   if paused or app.race.controls.blocked:
    paused=false
    app.race.controls.resume()
   app.race.pause_menu.show_menu(false)
   await process_frame
  print("MOVIE DRIVE: ",app.chosen_stage," progress ",station," -> ",app.race.session.progress," speed ",app.race.vehicle.linear_velocity.length()*3.6)
  if app.race.session.progress<station+20:
   push_error("Showcase vehicle did not drive forward")
   quit(1)
   return
  await app.leave_race()
 app.queue_free()
 await process_frame
 quit()
