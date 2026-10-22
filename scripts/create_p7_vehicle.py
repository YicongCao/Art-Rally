"""Author the XPENG new P7 (2025) rally source as a lofted body.

Blender --background --python scripts/create_p7_vehicle.py [-- --rebuild]
Godot coordinates (metres, +Y up, -Z forward); the body origin sits at the
same height as the other expansion cars so wheel mounts and physics stay put.

Reference: official XPENG new P7 photos and 5017 x 1970 x 1427 mm, 3008 mm
wheelbase. Silhouette traits taken from the photos: very low blunt nose with a
full-width light bar wrapping into vertical corner blades, long flat bonnet,
steeply raked screen, one continuous fastback roof arc falling to a short
ducktail, a thin full-width rear lamp under the ducktail, high flat waist and
flush handles. The rally build adds lift, arch cladding, skid plates and tyres.
"""
import bpy, bmesh, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
exec((ROOT/'scripts/create_screenprint_sources.py').read_text().split('def vehicle(')[0])
COLORS.update(led='f4f8f6',paint='b9c2c5',accent='238b8c',trim='2b3236',satin='4d575c',glass='26323a')
PATH=OUT/'vehicles'/'P7.blend'

W=1.970;L=5.017;WB=3.008;TRACK=1.66
HALF=W/2;END=L/2
WHEEL_Y=-.34;ARCH_R=.455
# Ground sits at -0.71 (wheel mount -0.34, 0.37 m tyre). Roof 1.427 m + 40 mm rally lift.

# Key stations front (-z) to rear (+z), interpolated with Catmull-Rom:
# z, half width, sill y, belt (shoulder crease) y, greenhouse base ratio, top y, crown exponent
KEYS=[
 (-2.508,.42,-.30,-.13,.97,-.12,2.0),
 (-2.485,.64,-.36,-.075,.97,-.065,2.0),
 (-2.42,.79,-.41,-.02,.97,.0,2.0),
 (-2.32,.875,-.43,.02,.97,.05,2.1),
 (-2.18,.932,-.43,.055,.97,.09,2.2),
 (-2.00,.962,-.43,.085,.97,.12,2.3),
 (-1.60,.984,-.43,.13,.955,.17,2.5),
 (-1.25,.985,-.43,.158,.92,.205,2.6),
 (-1.08,.985,-.43,.168,.82,.235,2.6),
 (-.75,.985,-.43,.176,.75,.50,2.6),
 (-.40,.985,-.43,.182,.74,.69,2.8),
 (.00,.985,-.43,.188,.74,.765,2.8),
 (.45,.985,-.43,.194,.735,.76,2.8),
 (.95,.982,-.43,.204,.73,.69,2.7),
 (1.40,.978,-.43,.216,.74,.57,2.6),
 (1.80,.970,-.43,.228,.82,.43,2.6),
 (2.10,.958,-.42,.238,.93,.34,2.6),
 (2.30,.935,-.40,.248,.96,.31,2.5),
 (2.42,.895,-.37,.258,.97,.318,2.4),
 (2.48,.80,-.33,.20,.97,.25,2.3),
 (2.508,.62,-.28,.10,.97,.12,2.2),
]
GLASS_Z=(-1.04,1.98)

def catmull(z):
 ks=KEYS
 if z<=ks[0][0]:return ks[0][1:]
 if z>=ks[-1][0]:return ks[-1][1:]
 i=max(j for j in range(len(ks)-1) if ks[j][0]<=z)
 a=ks[max(0,i-1)];b=ks[i];c=ks[i+1];d=ks[min(len(ks)-1,i+2)]
 t=(z-b[0])/(c[0]-b[0])
 out=[]
 for k in range(1,len(b)):
  p0,p1,p2,p3=a[k],b[k],c[k],d[k]
  v=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t**3)
  lo,hi=min(p1,p2),max(p1,p2)
  out.append(min(max(v,lo),hi))
 return out

def half_section(hw,sill,belt,ratio,top,n):
 """Right half, from bottom centre round to roof centre."""
 pts=[(0,sill),(hw*.55,sill),(hw*.88,sill+.008),(hw*.965,sill+.06),(hw*.995,sill+.17),(hw,(sill+belt)*.5),(hw*.997,belt-.06),(hw*.986,belt)]
 gw=hw*ratio;ledge=belt+.03
 pts.append((gw+(hw*.986-gw)*.25,ledge))
 rise=max(top-ledge,.02)
 for j in range(1,10):
  th=j/9*math.pi/2
  x=gw*math.cos(th)**(2/n) if j<9 else 0
  y=ledge+rise*math.sin(th)**(2/(n*1.15))
  pts.append((x,y))
 return pts

