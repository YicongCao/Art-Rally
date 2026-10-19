"""Blender authoring pass for the user-requested GTI / E30 M3 / quattro S1.
Run explicitly with -- --replace-reference-cars. Export remains a separate step.
Game dimensions and functional anchors retain the existing mechanical envelope.
"""
import bpy,math,sys,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
if '--replace-reference-cars' not in sys.argv: raise RuntimeError('Explicit --replace-reference-cars required')
# Reuse geometry primitives, never execute the legacy bootstrap entry point.
exec((ROOT/'scripts/create_screenprint_sources.py').read_text().split('for args in ')[0])
COLORS.update(white='f6f2e7',navy='152447',scarlet='dd2537',sun='ffca18',cyan='19a9e3',blue='254596',black='161b21',glass='233a48',chrome='b9c7cb',orange='fa8525',red='d52f32')

def outline(o): o['outline']=True;return o

def label(name,value,p,size,color,u=(1,0,0),v=(0,1,0)):
 bpy.ops.object.text_add();o=bpy.context.object;o.name=name;o.data.body=value;o.data.align_x='CENTER';o.data.align_y='CENTER';o.data.size=size;o.data.resolution_u=3;o.data.space_character=1.0
 o.data.materials.append(mat(color));bpy.ops.object.convert(target='MESH')
 pp,uu,vv=Vector(p),Vector(u),Vector(v)
 for vert in o.data.vertices:
  q=vert.co.copy();vert.co=xyz(pp+uu*q.x+vv*q.y)
 return o

def ring(name,p,r,t,color,u=(1,0,0),v=(0,1,0),count=32):
 verts=[]
 for i in range(count):
  a=i*math.tau/count
  for radius in [r-t/2,r+t/2]: verts.append(Vector(p)+Vector(u)*math.cos(a)*radius+Vector(v)*math.sin(a)*radius)
 return mesh(name,verts,[(i*2,i*2+1,((i+1)%count)*2+1,((i+1)%count)*2) for i in range(count)],color)

def disk(name,p,r,color,u=(1,0,0),v=(0,1,0)):
 verts=[Vector(p)]+[Vector(p)+Vector(u)*math.cos(i*math.tau/32)*r+Vector(v)*math.sin(i*math.tau/32)*r for i in range(32)]
 return mesh(name,verts,[(0,i+1,(i+1)%32+1) for i in range(32)],color)

def decal_poly(name,pts,p,scale,color,u,v):
 verts=[Vector(p)+Vector(u)*x*scale+Vector(v)*y*scale for x,y in pts]
 # Concave graphic decals need triangulation, not a triangle fan.
 from mathutils.geometry import tessellate_polygon
 triangles=tessellate_polygon([[Vector((x,y,0)) for x,y in pts]])
 lookup={(x,y):i for i,(x,y) in enumerate(pts)}
 faces=[tuple(a if isinstance(a,int) else lookup[min(lookup,key=lambda q:(q[0]-a.x)**2+(q[1]-a.y)**2)] for a in tri) for tri in triangles]
 return mesh(name,verts,faces,color)

def bull_mark(p,size,u,v):
 disk('RedBullSun',Vector(p)-Vector(v)*.015,size*.30,'sun',u,v)
 # Authored charging-bull silhouette, inspired by the supplied livery reference.
 bull=[(-.72,.02),(-.54,.13),(-.38,.12),(-.24,.21),(-.12,.15),(-.02,.25),(.03,.19),(-.04,.09),(.10,.04),(.08,-.04),(-.03,-.04),(-.12,-.16),(-.24,-.18),(-.21,-.10),(-.30,-.04),(-.47,-.07),(-.56,-.23),(-.64,-.22),(-.60,-.07),(-.71,-.10),(-.80,-.02),(-.91,.20),(-.88,.24),(-.79,.07)]
 for side in [-1,1]:
  pts=[(side*x,y) for x,y in bull]
  decal_poly('ChargingBullEdge',pts,Vector(p)+Vector(u)*(-side*.06*size),size*1.025,'white',u,v)
  normal=Vector(u).cross(Vector(v))
  decal_poly('ChargingBull',pts,Vector(p)+Vector(u)*(-side*.06*size)+normal*.0015,size,'scarlet',u,v)

