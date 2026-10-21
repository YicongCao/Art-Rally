"""Author the approved pressure-gate checkpoint in Blender; game axes in metres.
Run Blender -b --python scripts/build_pressure_checkpoint.py -- --replace-checkpoint.
Then export_screenprint.py -- --only=checkpoint. Existing other sources are untouched.
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
if '--replace-checkpoint' not in sys.argv: raise RuntimeError('Use --replace-checkpoint to replace this authored source explicitly')
exec((ROOT/'scripts/build_brushline_assets.py').read_text().split('# Refine tails')[0])
bpy.ops.wm.read_factory_settings(use_empty=True)
COLORS.update(AirIvory='eee3c7',AirOrange='df5428',AirInk='26363c',AirSeam='c9bda3',RibbonIvory='eee3c7',RibbonOrange='df5428',MachineTeal='295960',MachineDark='263239',MachineSteel='84938e',Sandbag='8c8368',StaticOrange='c54624',FanRotorOrange='f4b971')
# Thin grille wires and hose ribs use un-beveled bars; silhouette budget matters
# because the full assembly is instanced at every checkpoint.
def beam(name,a,b,width,color):
 va,vb=Vector(xyz(a)),Vector(xyz(b))
 o=box(name,(0,0,0),(width,(vb-va).length,width),color,0)
 o.location=(va+vb)/2;o.rotation_euler=(vb-va).to_track_quat('Z','Y').to_euler();return o

def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def path(t):return Vector((.88*smooth(.48,1,t),.49+2.74*t,0))
def radius(t):return .36-.065*t+.018*math.sin(t*math.pi)
def frame(t):
 tangent=(path(min(1,t+.001))-path(max(0,t-.001))).normalized()
 return Vector((tangent.y,-tangent.x,0))
# Sewn pressure tube: smooth shared vertices, deliberately broad material panels.
verts=[];faces=[];colors=[];N=40;S=20
for i in range(N+1):
 t=i/N;p=path(t);n=frame(t)
 for j in range(S):
  angle=j*math.tau/S;r=radius(t)*(1+.008*math.cos(angle*8))
  verts.append(p+n*math.cos(angle)*r+Vector((0,0,math.sin(angle)*r)))
for i in range(N):
 for j in range(S):
  faces.append((i*S+j,i*S+(j+1)%S,(i+1)*S+(j+1)%S,(i+1)*S+j))
  height=path((i+.5)/N).y
  col='AirOrange' if 1.65<height+.16*math.cos((j+.5)*math.tau/S)<2.24 else 'AirIvory'
  if .64<height<1.0: col='AirInk' if (j//2+int((height-.64)/.12))%2 else 'AirIvory'
  colors.append(col)
o=mesh('PressureFabric',verts,faces,'AirIvory')
for col in ['AirOrange','AirInk']:o.data.materials.append(mat(col))
for face,col in zip(o.data.polygons,colors):face.material_index=['AirIvory','AirOrange','AirInk'].index(col);face.use_smooth=True
# Closed softly rounded tip and padded base, both visibly pressurized.
p=path(1);cap=ellipsoid('SealedOrangeCap',p,(.295,.20,.295),'AirOrange')
cap.rotation_euler.y=-.4
box('InflatedBase',(0,.24,0),(.98,.48,.92),'StaticOrange',.15)
box('WeightedFoot',(0,.045,0),(1.10,.13,1.02),'MachineDark',.035)
for x in [-.36,.36]:
 box('Webbing',(x,.28,-.465),(.05,.32,.018),'MachineDark',.006)
 box('Buckle',(x,.24,-.481),(.082,.075,.014),'MachineSteel',.009)
for side in [-1,1]:
 ellipsoid('Sandbag',(side*.35,.10,.55),(.26,.115,.20),'Sandbag')
 beam('BagStrap',(side*.35,.19,.42),(side*.35,.19,.66),.026,'MachineDark')
# Four restrained longitudinal seams share the cloth animation mask.
for angle in [0,math.pi/2,math.pi,math.pi*1.5]:
 for i in range(12):
  def seam(t): return path(t)+frame(t)*math.cos(angle)*(radius(t)+.002)+Vector((0,0,math.sin(angle)*(radius(t)+.002)))
  beam('FabricSeam',seam(i/12),seam((i+1)/12),.006,'AirSeam')
# Wind streamer stitched into the outward cap, with alternating racing panels.
vv=[];ff=[]
for i in range(17):
 t=i/16
 for edge in [-1,1]: vv.append((.98+t*.85,3.28+.08*math.sin(t*math.tau)-t*.12+edge*.075*(1-.45*t),-.02+.04*math.sin(t*math.pi)))
for i in range(16):ff.append((i*2,i*2+1,i*2+3,i*2+2))
ribbon=mesh('TipStreamer',vv,ff,'RibbonOrange');ribbon.data.materials.append(mat('RibbonIvory'))
for face in ribbon.data.polygons:face.material_index=(face.index//3)%2
# Centrifugal blower located ALONG the shoulder rather than over the cliff edge.
box('BlowerFoot',(0,.08,-1.06),(.72,.13,.64),'MachineDark',.03)
bl=ellipsoid('BlowerHousing',(0,.35,-1.06),(.34,.32,.27),'MachineTeal')
box('MotorHandle',(0,.66,-1.06),(.31,.045,.13),'MachineDark',.02)
# Circular inlet and protective rings on both longitudinal faces.
for side in [-1,1]:
 z=-1.06+side*.265
 disk=cylinder('AirInlet',(0,.35,z),.255,.025,'MachineDark',20);disk.rotation_euler.x=math.pi/2
 for rad in [.11,.19,.245]:
  for j in range(16):
   a=j*math.tau/16;b=(j+1)*math.tau/16
   beam('GrilleRing',(math.cos(a)*rad,.35+math.sin(a)*rad,z+side*.018),(math.cos(b)*rad,.35+math.sin(b)*rad,z+side*.018),.009,'MachineSteel')
 for j in range(8):
  a=j*math.tau/8
  beam('GrilleSpoke',(0,.35,z+side*.022),(math.cos(a)*.24,.35+math.sin(a)*.24,z+side*.022),.012,'MachineSteel')
# Corrugated U-shaped pressure hose connects the blower side to padded base.
points=[Vector((.26,.25,-1.02)),Vector((.49,.22,-.83)),Vector((.52,.20,-.55)),Vector((.33,.22,-.33))]
for i in range(len(points)-1):
 a,b=points[i:i+2];beam('AirHose',a,b,.21,'MachineDark')
 for j in range(6):
  p=a.lerp(b,j/6);tangent=(b-a).normalized();n=tangent.cross(Vector((0,1,0))).normalized();up=tangent.cross(n)
  for k in range(10):
   v=p+(n*math.cos(k*math.tau/10)+up*math.sin(k*math.tau/10))*.115
   w=p+(n*math.cos((k+1)*math.tau/10)+up*math.sin((k+1)*math.tau/10))*.115
   beam('HoseRib',v,w,.016,'MachineSteel')
# High-contrast visible rotor behind each protective inlet grille.
for side in [-1,1]:
 z=-1.06+side*.278
 for blade in range(5):
  a=blade*math.tau/5
  points=[]
  for radius,delta in [(.055,-.20),(.22,.08),(.20,.38),(.065,.30)]:
   points.append((math.cos(a+delta)*radius,.35+math.sin(a+delta)*radius,z))
  mesh('FanRotor',points,[(0,1,2,3)],'FanRotorOrange')
marker('BlowerAudio' ,(0,.35,-1.06))
marker('StreamerRoot',(.98,3.28,-.02))
bpy.context.scene['checkpoint_revision']='pressure-gate-A-2'
bpy.context.scene['orientation']='Local +X bends away from the driving corridor; origin is grounded base.'
bpy.context.scene['animation']='Air* materials flex, Ribbon* flutter, other parts remain fixed.'
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'props/checkpoint.blend'))
print('PRESSURE CHECKPOINT SOURCE SAVED')
