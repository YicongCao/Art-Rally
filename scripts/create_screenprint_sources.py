"""Bootstrap ORIGINAL screenprint models once. Existing .blend files are NEVER overwritten.
Blender is the authoring tool; use export_screenprint.py after editing sources.
Coordinates below use Godot (metres, +Y up, -Z forward)."""
import bpy, math
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art_source/screenprint'
COLORS={'ink':'20252b','ivory':'eee2c5','teal':'246263','yellow':'d6a83c','red':'ae4e36','plum':'493e5c','glass':'324c5a','rubber':'272b2b','metal':'8c9a92','lamp':'f7d994'}
def xyz(p): return (p[0],-p[2],p[1])
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for m in list(bpy.data.materials): bpy.data.materials.remove(m)
 bpy.context.scene.unit_settings.system='METRIC'
def mat(name,color=None):
 m=bpy.data.materials.get(name)
 if m:return m
 h=COLORS.get(color or name,color or name); srgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in srgb]
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=.82
 return m
def mesh(name,verts,faces,color):
 me=bpy.data.meshes.new(name);me.from_pydata([xyz(p) for p in verts],[],faces);me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);ob.data.materials.append(mat(color));return ob
def bevel(o,width=.025,segments=3):
 mod=o.modifiers.new('Authored edge radius','BEVEL');mod.width=width;mod.segments=segments
 o.modifiers.new('Weighted body normals','WEIGHTED_NORMAL');return o
def box(name,p,s,color,edge=.015):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.name=name;o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat(color))
 if edge:bevel(o,edge)
 return o
def beam(name,a,b,width,color):
 va,vb=Vector(xyz(a)),Vector(xyz(b));o=box(name,(0,0,0),(width,(vb-va).length,width),color,width*.15);o.location=(va+vb)/2;o.rotation_euler=(vb-va).to_track_quat('Z','Y').to_euler();return o
def ellipsoid(name,p,s,color):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,location=xyz(p));o=bpy.context.object;o.name=name;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat(color));return o
def cylinder(name,p,r,depth,color,vertices=24):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=xyz(p));o=bpy.context.object;o.name=name;o.data.materials.append(mat(color));bevel(o,.012,2);return o
def quad(name,v,color):return mesh(name,v,[(0,1,2,3)],color)
def marker(name,p):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=xyz(p);o.empty_display_size=.12;return o
def text(name,value,p,size,color,side=0):
 bpy.ops.object.text_add(location=xyz(p));o=bpy.context.object;o.name=name;o.data.body=value;o.data.align_x='CENTER';o.data.align_y='CENTER';o.data.size=size;o.data.extrude=.0007;o.data.materials.append(mat(color));o.rotation_euler=(math.pi/2,0,side*math.pi/2 if side else 0);bpy.ops.object.convert(target='MESH');return o
def save(path,kind):
 bpy.context.scene['art_rally_source']='screenprint-v1';bpy.context.scene['asset_kind']=kind;bpy.context.scene['linear_palette_revision']=1
 bpy.ops.wm.save_as_mainfile(filepath=str(path))
