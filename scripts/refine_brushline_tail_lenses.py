"""Small authored-source fix: leave the dark surround visible around a lit lens."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
# Use the same metre/axis helpers as the authoritative Brushline authoring pass.
exec((ROOT/'scripts/build_brushline_assets.py').read_text().split('# Refine tails')[0])
for ident in ['F160','R200','A240']:
 path=OUT/'vehicles'/f'{ident}.blend';bpy.ops.wm.open_mainfile(filepath=str(path))
 for o in list(bpy.data.objects):
  if 'BrakeLampLensPanel' in o.name:bpy.data.objects.remove(o,do_unlink=True)
 end=-bpy.data.objects['PlateRear'].location.y-.095
 half={'F160':1.76,'R200':1.78,'A240':1.86}[ident]/2
 for side in [-1,1]:box('BrushlineDetail_BrakeLampLensPanel',(side*(half-.24),.18,end+.09),(.36,.13,.015),'red',.015)
 bpy.ops.wm.save_as_mainfile(filepath=str(path))
print('TAIL LENSES SAVED')
