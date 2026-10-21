"""Author expansion-only editable vehicle sources. Existing sources are preserved.
Run Blender --background --python scripts/create_expansion_vehicles.py.
Coordinates are metres in Godot space; decals are independent mesh objects.
Dimensions and approximate production baselines: docs/expansion/VEHICLES.md.
"""
import bpy, math, sys, bmesh
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
# Share primitive construction only; never execute the legacy asset generator.
exec((ROOT/'scripts/create_screenprint_sources.py').read_text().split('def vehicle(')[0])
# Node names may be translated in a user's Blender installation.
def mat(name,color=None):
 m=bpy.data.materials.get(name)
 if m:return m
 h=COLORS.get(color or name,color or name)
 rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=.7
 return m
CARS={
'I20':(1.82,4.04,2.56,1.60,.83,-.35,1.15,'779eb0','ec493c','20'),
'DELTA':(1.77,3.90,2.48,1.50,.91,-.55,1.16,'18396c','e6dac1','4'),
'EVO6':(1.77,4.35,2.51,1.51,.91,-.50,.79,'b82e30','eee7d7','6'),
'WRX':(1.795,4.595,2.65,1.535,.93,-.43,.80,'195bbb','e8be36','15'),
'P7':(1.970,5.017,3.008,1.66,.82,-.46,.82,'b5bfc2','238b8c','07')}

def profile_shell(name,sections,color):
 # Station ring: z, half-width, shoulder, hood/deck top. Chamfered shoulders.
 verts=[]
 for z,w,y,top in sections:
  verts.extend([(-w,y-.13,z),(-w,y,z),(-w*.83,top,z),(w*.83,top,z),(w,y,z),(w,y-.13,z)])
 faces=[tuple(range(5,-1,-1))]
 for i in range(len(sections)-1):
  for j in range(6):faces.append((i*6+j,i*6+(j+1)%6,(i+1)*6+(j+1)%6,(i+1)*6+j))
 faces.append(tuple(range((len(sections)-1)*6,len(sections)*6)))
 faces=[tuple(reversed(f)) for f in faces]
 o=mesh(name,verts,faces,color);o['outline']=True;bevel(o,.018,2);return o

def side_label(name,value,x,y,z,size,color,side):
 # Text local +X points toward vehicle front on left side; mirrored orientation on right.
 return text(name,value,(x,y,z),size,color,side)