def vehicle(ident,w,length,wb,roof,front,rear,number,color):
 path=OUT/'vehicles'/f'{ident}.blend'
 if path.exists(): print('Preserving authored source',path);return
 reset();half=w/2;end=length/2;rw=half-.16
 # Connected upper shoulder, deliberately curved wheel openings and tapered nose.
 body=box('BodyShoulder',(0,.21,0),(w,.25,length-.16),color,.055);body['outline']=True
 box('Floor',(0,-.15,0),(w-.16,.10,length-.26),'ink')
 box('FrontValance',(0,-.02,-end+.09),(w-.1,.28,.16),color,.035)
 box('RearValance',(0,-.01,end-.09),(w-.1,.26,.16),color,.035)
 for side in [-1,1]:
  contour=[(-end+.1,-.18)]
  for axle in [-wb/2,wb/2]:
   contour.append((axle-.44,-.18))
   for j in range(21):
    a=math.pi-j*math.pi/20;contour.append((axle+.445*math.cos(a),-.34+.49*math.sin(a)))
  contour.append((end-.1,-.18))
  for j in range(len(contour)-1):
   a,b=contour[j:j+2];quad('FenderSkin',[(side*half,a[1],a[0]),(side*half,b[1],b[0]),(side*half,.31,b[0]),(side*half,.31,a[0])],color)
  for axle in [-wb/2,wb/2]:
   verts=[]
   for j in range(21):
    t=j*math.pi/20
    for r,xx in [(.45,half+.013),(.49,half+.055),(.52,half+.015)]:verts.append((side*xx,-.34+r*math.sin(t),axle+r*math.cos(t)))
   faces=[]
   for j in range(20):
    for k in range(2):faces.append((j*3+k,j*3+k+1,(j+1)*3+k+1,(j+1)*3+k))
   arch=mesh('ArchLip',verts,faces,color if ident=='A240' else 'ink');arch['outline']=True
  # All livery is original geometry; large shapes survive distant viewing.
  box('LowerStripe',(side*(half+.006),.12,0),(.012,.085,length-.22),'yellow' if ident=='A240' else 'ivory',0)
  if ident=='F160':quad('DiagonalIvory',[(side*(half+.014),-.12,-.65),(side*(half+.014),.32,-.35),(side*(half+.014),.32,.64),(side*(half+.014),-.12,.34)],'ivory')
  box('NumberPanel',(side*(half+.023),.025,.12),(.015,.25,.43),'ivory',.004)
  text('RaceNumber',number,(side*(half+.034),.025,.12),.23,'ink',side)
  box('Mirror',(side*(half+.07),.47,front-.12),(.15,.12,.22),color,.035)
  box('MirrorGlass',(side*(half+.075),.47,front+.001),(.12,.085,.008),'glass',.003)
  box('DoorHandle',(side*(half+.012),.27,.55),(.023,.025,.15),'ink',.006)
  for z in ([.0,.75] if ident=='A240' else [.72]):beam('DoorSeam',(side*(half+.014),-.08,z),(side*(half+.014),.31,z),.008,'ink')
  box('MudFlap',(side*(half-.09),-.38,wb/2+.43),(.23,.32,.025),'ink',.005)
 bf=front-.42;br=rear+(.48 if ident=='R200' else .16)
 quad('Windscreen',[(-half+.065,.34,bf),(half-.065,.34,bf),(rw,roof-.035,front),(-rw,roof-.035,front)],'glass')
 quad('RearGlass',[(-rw,roof-.035,rear),(rw,roof-.035,rear),(half-.06,.34,br),(-half+.06,.34,br)],'glass')
 top=box('Roof',(0,roof,(front+rear)/2),(rw*2+.065,.075,rear-front+.08),'ivory' if ident=='F160' else color,.035);top['outline']=True
 for side in [-1,1]:
  quad('SideGlass',[(side*(half-.04),.35,bf+.04),(side*rw,roof-.05,front+.04),(side*rw,roof-.05,rear-.04),(side*(half-.04),.35,br-.04)],'glass')
  for a,b in [((side*(half-.03),.32,bf),(side*rw,roof,front)),((side*(half-.03),.32,br),(side*rw,roof,rear))]:beam('Pillar',a,b,.065,color)
  for z in ([.0,.72] if ident=='A240' else [.42]):beam('DoorPillar',(side*(half-.035),.33,z),(side*rw,roof-.02,z),.045,'ink')
  # Cage and cabin remain visible in glass highlights; never replace physics cockpit.
  beam('RollCage',(side*(rw-.08),.25,.65),(side*(rw-.08),roof-.13,.65),.032,'ivory')
  seat=box('Seat',(side*.32,.42,.20),(.37,.48,.27),'ink',.06)
 beam('RollCageCross',(-rw+.08,roof-.14,.67),(rw-.08,.25,.67),.025,'ivory')
 box('Dash',(0,.32,front-.10),(w-.38,.16,.22),'ink',.025)
 for z in [-end,end]:box('Bumper',(0,-.14,z),(w+.015,.12,.12),'ink',.025)
 box('Grille',(0,.16,-end+.005),(.65,.13,.035),'ink',.009)
 for side in [-1,1]:
  if ident=='R200':
   for dx in [-.095,.095]:
    o=cylinder('Headlamp',(side*.57+dx,.19,-end-.005),.082,.025,'lamp');o.rotation_euler.x=math.pi/2
  else:
   box('Headlamp',(side*.57,.20,-end+.002),(.30,.145,.045),'lamp',.027)
   box('Indicator',(side*.65,.065,-end-.006),(.12,.035,.035),'yellow',.007)
  tw,th=(.12,.26) if ident=='F160' else ((.5,.07) if ident=='R200' else (.47,.12))
  box('BrakeLamp',(side*(half-.17),.20,end-.005),(tw,th,.04),'red',.012)
  marker('TailLeft' if side<0 else 'TailRight',(side*(half-.17+tw/2),.20,end+.02))
 for z,tag in [(end+.065,'PlateRear'),(-end-.065,'PlateFront')]:marker(tag,(0,.015,z))
 marker('CameraCockpit',(0,.74,-.8));marker('CameraHood',(0,.72,-1.4))
 for i,(sx,sz) in enumerate([(-1,-1),(1,-1),(-1,1),(1,1)]):marker('WheelMount'+str(i),(sx*(half-.08),-.34,sz*wb/2))
 if ident=='R200':
  box('HoodStripe',(-.22,.34,(-end+bf)/2),(.24,.012,bf+end-.1),'ivory',0)
  box('RoofStripe',(-.22,roof+.041,(front+rear)/2),(.24,.008,rear-front),'ivory',0)
  box('Ducktail',(0,.39,end-.17),(w-.12,.15,.21),color,.035)
 elif ident=='A240':
  box('Intake',(0,.39,-1.13),(.46,.13,.4),color,.025);box('IntakeMouth',(0,.39,-1.34),(.33,.07,.012),'ink',.003)
  for x in [-.58,.58]:box('WingSupport',(x,.52,end-.26),(.06,.46,.10),'ink',.008)
  wing=box('Wing',(0,.77,end-.25),(w+.12,.07,.34),color,.025);wing['outline']=True
  for side in [-1,1]:box('WingEnd',(side*(half+.07),.77,end-.25),(.04,.23,.37),'yellow',.014)
 else:box('Spoiler',(0,roof+.02,rear+.09),(w-.16,.07,.23),'teal',.018)
 beam('Aerial',(.5,roof,rear-.1),(.5,roof+.3,rear),.008,'ink')
 save(path,'vehicle')