def loft():
 zs=[]
 z=-END
 while z<END:
  zs.append(z);step=.03 if abs(z)>2.3 else (.06 if abs(z)>1.9 else .09);z+=step
 zs.append(END)
 rings=[]
 for z in zs:
  hw,sill,belt,ratio,top,n=catmull(z)
  half=half_section(hw,sill,belt,ratio,top,n)
  # left side mirrored, skipping the duplicated centre points
  ring=[(-x,y) for x,y in reversed(half[1:-1])]+[(0,half[-1][1])]+[(x,y) for x,y in half[1:-1]][::-1][::-1]
  ring=[(x,y) for x,y in half]+[(-x,y) for x,y in reversed(half[1:-1])]
  rings.append(([(x,y,z) for x,y in ring],belt))
 n=len(rings[0][0])
 verts=[v for r,_ in rings for v in r]
 faces=[];glass=[]
 for i in range(len(rings)-1):
  for j in range(n):
   k=(j+1)%n
   faces.append(((i+1)*n+j,(i+1)*n+k,i*n+k,i*n+j))
   ya=rings[i][0][j][1];yb=rings[i][0][k][1];z=rings[i][0][j][2]
   belt=min(rings[i][1],rings[i+1][1])
   xa=abs(rings[i][0][j][0]);hw=catmull(z)[0];gw=hw*catmull(z)[3]
   upper=min(ya,yb)>belt+.045
   side=xa>gw*.80
   # Body-colour C-pillar sail: side windows end at 1.30 m, rear glass narrows along the fastback.
   sail=side and z>1.22
   glass.append(GLASS_Z[0]<z<GLASS_Z[1] and upper and not sail and not (z>1.75 and xa>gw*.62))
 faces.append(tuple(range(n)));glass.append(False)
 faces.append(tuple((len(rings)-1)*n+j for j in reversed(range(n))));glass.append(False)
 o=mesh('SculptedBody',verts,faces,'paint')
 o.data.materials.append(mat('glass'))
 for poly,g in zip(o.data.polygons,glass):poly.material_index=1 if g else 0
 bm=bmesh.new();bm.from_mesh(o.data)
 bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.0005)
 bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
 bm.to_mesh(o.data);bm.free()
 o['outline']=True
 return o

def cut_arches(body):
 # Boolean wheel openings so tyres sit inside real wells.
 for z in [-WB/2,WB/2]:
  for side in [-1,1]:
   bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=ARCH_R,depth=.75,location=xyz((side*(HALF-.12),WHEEL_Y+.03,z)))
   cut=bpy.context.object;cut.name='ArchCutter';cut.rotation_euler=(0,math.pi/2,0)
   bpy.context.view_layer.objects.active=body
   mod=body.modifiers.new('Wheel opening','BOOLEAN');mod.object=cut;mod.operation='DIFFERENCE';mod.solver='EXACT'
   bpy.ops.object.modifier_apply(modifier=mod.name)
   bpy.data.objects.remove(cut,do_unlink=True)
 bpy.context.view_layer.objects.active=body;body.select_set(True)
 bpy.ops.object.shade_smooth_by_angle(angle=math.radians(38))
 body.select_set(False)

def glass():
 # Thin satin window outline separates glasshouse from body like the real chrome-less trim.
 for side in [-1,1]:
  pts=[]
  for i in range(31):
   z=GLASS_Z[0]+.04+(GLASS_Z[1]-GLASS_Z[0]-.08)*i/30
   hw,sill,belt,ratio,top,n=catmull(z)
   pts.append((side*(hw*.986-.002),belt+.012,z))
  for a,b in zip(pts,pts[1:]):beam('WindowLine',a,b,.016,'trim')

def inside(z,x,y):
 hw,sill,belt,ratio,top,n=catmull(z)
 pts=half_section(hw,sill,belt,ratio,top,n)
 # Half width of the section at height y, from the polyline outline.
 width=0
 for (xa,ya),(xb,yb) in zip(pts,pts[1:]):
  if min(ya,yb)<=y<=max(ya,yb) and ya!=yb:width=max(width,xa+(xb-xa)*(y-ya)/(yb-ya))
 return abs(x)<=width and sill<=y<=top

