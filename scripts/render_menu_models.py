"""Blender-authored RGBA menu models, independent from gameplay asset export.

First build: Blender -b --python scripts/render_menu_models.py -- --build
Rerender edited .blend sources: omit --build. --only=F160 limits work.
Existing sources are never rebuilt unless --rebuild is explicitly supplied.
"""
import bpy, math, random, sys, json, hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCES=ROOT/'art_source/menu_models'
OUTPUT=ROOT/'assets/ui/menu_models'
ARGS=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
ONLY=next((a.split('=',1)[1] for a in ARGS if a.startswith('--only=')),None)
SIZE=int(next((a.split('=',1)[1] for a in ARGS if a.startswith('--size=')),1024))
SOURCES.mkdir(parents=True,exist_ok=True);OUTPUT.mkdir(parents=True,exist_ok=True)
rng=random.Random(73421)

def material(name,hexcolor,rough=.72,metal=0):
 m=bpy.data.materials.get('Menu_'+name)
 if m:return m
 rgb=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
 c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
 m=bpy.data.materials.new('Menu_'+name);m.diffuse_color=(*c,1);m.use_nodes=True
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 return m

def mesh(name,verts,faces,mat):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
 obj.data.materials.append(mat);return obj

def box(name,at,size,mat,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.name=name;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 if bevel:
  mod=o.modifiers.new('Soft manufactured edge','BEVEL');mod.width=bevel;mod.segments=2
  o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o

def cylinder(name,at,radius,depth,mat,verts=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=at)
 o=bpy.context.object;o.name=name;o.data.materials.append(mat);return o

def line(name,points,width,mat):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=width;c.bevel_resolution=0
 sp=c.splines.new('POLY');sp.points.add(len(points)-1)
 for p,co in zip(sp.points,points):p.co=(*co,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(mat);return o

def asset(name,kind='props',at=(0,0,0),scale=1,rotation=0):
 path=ROOT/'art_source/screenprint'/kind/(name+'.blend')
 with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=src.objects
 objects=[o for o in dst.objects if o and o.type in {'MESH','EMPTY','CURVE','FONT'}]
 for o in objects:bpy.context.collection.objects.link(o)
 root=bpy.data.objects.new('Display_'+name,None);bpy.context.collection.objects.link(root)
 for o in objects:
  if o.parent is None:o.parent=root
 root.location=at;root.scale=(scale,)*3;root.rotation_euler.z=rotation
 bpy.context.view_layer.update()
 return root,objects

def aero_rim():
 # High-fidelity P7 twin-spoke aero wheel for the menu render (mirrors RallyWheelMeshes.aero_rim).
 silver=material('aero silver','c9cfd2',.25,.8);dark=material('aero barrel','2c3134',.5,.2);red=material('caliper red','d0412f',.4)
 root=bpy.data.objects.new('AeroRim',None);bpy.context.collection.objects.link(root)
 bpy.ops.mesh.primitive_torus_add(major_radius=.215,minor_radius=.012,major_segments=64,minor_segments=8);lip=bpy.context.object;lip.data.materials.append(silver);lip.parent=root
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.19,depth=.01,location=(0,0,-.03));disc=bpy.context.object;disc.data.materials.append(dark);disc.parent=root
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.055,depth=.05,location=(0,0,.02));cap=bpy.context.object;cap.data.materials.append(silver);cap.parent=root
 for spoke in range(10):
  base=math.tau*(spoke//2)/5;pts=[]
  for r in range(9):
   t=r/8;radius=.055+.15*t;ang=base+(.022 if spoke%2 else -.022)/radius+t*.18
   pts.append((math.cos(ang)*radius,math.sin(ang)*radius,.03-t*.012))
  o=line('Aero spoke',pts,.011,silver);o.parent=root
 bpy.ops.mesh.primitive_cube_add(size=1,location=(.15,0,-.04));c=bpy.context.object;c.dimensions=(.09,.13,.03);c.data.materials.append(red);c.parent=root
 for o in root.children:
  if o.type=='MESH':
   for p in o.data.polygons:p.use_smooth=True
 return root

def car(ident,at=(0,0,0),scale=1,rotation=0):
 root,objects=asset(ident,'vehicles')
 mounts=[o for o in objects if o.name.startswith('WheelMount')]
 for mount in mounts:
  for part in ['wheel_tire','wheel_rim']:
   if part=='wheel_rim' and ident=='P7':
    wheel=aero_rim();wheel.parent=root
    side=1 if mount.location.x>0 else -1
    wheel.location=mount.location.copy();wheel.location.x+=side*.13
    wheel.rotation_euler.y=math.pi/2*side
    continue
   wheel,_=asset(part)
   wheel.parent=root
   side=1 if mount.location.x>0 else -1
   wheel.location=mount.location.copy()
   wheel.rotation_euler.y=math.pi/2*side
   if part=='wheel_rim':wheel.location.x+=side*.115
 # Runtime license plate replicated as geometry on its explicit authored mount.
 for marker in [o for o in objects if o.name.startswith('PlateRear')]:
  p=marker.location.copy();p.y-=.012
  ivory=material('plate','eee2c5');ink=material('plate_ink','20252b')
  plate=box('DisplayLicense',p,(.49,.018,.11),ivory,.008);plate.parent=root
  bpy.ops.object.text_add(location=(p.x,p.y-.011,p.z))
  text=bpy.context.object;text.name='DisplayLicenseText';text.data.body='BRUSHLINE';text.data.align_x='CENTER';text.data.align_y='CENTER';text.data.size=.065
  text.rotation_euler=(math.pi/2,0,0);text.data.materials.append(ink);text.parent=root
 root.location=at;root.scale=(scale,)*3;root.rotation_euler.z=rotation
 bpy.context.view_layer.update();return root

def reset():
 bpy.ops.wm.read_factory_settings(use_empty=True)
 scene=bpy.context.scene;scene.unit_settings.system='METRIC'
 scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
 scene.cycles.max_bounces=5;scene.render.film_transparent=True
 scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8'
 scene.render.resolution_x=SIZE;scene.render.resolution_y=SIZE*3//4;scene.render.resolution_percentage=100
 scene.view_settings.view_transform='AgX'
 scene.world=bpy.data.worlds.new('Transparent studio');scene.world.use_nodes=True
 scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.48,.57,.68,1)
 scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.4
 scene['purpose']='Transparent menu illustration; not a gameplay screenshot or route map'
 scene['source_policy']='Menu composition is editable here; gameplay sources remain separate'

