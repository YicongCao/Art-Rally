extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 root.size=Vector2i(1200,800)
 var view:=RallyGarageView.new()
 root.add_child(view)
 view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.reduced_motion=true
 for node: Node in view.world.get_children():
  if node not in [view.camera,view.display] and node is not Light3D and node is not WorldEnvironment: node.queue_free()
 view.set_process(false)
 GrayboxGeometry.box(view.world,"StudioFloor",Vector3(200,.1,200),Vector3(0,-.05,0),Color("a5aca7"))
 view.camera.fov=42
 var directory:="res://docs/expansion/models"
 DirAccess.make_dir_recursive_absolute(directory)
 for id: String in ["I20","DELTA","EVO6","WRX","P7"]:
  view.set_car(RallyContentCatalog.vehicle(id))
  for side: String in ["front","rear","side"]:
   view.camera.position={"front":Vector3(5,2.8,-6.5),"rear":Vector3(-5,2.8,6.5),"side":Vector3(7.9,1.15,0)}[side]
   view.camera.look_at(Vector3(0,.65,0))
   for i: int in range(8): await process_frame
   await RenderingServer.frame_post_draw
   var shot:=view.viewport.get_texture().get_image()
   shot.save_png(directory+"/"+id+"-"+side+".png")
   if side=="front": shot.save_png("res://assets/ui/menu_models/"+id+".png")
   print("MODEL ",id," ",side)
 view.queue_free()
 await process_frame
 quit()
