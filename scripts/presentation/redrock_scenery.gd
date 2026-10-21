class_name RallyRedrockScenery
extends RefCounted

static func build(scene: RallyStageScenery) -> void:
 var route := scene.route
 var root := scene.dressing
 var rng := RandomNumberGenerator.new()
 rng.seed=86204
 var rock := ShaderMaterial.new()
 rock.shader=preload("res://assets/shaders/redrock.gdshader")
 if route.length<1000:
  if scene.generator.definition.stage_id=="redrock_sample":
   for s: int in range(0,90,25):
    for side: float in [-1,1]: _tower(root,scene.ground_at(s,side*15),Vector3(15,30,22),rock,rng)
  else:
   for s: int in range(160,230,10):
    for side: float in [-1,1]: GrayboxGeometry.box(root,"BrakeMarker",Vector3(.35,.6,.35),scene.ground_at(s,side*5)+Vector3.UP*.3,Color("e26935"))
  return
 # Layered towers frame the opening; their bases stay outside the collision apron.
 for s: float in range(100,870,55):
  for side: float in [-1,1]:
   var height := rng.randf_range(20,42)
   var at := scene.ground_at(s,side*rng.randf_range(13,19))
   _tower(root,at,Vector3(rng.randf_range(8,13),height,rng.randf_range(19,31)),rock,rng)
 # Eroded banks make the gravel section read as a dry river channel. The
 # stepped ledges stay outside the recoverable driving corridor, below the arch.
 var bank_rng:=RandomNumberGenerator.new()
 bank_rng.seed=86205
 var riverbed:=Node3D.new()
 riverbed.name="DryRiverbedBanks"
 root.add_child(riverbed)
 for s: int in range(2250,2990,32):
  for side: float in [-1,1]:
   for ledge: int in range(2):
    var at:=scene.ground_at(s,side*(17+ledge*8))
    var near:=scene.nearest(at)
    if float(near.distance)<12: continue
    _tower(riverbed,at,Vector3(8+ledge*3,4+ledge*5+bank_rng.randf_range(0,2),25),rock,bank_rng)
 # A single readable landmark, authored in route space so its opening crosses the road.
 var arch_pose := route.pose_at(minf(2740,route.length*.76),0)
 var arch := Node3D.new()
 arch.name="MonumentalStoneArch"
 arch.transform=arch_pose
 root.add_child(arch)
 for side: float in [-1,1]:
  _tower(arch,Vector3(side*15,-3,0),Vector3(10,29,13),rock,rng)
 var arch_mesh:=SurfaceTool.new()
 arch_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i: int in range(32):
  var rings: Array=[]
  for j: int in [i,i+1]:
   var angle:=float(j)/32*PI
   var outer:=19.2+sin(angle*5)*.5
   var inner:=12.1+sin(angle*7)*.3
   var points: Array[Vector3]=[]
   for pair: Vector2 in [Vector2(inner,-4.5),Vector2(outer,-4.2),Vector2(outer,4.2),Vector2(inner,4.5)]:
    points.append(Vector3(cos(angle)*pair.x,13+sin(angle)*pair.x,pair.y+sin(angle*3)*.5))
   rings.append(points)
  for edge: int in range(4):
   for vertex: Vector3 in [rings[0][edge],rings[1][(edge+1)%4],rings[1][edge],rings[0][edge],rings[0][(edge+1)%4],rings[1][(edge+1)%4]]: arch_mesh.add_vertex(vertex)
 arch_mesh.generate_normals()
 var bridge:=MeshInstance3D.new()
 bridge.mesh=arch_mesh.commit()
 bridge.material_override=rock
 arch.add_child(bridge)
 # Distant flat-top mesas; sizes and placements echo the finish overlook.
 for i: int in range(18):
  var s := 200.0+float(i)/17*(route.length-400)
  var side := -1.0 if i%2==0 else 1.0
  var at := scene.ground_at(s,side*rng.randf_range(180,360))
  var nearest:=scene.nearest(at)
  if float(nearest.distance)<85 or float(nearest.s)>3000: continue
  _tower(root,at,Vector3(rng.randf_range(55,100),rng.randf_range(55,115),rng.randf_range(65,120)),rock,rng)
 var plants := RallySampleMeshes.new()
 for s: int in range(40,int(route.length)-50,10):
  for side: float in [-1,1]:
   if rng.randf()>.58: continue
   var at := scene.ground_at(s,side*rng.randf_range(8,28))
   for branch: int in range(3):
    var tip := at+Vector3(rng.randf_range(-.45,.45),rng.randf_range(.3,.7),rng.randf_range(-.45,.45))
    plants.beam(at,tip,.065,Color("647467"))
   if rng.randf()<.2: _rock(root,at+Vector3(0,.12,0),Vector3(.6,.3,.55),rock)
 var vegetation := MeshInstance3D.new()
 vegetation.name="DesertSage"
 vegetation.mesh=plants.finish()
 vegetation.visibility_range_end=220
 root.add_child(vegetation)
 # Weathered mining gantry at the opening, kept off the driving lane.
 var station := route.pose_at(65,0)
 var service := Node3D.new()
 service.name="MiningServiceStation"
 service.transform=station
 root.add_child(service)
 for x: float in [-15,-9]:
  GrayboxGeometry.box(service,"Timber",Vector3(.4,5,.4),Vector3(x,2.5,4),Color("675547"))
 GrayboxGeometry.box(service,"Gantry",Vector3(8,.5,.5),Vector3(-12,5,4),Color("826548"))
 GrayboxGeometry.box(service,"ServiceShed",Vector3(6,3.8,5),Vector3(-12,1.9,-3),Color("606a68"))
 GrayboxGeometry.box(service,"TinRoof",Vector3(6.6,.18,5.5),Vector3(-12,3.9,-3),Color("b2a083"))
 for node: Node in scene.generator.get_children():
  if node.get_meta("prototype_marker",false): node.visible=false

static func _rock(parent: Node3D,at: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new()
 var tool:=SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings: Array=[]
 var seed_angle:=at.x*.37+at.z*.29
 for level: int in range(9):
  var y:=float(level)/8-.5
  var ring: Array[Vector3]=[]
  var radius:=.49-.11*float(level)/8+.035*sin(level*2.1+seed_angle)
  for j: int in range(11):
   var angle:=j*TAU/11
   var r:=radius+.035*sin(angle*3+seed_angle)
   ring.append(Vector3(cos(angle)*r,y,sin(angle)*r))
  rings.append(ring)
 for level: int in range(8):
  for j: int in range(11):
   var k: int=(j+1)%11
   for vertex: Vector3 in [rings[level][j],rings[level+1][k],rings[level+1][j],rings[level][j],rings[level][k],rings[level+1][k]]: tool.add_vertex(vertex)
 for j: int in range(11):
  for vertex: Vector3 in [Vector3(0,.5,0),rings[8][j],rings[8][(j+1)%11]]: tool.add_vertex(vertex)
 tool.generate_normals()
 mesh.mesh=tool.commit()
 mesh.position=at
 mesh.scale=size
 mesh.material_override=material
 parent.add_child(mesh)
 return mesh

static func _tower(parent: Node3D,base: Vector3,size: Vector3,material: Material,rng: RandomNumberGenerator) -> void:
 var mesh:=_rock(parent,base+Vector3.UP*size.y*.5,size,material)
 mesh.rotation.y=rng.randf_range(-.2,.2)
