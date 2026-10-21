"""Trim only unused tails; retain original physical preroll and 60 Hz samples."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[2]
manifest = json.loads((root/'resources/showcase/film.json').read_text())
for key, path in manifest['clips'].items():
    file = root/path.removeprefix('res://')
    clip = json.loads(file.read_text())
    end = max(s['source_in'] + s['duration'] for s in manifest['shots'] if s['clip'] == key) + .25
    clip.setdefault('provenance', {'original_duration':clip['recording']['duration'], 'original_road_clear':clip.get('road_clear'), 'original_max_lateral':clip['max_lateral'], 'note':'Only unused tail removed. Preroll and every physical sample retained; no pose edits.'})
    clip['recording']['frames'] = [f for f in clip['recording']['frames'] if f[0] <= end+.00001]
    clip['telemetry'] = [f for f in clip['telemetry'] if f[0] <= end+.00001]
    clip['recording']['duration'] = clip['recording']['frames'][-1][0]
    clip['max_lateral'] = max(abs(f[9]) for f in clip['telemetry'])
    # A geometric check against the actual course is performed by showcase_test.gd.
    clip.pop('road_clear', None)
    clip['validation_scope'] = 'Road-only physical recording; full-scene collision sweep is validated separately.'
    file.write_text(json.dumps(clip,separators=(',',':'))+'\n')
