"""Brushline authored Blender pass. Run with Blender --background --python this file.
Refines existing editable vehicle/prop sources in place; creates new named-part sources.
Export is independent. Runtime animation uses Leg*, Rotor, FlagArm nodes.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
exec((ROOT/'scripts/create_screenprint_sources.py').read_text().split('for args in ')[0])
# Localized Blender shader nodes must be found by type.
def mat(name,color=None):
 m=bpy.data.materials.get(name)
 if m:return m
 h=COLORS.get(color or name,color or name);rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
 m=bpy.data.materials.new(name);m.use_nodes=True
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(*rgb,1);bs.inputs['Roughness'].default_value=.74
 m.diffuse_color=(*rgb,1);return m
COLORS.update(white='f0e8ce',orange='ef652f',navy='182640',chrome='abb6bc',brown='8d6849',skin='bd8968',dark='282b30',sand='d9bd8b')
OUT=ROOT/'art_source/screenprint'
def finish(kind):
 path=OUT/'props'/f'{kind}.blend';bpy.context.scene['brushline_revision']='1';save(path,'prop')
def parent_keep(o,p):
 bpy.context.view_layer.update()
 m=o.matrix_world.copy();o.parent=p;o.matrix_parent_inverse=p.matrix_world.inverted();o.matrix_world=m
 bpy.context.view_layer.update()

def person(kind='marshal',at=(0,0,0)):
 origin=Vector(at);before=set(bpy.data.objects)
 shirt='orange' if kind=='marshal' else 'teal'
 box('Jacket',origin+Vector((0,1.18,0)),(.45,.55,.27),shirt,.08)
 for y in [.99,1.29]:box('ReflectiveVest',origin+Vector((0,y,-.145)),(.44,.045,.014),'white',.002)
 ellipsoid('Head',origin+Vector((0,1.68,0)),(.15,.19,.15),'skin')
 box('Cap',origin+Vector((0,1.85,-.02)),(.33,.06,.36),'navy',.02)
 for side in [-1,1]:
  beam('Trouser',origin+Vector((side*.12,.94,0)),origin+Vector((side*.15,.18,.03)),.15,'navy')
  box('Boot',origin+Vector((side*.15,.1,-.06)),(.19,.15,.33),'dark',.03)
  limb_before=set(bpy.data.objects)
  shoulder=origin+Vector((side*.26,1.38,0));end=origin+Vector((side*.52,1.85 if side==1 else 1.12,-.08))
  beam('Sleeve',shoulder,shoulder.lerp(end,.55),.14,shirt);beam('Forearm',shoulder.lerp(end,.55),end,.09,'skin')
  arm=bpy.data.objects.new('FlagArm' if side==1 else 'CheerArm',None);bpy.context.collection.objects.link(arm);arm.location=(shoulder.x,-shoulder.z,shoulder.y)
  for obj in set(bpy.data.objects)-limb_before-{arm}:parent_keep(obj,arm)
 if kind=='marshal':
  flag_before=set(bpy.data.objects)
  beam('FlagPole',origin+Vector((.52,1.78,-.08)),origin+Vector((.52,2.8,-.08)),.025,'chrome')
  for x in range(5):
   for y in range(3):
    quad('CheckerFlag',[(origin.x+.52+x*.13,origin.y+2.8-y*.12,origin.z-.08),(origin.x+.65+x*.13,origin.y+2.8-y*.12,origin.z-.08+math.sin(x)*.04),(origin.x+.65+x*.13,origin.y+2.68-y*.12,origin.z-.08+math.sin(x)*.04),(origin.x+.52+x*.13,origin.y+2.68-y*.12,origin.z-.08)],'dark' if (x+y)%2 else 'white')
  for obj in set(bpy.data.objects)-flag_before:parent_keep(obj,bpy.data.objects["FlagArm"])
 return set(bpy.data.objects)-before

# Refine tails without regenerating the approved front/side shapes or anchors.
for ident in ['F160','R200','A240']:
 path=OUT/'vehicles'/f'{ident}.blend';bpy.ops.wm.open_mainfile(filepath=str(path))
 for o in list(bpy.data.objects):
  if o.name.startswith(('RearModel','BrushlineDetail')):bpy.data.objects.remove(o,do_unlink=True)
 plate=bpy.data.objects['PlateRear'];end=-plate.location.y-.095
 width={'F160':1.76,'R200':1.78,'A240':1.86}[ident];half=width/2
 before=set(bpy.data.objects)
 # Structured lamp lenses, hatch seam, paired catches and rear towing loop.
 for side in [-1,1]:
  x=side*(half-.24)
  box('LampSurround',(x,.18,end+.076),(.40,.17,.026),'dark',.025)
  box('BrakeLampLensPanel',(x,.18,end+.09),(.36,.13,.015),'red',.015)
  for j in range(5):box('LensFlute',(x-.16+j*.08,.20,end+.094),(.012,.10,.012),'red',.003)
  box('ReverseLens',(x-side*.10,.14,end+.098),(.09,.035,.012),'white',.003)
  beam('HatchSeam',(side*(half-.43),.31,end+.073),(side*(half-.43),.06,end+.073),.005,'dark')
  box('HatchCatch',(side*.40,.29,end+.079),(.035,.07,.02),'chrome',.006)
  box('RearMudflap',(side*(half-.11),-.40,end-.20),(.25,.36,.035),'dark',.01)
 for j in range(5):box('DiffuserFin',(-.48+j*.24,-.24,end),(.024,.12,.23),'dark',.005)
 beam('RearStrut',(-.63,-.10,end+.075),(-.44,-.23,end+.14),.018,'chrome')
 if ident=='R200':
  for j,col in enumerate(['teal','plum','red']):box('RearTricolor',(-.35+j*.11,.28,end+.09),(.10,.07,.016),col,0)
 elif ident=='F160':
  for side in [-1,1]:quad('RearRacingSlash',[(side*.52,-.09,end+.083),(side*.76,-.02,end+.083),(side*.76,.05,end+.083),(side*.52,-.02,end+.083)],'red')
 else:
  for j in range(10):box('RearVent',(-.40+j*.09,.32,end+.085),(.05,.085,.016),'dark',.003)
 for o in set(bpy.data.objects)-before:o.name='BrushlineDetail_'+o.name
 bpy.context.scene['brushline_revision']='tail-1';save(path,'vehicle')

reset()
# Soft inflated pillar with panel seams and weighted foot.
for y,r,c in [(0.15,.32,'dark'),(.32,.26,'white'),(2.45,.24,'orange')]:
 cylinder('Pillar', (0,y,0),r,.30 if y<.4 else 4.2,c,24)
ellipsoid('Cap',(0,4.56,0),(.24,.17,.24),'orange')
for y in [.62,1.25,3.65,4.15]:cylinder('Band',(0,y,0),.245,.16,'white',24)
for a in range(6):
 x,z=math.cos(a*math.tau/6)*.242,math.sin(a*math.tau/6)*.242
 beam('FabricSeam',(x,.4,z),(x,4.45,z),.006,'sand')
finish('checkpoint')

reset()
# Sewn balloon gores: shaped envelope, ropes, burner and woven basket.
for sector in range(24):
 verts=[]
 for ring in range(17):
  phi=.22+ring*2.7/16
  for edge in [0,1]:
   a=(sector+edge)*math.tau/24
   verts.append((math.sin(phi)*math.cos(a)*6,math.cos(phi)*8+10,math.sin(phi)*math.sin(a)*6))
 mesh('EnvelopeGore',verts,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(16)],['orange','white','teal','white'][sector//3%4])
box('Basket',(0,.65,0),(2.1,1.3,1.6),'brown',.13)
for y in range(8):
 for z in [-.81,.81]:beam('BasketWeave',(-1,.15+y*.14,z),(1,.15+y*.14,z),.025,'sand')
for side in [-1,1]:
 for z in [-.7,.7]:beam('SuspensionRope',(side*.9,1.2,z),(side*1.5,3.4,z),.035,'white')
cylinder('Burner',(0,2.5,0),.3,.45,'chrome');finish('balloon')

for kind in ['reindeer','bear','zebra','ostrich','kangaroo']:
 reset();coat={'reindeer':'brown','bear':'504039','zebra':'white','ostrich':'dark','kangaroo':'b5895e'}[kind]
 hip=1.3 if kind=='ostrich' else (.7 if kind=='kangaroo' else .95)
 body=(.56,.57,.96) if kind=='bear' else ((.5,.5,.73) if kind=='ostrich' else (.38,.46,.76))
 ellipsoid('Torso',(0,hip+.25,0),body,coat)
 head_y={'reindeer':2.0,'bear':1.3,'zebra':2.1,'ostrich':2.85,'kangaroo':2.05}[kind]
 beam('Neck',(0,hip+.3,-.45),(0,head_y-.15,-.65),.22 if kind!='ostrich' else .09,coat)
 ellipsoid('Head',(0,head_y,-.77),(.22,.24,.34),coat)
 ellipsoid('Muzzle',(0,head_y-.08,-1.04),(.18,.13,.17),'dark' if kind!='bear' else 'sand')
 for side in [-1,1]:
  ellipsoid('Eye',(side*.193,head_y+.05,-.94),(.035,.04,.045),'dark')
  ellipsoid('Ear',(side*.18,head_y+.25,-.65),(.08,.24 if kind=='kangaroo' else .14,.09),coat)
 if kind=='reindeer':
  for side in [-1,1]:
   beam('Antler',(side*.13,2.15,-.6),(side*.5,2.8,-.4),.035,'sand')
   for j in range(4):beam('AntlerTine',(side*(.18+j*.08),2.27+j*.13,-.55),(side*(.30+j*.10),2.62+j*.12,-.77),.021,'sand')
 if kind=='kangaroo':
  beam('Tail',(0,.7,.45),(0,.13,1.7),.16,coat)
  ellipsoid('Pouch',(0,1.1,-.40),(.24,.4,.10),'sand')
  for side in [-1,1]:beam('Arm',(side*.25,1.5,-.4),(side*.3,.95,-.67),.07,coat)
 if kind=='ostrich':
  for side in [-1,1]:ellipsoid('Wing',(side*.48,1.53,.1),(.17,.33,.66),'white')
  ellipsoid('Tail',(0,1.8,.7),(.30,.25,.4),'white')
 if kind=='zebra':
  # Irregular wrap stripes follow the torso surface, not planar decals.
  for band in range(10):
   z=-.65+band*.14;radius=math.sqrt(max(.01,1-(z/.78)**2))
   verts=[]
   for j in range(33):
    t=j*math.tau/32
    for d in [-.025,.025]:verts.append((.385*radius*math.cos(t),hip+.25+.465*radius*math.sin(t),z+d+.018*math.sin(t*3)))
   mesh('ZebraStripe',verts,[(j*2,j*2+1,j*2+3,j*2+2) for j in range(32)],'dark')
  box('Mane',(0,1.8,-.47),(.12,.7,.12),'dark')
 count=2 if kind in ['ostrich','kangaroo'] else 4
 for i in range(count):
  at=Vector(((-.27 if i%2==0 else .27),hip,(-.48 if i<2 else .48) if count==4 else .08));pivot=marker(f'Leg{i}',at)
  a=beam('UpperLeg',at,at+Vector((0,-hip*.55,.08)),.16 if kind=='bear' else .085,coat);parent_keep(a,pivot)
  a=beam('LowerLeg',at+Vector((0,-hip*.55,.08)),at+Vector((0,-hip+.14,-.04)),.12 if kind=='bear' else .055,coat);parent_keep(a,pivot)
  a=box('Foot',at+Vector((0,-hip+.08,-.12)),(.20,.14,.49 if kind=='kangaroo' else .26),'dark',.035);parent_keep(a,pivot)
 finish(kind)

reset();person('marshal');finish('marshal')
reset();person('spectator');finish('spectator')
reset()
# Service point: canopy, reinforced frame, tool chest, fuel cans, stacked tires.
for x in [-2.8,2.8]:
 for z in [-1.8,1.8]:beam('TentPole',(x,0,z),(x,2.8,z),.06,'chrome')
mesh('Canopy',[(-3,2.8,-2),(3,2.8,-2),(3,2.8,2),(-3,2.8,2),(0,3.7,-2),(0,3.7,2)],[(0,1,4),(3,5,2),(0,4,5,3),(4,1,2,5)],'orange')
box('ToolChest',(-1.5,.55,.6),(1.3,1.1,.6),'teal',.04)
for y in [.2,.4,.6,.8]:box('DrawerHandle',(-1.5,y,.28),(.65,.025,.04),'chrome',.005)
for x in [.4,.9]:
 box('FuelCan',(x,.30,.6),(.3,.55,.24),'red',.05);beam('CanHandle',(x-.08,.59,.6),(x+.08,.59,.6),.04,'dark')
for y in [.17,.48,.79]:
 o=cylinder('SpareTire',(1.8,y,.6),.37,.28,'dark');cylinder('WheelHub',(1.8,y+.145,.6),.19,.012,'white')
finish('service_station')
# Existing authored props stay authoritative. Add refinements without replacing them.
for kind in ['helicopter','sailboat']:
 path=OUT/'props'/f'{kind}.blend';bpy.ops.wm.open_mainfile(filepath=str(path))
 for o in list(bpy.data.objects):
  if o.name.startswith('Brushline'):bpy.data.objects.remove(o,do_unlink=True)
 if kind=='helicopter':
  # Reporter and shoulder camera project out of the left door into the player's view.
  box('BrushlineDoorOpening',(-1.65,.15,.65),(.04,1.6,1.6),'dark',.06)
  box('BrushlineReporterVest',(-2.03,.25,.65),(.45,.65,.44),'orange',.08)
  ellipsoid('BrushlineReporterHead',(-2.03,.95,.65),(.22,.25,.22),'skin')
  box('BrushlineShoulderCamera',(-2.65,.72,1.04),(1.05,.42,.44),'dark',.045)
  ellipsoid('BrushlineCameraGlass',(-3.20,.72,1.04),(.04,.20,.20),'teal')
  for z in [.47,.85]:
   beam('BrushlineArm',(-2.02,.50,z),(-2.6,.60,z+.25),.09,'skin')
   beam('BrushlineLeg',(-2.0,-.12,z),(-2.35,-1.15,z+.15),.13,'navy')
 else:
  for side in [-1,1]:
   beam('BrushlineShroud',(side*1.2,1.1,0),(0,8.3,.1),.024,'white')
   beam('BrushlineRail',(side*1.1,1.25,-2.7),(side*1.1,1.25,2.6),.035,'chrome')
  box('BrushlineCabin',(0,1.25,.2),(1.5,.6,1.8),'white',.10)
 finish(kind)
print('BRUSHLINE AUTHORING PASSED')