def headlamp(x,y,z,r):
 # Front faces look along -Z. Radial lens rings remain readable with toon shading.
 disk('LampHousing',(x,y,z),r*1.16,'black',(-1,0,0))
 disk('LampReflector',(x,y,z-.005),r,'chrome',(-1,0,0))
 disk('LampGlass',(x,y,z-.009),r*.83,'white',(-1,0,0))
 ring('LensRim',(x,y,z-.012),r*.94,.012,'chrome',(-1,0,0))
 for offset in [-.45,0,.45]:beam('LensFlute',(x+offset*r,y-r*.64,z-.013),(x+offset*r,y+r*.64,z-.013),.003,'chrome')

def make(ident,w,L,wb,track,roof,front,rear,title):
 reset();h=w/2;e=L/2;rw=h-.14
 body='navy' if ident=='F160' else 'white'
 bpy.context.scene['reference_vehicle']=title
 # Longitudinal shoulder loft, chamfered corners and a sloping bonnet.
 sections=[(-e+.025,h*.87,.23),(-e+.17,h*.97,.29),(-wb/2,h,.35),(front-.38,h,.39),(rear+.23,h,.38),(e-.12,h*.97,.34),(e-.025,h*.87,.28)]
 verts=[]
 for z,x,y in sections:verts += [(-x,y-.14,z),(-x+.055,y,z),(x-.055,y,z),(x,y-.14,z)]
 faces=[]
 for i in range(len(sections)-1):
  for j in range(3):faces.append((i*4+j,i*4+j+1,(i+1)*4+j+1,(i+1)*4+j))
 outline(bevel(mesh('SculptedShoulder',verts,faces,body),.018,2))
 box('Floor',(0,-.17,0),(w-.20,.09,L-.27),'black')
 # Quarter panels follow actual wheel openings, not rectangular wheel overlays.
 for side in [-1,1]:
  contour=[(-e+.08,-.19)]
  for axle in [-wb/2,wb/2]:
   contour.append((axle-.43,-.19))
   for j in range(25):
    a=math.pi-j*math.pi/24;contour.append((axle+.435*math.cos(a),-.34+.465*math.sin(a)))
  contour.append((e-.08,-.19))
  for a,b in zip(contour,contour[1:]):
   quad('SidePanel',[(side*(h-.025),a[1],a[0]),(side*(h-.025),b[1],b[0]),(side*(h-.025),.30,b[0]),(side*(h-.025),.30,a[0])],body)
  for axle in [-wb/2,wb/2]:
   vv=[]
   for j in range(25):
    a=j*math.pi/24
    for radius,xx in [(.437,h-.014),(.487,h+.035),(.515,h-.005)]:vv.append((side*xx,-.34+radius*math.sin(a),axle+radius*math.cos(a)))
   outline(mesh('WideArch',vv,[(j*3+k,j*3+k+1,(j+1)*3+k+1,(j+1)*3+k) for j in range(24) for k in range(2)],body if ident!='A240' else 'sun'))
  box('Sill',(side*(h-.02),-.16,0),(.08,.12,wb-.83),'sun' if ident=='A240' else body,.025)
  box('DoorHandle',(side*(h-.008),.24,.36),(.035,.04,.15),'black',.008)
  beam('DoorShutline',(side*(h-.012),-.08,.55),(side*(h-.012),.30,.55),.007,'black')
  box('Mudflap',(side*(track/2),-.42,wb/2+.40),(.25,.29,.025),'black',.003)
 # Cabin includes a roof, four carefully fitted windows and proper C pillars.
 bf=front-.44;br=(e-.16 if ident=='A240' else rear+(.40 if ident=='R200' else .24))
 if ident=='F160':
  # Crowned, rounded roof distinguishes the modern GTI from the two boxier classics.
  vv=[]
  for z in [front-.04,(front+rear)/2,rear+.04]:
   for x in [-rw-.025,-rw+.05,0,rw-.05,rw+.025]:
    yy=roof+.055*(1-(x/(rw+.025))**2)
    vv.append((x,yy,z))
  outline(bevel(mesh('GTICrownedRoof',vv,[(j*5+i,j*5+i+1,(j+1)*5+i+1,(j+1)*5+i) for j in range(2) for i in range(4)],body),.018,3))
 else:outline(box('Roof',(0,roof,(front+rear)/2),(rw*2+.07,.07,rear-front+.12),body,.035))
 # Dark rubber seals give glazing controlled structure lines.
 quad('Windscreen',[(-h+.07,.39,bf),(h-.07,.39,bf),(rw,roof-.035,front),(-rw,roof-.035,front)],'glass')
 quad('RearGlass',[(-rw,roof-.035,rear),(rw,roof-.035,rear),(h-.085,.38,br),(-h+.085,.38,br)],'glass')
 for side in [-1,1]:
  quad('SideWindows',[(side*(h-.055),.40,bf+.055),(side*rw,roof-.04,front+.07),(side*rw,roof-.04,rear-.08),(side*(h-.07),.39,br-.07)],'glass')
  for a,b,width in [((side*(h-.04),.36,bf),(side*rw,roof,front),.075),((side*(h-.055),.36,br),(side*rw,roof,rear),.11),((side*(h-.045),.37,.28),(side*rw,roof-.015,.28),.055)]:beam('WindowPillar',a,b,width,body)
  beam('WindowSill',(side*(h-.04),.385,bf),(side*(h-.06),.385,br),.035,'black')
  beam('RoofSideRail',(side*rw,roof-.015,front),(side*rw,roof-.015,rear),.075,body)
  box('Mirror',(side*(h+.04),.49,bf+.16),(.16,.12,.23),'scarlet' if ident=='R200' else 'white',.045)
  box('MirrorFace',(side*(h+.04),.49,bf+.285),(.12,.08,.012),'glass',.003)
  box('RacingSeat',(side*.29,.46,.28),(.34,.48,.25),'black',.07)
  beam('RollCage',(side*(rw-.09),.22,.71),(side*(rw-.09),roof-.10,.71),.028,'white')
 beam('CageBrace',(-rw+.1,roof-.12,.73),(rw-.1,.25,.73),.027,'white')
 beam('CageBrace',(rw-.1,roof-.12,.75),(-rw+.1,.25,.75),.027,'white')
 box('Dashboard',(0,.36,bf+.16),(w-.3,.14,.25),'black')
 for x in [-.30,.30]: beam('Wiper',(x,.40,bf-.015),(x+.18,.66,bf+.17),.014,'black')
 beam('Aerial',(.3,roof,rear-.15),(.31,roof+.24,rear-.10),.008,'black')
 # Front and rear fascia close the body; vents are recessed dark inserts.
 outline(box('FrontFascia',(0,.06,-e+.025),(w-.10,.36,.13),body,.035))
 outline(box('RearFascia',(0,.055,e-.025),(w-.10,.40,.13),body,.025))
 box('RearBumper',(0,-.16,e+.01),(w,.13,.14),'black',.022)
 box('Exhaust',(.48,-.24,e+.04),(.11,.075,.18),'chrome',.012)
 if ident=='F160':
  box('FrontIntake',(0,-.03,-e-.047),(w-.40,.22,.025),'black',.025)
  box('FrontSplitter',(0,-.23,-e-.025),(w+.04,.035,.24),'black',.01)
  box('GTIGrille',(0,.22,-e-.052),(w-.48,.125,.018),'black',.012)
  box('GTIRedPinstripe',(0,.268,-e-.063),(w-.40,.015,.014),'scarlet',.002)
  for side in [-1,1]:
   box('HeadlightBezel',(side*.57,.23,-e-.057),(.34,.16,.03),'black',.034)
   box('HeadlightLens',(side*.57,.23,-e-.077),(.29,.105,.015),'chrome',.025)
   box('LED',(side*.57,.19,-e-.09),(.25,.015,.008),'white',.003)
   quad('SideSpeedWhite',[(side*(h-.017),-.12,-.65),(side*(h-.017),.29,-.44),(side*(h-.017),.29,.87),(side*(h-.017),-.12,.42)],'white')
   quad('SideSpeedRed',[(side*(h-.014),-.11,-.37),(side*(h-.014),.29,-.20),(side*(h-.014),.29,.01),(side*(h-.014),-.11,-.14)],'scarlet')
   u=(0,0,-side);p=(side*(h-.008),.12,.13)
   bull_mark(p,.37,u,(0,1,0));label('RedBullWordmark','Red Bull',(side*h,-.055,.08),.16,'scarlet',u)
   box('YellowFender',(side*(h+.015),.26,-wb/2),(.025,.15,.49),'sun',.015)
   # Long white/red wedges wrap around the nose like the reference livery.
   quad('WhiteHoodSweep',[(side*.53,.35,-1.17),(side*.68,.27,-e+.11),(side*.43,.29,-e+.11),(side*.42,.36,-1.17)],'white')
   quad('RedHoodSweep',[(side*.53,.354,-1.17),(side*.62,.274,-e+.11),(side*.55,.294,-e+.11),(side*.48,.364,-1.17)],'scarlet')
   box('GTISideAirIntake',(side*.62,-.06,-e-.052),(.20,.22,.025),'black',.032)
   box('GTIIntakeVertical',(side*.71,-.07,-e-.073),(.018,.16,.016),'chrome',.003)
   for j in range(3):box('GrilleHoneycomb',(side*.25,.18+j*.035,-e-.065),(.35,.008,.008),'chrome',.001)
   box('HoodVent',(side*.35,.36,-1.17),(.23,.018,.26),'black',.01)
   for n in range(4):box('VentRib',(side*.35,.372,-1.27+n*.062),(.22,.008,.010),'chrome',0)
   box('WingSupport',(side*.58,roof+.025,rear+.15),(.04,.16,.16),'black')
  outline(box('RoofWing',(0,roof+.12,rear+.16),(w+.01,.045,.23),'navy',.016))
  box('RoofScoop',(0,roof+.08,-.02),(.38,.10,.29),'navy',.03)
  box('ScoopOpening',(0,roof+.08,-.17),(.28,.045,.012),'black',.006)
  bull_mark((0,.366,-1.30),.56,(-1,0,0),(0,0,1))
  label('HoodRedBull','Red Bull',(0,.359,-1.57),.25,'scarlet',(-1,0,0),(0,0,1))
  ring('VWBadge',(0,.22,-e-.075),.062,.009,'chrome',(-1,0,0))
  label('VW','VW',(0,.22,-e-.08),.065,'white',(-1,0,0))
  label('GTI','GTI',(-.20,.21,-e-.073),.055,'scarlet',(-1,0,0))
  label('Volkswagen','Volkswagen',(0,roof-.105,front-.085),.13,'white',(-1,0,0),(0,.815,.58))
 elif ident=='R200':
  box('Bumper',(0,-.10,-e-.01),(w,.15,.17),'white',.015)
  box('BlackRubberBumper',(0,-.055,-e-.106),(w-.06,.025,.012),'black',.002)
  box('Grille',(0,.21,-e-.052),(w-.17,.22,.018),'black',.01)
  for x in [-.67,-.46,.46,.67]:headlamp(x,.23,-e-.07,.088)
  for side in [-1,1]:
   box('KidneyChrome',(side*.065,.21,-e-.071),(.106,.21,.02),'chrome',.022)
   box('KidneyBlack',(side*.065,.21,-e-.085),(.081,.18,.014),'black',.013)
   for j in range(3):box('KidneySlat',(side*.065+(j-1)*.021,.21,-e-.094),(.007,.16,.008),'chrome',.001)
   box('FogLamp',(side*.60,-.11,-e-.103),(.22,.07,.02),'white',.005)
   box('Indicator',(side*.68,.04,-e-.098),(.17,.055,.022),'orange',.004)
   box('BrakeDuct',(side*.30,-.18,-e-.095),(.16,.07,.022),'black',.008)
   for axle in [-wb/2,wb/2]:
    outline(box('E30BoxFlareTop',(side*(h+.015),.245,axle),(.085,.11,.89),'white',.025))
   beam('E30SideRubberStrip',(side*(h+.014),.005,-.66),(side*(h+.014),.005,.68),.017,'black')
   # Triple stripes climb the fender and continue over the roof, clear of numbers.
   for j,col in enumerate(['cyan','blue','scarlet']):
    z=-.60+j*.14
    quad('MTricolorSide',[(side*(h-.014),-.14,z-.14),(side*(h-.014),.31,z+.12),(side*(h-.014),.31,z+.255),(side*(h-.014),-.14,z-.005)],col)
    box('RoofMStripe',(-.35+j*.14,roof+.037,(front+rear)/2),(.14,.008,rear-front+.01),col,0)
   label('Mobil1Side','Mobil 1',(side*(h-.003),.13,.10),.205,'blue',(0,0,-side))
   label('BMWMotorsportSide','BMW Motorsport',(side*h,-.08,.14),.064,'black',(0,0,-side))
   box('RearWingPylon',(side*.54,.48,e-.20),(.06,.30,.11),'white',.01)
  outline(box('E30RearWing',(0,.64,e-.21),(w-.12,.065,.28),'white',.014))
  label('HoodMobil1','Mobil 1',(0,.363,-1.20),.32,'blue',(-1,0,0),(0,0,1))
  label('HoodMotorsport','BMW MOTORSPORT',(0,.322,-1.74),.095,'black',(-1,0,0),(0,0,1))
  disk('BMWRoundel',(0,.292,-e+.10),.045,'blue',(-1,0,0),(0,0,1));ring('BMWRoundelRing',(0,.294,-e+.10),.047,.009,'chrome',(-1,0,0),(0,0,1))
  box('BootLid',(0,.39,(br+e)/2),(w-.18,.04,max(.1,e-br)),'white',.02)
 else:
  outline(box('S1FrontApron',(0,-.13,-e-.02),(w+.03,.23,.28),'sun',.028))
  box('Splitter',(0,-.255,-e-.08),(w+.08,.03,.38),'black',.006)
  box('RadiatorGrille',(0,.20,-e-.057),(w-.18,.21,.025),'black',.008)
  for side in [-1,1]:
   box('RectHeadlamp',(side*.69,.21,-e-.078),(.27,.13,.025),'white',.01)
   box('FrontIndicator',(side*.73,-.02,-e-.174),(.23,.08,.015),'orange',.008)
   # Box arches, deep rear-quarter cooling intakes and yellow shoulder band.
   box('YellowShoulder',(side*(h-.006),.26,0),(.025,.14,L-.25),'sun',.005)
   for axle in [-wb/2,wb/2]:
    outline(box('S1BoxFlareTop',(side*(h+.015),.25,axle),(.11,.12,1.02),'sun',.015))
   # A clear racing number on the tall wing side remains readable from behind.
   label('S1WingSide','quattro',(side*(h-.018),.90,e-.20),.105,'black',(0,0,-side))
   box('RearIntake',(side*(h+.019),.035,wb/2-.19),(.035,.36,.28),'black',.008)
   for j in range(7):box('IntakeLouvre',(side*(h+.04),-.105+j*.045,wb/2-.19),(.015,.010,.26),'chrome',0)
   for j in range(6):box('BonnetLouvre',(side*.36,.36,-1.2+j*.075),(.22,.012,.025),'black',.002)
   label('AudiSportSide','Audi Sport',(side*(h+.015),.26,-.25),.12,'black',(0,0,-side))
   label('QuattroSide','quattro',(side*(h+.018),-.035,.32),.15,'black',(0,0,-side))
   label('BoschSide','BOSCH',(side*(h+.02),-.13,-.08),.085,'black',(0,0,-side))
   # Tall wing endplates and vertical fins define S1 even in the chase camera.
   outline(box('WingEndplate',(side*(h-.06),.82,e-.20),(.07,.72,.63),'white',.018))
  outline(box('S1WingUpper',(0,1.15,e-.20),(w+.02,.07,.61),'white',.016))
  box('S1WingLower',(0,.69,e-.12),(w-.12,.045,.42),'sun',.012)
  label('WingQuattro','quattro',(0,1.19,e-.20),.20,'black',(-1,0,0),(0,0,1))
  for x,y in [(-.46,.31),(.46,.31),(-.32,-.06),(0,-.06),(.32,-.06)]:
   beam('RallyLightSupport',(x,y,-e-.04),(x,y,-e-.23),.04,'black');headlamp(x,y,-e-.245,.112)
  for j in range(4):ring('AudiRing',((j-1.5)*.053,.22,-e-.087),.034,.007,'chrome',(-1,0,0))
  label('AudiSportHood','Audi Sport',(0,.362,-1.45),.24,'black',(-1,0,0),(0,0,1))
  for j,col in enumerate(['black','scarlet','sun']):box('AudiHoodStripe',(-.47+j*.13,.368,-.98),(.12,.012,.55),col,0)
  label('Michelin','MICHELIN',(0,-.16,-e-.17),.15,'black',(-1,0,0))
 # Rear identity, lamp lenses and functionality use explicit mounts.
 for side in [-1,1]:
  tw,th=(.29,.15) if ident=='F160' else (.40,.13)
  x=side*(h-.24)
  box('TailHousing',(x,.205,e+.046),(tw+.035,th+.03,.038),'black',.012)
  box('BrakeLamp',(x,.22,e+.07),(tw,th*.68,.025),'red',.008)
  box('RearIndicator',(x,.16,e+.071),(tw*.46,.037,.027),'orange',.004)
  marker('TailLeft' if side<0 else 'TailRight',(x+side*tw/2,.22,e+.087))
  # Existing race identity is retained in a small contrasting rear-quarter plate.
  u=(0,0,-side)
  number_z=.60 if ident=='A240' else .72
  box('NumberBoard',(side*(h+.02),.19,number_z),(.015,.23,.22 if ident=='A240' else .28),'white',.003)
  label('RaceNumber',{'F160':'16','R200':'27','A240':'44'}[ident],(side*(h+.03),.19,number_z),.19,'black',u)
 for z,tag in [(e+.095,'PlateRear'),(-e-.19 if ident=='A240' else -e-.12,'PlateFront')]:marker(tag,(0,-.18 if ident=='A240' and tag=='PlateFront' else .015,z))
 label('RearModel',{'F160':'GTI','R200':'M3','A240':'quattro'}[ident],(0,.28,e+.077),.085,'chrome')
 cams={'F160':((0,.80,-.64),(0,.75,-1.25)),'R200':((0,.65,-.40),(0,.66,-1.40)),'A240':((0,.74,-.80),(0,.72,-1.40))}
 marker('CameraCockpit',cams[ident][0]);marker('CameraHood',cams[ident][1])
 for i,(sx,sz) in enumerate([(-1,-1),(1,-1),(-1,1),(1,1)]):marker('WheelMount'+str(i),(sx*track/2,-.34,sz*wb/2))
 # Consistent outward normals for authored surfaces (text is deliberately planar).
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  bpy.context.view_layer.objects.active=o;o.select_set(True)
  if len(o.data.polygons)>1:
   import bmesh
   bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
  o.select_set(False)
 bpy.context.scene['reference_revision']=1
 bpy.context.scene['mount_revision']=1
 save(OUT/'vehicles'/f'{ident}.blend','vehicle')
 print('REFERENCE CAR AUTHORED',ident,title)

for args in [('F160',1.65,3.65,2.35,1.5,1.01,-.53,1.14,'Volkswagen GTI Red Bull'),('R200',1.76,4.15,2.5,1.58,.88,-.37,.80,'BMW M3 E30 Mobil 1'),('A240',1.88,4.2,2.6,1.72,.94,-.48,1.10,'Audi quattro S1')]:make(*args)