def prop(kind):
 path=OUT/'props'/f'{kind}.blend'
 if path.exists():return
 reset()
 if kind=='wheel_tire':
  bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,major_radius=.255,minor_radius=.075);o=bpy.context.object;o.name='ATCasing';o.scale.z=1.48;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat('rubber'))
  for row in range(24):
   for lane in range(4):
    a=(row+(.45 if lane%2 else 0))*math.tau/24
    o=box('ATTread',(math.cos(a)*.332,(lane-1.5)*.049,math.sin(a)*.332),(.055,.038,.018),'rubber',0)
    o.rotation_euler.z=-a+math.pi/2
  for side in [-1,1]:
   for row in range(12):
    a=row*math.tau/12;o=box('ShoulderLug',(math.cos(a)*.29,side*.108,math.sin(a)*.29),(.045,.013,.024),'ink',0);o.rotation_euler.z=-a+math.pi/2
 elif kind=='wheel_rim':
  bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=4,major_radius=.187,minor_radius=.018);o=bpy.context.object;o.name='RimLip';o.data.materials.append(mat('ivory'))
  cylinder('Hub',(0,0,0),.05,.035,'ivory',8)
  for i in range(5):
   a=i*math.tau/5
   ob=box('Spoke',(math.sin(a)*.11,0,math.cos(a)*.11),(.045,.025,.15),'ivory',.004);ob.modifiers.clear();ob.rotation_euler.z=a
   cylinder('Bolt',(math.sin(a)*.032,.024,math.cos(a)*.032),.006,.006,'metal',4)
  cylinder('BrakeDisc',(0,-.025,0),.16,.008,'ink',16)
  for o in bpy.context.scene.objects:o.modifiers.clear()
 elif kind=='cabin':
  box('TimberBody',(0,2.5,0),(8,5,6),'red',.08)
  for x in range(-4,5):box('BoardJoint',(x,2.5,3.015),(.035,5,.035),'ink',0)
  for side in [-1,1]:
   o=box('Roof',(side*2,6,0),(5.1,.22,7),'ink',.03);o.rotation_euler.y=-side*.65
   box('Window',(side*2.4,2.8,3.04),(1.4,1.5,.08),'glass',.03)
   for xx in [-.75,0,.75]:box('WindowFrame',(side*2.4+xx,2.8,3.10),(.06,1.62,.07),'ivory',.008)
   for yy in [2.0,2.8,3.6]:box('WindowFrame',(side*2.4,yy,3.10),(1.55,.06,.07),'ivory',.008)
  box('Door',(0,1.4,3.04),(1.6,2.8,.12),'yellow',.03);box('DoorBrace',(0,1.4,3.12),(1.4,.08,.03),'ivory');box('Chimney',(2,6.8,-1),(1,2,1),'ivory',.06)
 elif kind=='lighthouse':
  bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=3,radius2=2.1,depth=20,location=xyz((0,10,0)));o=bpy.context.object;o.name='Tower';o.data.materials.append(mat('ivory'))
  for y in [7.5,8.5]:cylinder('PaintBand',(0,y,0),2.72,.5,'red',32)
  cylinder('Gallery',(0,20,0),3.3,.4,'teal',32);cylinder('Lantern',(0,21.5,0),2,3,'glass',16)
  for i in range(12):
   a=i*math.tau/12;beam('LanternBar',(math.cos(a)*2,20,math.sin(a)*2),(math.cos(a)*2,23,math.sin(a)*2),.09,'ink')
   beam('Rail',(math.cos(a)*3,20,math.sin(a)*3),(math.cos(a)*3,21,math.sin(a)*3),.06,'ivory')
  bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=3,radius2=0,depth=2,location=xyz((0,24,0)));bpy.context.object.data.materials.append(mat('red'))
  box('Door',(0,1.25,2.94),(1.3,2.5,.16),'teal',.06)
 elif kind=='bridge_post':
  box('Post',(0,.63,0),(.15,1.12,.15),'ivory',.02)
  box('Cap',(0,1.21,0),(.20,.08,.20),'yellow',.02)
  for y in [.65,1.12]:box('Bracket',(0,y,0),(.22,.13,.20),'metal',.015)
 elif kind=='medical':
  box('Van',(0,1.1,0),(2.2,1.6,4.6),'ivory',.18);box('Roof',(0,2,0),(1.96,.22,3.8),'ivory',.12)
  box('Stripe',(0,1.2,0),(2.22,.24,4.62),'red',.015);box('Windshield',(0,1.65,-2.32),(1.85,.6,.03),'glass',.08)
  for side in [-1,1]:
   box('SideGlass',(side*1.11,1.67,-1.25),(.025,.58,1.1),'glass',.03)
   for z in [-1.45,1.45]:ellipsoid('Wheel',(side*1.08,.38,z),(.22,.43,.43),'ink')
   for p,s in [((side*1.12,1.65,.65),(.025,.55,.16)),((side*1.13,1.65,.65),(.025,.16,.55))]:box('MedicalMark',p,s,'teal',.01)
   box('Beacon',(side*.65,2.22,-1),(.35,.15,.32),'teal',.04)
 elif kind=='sailboat':
  ellipsoid('Hull',(0,0,0),(3.2,.8,8),'ivory');box('Deck',(0,.5,0),(4,.1,10),'yellow',.04)
  beam('Mast',(0,.3,0),(0,18,0),.11,'ink')
  mesh('MainSail',[(.1,17.6,0),(.6,8,-2.9),(.1,1,-7),(.1,1,0)],[(0,1,3),(1,2,3)],'ivory')
  mesh('ForeSail',[(-.1,14,0),(-.6,7,3),(-.1,1,7),(-.1,1,0)],[(0,3,1),(1,3,2)],'red')
  beam('Rigging',(0,18,0),(0,0,7),.025,'ivory');beam('Rigging',(0,18,0),(0,0,-7),.025,'ivory')
 elif kind=='helicopter':
  ellipsoid('Cabin',(0,0,0),(1.7,1.4,3),'ivory');ellipsoid('Canopy',(0,.25,-1.8),(1.5,1,1.6),'glass')
  box('Stripe',(0,-.32,.2),(3,.48,2.5),'red',.12);beam('Tail',(0,.25,1.8),(0,1.2,8.1),.35,'ivory')
  box('Fin',(0,1.6,8),(.18,2.8,1.8),'red',.12);box('Stabilizer',(0,1.1,7),(3.8,.15,.8),'ivory',.1)
  beam('Mast',(0,.8,0),(0,2.2,0),.12,'metal')
  for side in [-1,1]:
   beam('Skid',(side*1.9,-1.9,-2.8),(side*1.9,-1.9,2.7),.1,'metal')
   for z in [-1.4,1.4]:beam('SkidStrut',(side*.9,-.8,z),(side*1.9,-1.9,z),.07,'metal')
  box('OpenDoor',(-1.65,.05,.65),(.12,1.65,2),'ink',.1)
  box('Footstep',(-1.98,-.85,.65),(.9,.15,1.7),'metal',.05)
  ellipsoid('ReporterVest',(-2.02,.12,.65),(.32,.5,.3),'yellow');ellipsoid('ReporterHead',(-2.05,1.02,.65),(.24,.29,.24),'d49b76');ellipsoid('Helmet',(-2.05,1.23,.65),(.27,.13,.25),'ink')
  for z in [.40,.88]:
   beam('Leg',(-2,-.22,z),(-2.38,-.65,z+.1),.14,'plum');beam('Boot',(-2.38,-.65,z+.1),(-2.3,-1.25,z+.2),.13,'ink')
   beam('Arm',(-2.05,.5,z),(-2.52,.25,z),.10,'d49b76');beam('Arm',(-2.52,.25,z),(-2.75,.68,z+.45),.09,'d49b76')
  box('ShoulderCamera',(-2.68,.78,1.25),(1.05,.45,.48),'ink',.06);box('LensHood',(-3.28,.78,1.25),(.28,.6,.62),'ink',.03);ellipsoid('Lens',(-3.44,.78,1.25),(.03,.22,.22),'teal');box('Tally',(-3.44,1.04,1.25),(.08,.08,.08),'red',.01)
 elif kind=='arch':
  points=[];half=6.0
  for i in range(9):points.append((-half,i*.55))
  for i in range(1,9):
   a=math.pi-i*math.pi*.5/8;points.append((-half+1.3+math.cos(a)*1.3,4.4+math.sin(a)*1.3))
  for i in range(1,13):points.append((-half+1.3+(half*2-2.6)*i/12,5.7))
  for i in range(1,9):
   a=math.pi*.5-i*math.pi*.5/8;points.append((half-1.3+math.cos(a)*1.3,4.4+math.sin(a)*1.3))
  for i in range(1,9):points.append((half,4.4-i*.55))
  verts=[];uv=[];run=0
  for i,(x,y) in enumerate(points):
   if i:run+=math.dist(points[i-1],points[i])
   a=Vector(points[max(i-1,0)]);b=Vector(points[min(i+1,len(points)-1)]);t=(b-a).normalized()
   for j in range(25):
    angle=j*math.tau/24;verts.append((x-t.y*math.cos(angle)*.55,y+t.x*math.cos(angle)*.55,math.sin(angle)*.55));uv.append((run/.65,j/24))
  faces=[]
  for i in range(len(points)-1):
   for j in range(24):faces.append((i*25+j,(i+1)*25+j,(i+1)*25+j+1,i*25+j+1))
  o=mesh('ClothArch',verts,faces,'ivory');layer=o.data.uv_layers.new(name='UVMap')
  for poly in o.data.polygons:
   poly.use_smooth=True
   for li in poly.loop_indices:layer.data[li].uv=uv[o.data.loops[li].vertex_index]
 elif kind=='arch_foot':
  box('Anchor',(0,.06,0),(1.5,.12,1.5),'ink',.09)
  cylinder('InflationCollar',(0,.22,0),.58,.35,'ivory',24)
  for side in [-1,1]:beam('TieDown',(0,.4,0),(side*.8,.03,.6),.025,'yellow')
 save(path,'prop')
for args in [('F160',1.65,3.65,2.35,1.04,-.48,1.40,'16','teal'),('R200',1.76,4.15,2.50,.76,-.10,.85,'27','red'),('A240',1.88,4.2,2.6,.91,-.57,.92,'44','plum')]:vehicle(*args)
for name in ['cabin','lighthouse','bridge_post','medical','sailboat','helicopter','arch_foot','arch','wheel_tire','wheel_rim']:prop(name)
