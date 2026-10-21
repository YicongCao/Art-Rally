class_name RallyGarageView
extends SubViewportContainer
signal shelf_selected(category: String)
var viewport:=SubViewport.new()
var world:=Node3D.new()
var camera:=Camera3D.new()
var display:=Node3D.new()
var target_position:=Vector3(3.6,2.6,4.5)
var target_look:=Vector3(0,.65,0)
var look_point:=Vector3(0,.65,0)
var shelves: Dictionary={}
var orbit:=0.0
var reduced_motion:=false
var category: String=""
var door:=Node3D.new()
var door_progress:=0.0

func _ready() -> void:
 stretch=true
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 size_flags_vertical=Control.SIZE_EXPAND_FILL
 custom_minimum_size=Vector2(420,240)
 add_child(viewport)
 viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.msaa_3d=Viewport.MSAA_2X
 viewport.add_child(world)
 world.add_child(camera)
 camera.position=target_position
 camera.look_at(target_look)
 camera.fov=58
 world.add_child(display)
 var environment:=WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("84adbb")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("b1cbd2")
 environment.environment.ambient_light_energy=.6
 environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 world.add_child(environment)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-32,-45,0)
 sun.light_color=Color("ffe1a4")
 sun.light_energy=1.8
 sun.shadow_enabled=true
 world.add_child(sun)
 var key:=OmniLight3D.new()
 key.position=Vector3(1,4,2)
 key.light_color=Color("bbdbea")
 key.light_energy=2
 key.omni_range=13
 world.add_child(key)
 _box(world,"Concrete",Vector3(15,.2,15),Vector3(0,-.15,0),"656961")

 for side: float in [-1,1]:
  _box(world,"SideWall",Vector3(.2,5,14),Vector3(side*7,2.5,0),"536a6e")
  _box(world,"DoorJamb",Vector3(3.6,5,.22),Vector3(side*5.1,2.5,-5),"586367")
 _box(world,"DoorLintel",Vector3(7,1,.3),Vector3(0,4.5,-5),"49595c")
 _box(world,"DesertOutside",Vector3(40,.1,40),Vector3(0,-.25,-22),"d6a669")
 world.add_child(door)
 door.position=Vector3(0,0,-5)
 for i: int in range(22): _box(door,"ShutterSlat",Vector3(6.6,.175,.08),Vector3(0,.11+i*.18,0),"9aa8a5")
 _box(world,"Workbench",Vector3(2.6,.17,.85),Vector3(4.6,1.1,-4.25),"b9a17a")
 for side: float in [-1,1]: _box(world,"BenchLeg",Vector3(.10,1.1,.65),Vector3(4.6+side*1.05,.5,-4.25),"394f54")
 _box(world,"ToolWall",Vector3(2.6,1.5,.1),Vector3(4.6,2.2,-4.83),"30494e")
 for i: int in range(10):
  _box(world,"Tool",Vector3(.035,.28+.08*(i%3),.04),Vector3(3.5+i*.24,2.25,-4.72),"b3bbb1")
 for i: int in range(4):
  var cat: String=RallyGarageCatalog.CATEGORIES[i]
  var at:=Vector3(-5.1 if i<2 else 5.1,0,-2.4 if i%2==0 else .8)
  shelves[cat]=at
  var shelf:=Node3D.new()
  shelf.position=at
  world.add_child(shelf)
  for x: float in [-.78,.78]:
   for z: float in [-.65,.65]: _box(shelf,"Upright",Vector3(.06,2.6,.06),Vector3(x,1.3,z),"c3a75d")
  for y: float in [.15,1.0,1.9]: _box(shelf,"Shelf",Vector3(1.7,.07,1.5),Vector3(0,y,0),"40545a")
  for n: int in range(3):
   var pos:=Vector3((n-1)*.47,1.35,0)
   if cat=="tires":
    var tire:=MeshInstance3D.new()
    tire.mesh=RallyWheelMeshes.tire(.34)
    tire.rotation.z=PI*.5
    tire.position=pos
    shelf.add_child(tire)
   elif cat=="suspension":
    _box(shelf,"Damper",Vector3(.08,.6,.08),pos,"d6a83c")
    for ring: int in range(7):
     var spring:=MeshInstance3D.new()
     var torus:=TorusMesh.new()
     torus.inner_radius=.075; torus.outer_radius=.10; torus.rings=12; torus.ring_segments=4
     spring.mesh=torus
     spring.position=pos+Vector3(0,-.22+ring*.07,0)
     shelf.add_child(spring)
   else:
    _box(shelf,"TransmissionCase" if cat=="gearbox" else "PowerModule",Vector3(.35,.36,.5),pos,"a6b2ad")
    _box(shelf,"Shaft" if cat=="gearbox" else "CylinderHead",Vector3(.08,.12,.65),pos+Vector3(0,.18,0),"3c555b")
  var label:=Label3D.new()
  label.text=RallyGarageCatalog.TITLES[cat]
  label.font=RallyFonts.bold()
  label.font_size=64
  label.pixel_size=.006
  label.position=Vector3(0,2.9,0)
  label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  shelf.add_child(label)
  var area:=Area3D.new()
  area.set_meta("category",cat)
  var shape:=CollisionShape3D.new()
  var box:=BoxShape3D.new()
  box.size=Vector3(1.9,2.8,1.7)
  shape.shape=box
  shape.position.y=1.4
  area.add_child(shape)
  shelf.add_child(area)
 gui_input.connect(_input_view)

