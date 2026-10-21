extends "res://tests/test_suite.gd"
func _run() -> void:
 var app:=load("res://scenes/game/game.tscn").instantiate() as RallyGameApp
 app.profile.path="user://garage-ui-%d/profile.json"%Time.get_ticks_usec()
 root.add_child(app)
 app.prefs.values.reduced_motion=true
 for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  root.size=resolution
  await ticks(2)
  for page: String in ["garage","stages","vehicles","records"]:
   if page=="garage": app.show_garage(); app.garage_category="tuning"; RallyGaragePage.refresh_panel(app)
   elif page=="stages": app.show_stages()
   elif page=="vehicles": app.vehicle_page=2; app.show_vehicles()
   else: app.show_records()
   app.transitions.finish_slide()
   await ticks(3)
   var inside:=true
   for button: Node in app.ui.find_children("*","Button",true,false):
    if not button.is_visible_in_tree(): continue
    var rect: Rect2=button.get_global_rect()
    if rect.position.x<0 or rect.position.y<0 or rect.end.x>resolution.x+1 or rect.end.y>resolution.y+1:
     inside=false
     print("OVERFLOW ",page," ",resolution," ",button.text," ",rect)
   check(inside,page+" actions visible at "+str(resolution))
 app.show_garage()
 app.garage_category="tires"
 RallyGaragePage.refresh_panel(app)
 var sand: Button
 for button: Node in app.garage_panel.find_children("*","Button",true,false):
  if button.get_meta("focus_key","")=="garage-part:sand": sand=button
 check(sand!=null,"Sand part is keyboard focusable")
 sand.grab_focus()
 var event:=InputEventKey.new()
 event.keycode=KEY_ENTER
 event.pressed=true
 root.push_input(event)
 event=event.duplicate(); event.pressed=false; root.push_input(event)
 await ticks(2)
 check(app.garage_draft.parts.tires=="sand","GUI keyboard confirmation installs focused part")
 check(app.get_viewport().gui_get_focus_owner()!=null,"Part refresh restores focus")
 app.garage_slot=0
 app.garage_save()
 await ticks(4)
 var selectors:=app.ui.find_children("*","OptionButton",true,false)
 check(not app.garage_dirty and selectors[1].selected==1,"Saving refreshes the selected custom slot")
 app.garage_change_vehicle("P7")
 await ticks(3)
 check(app.garage_vehicle=="P7" and app.garage_draft.vehicle=="P7","Vehicle switch creates its own stock draft")
 app.garage_category="tires"
 RallyGaragePage.refresh_panel(app)
 var road: Button
 for button: Node in app.garage_panel.find_children("*","Button",true,false):
  if button.get_meta("focus_key","")=="garage-part:road": road=button
 road.grab_focus()
 var joy:=InputEventJoypadButton.new()
 joy.button_index=JOY_BUTTON_A
 joy.pressed=true
 root.push_input(joy)
 joy=joy.duplicate(); joy.pressed=false; root.push_input(joy)
 await ticks(3)
 check(app.garage_draft.parts.tires=="road","Virtual gamepad confirm installs the focused part")
 app.garage_load_slot(-1)
 var dialog: ConfirmationDialog=app.ui.find_child("*",true,false) as ConfirmationDialog
 for child: Node in app.ui.get_children():
  if child is ConfirmationDialog: dialog=child
 check(dialog!=null,"Dirty setup requests save or discard")
 dialog.confirmed.emit()
 await ticks(3)
 check(app.garage_draft.parts.tires=="stock" and not app.garage_dirty,"Discard restores stock without writing the draft")
 check(app.garage_store.slots("R200")[0].parts.tires=="sand","Other car's saved setup remains intact")
 app.queue_free()
 await process_frame
 finish()
