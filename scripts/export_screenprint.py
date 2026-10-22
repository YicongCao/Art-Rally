"""Export authored .blend sources without saving or regenerating them.
Blender --background --python scripts/export_screenprint.py [-- --only=F160]
Produces GLBs, three vehicle LODs, and a geometry/anchor manifest.
"""
import bpy,json,sys,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
only=next((a.split('=',1)[1] for a in args if a.startswith('--only=')),None)
manifest={}
# Vehicles rendered with the smooth high-fidelity shader; no ink outline shell.
HIFI={'P7'}
for src in sorted((ROOT/'art_source/screenprint').glob('*/*.blend')):
 if only and src.stem not in only.split(","):continue
 vehicle=src.parent.name=='vehicles'
 for lod in range(3 if vehicle else 1):
  bpy.ops.wm.open_mainfile(filepath=str(src))
  # Apply only on the export copy; edited source remains authoritative.
  for o in list(bpy.context.scene.objects):
   if o.type!='MESH':continue
   bpy.context.view_layer.objects.active=o;o.select_set(True)
   for m in list(o.modifiers):
    try:bpy.ops.object.modifier_apply(modifier=m.name)
    except RuntimeError: pass
   if lod and len(o.data.polygons)>40:
    ratios=[1,.40,.14] if src.stem in HIFI else [1,.52,.22]
    m=o.modifiers.new('Export LOD','DECIMATE');m.ratio=ratios[lod];bpy.ops.object.modifier_apply(modifier=m.name)
   if vehicle and src.stem not in HIFI and (o.get('outline',False) or o.name.startswith(('Bumper','Spoiler','FrontValance','RearValance'))):
    proxy=o.copy();proxy.data=o.data.copy();proxy.name='Outline_'+o.name;bpy.context.collection.objects.link(proxy)
    for p in proxy.data.polygons:p.use_smooth=True
    proxy.data.materials.clear()
    ink=bpy.data.materials.get('OutlineInk') or bpy.data.materials.new('OutlineInk');ink.diffuse_color=(.012,.016,.022,1);proxy.data.materials.append(ink)
   o.select_set(False)
  # Batch by semantic material on export, preserving authored source components.
  groups={}
  for o in list(bpy.context.scene.objects):
   if o.type!='MESH':continue
   key='OutlineInk' if o.name.startswith('Outline_') else ('BrakeLamp' if 'BrakeLamp' in o.name else o.data.materials[0].name)
   groups.setdefault((o.parent.name if o.parent else '',key),[]).append(o)
  for (parent_name,key),objects in groups.items():
   bpy.ops.object.select_all(action='DESELECT')
   for o in objects:o.select_set(True)
   bpy.context.view_layer.objects.active=objects[0]
   if len(objects)>1:bpy.ops.object.join()
   bpy.context.object.name='Outline_Body' if key=='OutlineInk' else key
  meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
  triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes if not o.name.startswith('Outline_'))
  # High-fidelity exception: the P7 is authored with subdivision surfaces.
  budget=90000 if src.stem in HIFI else 40000
  if vehicle and triangles>budget:raise RuntimeError(f'{src}: {triangles} exceeds budget')
  for o in meshes:
   if any(not math.isfinite(v) for vert in o.data.vertices for v in vert.co):raise RuntimeError('Nonfinite vertex '+o.name)
   if not o.data.materials:raise RuntimeError('Missing material '+o.name)
  mounts={o.name:[round(o.location.x,6),round(o.location.z,6),round(-o.location.y,6)] for o in bpy.context.scene.objects if o.type=='EMPTY'}
  if vehicle:
   required={'PlateFront','PlateRear','TailLeft','TailRight','CameraCockpit','CameraHood',*(f'WheelMount{i}' for i in range(4))}
   if not required<=set(mounts):raise RuntimeError('Missing mounts '+str(required-set(mounts)))
  dest=ROOT/'assets/screenprint'/src.parent.name/(src.stem+(f'-lod{lod}' if vehicle else '')+'.glb')
  dest.parent.mkdir(parents=True,exist_ok=True)
  bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_apply=True,export_yup=True,export_extras=True)
  manifest[str(dest.relative_to(ROOT))]={'source':str(src.relative_to(ROOT)),'triangles':triangles,'lod':lod,'mounts':mounts}
if only and not manifest: raise RuntimeError('No source matched --only='+only)
exported=len(manifest)
path=ROOT/'assets/screenprint/manifest.json'
if only and path.exists():manifest={**json.loads(path.read_text()),**manifest}
path.write_text(json.dumps(manifest,indent=2)+'\n')
print('SCREENPRINT EXPORT PASSED',exported,'assets')