def strip(name,pts,height,depth,color,facing):
 """Continuous rectangular ribbon through pts (one mesh, no segment seams)."""
 verts=[];faces=[]
 for x,y,z in pts:
  for dy,dz in [(-height/2,0),(height/2,0),(height/2,facing*depth),(-height/2,facing*depth)]:verts.append((x,y+dy,z+dz))
 for i in range(len(pts)-1):
  for k in range(4):faces.append((i*4+k,i*4+(k+1)%4,(i+1)*4+(k+1)%4,(i+1)*4+k))
 faces.append((0,1,2,3));n=len(pts)-1;faces.append((n*4+3,n*4+2,n*4+1,n*4))
 o=mesh(name,verts,faces,color)
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
 return o

def nose_z(y,x=0):
 """Front-most body z at (x,y) so lamps sit on the nose skin."""
 for i in range(600):
  z=-END+i*.003
  if inside(z,x,y):return z
 return -END+.2

def tail_z(y,x=0):
 for i in range(600):
  z=END-i*.003
  if inside(z,x,y):return z
 return END-.2

def side_x(z,y):
 hw,sill,belt,ratio,top,n=catmull(z)
 pts=half_section(hw,sill,belt,ratio,top,n)
 width=0
 for (xa,ya),(xb,yb) in zip(pts,pts[1:]):
  if min(ya,yb)<=y<=max(ya,yb) and ya!=yb:width=max(width,xa+(xb-xa)*(y-ya)/(yb-ya))
 return width

def lights_and_trim():
 # Front: slim full-width light bar across the blunt nose, wrapping into vertical corner blades.
 bar=[]
 for i in range(29):
  x=-HALF*.80+i/28*HALF*1.60
  y=-.005
  bar.append((x,y,nose_z(y,x)+.004))
 # Gloss-black band directly under the LED line, as on the real car, gives the bar contrast on silver.
 strip('FrontLampBand',[(x,-.075,nose_z(-.075,x)+.004) for x,y,z in bar],.10,.03,'trim',-1)
 strip('FrontLightBar',bar,.04,.04,'led',-1)
 for side in [-1,1]:
  top=bar[-1 if side>0 else 0]
  lx=side*HALF*.80;low=(lx,-.25,nose_z(-.25,lx)-.004)
  beam('CornerBlade',top,low,.036,'led')
 box('FrontLogo',(0,.10,nose_z(.10)-.004),(.12,.014,.012),'ivory',.003)
 # Lower nose: dark grille band, rally skid plate and tow hooks.
 box('LowerGrille',(0,-.25,nose_z(-.25)+.03),(1.24,.11,.07),'trim',.02)
 box('FrontSkid',(0,-.43,-END+.30),(1.20,.04,.55),'metal',.012)
 for side in [-1,1]:box('FrontTowHook',(side*.45,-.36,nose_z(-.36)-.01),(.07,.05,.06),'red',.01)
 # Rear: thin full-width lamp just under the ducktail lip and a diffuser band.
 lamp=[]
 for i in range(25):
  x=-HALF*.80+i/24*HALF*1.60
  lamp.append((x,.215,tail_z(.215,x)-.012))
 strip('BrakeLampBar',lamp,.035,.03,'red',1)
 for side in [-1,1]:
  end=lamp[-1 if side>0 else 0]
  ex=side*HALF*.86;beam('BrakeLampBar',end,(ex,.08,tail_z(.08,ex)+.006),.026,'red')
 box('RearDiffuser',(0,-.29,tail_z(-.29)-.02),(1.50,.12,.08),'trim',.02)
 box('RearSkid',(0,-.43,END-.30),(1.10,.035,.45),'metal',.01)
 text('RearXPENG','X P E N G',(0,.12,tail_z(.12)+.008),.075,'ink')
 box('Ducktail',(0,.305,tail_z(.30)-.02),(1.55,.02,.10),'trim',.008)
 # Side: flush handles, door mirrors, satin sill cladding, rally arch flares and mud flaps.
 for side in [-1,1]:
  for z in [-.32,.58]:box('FlushHandle',(side*(HALF+.003),.12,z),(.012,.026,.20),'trim',.004)
  mx=side_x(-.66,.22)
  box('Mirror',(side*(mx+.075),.25,-.66),(.15,.075,.19),'paint',.03)
  box('MirrorStalk',(side*(mx+.015),.235,-.66),(.07,.03,.05),'trim',.008)
  box('SideCladding',(side*(HALF-.002),-.37,0),(.03,.09,WB-ARCH_R*2-.10),'satin',.012)
  for axle in [-WB/2,WB/2]:
   verts=[]
   for j in range(25):
    a=j*math.pi/24
    for r,xx in [(ARCH_R,HALF-.02),(ARCH_R+.05,HALF+.035),(ARCH_R+.075,HALF-.005)]:verts.append((side*xx,WHEEL_Y+.03+r*math.sin(a),axle+r*math.cos(a)))
   faces=[(j*3+k,j*3+k+1,(j+1)*3+k+1,(j+1)*3+k) for j in range(24) for k in range(2)]
   ob=mesh('WideArch',verts,faces,'satin');ob['outline']=True
   box('MudFlap',(side*(TRACK/2),-.47,axle+.50),(.24,.24,.025),'ink',.003)
  # Livery: teal sweep low on the doors and the race number, separate editable meshes.
  x=side*(HALF+.004)
  def sx(z,y,o=.004):return side*(side_x(z,y)+o)
  # Livery strip sampled along the door skin so it never sinks into the curved panels.
  verts=[];faces=[]
  for i in range(13):
   t=i/12;z=1.02+(-.55-1.02)*t;lo=-.36+.18*t;hi=lo+.16
   for y in [lo,(lo+hi)/2,hi]:verts.append((sx(z,y,.006),y,z))
  for i in range(12):
   for k in range(2):faces.append((i*3+k,i*3+k+1,(i+1)*3+k+1,(i+1)*3+k))
  mesh('LiverySweep',verts,faces,'accent')
  box('NumberBacking',(sx(.18,.005,.006),.005,.18),(.012,.21,.33),'ivory',.003)
  text('RaceNumber','07',(sx(.18,.005,.016),.005,.18),.18,'ink',side)
  text('BrandDecal','XPENG',(sx(-1.10,.07,.010),.07,-1.10),.08,'ink',side)

