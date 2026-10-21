class_name RallyGaragePage
extends RefCounted

static func build(app: RallyGameApp) -> void:
 app._page("自由改装车库","","garage")
 var top:=app._row(app.column)
 var selector:=OptionButton.new()
 for id: String in RallyContentCatalog.VEHICLES: selector.add_item(RallyContentCatalog.vehicle(id).short_title())
 selector.select(RallyContentCatalog.VEHICLES.find(app.garage_vehicle))
 selector.item_selected.connect(func(i: int): app.garage_change_vehicle(RallyContentCatalog.VEHICLES[i]))
 top.add_child(selector)
 var slots:=OptionButton.new()
 slots.add_item("原厂方案")
 var saved:=app.garage_store.slots(app.garage_vehicle)
 for i: int in range(3): slots.add_item("方案 %d%s"%[i+1," · 空" if saved[i]==null else ""])
 slots.selected=app.garage_slot+1
 slots.item_selected.connect(func(i: int): app.garage_load_slot(i-1))
 top.add_child(slots)
 app._button(top,"保存方案",app.garage_save).custom_minimum_size.x=110
 app._button(top,"恢复默认",func(): app.garage_confirm(func(): app.garage_draft=RallyGarageCatalog.stock(RallyContentCatalog.vehicle(app.garage_vehicle)); app.garage_slot=-1; app.show_garage())).custom_minimum_size.x=110
 var body:=app._row(app.column)
 body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var view:=RallyGarageView.new()
 app.garage_view=view
 view.reduced_motion=app.prefs.values.reduced_motion
 body.add_child(view)
 view.set_car(RallyGarageCatalog.resolve(RallyContentCatalog.vehicle(app.garage_vehicle),app.garage_draft))
 view.shelf_selected.connect(func(cat: String): app.garage_category=cat; view.focus_shelf(cat); refresh_panel(app))
 var panel:=app._card(body)
 panel.add_theme_constant_override("separation",5)
 panel.get_parent().custom_minimum_size.x=360
 panel.get_parent().size_flags_horizontal=Control.SIZE_SHRINK_END
 app.garage_panel=panel
 var nav:=app._row(app.column)
 for cat: String in RallyGarageCatalog.CATEGORIES+ ["tuning"]:
  var button:=app._button(nav,"调校" if cat=="tuning" else RallyGarageCatalog.TITLES[cat],func(): app.garage_category=cat; view.focus_shelf("" if cat=="tuning" else cat); refresh_panel(app))
  button.custom_minimum_size=Vector2(110,40)
  button.set_meta("garage_category",cat)
 app._button(nav,"向左环绕",func(): view.rotate_car(-PI*.25)).custom_minimum_size=Vector2(90,40)
 app._button(nav,"向右环绕",func(): view.rotate_car(PI*.25)).custom_minimum_size=Vector2(90,40)
 refresh_panel(app)
 var footer:=app._row(app.column)
 app._button(footer,"返回主菜单",func(): app.garage_confirm(func(): app.modified_mode=false; app.garage_test=false; app.show_home())).custom_minimum_size.x=170
 app._button(footer,"改装计时",func(): app.modified_mode=true; app.garage_test=false; app.chosen_vehicle=app.garage_vehicle; app.chosen_power_tier=0; app.show_stages())
 app._button(footer,"600 m 试车",func(): app.modified_mode=true; app.garage_test=true; app.chosen_vehicle=app.garage_vehicle; app.chosen_power_tier=0; app.start_race()).grab_focus()
 app.page_back=func(): app.garage_confirm(func(): app.modified_mode=false; app.show_home())