def light(name,at,power,size,color,target=(0,0,0)):
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
 o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()

def camera(at,target,ortho):
 data=bpy.data.cameras.new('MenuCamera');data.type='ORTHO';data.ortho_scale=ortho
 o=bpy.data.objects.new('MenuCamera',data);bpy.context.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();bpy.context.scene.camera=o

def rock(at,scale,color):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=at)
 o=bpy.context.object;o.name='Chiselled rock';o.scale=scale;o.rotation_euler=(rng.random()*.3,rng.random()*.3,rng.random()*math.tau);o.data.materials.append(color);return o

def pine(x,y,z,h,color):
 bark=material('bark','654538');cylinder('Pine trunk',(x,y,z+h*.40),h*.035,h*.8,bark,7)
 # Six overlapping ragged skirts, visible boughs instead of one smooth cone.
 for layer in range(6):
  t=layer/6;r=h*(.27-.033*layer);base=z+h*(.22+t*.66)
  verts=[(x,y,base+h*.32)]
  for j in range(12):
   a=j*math.tau/12;rr=r*(1 if j%2==0 else .72)
   verts.append((x+rr*math.cos(a),y+rr*math.sin(a),base-rng.uniform(0,.06)*h))
  mesh('Pine bough tier',verts,[(0,1+j,1+(j+1)%12) for j in range(12)],color)

