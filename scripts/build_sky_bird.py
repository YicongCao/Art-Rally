"""Original stylized long-wing bird, Blender source with independent wing pivots."""
import bpy, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
exec((ROOT/'scripts/build_brushline_assets.py').read_text().split('# Refine tails')[0])
bpy.ops.wm.read_factory_settings(use_empty=True)
COLORS.update(BirdIvory='e9dfc1',BirdSlate='344954',BirdWing='64787b',BirdBeak='c98d4c')
ellipsoid('Body',(0,0,0),(.13,.14,.36),'BirdIvory')
ellipsoid('Neck',(0,.065,-.30),(.09,.11,.21),'BirdIvory')
ellipsoid('Head',(0,.12,-.48),(.105,.10,.13),'BirdIvory')
mesh('Beak',[(-.055,.10,-.56),(.055,.10,-.56),(0,.12,-.79),(0,.18,-.56)],[(0,1,2),(1,3,2),(3,0,2),(0,3,1)],'BirdBeak')
mesh('Tail',[(-.10,0,.23),(.10,0,.23),(.24,.015,.60),(0,.04,.50),(-.24,.015,.60)],[(0,1,3),(1,2,3),(0,3,4)],'BirdSlate')
for side in [-1,1]:
 before=set(bpy.data.objects)
 # A swept tapered wing, slight thickness and just three feather lobes.
 v=[(side*.08,0,-.12),(side*.42,.045,-.20),(side*.90,.035,-.06),(side*1.17,-.005,.34),(side*.91,0,.24),(side*.78,0,.33),(side*.67,.015,.24),(side*.40,.015,.26),(side*.08,0,.18)]
 wing=mesh('FlightWing',v,[(0,1,7),(0,7,8),(1,2,7),(2,6,7),(2,3,4),(2,4,5),(2,5,6)],'BirdIvory')
 solid=wing.modifiers.new('Soft wing thickness','SOLIDIFY');solid.thickness=.016
 mesh('DarkWingTips',[(side*.90,.04,-.06),(side*1.17,0,.34),(side*.91,.005,.24),(side*.78,.005,.33),(side*.67,.02,.24)],[(0,1,2),(0,2,3),(0,3,4)],'BirdSlate')
 pivot=bpy.data.objects.new('WingLeft' if side<0 else 'WingRight',None);bpy.context.collection.objects.link(pivot)
 for o in set(bpy.data.objects)-before-{pivot}:parent_keep(o,pivot)
bpy.context.scene['brushline_revision']='sky-bird-1'
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'props/sky_bird.blend'))
