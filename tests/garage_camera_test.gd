extends "res://tests/test_suite.gd"
func _run() -> void:
 var view:=RallyGarageView.new()
 root.add_child(view)
 view.set_process(false)
 var initial:=Vector3(3.6,2.6,4.5)
 var reference: Dictionary={}
 for fps: int in [30,60,120]:
  for cat: String in RallyGarageCatalog.CATEGORIES:
   view.camera.position=initial
   view.look_point=Vector3(0,.65,0)
   view.focus_shelf(cat)
   var stable:=true
   for i: int in range(fps*2):
    view._process(1.0/fps)
    stable=stable and view.camera.position.is_finite() and view.camera.position.y>1.5 and view.camera.basis.y.dot(Vector3.UP)>.5
   check(stable,"Shelf camera has a stable horizon at %d FPS: %s"%[fps,cat])
   if fps==30: reference[cat]=view.camera.transform
   else:
    var baseline: Transform3D=reference[cat]
    check(view.camera.position.distance_to(baseline.origin)<.0001 and view.camera.basis.is_equal_approx(baseline.basis),"Camera agrees across frame rates: "+cat)
 view.reduced_motion=true
 view.focus_shelf("")
 view._process(1.0/120)
 check(view.camera.position==initial,"Reduced motion snaps to overview")
 view.queue_free()
 await process_frame
 finish()