def leaf_tree(x,y,z,h,color):
 bark=material('bark','654538');line('Autumn trunk',[(x,y,z),(x+.08,y,z+h*.72)],.055*h,bark)
 for j in range(4):
  a=j*math.tau/3;px=x+math.cos(a)*h*.19;py=y+math.sin(a)*h*.19;pz=z+h*(.64+j*.05)
  line('Branch',[(x,y,z+h*.45),(px,py,pz)],.025*h,bark)
  rock((px,py,pz),(h*.32,h*.3,h*.34),color)

def path_samples(points):
 out=[]
 for i in range(len(points)-1):
  a=Vector(points[max(0,i-1)]);b=Vector(points[i]);c=Vector(points[i+1]);d=Vector(points[min(len(points)-1,i+2)])
  for j in range(12):
   t=j/12;v=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t);out.append(v)
 out.append(Vector(points[-1]));return out

def yucca(x,y,z,h):
 trunk=material('yucca trunk','6b5541');leaf=material('yucca leaf','5f9a50')
 cylinder('Yucca trunk',(x,y,z+h*.25),h*.05,h*.5,trunk,6)
 for j in range(9):
  a=j*math.tau/9;line('Yucca blade',[(x,y,z+h*.5),(x+math.cos(a)*h*.45,y+math.sin(a)*h*.45,z+h*(.85+.15*math.sin(j)))],h*.035,leaf)

def ocotillo(x,y,z,h):
 stem=material('ocotillo','6a6a48');bloom=material('ocotillo bloom','d8513a')
 for j in range(6):
  a=j*math.tau/6+rng.random()*.4;tip=(x+math.cos(a)*h*.28,y+math.sin(a)*h*.28,z+h)
  line('Ocotillo stem',[(x,y,z),tip],h*.025,stem);cylinder('Ocotillo bloom',(tip[0],tip[1],tip[2]+h*.06),h*.035,h*.14,bloom,5)

def butte(x,y,z,w,d,h,mats,tiers=2,name='Butte'):
 """Stacked faceted sandstone tiers with alternating strata colours."""
 zz=z
 for t in range(tiers):
  th=h/tiers
  for band in range(3):
   bh=th/3;sc=1-.04*t-.015*band
   verts=[];sides=8
   for k,(r,hz) in enumerate([(1,zz),(.96,zz+bh)]):
    for j in range(sides):
     a=j*math.tau/sides+.2;jit=.80+.20*abs(math.sin(j*2.7+x*1.3+y))
     verts.append((x+math.cos(a)*w*.5*sc*r*jit,y+math.sin(a)*d*.5*sc*r*jit,hz))
   faces=[(j,(j+1)%sides,sides+(j+1)%sides,sides+j) for j in range(sides)]+[tuple(range(sides,2*sides)),tuple(range(sides-1,-1,-1))]
   mesh(name,verts,faces,mats[(t*3+band)%len(mats)])
   zz+=bh
  w*=.86;d*=.86

def mesa(x0,x1,y0,y1,z,h,mats,seed=0,name='Mesa wall'):
 """Broad flat-topped sandstone wall: stepped strata slabs with a jagged eroded face."""
 r=random.Random(seed);bands=5;steps=14
 front=[(x0+(x1-x0)*i/steps,y0+r.uniform(-.25,.25)) for i in range(steps+1)]
 for b in range(bands):
  inset=.10*b+(.35 if b==bands-1 else 0);zb=z+h*b/bands;zt=z+h*(b+1)/bands
  shrink=.12*b
  ring=[(x+(shrink if i==0 else (-shrink if i==steps else 0)),y+inset) for i,(x,y) in enumerate(front)]
  ring+=[(x1-shrink,y1),(x0+shrink,y1)]
  k=len(ring)
  verts=[(x,y,zb) for x,y in ring]+[(x,y,zt) for x,y in ring]
  faces=[(i,(i+1)%k,k+(i+1)%k,k+i) for i in range(k)]+[tuple(range(k,2*k)),tuple(range(k-1,-1,-1))]
  o=mesh(name,verts,faces,mats[[0,2,1,3,1][b]])
  bpy.context.view_layer.objects.active=o
  for poly in o.data.polygons:poly.use_smooth=False

