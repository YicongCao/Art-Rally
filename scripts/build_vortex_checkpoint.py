"""Blender source for the vortex wind marker; exports through export_screenprint.py.
Run Blender -b --python scripts/build_vortex_checkpoint.py -- --replace-checkpoint.
The previous pressure-gate generator remains available as an archived design.
"""
import bpy,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
if '--replace-checkpoint' not in sys.argv:raise RuntimeError('Explicit --replace-checkpoint required')
legacy=(ROOT/'scripts/build_pressure_checkpoint.py').read_text()
exec(legacy.split('# Sewn pressure tube')[0])
COLORS.update(VortexOrange='eb5c2d',VortexIvory='efe1bb',VortexTeal='327983',VortexGold='e9b453',StaticIvory='eee3c7',StaticInk='26363c')
box('WeightedFoot',(0,.045,0),(1.1,.13,1.02),'MachineDark',.035)
box('AirPlenum',(0,.24,0),(.88,.40,.82),'MachineTeal',.10)
for side in [-1,1]:ellipsoid('Sandbag',(side*.35,.10,.55),(.26,.115,.20),'Sandbag')
cylinder('Mast',(0,1.83,0),.055,3.24,'MachineSteel',12)
cylinder('BaseCollar',(0,.60,0),.22,.35,'StaticInk',16)
# Three broad twisted scoops: a readable wind-driven helix rather than a floppy tube.
for blade in range(3):
 vv=[];ff=[];n=40
 for i in range(n+1):
  t=i/n;angle=t*math.pi*1.7+blade*math.tau/3
  radius=.36+.10*math.sin(t*math.pi)
  for edge in [-1,1]:
   a=angle+edge*.47
   vv.append((radius*math.cos(a),.80+t*2.45,radius*math.sin(a)))
 for i in range(n):ff.append((i*2,i*2+1,i*2+3,i*2+2))
 o=mesh('HelicalSail',vv,ff,['VortexOrange','VortexIvory','VortexTeal'][blade])
 m=o.modifiers.new('Woven sail edge','SOLIDIFY');m.thickness=.025
 for f in o.data.polygons:f.use_smooth=True
# A small cap, ball bearings and open rotating crown reveal the vortex axis.
for y in [.77,3.27]:cylinder('Bearing',(0,y,0),.13,.10,'MachineSteel',16)
ellipsoid('Crown',(0,3.43,0),(.17,.17,.17),'VortexGold')
for blade in range(3):
 a=blade*math.tau/3
 mesh('CrownFin',[(0,3.34,0),(.42*math.cos(a),3.31,.42*math.sin(a)),(.48*math.cos(a+.6),3.50,.48*math.sin(a+.6)),(.1*math.cos(a+.9),3.48,.1*math.sin(a+.9))],[(0,1,2,3)],'VortexOrange')
# Checker drum is fixed: rotation remains clear against its visual reference.
for ring in range(2):
 for j in range(12):
  a=j*math.tau/12;b=(j+1)*math.tau/12;y=.44+ring*.12
  mesh('CheckerDrum',[(.24*math.cos(a),y,.24*math.sin(a)),(.24*math.cos(b),y,.24*math.sin(b)),(.24*math.cos(b),y+.12,.24*math.sin(b)),(.24*math.cos(a),y+.12,.24*math.sin(a))],[(0,1,2,3)],'StaticInk' if (j+ring)%2 else 'StaticIvory')
# Reuse the already authored blower, grille and connected hose.
exec(legacy.split('# Centrifugal blower')[1].split('\n',1)[1].split("marker('StreamerRoot'")[0])
bpy.context.scene['checkpoint_revision']='vortex-wind-marker-1'
bpy.context.scene['orientation']='Local Y is the fixed rotation axis. Foot origin rests on the shoulder.'
bpy.context.scene['animation']='Vortex* rotates about Y; FanRotor* spins about Z; mast and plenum stay fixed.'
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'props/checkpoint.blend'))
