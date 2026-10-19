"""One-time authored corrections; never regenerate vehicle bodies. Safe to rerun."""
import bpy,math,runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
for ident,track,cockpit,hood in [('F160',1.5,(0,.80,-.64),(0,.75,-1.25)),('R200',1.58,(0,.65,-.40),(0,.66,-1.40)),('A240',1.72,(0,.74,-.8),(0,.72,-1.4))]:
 p=ROOT/'art_source/screenprint/vehicles'/f'{ident}.blend';bpy.ops.wm.open_mainfile(filepath=str(p))
 if bpy.context.scene.get('mount_revision')==1:continue
 for name,pos in [('CameraCockpit',cockpit),('CameraHood',hood)]:bpy.data.objects[name].location=(pos[0],-pos[2],pos[1])
 for i in range(4):bpy.data.objects[f'WheelMount{i}'].location.x=(-.5 if i%2==0 else .5)*track
 bpy.context.scene['mount_revision']=1;bpy.ops.wm.save_as_mainfile(filepath=str(p))
p=ROOT/'art_source/screenprint/props/cabin.blend';bpy.ops.wm.open_mainfile(filepath=str(p))
if not bpy.context.scene.get('gable_revision'):
 for o in bpy.context.scene.objects:
  if o.name.startswith('Roof'):o.rotation_euler.y=-o.rotation_euler.y
 # Solid gable faces close the triangular gaps under the roof.
 for z in [-3,3]:
  me=bpy.data.meshes.new('Gable');me.from_pydata([(-4,-z,5),(4,-z,5),(0,-z,7.5)],[],[(0,1,2)]);me.update();o=bpy.data.objects.new('Gable',me);bpy.context.collection.objects.link(o);o.data.materials.append(bpy.data.materials['red'])
 bpy.context.scene['gable_revision']=1;bpy.ops.wm.save_as_mainfile(filepath=str(p))

p=ROOT/'art_source/screenprint/props/wheel_tire.blend'
if p.exists():
 bpy.ops.wm.open_mainfile(filepath=str(p))
 if not bpy.context.scene.get('tread_revision'):
  for o in bpy.context.scene.objects:
   if o.name.startswith(('ATTread','ShoulderLug')):
    a=math.atan2(-o.location.y,o.location.x);o.rotation_euler=(0,0,-a+math.pi/2)
  bpy.context.scene['tread_revision']=1;bpy.ops.wm.save_as_mainfile(filepath=str(p))

# Deliberate one-time rim topology revision to satisfy the four-wheel budget.
p=ROOT/'art_source/screenprint/props/wheel_rim.blend'
bpy.ops.wm.open_mainfile(filepath=str(p))
if not bpy.context.scene.get('rim_budget_revision'):
 for o in bpy.context.scene.objects:
  for m in list(o.modifiers):o.modifiers.remove(m)
  if o.type=='MESH' and o.name.startswith('RimLip'):
   bpy.context.view_layer.objects.active=o;m=o.modifiers.new('Controlled rim simplification','DECIMATE');m.ratio=.60;bpy.ops.object.modifier_apply(modifier=m.name)
 bpy.context.scene['rim_budget_revision']=1;bpy.ops.wm.save_as_mainfile(filepath=str(p))

# Blender/GLTF store linear values. The art bible hex palette is sRGB.
for p in sorted((ROOT/'art_source/screenprint').glob('*/*.blend')):
 bpy.ops.wm.open_mainfile(filepath=str(p))
 if bpy.context.scene.get('linear_palette_revision'):continue
 for material in bpy.data.materials:
  c=material.diffuse_color
  linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c[:3]]
  material.diffuse_color=(*linear,c[3])
  if material.use_nodes:
   bs=material.node_tree.nodes.get('Principled BSDF')
   if bs:bs.inputs['Base Color'].default_value=(*linear,c[3])
 bpy.context.scene['linear_palette_revision']=1
 bpy.ops.wm.save_as_mainfile(filepath=str(p))

p=ROOT/'art_source/screenprint/props/wheel_rim.blend'
bpy.ops.wm.open_mainfile(filepath=str(p))
if not bpy.context.scene.get('radial_spoke_revision'):
 for o in bpy.context.scene.objects:
  if o.name.startswith('Spoke'):
   o.rotation_euler.z=math.atan2(o.location.x,-o.location.y)
   direction=o.rotation_euler.to_matrix()@Vector((0,1,0))
   assert abs(direction.normalized().dot(o.location.normalized()))>.99
 ink=bpy.data.materials.get('ink') or bpy.data.materials.new('ink')
 srgb=[int('20252b'[i:i+2],16)/255 for i in (0,2,4)]
 c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in srgb]
 ink.diffuse_color=(*c,1);ink.use_nodes=True
 ink.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
 for o in bpy.context.scene.objects:
  if o.name.startswith('BrakeDisc'):o.data.materials.clear();o.data.materials.append(ink)
 bpy.context.scene['radial_spoke_revision']=1
 bpy.ops.wm.save_as_mainfile(filepath=str(p))