def redrock_landmarks(path,height,stone,ivory,red,teal):
 strata=[material('deep red rock','8f3a22'),material('terracotta rock','b9532f'),material('orange rock','d4834e'),material('pale band','e8bf8a')]
 # Canyon walls along the back edge and left, like the stage's first kilometre.
 for x0,x1,y0,h,seed in [(-9.9,-4.2,4.7,3.4,1),(-3.6,1.6,5.4,4.2,2),(2.2,9.9,4.9,3.0,3)]:
  mesa(x0,x1,y0,6.95,min(height(x0,y0),height(x1,y0))-.4,h,strata,seed)
 mesa(-9.95,-8.2,-2.2,4.9,height(-9,-2)-.4,2.4,strata,4,'Canyon side wall')
 # A free-standing hoodoo and low boulders.
 butte(6.4,-4.6,height(6.4,-4.6)-.2,1.4,1.2,3.0,strata,3,'Hoodoo')
 for x,y in [(-3.5,-5.2),(3.0,-5.8),(8.5,-1.5),(-6.5,-1.5)]:rock((x,y,height(x,y)+.15),(.55,.45,.40),stone)
 # The weathered stone arch spanning the road.
 i=int(len(path)*.72);p=path[i];t=(path[i+1]-path[i-1]).normalized();n=Vector((-t.y,t.x))
 z0=height(p.x,p.y);pts=[]
 for j in range(21):
  a=math.pi*j/20;q=p+n*math.cos(a)*1.9;pts.append((q.x,q.y,z0+math.sin(a)*2.7))
 line('Stone arch',pts,.42,strata[1])
 for side in [-1,1]:
  q=p+n*1.9*side;butte(q.x,q.y,height(q.x,q.y)-.2,1.2,1.0,1.4,strata,1,'Arch foot')
 # Desert life: windpump, water tank, mining headframe.
 wood=material('weathered timber','6b5541');steel=material('windpump steel','8b9290')
 x,y=-6.8,-4.6;z=height(x,y)
 for dx,dy in [(-.3,-.3),(.3,-.3),(-.3,.3),(.3,.3)]:line('Windpump leg',[(x+dx,y+dy,z),(x,y,z+3.0)],.035,steel)
 for j in range(10):
  a=j*math.tau/10;line('Windpump blade',[(x,y-.05,z+3.1),(x+math.cos(a)*.6,y-.05,z+3.1+math.sin(a)*.6)],.05,ivory if j%2 else red)
 cylinder('Water tank',(x+1.1,y+.2,z+.25),.55,.5,steel,16)
 x,y=-3.2,3.8;z=height(x,y)
 for dx in [-.4,.4]:line('Headframe',[(x+dx,y-.4,z),(x,y,z+2.6)],.06,wood);line('Headframe',[(x+dx,y+.4,z),(x,y,z+2.6)],.06,wood)
 cylinder('Sheave',(x,y,z+2.7),.3,.06,material('iron','3f4a4c'),16)
 box('Ore hopper',(x+.9,y,z+.6),(.8,.8,1.0),material('rust hopper','b34d2d'),.03)
 # Teal shade sail with spectators near the finish.
 q=path[-6];z=height(q.x,q.y+1.4)
 for dx,dy in [(-.6,-.4),(.6,-.4),(-.6,.4),(.6,.4)]:cylinder('Shade post',(q.x+dx,q.y+1.6+dy,z+.4),.03,.8,wood,6)
 box('Shade sail',(q.x,q.y+1.6,z+.82),(1.5,1.0,.04),teal,.01)