func _box(parent: Node3D,label: String,dimensions: Vector3,at: Vector3,color: String) -> void:
 GrayboxGeometry.box(parent,label,dimensions,at,Color(color))

func set_car(car: RallyVehicleDefinition) -> void:
 for child: Node in display.get_children(): child.free()
 var config:=car.physics_config()
 var body:=RallyVehicleAppearance.build(car)
 var ride:=config.suspension_rest-config.static_compression/config.spring_multiplier+config.wheel_radius
 body.position.y=ride
 display.add_child(body)
 for i: int in range(4):
  var wheel:=MeshInstance3D.new()
  wheel.mesh=RallyWheelMeshes.tire(config.wheel_radius,car.tire_config().compound)
  wheel.rotation.z=PI*.5
  wheel.position=config.wheel_mount(i)+Vector3.UP*config.wheel_radius
  var width_scale:=car.tire_config().section_width/.23
  wheel.scale.y=width_scale
  display.add_child(wheel)
  var rim:=MeshInstance3D.new()
  rim.mesh=RallyWheelMeshes.five_spoke()
  rim.rotation.z=-signf(wheel.position.x)*PI*.5
  rim.position=wheel.position+Vector3(signf(wheel.position.x)*.115*width_scale,0,0)
  if car.vehicle_id=="WRX":
   var gold:=StandardMaterial3D.new()
   gold.albedo_color=Color("d6b046")
   rim.material_override=gold
  display.add_child(rim)
  _box(display,"VisibleDamper",Vector3(.065,maxf(.15,ride-.2),.065),Vector3(wheel.position.x*.85,(ride+.2)*.5,wheel.position.z),"d6a83c")

func focus_shelf(cat: String) -> void:
 category=cat
 if cat.is_empty():
  target_position=Vector3(3.6,2.6,4.5)
  target_look=Vector3(0,.65,0)
 else:
  var at: Vector3=shelves.get(cat,Vector3.ZERO)
  target_position=at+Vector3(-signf(at.x)*3.8,2.2,3.1)
  target_look=at+Vector3.UP*1.4

func _process(dt: float) -> void:
 var weight:=1.0 if reduced_motion else 1-exp(-dt*6)
 camera.position=camera.position.lerp(target_position,weight)
 look_point=look_point.lerp(target_look,weight)
 camera.look_at(look_point)
 door_progress=move_toward(door_progress,1,dt/(.15 if reduced_motion else 2.3))
 door.position.y=door_progress*3.8
 if Input.is_key_pressed(KEY_LEFT) and has_focus(): rotate_car(-dt)
 if Input.is_key_pressed(KEY_RIGHT) and has_focus(): rotate_car(dt)

func rotate_car(amount: float) -> void:
 display.rotation.y+=amount

func _input_view(event: InputEvent) -> void:
 if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
  display.rotation.y+=event.relative.x*.008
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  var point: Vector2=event.position
  var origin:=camera.project_ray_origin(point)
  var ray:=PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(point)*100)
  ray.collide_with_areas=true
  var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
  if not hit.is_empty() and hit.collider.has_meta("category"): shelf_selected.emit(str(hit.collider.get_meta("category")))

func install_part(cat: String) -> void:
 if reduced_motion: return
 var part:=MeshInstance3D.new()
 if cat=="tires": part.mesh=RallyWheelMeshes.tire(.34,"sand")
 else:
  var block:=BoxMesh.new()
  block.size=Vector3(.35,.25,.5)
  part.mesh=block
  var material:=StandardMaterial3D.new()
  material.albedo_color=Color("d6a83c") if cat=="suspension" else Color("a6b2ad")
  part.material_override=material
 world.add_child(part)
 part.position=shelves.get(cat,Vector3.ZERO)+Vector3.UP*1.4
 var tween:=create_tween()
 tween.tween_property(part,"position",Vector3(0,1.2,-1),.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 tween.tween_property(part,"scale",Vector3.ONE*.05,.16)
 tween.tween_callback(part.queue_free)
