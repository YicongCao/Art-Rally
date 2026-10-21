"""Localized editable-source livery pass; no regeneration of vehicle geometry.
Blender -b --python scripts/refine_racing_livery.py. Export GLBs separately.
"""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
exec((ROOT/'scripts/build_brushline_assets.py').read_text().split('# Refine tails')[0])
COLORS.update(cyan='19a9e3',blue='254596',scarlet='dd2537',sun='ffca18',black='161b21')
for ident in ['F160','R200','A240']:
 path=OUT/'vehicles'/f'{ident}.blend'
 bpy.ops.wm.open_mainfile(filepath=str(path))
 anchors={o.name:tuple(o.location) for o in bpy.data.objects if o.type=='EMPTY'}
 for o in list(bpy.data.objects):
  if o.name.startswith('LiveryRear_') or (ident=='A240' and o.name.startswith(('WingQuattro','S1WingSide'))): bpy.data.objects.remove(o,do_unlink=True)
 if ident=='A240':
  for o in bpy.data.objects:
   if o.name=='Roof' or o.name.startswith('RoofSideRail'):
    o.data.materials.clear();o.data.materials.append(mat('sun'))
 e=-bpy.data.objects['PlateRear'].location.y-.095
 # Three-color band follows the existing sloping rear glass instead of floating
 # beyond the tail body. It repeats the side livery high in the chase camera.
 roof,rear,br,rw,h={'F160':(1.01,1.14,1.38,.665,.825),'R200':(.88,.80,1.20,.72,.88),'A240':(.94,1.10,e-.16,.78,.94)}[ident]
 palette={'F160':['white','scarlet','sun'],'R200':['cyan','blue','scarlet'],'A240':['sun','black','scarlet']}[ident]
 for j,col in enumerate(palette):
  def point(u,t):
   half=(h-.085)*(1-t)+rw*t
   return (u*half,.38*(1-t)+(roof-.035)*t+.003,br*(1-t)+rear*t+.004)
  u0=-.96+j*.64;u1=u0+.64
  quad('LiveryRear_GlassBanner',[point(u0,.78),point(u1,.78),point(u1,.93),point(u0,.93)],col)
 # Cross-car rear graphics sit clear of lenses, plate and glass. Wraps repeat
 # livery colors without placing large model-name lettering on the hatch.
 if ident=='F160':
  quad('LiveryRear_WhiteSash',[(-.75,-.19,e+.081),(.48,-.19,e+.081),(.64,-.10,e+.081),(-.75,-.10,e+.081)],'white')
  quad('LiveryRear_RedSash',[(-.68,-.184,e+.086),(-.32,-.184,e+.086),(-.16,-.106,e+.086),(-.52,-.106,e+.086)],'scarlet')
  quad('LiveryRear_YellowSash',[(.08,-.184,e+.087),(.39,-.184,e+.087),(.53,-.106,e+.087),(.22,-.106,e+.087)],'sun')
 elif ident=='R200':
  wing=bpy.data.objects['E30RearWing']
  # Three broad bands run along the complete top chord and wrap over its rear edge.
  for j,col in enumerate(['cyan','blue','scarlet']):
   x=-.54+j*.32
   box('LiveryRear_MWingTop',(x,.677,e-.21),(.32,.005,.255),col,0)
   box('LiveryRear_MWingEdge',(x,.64,e-.067),(.32,.058,.006),col,0)
   quad('LiveryRear_MFascia',[(x-.13,-.19,e+.083),(x+.13,-.19,e+.083),(x+.23,-.10,e+.083),(x-.03,-.10,e+.083)],col)
   box('LiveryRear_MBoot',(x,.413,e-.46),(.25,.005,.37),col,0)
 else:
  box('LiveryRear_YellowUpper',(0,-.17,e+.084),(1.62,.045,.008),'sun',0)
  for j,col in enumerate(['black','scarlet','sun']):
   x=-.48+j*.16
   quad('LiveryRear_AudiSlash',[(x,-.11,e+.088),(x+.12,-.11,e+.088),(x+.24,-.035,e+.088),(x+.12,-.035,e+.088)],col)
   # Asymmetric racing stripe replaces the removed wing wordmark.
   box('LiveryRear_WingStripe',(x,1.188,e-.20),(.15,.005,.57),col,0)
   box('LiveryRear_WingEdge',(x,1.15,e+.108),(.15,.062,.006),col,0)
 assert anchors=={o.name:tuple(o.location) for o in bpy.data.objects if o.type=='EMPTY'}
 bpy.context.scene['brushline_revision']='tail-livery-2'
 bpy.ops.wm.save_as_mainfile(filepath=str(path))
 print('LIVERY SAVED',ident)