def stage(kind):
 reset();rng.seed(73421)
 ivory=material('ivory','eee2c5');red=material('orange','e66a39');teal=material('pine','245b52');yellow=material('larch','c6ab4e')
 if kind=='sunset_ridge':
  ground=material('ochre meadow','d2a24c');edge=material('cut clay','84634b');road=material('loose gravel','ad9680');stone=material('ridge rock','818c91')
  points=[(-9,-5),(-4,-4),(1,-2),(-3,1),(-1,4),(8,5)]
  def base(x,y):return .4+.05*y+2.4*math.exp(-((x+6)**2+(y-5)**2)/14)+.8*math.exp(-((x-7)**2+(y+1)**2)/15)
 elif kind=='sunlit_cape':
  ground=material('coast turf','8d9b70');edge=material('chalk cliff','e2dac7');road=material('coastal asphalt','58666b');stone=material('coastal chalk','e3dac1')
  points=[(-9,-2),(-4,-1),(0,2),(4,3),(7,1),(9,0)]
  def base(x,y):return 1.1+.10*(x+10)+.05*y+.7*math.exp(-((x+5)**2+(y-4)**2)/15)
 elif kind=='redrock_canyon':
  ground=material('desert sand','e0ac6a');edge=material('red strata','a5472c');road=material('packed red earth','9c6143');stone=material('sandstone','c0583a')
  points=[(-9,-3.5),(-5,-3),(-1,-1),(2,1.5),(5,1.0),(9,3)]
  def base(x,y):return .45+.05*y+.55*math.sin(x*.55+y*.35)*math.exp(-((y+1)**2)/30)
 else:
  ground=material('dusk meadow','798b83');edge=material('purple cliff','525a75');road=material('highland gravel','90908b');stone=material('mountain blue','586c86')
  points=[(-9,-4),(-5,-2),(0,-.5),(4,0),(7,2),(9,4)]
  def base(x,y):return 1.2+.14*(x+10)+.10*y
 path=path_samples(points)
 def distance(x,y):return min((Vector((x,y))-p).length for p in path)
 def height(x,y):
  h=base(x,y)
  if kind=='misty_highlands':
   nearest=min(path,key=lambda p:(Vector((x,y))-p).length)
   side=y-nearest.y
   if side>1.2:h+=min(4.5,(side-1.2)*1.1)
   if side< -1.5:h-=min(4.5,(-side-1.5)*6.0)
  return h
 # Cut-away display terrain; coast has a separate foreground sea level.
 ymin=-3.8 if kind=='sunlit_cape' else -7
 n=32;verts=[]
 for j in range(n+1):
  for i in range(n+1):
   x=-10+20*i/n
   front=min(path,key=lambda p:abs(p.x-x)).y-2.3 if kind=='misty_highlands' else ymin
   y=front+(7-front)*j/n
   verts.append((x,y,height(x,y)))
 faces=[]
 for j in range(n):
  for i in range(n):
   a=j*(n+1)+i;faces.extend([(a,a+1,a+n+2),(a,a+n+2,a+n+1)])
 obj=mesh('Contoured landscape',verts,faces,ground)
 # Broad color regions, no noisy image textures.
 alt=material('grass highlight',{'sunset_ridge':'e2b653','sunlit_cape':'aeb98b','misty_highlands':'939e88','redrock_canyon':'eec383'}[kind]);obj.data.materials.append(alt)
 for face in obj.data.polygons:
  p=face.center
  if math.sin(p.x*.42+p.y*.63)+math.cos(p.y*.71-p.x*.22)>.85:face.material_index=1
 ring=[i for i in range(n+1)]+[j*(n+1)+n for j in range(1,n+1)]+[n*(n+1)+i for i in range(n-1,-1,-1)]+[j*(n+1) for j in range(n-1,0,-1)]
 bottom=-3.5 if kind=='misty_highlands' else -1.5
 sideverts=[verts[i] for i in ring]+[(verts[i][0],verts[i][1],bottom) for i in ring]
 k=len(ring);mesh('Exposed terrain strata',sideverts,[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)],edge)
 mesh('Diorama underside',[(x,y,bottom) for x,y,z in verts],[(0,n,n*(n+1)+n,n*(n+1))],edge)
 width=.72 if kind=='misty_highlands' else .87
 for extra,mat in [(.19,stone),(0,road)]:
  vs=[]
  for i,p in enumerate(path):
   tangent=(path[min(i+1,len(path)-1)]-path[max(0,i-1)]).normalized();normal=Vector((-tangent.y,tangent.x))
   for sign in [-1,1]:
    q=p+normal*(width+extra)*sign;vs.append((q.x,q.y,height(q.x,q.y)+.045+(0.01 if extra==0 else 0)))
  mesh('Road shoulder' if extra else 'Winding rally road',vs,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(path)-1)],mat)
 # Reflective posts and a few surface stones make the driving scale legible.
 for i in range(4,len(path)-3,6):
  p=path[i];t=(path[i+1]-path[i-1]).normalized();normal=Vector((-t.y,t.x))
  for sign in [-1,1]:
   q=p+normal*(width+.22)*sign;z=height(*q)
   cylinder('White roadside marker',(q.x,q.y,z+.28),.045,.56,ivory,8)
   cylinder('Red reflector band',(q.x,q.y,z+.41),.047,.12,red,8)
 for _ in range(65):
  x=rng.uniform(-9.3,9.3);y=rng.uniform(ymin+.6,6.3)
  if distance(x,y)<1.6:continue
  if kind=='sunlit_cape' and x>4 and y>3:continue
  if kind=='sunset_ridge' and (x+5)**2+(y-3)**2<8:continue
  if kind=='misty_highlands' and y<min(path,key=lambda p:abs(p.x-x)).y-1.2:continue
  if kind=='redrock_canyon' and (y>4.4 or (x<-7.9 and y>-2.4)):continue
  z=height(x,y)
  if rng.random()<.2:
   rock((x,y,z+.12),(rng.uniform(.3,.65),.35,.42),stone);continue
  if kind=='redrock_canyon':
   if rng.random()<.45:continue
   if rng.random()<.6:yucca(x,y,z,rng.uniform(.45,.8))
   else:ocotillo(x,y,z,rng.uniform(.8,1.3))
   continue
  if kind=='sunlit_cape':
   if rng.random()<.60:continue
   leaf_tree(x,y,z,rng.uniform(.7,1.3),teal)
  elif kind=='misty_highlands':
   pine(x,y,z,rng.uniform(1.1,2.5),teal)
  elif rng.random()<.48:
   leaf_tree(x,y,z,rng.uniform(1.5,2.7),red if rng.random()<.6 else yellow)
  else:pine(x,y,z,rng.uniform(1.4,3.0),teal)
 if kind=='redrock_canyon':redrock_landmarks(path,height,stone,ivory,red,teal)
 if kind=='sunset_ridge':
  x,y=-5,3;asset('cabin',at=(x,y,height(x,y)),scale=.45,rotation=.05)
  for j in range(5):rock((-8+j*.6,5.9,height(-8+j*.6,5.9)+.4),(.8,.65,.9),stone)
 elif kind=='sunlit_cape':
  sea=material('turquoise sea','268f9f',.3);box('Sea slice',(0,-5.6,-1.15),(20,5.0,.62),sea,.08)
  sand=material('golden beach','e3b763');mesh('Beach ledge',[(-10,-3.8,-.8),(10,-3.8,-.8),(10,-4.65,-.85),(-10,-4.45,-.85)],[(0,1,2,3)],sand)
  x,y=6,4.7;asset('lighthouse',at=(x,y,height(x,y)),scale=.24)
  asset('sailboat',at=(-2,-6.1,-.80),scale=.22,rotation=-.45)
  foam=material('sea glints','bad9cd')
  for j in range(16):
   x=rng.uniform(-9,9);y=rng.uniform(-7.5,-4.9);line('Wave glint',[(x,y,-.826),(x+rng.uniform(.2,.7),y,-.826)],.025,foam)
 elif kind=='misty_highlands':
  for j in range(7):
   x=-8+j*2.5;y=5.5;rock((x,y,height(x,y)-.4),(1.5,1.7,1.2+rng.random()*1.5),stone)
  # Warm reflectors make the dusk concept clear without a painted sky rectangle.
  lamp=material('amber lamps','fac66f');bs=next(n for n in lamp.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Emission Color'].default_value=(1,.35,.06,1);bs.inputs['Emission Strength'].default_value=2
  for i in [15,29,43]:
   p=path[i];cylinder('Reflector lantern',(p.x,p.y-1,height(p.x,p.y-1)+.5),.08,.22,lamp)
 # Tiny real model provides a scale cue and makes this a rally diorama.
 p=path[len(path)//2];t=(path[len(path)//2+1]-path[len(path)//2-1]).normalized()
 car({'sunset_ridge':'F160','sunlit_cape':'R200','misty_highlands':'A240','redrock_canyon':'P7'}[kind],(p.x,p.y,height(*p)+.26),.35,math.atan2(-t.x,t.y))
 if kind=='misty_highlands':
  light('Blue dusk fill',(4,-10,16),1500,12,(.45,.58,1));light('Last orange rim',(-10,12,14),2400,8,(1,.43,.20))
  light('Soft road readability',(1,-6,10),500,9,(.7,.8,1))
 else:
  light('Warm afternoon',(-10,-8,19),3100,10,(1,.82,.60));light('Cool sky',(12,5,16),2000,12,(.63,.80,1))
  sun=bpy.data.lights.new('Clear afternoon sun','SUN');sun.energy=1.25;sun.angle=.12
  o=bpy.data.objects.new('Clear afternoon sun',sun);bpy.context.collection.objects.link(o);o.rotation_euler=(.55,-.42,-.4)
 camera((22,-31,24),(0,0,1.0 if kind!='misty_highlands' else 2),30)
 bpy.context.scene['theme']=kind

def vehicle(ident):
 reset();car(ident)
 light('Broad warm key',(-3,-5,6),700,5,(1,.91,.80));light('Cool rim',(4,3,5),950,4,(.72,.85,1));light('Rear fill',(1,-5,2),180,3,(1,.8,.65))
 camera((-5.8,8.4,3.5),(0,.05,.22),5.1)
 bpy.context.scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.55
 bpy.context.scene['vehicle_id']=ident

for ident in ['sunset_ridge','sunlit_cape','misty_highlands','redrock_canyon','F160','R200','A240','I20','DELTA','EVO6','WRX','P7']:
 if ONLY and ident!=ONLY:continue
 source=SOURCES/(ident+'.blend')
 if '--rebuild' in ARGS or (not source.exists() and '--build' in ARGS):
  stage(ident) if '_' in ident else vehicle(ident)
  bpy.context.scene.render.filepath='//../../assets/ui/menu_models/'+ident+'.png'
  bpy.ops.file.pack_all()
  bpy.ops.wm.save_as_mainfile(filepath=str(source))
 elif source.exists():bpy.ops.wm.open_mainfile(filepath=str(source))
 else:raise RuntimeError('Missing authored source; run --build first: '+str(source))
 scene=bpy.context.scene;scene.render.resolution_x=SIZE;scene.render.resolution_y=SIZE*3//4
 scene.render.filepath=str(OUTPUT/(ident+'.png'))
 bpy.ops.render.render(write_still=True)
 png=OUTPUT/(ident+'.png')
 image=bpy.data.images.load(str(png),check_existing=False)
 pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
 alpha=pixels.reshape(-1,4)[:,3]
 assert np.mean(alpha==0)>.15 and np.mean(alpha>.99)>.12, 'Expected a visible model and a transparent surrounding region'
 assert np.any((alpha>0)&(alpha<1)), 'Expected antialiased alpha edges'
 manifest_path=OUTPUT/'manifest.json'
 manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
 manifest[ident]={'source':str(source.relative_to(ROOT)),'render':str(png.relative_to(ROOT)),'sha256':hashlib.sha256(png.read_bytes()).hexdigest(),'resolution':list(image.size),'transparent_fraction':round(float(np.mean(alpha==0)),4),'opaque_fraction':round(float(np.mean(alpha>.99)),4),'engine':'Blender Cycles','samples':scene.cycles.samples,'alpha':'straight RGBA','purpose':'vehicle display' if '_' not in ident else 'representative diorama, not a navigation map'}
 manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
 bpy.data.images.remove(image)
 print('MENU MODEL RENDERED',ident,flush=True)
print('MENU RENDERS COMPLETE',flush=True)