def author(ident,data):
 path=OUT/'vehicles'/f'{ident}.blend'
 if path.exists() and "--rebuild" not in sys.argv: print('Preserving',path);return
 reset();w,L,wb,track,roof,rf,rr,paint,accent,num=data
 COLORS.update(paint=paint,accent=accent)
 half=w/2;end=L/2;rw=half*(.77 if ident=='P7' else .83)
 p7=ident=='P7';hatch=ident in ['I20','DELTA']
 bf=rf-(.72 if p7 else (.65 if ident=='I20' else .48));br=(end-.23) if hatch else rr+(1.12 if p7 else .50)
 shoulder=.26 if p7 else .30
 profile_shell('SculptedBody',[(-end,half*(.94 if p7 else .96),.17,.21),(-end+.20,half*.96,.25,.32),(-wb/2,half,.28,.35),(bf,half,shoulder,.36),(br,half,shoulder,.34),(end-.22,half*.98,.26,.32),(end,half*.88,.17,.23)],'paint')
 box('Underbody',(0,-.40,0),(w-.64,.09,L-.35),'ink')
 for side in [-1,1]:
  # Tire openings are built as separate panels, not black discs painted on a solid box.
  contour=[(-end+.12,-.40)]
  radius=.48 if p7 else .43
  for axle in [-wb/2,wb/2]:
   contour.append((axle-radius,-.40))
   for j in range(25):
    a=math.pi-j*math.pi/24;contour.append((axle+radius*math.cos(a),-.34+radius*math.sin(a)))
  contour.append((end-.12,-.40))
  for (za,ya),(zb,yb) in zip(contour,contour[1:]):
   quad('LowerBody',[(side*half,ya,za),(side*half,yb,zb),(side*half,.285,zb),(side*half,.285,za)],'paint')
  for axle in [-wb/2,wb/2]:
   verts=[]
   for j in range(25):
    a=j*math.pi/24
    for r,xx in [(radius,half+.008),(radius+.045,half+.045),(radius+.07,half+.009)]:verts.append((side*xx,-.34+r*math.sin(a),axle+r*math.cos(a)))
   faces=[(j*3+k,j*3+k+1,(j+1)*3+k+1,(j+1)*3+k) for j in range(24) for k in range(2)]
   ob=mesh('WideArch',verts,faces,'ink' if p7 else 'paint');ob['outline']=True
   box('MudFlap',(side*(track/2),-.38,axle+.47),(.25,.29,.025),'ink',.003)
  # Distinct asymmetric geometric livery, with discrete editable sponsor type.
  stripe_y=-.015 if p7 else .11
  box('SillGraphic',(side*(half+.012),stripe_y,.05),(.012,.09,wb-radius*2),'accent',.002)
  if ident in ['I20','EVO6']:
   quad('DiagonalLivery',[(side*(half+.016),-.14,-.72),(side*(half+.016),.29,-.40),(side*(half+.016),.29,.75),(side*(half+.016),-.14,.43)],'accent')
  if ident=='WRX':
   for j in range(3):
    quad('CometGraphic',[(side*(half+.018),.03-j*.035,-.7),(side*(half+.018),.10-j*.03,.3),(side*(half+.018),.28-j*.025,1.38),(side*(half+.018),.20-j*.025,.55)],'accent')
  if ident=='DELTA':
   for j,c in enumerate(['ivory','red','yellow']):box('HeritageStripe',(side*(half+.016),.20-j*.045,.0),(.012,.032,L-.25),c,0)
  box('NumberBacking',(side*(half+.022),.025,-.25),(.012,.24,.36),'ivory',.003)
  side_label('RaceNumber',num,side*(half+.033),.035,-.25,.205,'ink',side)
  brand={'I20':'HYUNDAI N','DELTA':'LANCIA','EVO6':'RALLIART','WRX':'SUBARU','P7':'XPENG'}[ident]
  side_label('BrandDecal',brand,side*(half+.026),.06,.65,.095,'ivory' if ident!='P7' else 'ink',side)
  if ident=='I20':
   for j,(label,c) in enumerate([('Shell','yellow'),('MOBIS','ivory'),('Pirelli','yellow')]):
    side_label('Sponsor_'+label,label,side*(half+.027),.21-j*.075,-.80,.061,c,side)
  for z in [-.05,.75]:
   beam('DoorShutLine',(side*(half+.008),-.13,z),(side*(half+.008),.30,z),.006,'ink')
   box('FlushHandle' if p7 else 'Handle',(side*(half+.018),.26,z-.15),(.018,.021,.13),'ink',.004)
  box('Mirror',(side*(half+.055),.46,bf+.15),(.16,.10,.22),'paint',.03)
  quad('SideGlass',[(side*(half-.04),.345,bf+.05),(side*rw,roof-.035,rf+.035),(side*rw,roof-.035,rr-.025),(side*(half-.07),.345,br-.07)],'glass')
  for a,b in [((side*(half-.035),.33,bf),(side*rw,roof,rf)),((side*rw,roof,rr),(side*(half-.055),.33,br))]:beam('Pillar',a,b,.055 if p7 else .07,'paint')
  for z in ([.12] if p7 else [.12,.78]):beam('WindowPillar',(side*(half-.04),.34,z),(side*rw,roof-.035,z),.035,'ink')
  beam('SillWindowTrim',(side*(half-.03),.34,bf),(side*(half-.03),.34,br),.018,'ink')
 quad('Windscreen',[(-half+.07,.35,bf),(half-.07,.35,bf),(rw,roof-.025,rf),(-rw,roof-.025,rf)],'glass')
 quad('RearGlass',[(-rw,roof-.025,rr),(rw,roof-.025,rr),(half-.085,.34,br),(-half+.085,.34,br)],'glass')
 top=box('PanoramicRoof' if p7 else 'Roof',(0,roof,(rf+rr)/2),(rw*2+.045,.055,rr-rf+.05),'glass' if p7 else 'paint',.045);top['outline']=True
 if ident=='I20':
  # Rally2's broad angular nose and multiple livery zones distinguish it from a classic hatch.
  quad('HoodRedChevron',[(-.42,.367,-1.65),(.42,.367,-1.65),(.18,.371,-.98),(-.18,.371,-.98)],'accent')
  hood=text('HoodN','N',(0,.38,-1.3),.18,'ivory');hood.rotation_euler=(0,0,0)
  for side in [-1,1]:
   quad('RearQuarterRed',[(side*(half+.017),-.2,1.53),(side*(half+.017),.28,1.20),(side*(half+.017),.28,1.76),(side*(half+.017),-.2,1.88)],'accent')
   side_label('Sponsor_Michelin','MICHELIN',side*(half+.027),-.29,-.30,.064,'ivory',side)
 # A real cabin is retained behind the glazing and used by cockpit camera.
 box('Dashboard',(0,.34,bf+.14),(w-.27,.16,.25),'ink',.035)
 for side in [-1,1]:
  box('SeatCushion',(side*.32,.08,.23),(.38,.13,.48),'ink',.045)
  box('SeatBack',(side*.32,.40,.46),(.38,.57,.16),'ink',.06)
  box('Headrest',(side*.32,.58 if p7 else .72,.46),(.25,.16 if p7 else .18,.14),'ink',.035)
 beam('SteeringColumn',(-.32,.24,bf+.26),(-.32,.43 if p7 else .49,bf+.46),.045,'ink')
 bpy.ops.mesh.primitive_torus_add(major_radius=.145,minor_radius=.016,major_segments=24,minor_segments=6,location=xyz((-.32,.43 if p7 else .49,bf+.48)))
 ob=bpy.context.object;ob.name='SteeringWheel';ob.rotation_euler.x=math.pi/2;ob.data.materials.append(mat('ink'))
 box('Display',(0,.43 if p7 else .49,bf+.25),(.27,.14 if p7 else .16,.025),'glass',.008)
 if p7:
  # 2025 P7: thin full-width front/rear bars, long fastback, clean low nose.
  box('FrontLightBar',(0,.247,-end-.008),(w*.86,.026,.025),'lamp',.01)
  box('LowerIntake',(0,-.24,-end-.028),(w*.74,.10,.032),'ink',.02)
  box('FrontValance',(0,-.18,-end+.10),(w*.84,.40,.22),'paint',.035)
  box('RearValance',(0,-.18,end-.12),(w*.87,.40,.24),'paint',.035)
  box('SkidPlate',(0,-.455,-end+.20),(w*.73,.035,.55),'metal',.015)
  for side in [-1,1]:
   box('HeadlampPod',(side*half*.80,.12,-end+.012),(.16,.08,.025),'ink',.015)
   box('Headlamp',(side*half*.80,.12,-end-.005),(.13,.027,.03),'lamp',.005)
  box('BrakeLampBar',(0,.247,end+.005),(w*.88,.032,.025),'red',.01)
  text('RearXPENG','X P E N G',(0,.12,end+.016),.09,'ink')
 else:
  box('FrontBumper',(0,-.11,-end+.04),(w*.98,.20,.14),'paint',.045)
  box('MainIntake',(0,-.055,-end-.04),(w*.55,.15,.035),'ink',.02)
  box('Grille',(0,.20,-end-.025),(.57,.13,.027),'ink',.007)
  if ident=='DELTA':
   for side in [-1,1]:
    for dx in [-.105,.105]:
     o=cylinder('RoundHeadlamp',(side*.57+dx,.21,-end-.034),.085,.03,'lamp');o.rotation_euler.x=math.pi/2
    box('BrakeLamp',(side*.69,.12,end+.012),(.21,.31,.035),'red',.012)
   box('RoofSpoiler',(0,roof+.075,rr+.21),(w-.12,.055,.26),'paint')
  else:
   for side in [-1,1]:
    # Angular eye shapes give each generation its own face.
    z=-end-.035
    quad('Headlamp',[(side*.32,.24,z),(side*.78,.29,z+.025),(side*.77,.15,z+.025),(side*.44,.15,z)],'lamp')
    box('BrakeLamp',(side*.64,.23,end+.012),(.38,.12,.035),'red',.025)
   if ident=='WRX':
    box('HoodScoop',(0,.405,-1.2),(.53,.14,.35),'paint',.025)
    box('ScoopOpening',(0,.415,-1.39),(.43,.07,.02),'ink',.007)
   if ident=='EVO6':
    for side in [-1,1]:
     box('BonnetHeatVent',(side*.33,.364,-1.05),(.32,.017,.42),'ink',.018)
     for slit in range(5):box('VentSlat',(side*.33,.377,-1.23+slit*.075),(.30,.014,.018),'paint',.002)
     fog=cylinder('FogLamp',(side*.64,-.065,-end-.047),.10,.035,'lamp',24);fog.rotation_euler.x=math.pi/2
    box('LowerRearWing',(0,.51,end-.28),(w-.13,.05,.25),'paint',.02)
   wing_y=roof+.07 if ident=='I20' else .84
   wing_z=end-.28
   for x in [-.57,.57]:box('WingUpright',(x,(.34+wing_y)/2,wing_z),(.055,wing_y-.34,.15),'ink' if ident=='I20' else 'paint',.008)
   wing=box('RearWing',(0,wing_y,wing_z),(w+.08,.065,.38),'paint',.025);wing['outline']=True
   for side in [-1,1]:box('WingEndplate',(side*(half+.055),wing_y+.02,wing_z),(.035,.19,.4),'accent',.012)
  if ident=='I20':
   for ob in list(bpy.context.scene.objects):
    if ob.name.startswith(('Headlamp','Grille','MainIntake')):bpy.data.objects.remove(ob,do_unlink=True)
   quad('Rally2Grille',[(-.70,.24,-end-.045),(.70,.24,-end-.045),(.49,-.13,-end-.05),(-.49,-.13,-end-.05)],'ink')
   for side in [-1,1]:
    quad('Headlamp',[(side*.54,.27,-end-.055),(side*.87,.32,-end+.025),(side*.84,.20,-end+.025),(side*.65,.18,-end-.055)],'lamp')
    box('BrakeIntake',(side*.77,-.07,-end-.048),(.15,.16,.04),'ink',.012)
   badge=text('FrontHyundai','H',(0,.13,-end-.061),.10,'metal');badge.rotation_euler.z=math.pi
  for side in [-1,1]:box('RearBumperVent',(side*.65,-.10,end+.035),(.22,.11,.025),'ink',.015)
  box('RearBumper',(0,-.14,end+.015),(w*.96,.16,.10),'paint',.03)
 for side in [-1,1]:marker('TailLeft' if side<0 else 'TailRight',(side*(half-.13),.23,end+.04))
 for z,name in [(end+.075,'PlateRear'),(-end-.075,'PlateFront')]:marker(name,(0,-.025,z))
 marker('CameraCockpit',(-.30,.70,bf+.48));marker('CameraHood',(0,.60,-end+.36))
 for i,(sx,sz) in enumerate([(-1,-1),(1,-1),(-1,1),(1,1)]):marker('WheelMount'+str(i),(sx*track*.5,-.34,sz*wb*.5))
 if not p7:beam('RoofAntenna',(0,roof,rr-.15),(0,roof+.28,rr-.05),.008,'ink')
 if p7:
  # New P7 has a continuous curved canopy, not the three-box roof of the old P7.
  for ob in list(bpy.context.scene.objects):
   if ob.name.startswith(('SideGlass','Windscreen','RearGlass','PanoramicRoof','Pillar','WindowPillar','SillWindowTrim')): bpy.data.objects.remove(ob,do_unlink=True)
  canopy=[(-1.30,.35,.91),(-.91,.56,.84),(-.43,.70,.78),(.12,.745,.76),(.65,.71,.775),(1.13,.60,.81),(1.59,.43,.86),(1.93,.32,.90)]
  for i in range(len(canopy)-1):
   za,ha,wa=canopy[i];zb,hb,ww=canopy[i+1]
   quad('CurvedCanopy',[(-wa,ha,za),(wa,ha,za),(ww,hb,zb),(-ww,hb,zb)],'glass')
   for side in [-1,1]:
    quad('SideGlass',[(side*.938,.325,za),(side*wa,ha,za),(side*ww,hb,zb),(side*.938,.325,zb)],'glass')
    beam('CanopyRail',(side*wa,ha+.01,za),(side*ww,hb+.01,zb),.032,'paint')
  for side in [-1,1]:
   beam('WindowPillar',(side*.94,.32,.13),(side*.76,.745,.13),.032,'ink')
   beam('WindowPillar',(side*.94,.32,1.04),(side*.80,.62,1.04),.035,'ink')
   beam('BeltTrim',(side*.95,.324,-1.30),(side*.95,.324,1.94),.022,'paint')
  # Body has a rounded, low nose and tapered tail rather than square bumper corners.
  for ob in bpy.context.scene.objects:
   if ob.type!='MESH' or not ob.name.startswith(('LowerBody','SillGraphic','SculptedBody')):continue
   inv=ob.matrix_world.inverted()
   for vert in ob.data.vertices:
    at=ob.matrix_world@vert.co
    z=-at.y
    taper=1-.13*max(0,(abs(z)-(end-.38))/.38)
    at.x*=taper
    vert.co=inv@at
 bpy.context.scene['reference_model']=ident
 bpy.context.scene['concept']=f'docs/expansion/concepts/{dict(I20="i20",DELTA="delta",EVO6="evo",WRX="wrx",P7="p7")[ident]}.png'
 for ob in bpy.context.scene.objects:
  if ob.type=='MESH' and len(ob.data.polygons)>10:
   bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
 save(path,'vehicle')
selected=next((arg.split("=",1)[1].split(",") for arg in sys.argv if arg.startswith("--only=")),list(CARS))
for ident,data in CARS.items():
 if ident in selected:author(ident,data)
