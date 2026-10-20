"""Create visible shoulder pivots for finish-line cheering and flag waving."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
exec((ROOT/'scripts/build_brushline_assets.py').read_text().split('# Refine tails')[0])
for kind in ['marshal','spectator']:
 reset();person(kind);finish(kind)
