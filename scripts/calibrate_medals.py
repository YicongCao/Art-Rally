"""Freeze medal baselines from three distinct clean HUMAN runs per current challenge.
This checks recorded metadata; the release owner must also verify that the runs were skilled human play.
Usage: python3 scripts/calibrate_medals.py --profile /path/to/player/profile.json --version time-trial-2 --output /tmp/proposed-targets.json
Inspect the output before replacing resources/content/challenge_targets.json. This script never edits a player profile.
"""
import argparse,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def propose(profile,current,version):
    if not version or version==current['rules_version']:raise ValueError('Use a new rules version to isolate old medals and ghosts')
    if profile.get('version')!=1:raise ValueError('Unsupported player profile version')
    output={'rules_version':version,'challenges':{}}
    for pair,target in current['challenges'].items():
        stage,vehicle=pair.split('/')
        key=f"{stage}@{target['stage_version']}|{vehicle}@{target['vehicle_revision']}|{current['rules_version']}"
        runs=profile.get('challenges',{}).get(key,{}).get('recent',[])
        clean={}
        for run in runs:
            if run.get('source') not in ['human_keyboard','human_gamepad'] or run.get('practice',False):continue
            if run.get('penalty',-1)!=0 or run.get('reset_count',-1)!=0:continue
            elapsed=run.get('elapsed',0);timestamp=run.get('recorded_at',0)
            if not isinstance(elapsed,(int,float)) or not math.isfinite(elapsed) or elapsed<=0 or timestamp<=0:continue
            if abs(elapsed-run.get('total_time',-1))>.01:continue
            clean[timestamp]=elapsed
        if len(clean)<3:raise ValueError(f'{pair}: only {len(clean)} distinct clean human runs; 3 required')
        item=dict(target,reference_seconds=min(clean.values()),human_calibrated=True)
        item['baseline_run_count']=len(clean)
        item['baseline_recorded_at']=sorted(clean)
        output['challenges'][pair]=item
    return output
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile',required=True,type=Path);parser.add_argument('--version',required=True);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    if args.output.resolve()==args.profile.resolve():parser.error('Output must not replace the player profile')
    try:
        result=propose(json.loads(args.profile.read_text()),json.loads((ROOT/'resources/content/challenge_targets.json').read_text()),args.version)
    except (ValueError,KeyError,OSError) as error:parser.error(str(error))
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('Wrote proposed frozen targets:',args.output)
