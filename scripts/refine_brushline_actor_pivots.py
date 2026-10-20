"""Preserve world transforms when attaching authored limbs to animation pivots."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'scripts/build_brushline_assets.py').read_text()
exec(source.split('# Refine tails')[0])
start=source.index("for kind in ['reindeer'")
end=source.index("reset()\n# Service point",start)
exec(source[start:end])