static func refresh_panel(app: RallyGameApp) -> void:
 var focus:=app.get_viewport().gui_get_focus_owner()
 var focus_key: String=str(focus.get_meta("focus_key","")) if focus!=null else ""
 for child: Node in app.garage_panel.get_children():
  app.garage_panel.remove_child(child)
  child.queue_free()
 var panel:=app.garage_panel
 var cat:=app.garage_category
 for button: Node in app.ui.find_children("*","Button",true,false):
  if button.has_meta("garage_category"): RallySelectionStyle.apply(button,str(button.get_meta("garage_category"))==cat)
 var car:=RallyContentCatalog.vehicle(app.garage_vehicle)
 app._label(panel,car.short_title(),18)
 if cat=="tuning":
  app._label(panel,"整车调校",17)
  for row: Array in RallyGarageCatalog.tuning_rows(car,app.garage_draft):
   var line:=app._row(panel)
   var caption:=app._label(line,str(row[1]),15)
   caption.custom_minimum_size.x=115
   var value:=app._label(line,_value(float(app.garage_draft.tune[row[0]]),str(row[5])),15)
   value.autowrap_mode=TextServer.AUTOWRAP_OFF
   var slider:=HSlider.new()
   slider.min_value=row[2]; slider.max_value=row[3]; slider.step=row[4]
   slider.value=float(app.garage_draft.tune[row[0]])
   slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   slider.custom_minimum_size=Vector2(105,28)
   line.add_child(slider)
   if row[0]=="lock":
    caption.text="锁止"
    caption.custom_minimum_size.x=38
    var presets:=OptionButton.new()
    for title: String in ["开放","均衡","强锁止","自定"]: presets.add_item(title)
    presets.custom_minimum_size.x=80
    presets.add_theme_font_size_override("font_size",14)
    slider.custom_minimum_size.x=90
    value.custom_minimum_size.x=43
    presets.set_item_disabled(3,true)
    presets.select([0.0,50.0,100.0].find(slider.value) if slider.value in [0.0,50.0,100.0] else 3)
    slider.value_changed.connect(func(v: float): presets.select([0.0,50.0,100.0].find(v) if v in [0.0,50.0,100.0] else 3))
    line.add_child(presets)
    line.move_child(presets,1)
    presets.item_selected.connect(func(index: int): slider.value=[0,50,100][index])
   slider.value_changed.connect(func(v: float): app.garage_draft.tune[row[0]]=v; value.text=_value(v,str(row[5])); update_car(app))
  app._label(panel,"0% 开放 · 100% 最大附加锁止",12)
 else:
  app._label(panel,("电驱控制" if car.electric and cat=="engine" else ("减速器" if car.electric and cat=="gearbox" else RallyGarageCatalog.TITLES[cat])),20)
  for part: Array in RallyGarageCatalog.PARTS[cat]:
   var button:=app._button(panel,str(part[1]),func(): app.garage_draft.parts[cat]=part[0]; RallyGarageCatalog.fit_ranges(car,app.garage_draft); update_car(app); app.garage_view.install_part(cat); refresh_panel(app))
   button.custom_minimum_size=Vector2(260,36)
   button.set_meta("focus_key","garage-part:"+str(part[0]))
   RallySelectionStyle.apply(button,app.garage_draft.parts[cat]==part[0])
   if str(button.get_meta("focus_key"))==focus_key: button.grab_focus()
  for part: Array in RallyGarageCatalog.PARTS[cat]:
   if app.garage_draft.parts[cat]==part[0]: app._label(panel,str(part[2]),14)
 app._label(panel,"当前草稿 · %s"%RallyGarageCatalog.fingerprint(app.garage_draft).substr(0,8),13).set_meta("garage_fingerprint",true)
 if not app.garage_store.message.is_empty(): app._label(panel,app.garage_store.message,14)

static func update_car(app: RallyGameApp) -> void:
 app.garage_dirty=true
 for label: Node in app.garage_panel.get_children():
  if label.has_meta("garage_fingerprint"): label.text="当前草稿 · "+RallyGarageCatalog.fingerprint(app.garage_draft).substr(0,8)
 app.garage_view.set_car(RallyGarageCatalog.resolve(RallyContentCatalog.vehicle(app.garage_vehicle),app.garage_draft))

static func _value(value: float,unit: String) -> String:
 return ("%.2f"%value if unit=="×" else "%.0f"%value)+" "+unit
