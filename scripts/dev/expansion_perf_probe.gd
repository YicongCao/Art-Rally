extends SceneTree
# Baseline-compatible probe: run this absolute script with either checkout's --path.
# Fixed simulation frames and native 1080p render target; loading is excluded.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(1920,1080)
 viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var display:=TextureRect.new()
 display.texture=viewport.get_texture()
 display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.add_child(display)
 var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
 app.profile.path="user://expansion-perf-%d/profile.json"%OS.get_process_id()
 viewport.add_child(app)
 AudioServer.set_bus_mute(0,true)
 app.chosen_stage="sunlit_cape"
 app.chosen_vehicle="A240"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--probe-stage="): app.chosen_stage=argument.trim_prefix("--probe-stage=")
  if argument.begins_with("--probe-car="): app.chosen_vehicle=argument.trim_prefix("--probe-car=")
 app.practice=true
 await app.start_race()
 app.race._set_autopilot_mode_name("vgamepad")
 var frames: Array[float]=[]
 var physics: Array[float]=[]
 var previous:=Time.get_ticks_usec()
 for i: int in range(780):
  paused=false
  app.race.controls.resume()
  app.race.pause_menu.hide()
  await process_frame
  var now:=Time.get_ticks_usec()
  if i>=180:
   frames.append((now-previous)/1000.0)
   physics.append(app.race.vehicle.physics_usec/1000.0)
  previous=now
 frames.sort()
 physics.sort()
 var total:=0.0
 for ms: float in frames: total+=ms
 print("EXPANSION_PERF: ",JSON.stringify({"stage":app.chosen_stage,"vehicle":app.chosen_vehicle,"pixels":[viewport.size.x,viewport.size.y],"frames":frames.size(),"average_fps":frames.size()*1000/total,"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"min_fps":1000/frames[-1],"max_fps":1000/frames[0],"physics_p95_ms":physics[int(physics.size()*.95)],"progress":app.race.session.progress,"renderer":RenderingServer.get_video_adapter_name()}))
 await app.leave_race()
 viewport.queue_free()
 display.queue_free()
 await process_frame
 quit()