def cabin():
 box('Dashboard',(0,.26,-.62),(1.55,.14,.30),'ink',.03)
 box('Display',(.10,.38,-.60),(.42,.22,.02),'glass',.006)
 for side in [-1,1]:
  box('SeatCushion',(side*.36,-.05,.05),(.42,.12,.50),'ink',.04)
  box('SeatBack',(side*.36,.24,.30),(.42,.52,.14),'ink',.05)
  box('Headrest',(side*.36,.55,.30),(.24,.14,.12),'ink',.03)
 beam('SteeringColumn',(-.30,.20,-.60),(-.30,.36,-.46),.045,'ink')
 bpy.ops.mesh.primitive_torus_add(major_radius=.15,minor_radius=.017,major_segments=24,minor_segments=6,location=xyz((-.30,.38,-.44)))
 ob=bpy.context.object;ob.name='SteeringWheel';ob.rotation_euler.x=math.pi/2-.35;ob.data.materials.append(mat('ink'))
 box('Underbody',(0,-.42,0),(W-.40,.05,L-.60),'ink',0)

def author():
 if PATH.exists() and '--rebuild' not in sys.argv:
  print('Preserving',PATH);return
 reset()
 body=loft();cut_arches(body)
 glass();lights_and_trim();cabin()
 # Mount contract shared with the runtime; positions match the prior P7 so cameras,
 # plates, lamps and wheel physics are unchanged.
 for side in [-1,1]:marker('TailLeft' if side<0 else 'TailRight',(side*(HALF-.13),.23,END+.04))
 for z,name in [(END+.075,'PlateRear'),(-END-.075,'PlateFront')]:marker(name,(0,-.025,z))
 marker('CameraCockpit',(-.30,.70,-.70));marker('CameraHood',(0,.60,-END+.36))
 for i,(sx,sz) in enumerate([(-1,-1),(1,-1),(-1,1),(1,1)]):marker('WheelMount'+str(i),(sx*TRACK*.5,WHEEL_Y,sz*WB*.5))
 bpy.context.scene['reference_model']='P7'
 bpy.context.scene['reference']='XPENG new P7 official photos, 5017x1970x1427 mm, 3008 mm wheelbase'
 for ob in bpy.context.scene.objects:
  if ob.type=='MESH' and len(ob.data.polygons)>10 and ob.name!='SculptedBody':
   bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
 save(PATH,'vehicle')
 print('P7 AUTHORED',PATH)

author()
