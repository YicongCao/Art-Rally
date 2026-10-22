"""Offline Mandarin co-driver lines. Build-only dependencies: kokoro==0.9.4, misaki[zh]==0.9.4, soundfile.
Model: hexgrad/Kokoro-82M-v1.1-zh (Apache-2.0, permissively supplied Chinese dataset).
Game ships only rendered clips, no runtime model, network or Python dependency.
"""
from pathlib import Path
import json
import argparse
import numpy as np
import soundfile as sf
import torch
from kokoro import KModel, KPipeline
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/voice'
LINES={'SAND':'进入沙地。','LOGS':'圆木障碍，不要切弯。','ROCKFALL':'注意落石。','LEFT_MEDIUM':'左三。','RIGHT_MEDIUM':'右三。','LEFT_TIGHT':'左急弯。','RIGHT_TIGHT':'右急弯。','CAUTION_NARROW':'注意收窄，不要切弯。','CUT':'可以小切。','MUD_NARROW':'泥地收窄。','WATER':'前方积水。','ASPHALT':'进入柏油。','GRAVEL':'进入砂石。','CREST_JUMP':'坡顶，准备跳跃。','FINISH':'前方终点。','preview':'准备好了吗？左三，接右三。'}
GRADE_LINES={f'{side}_{grade}':f'{word}{"一二三四五六"[grade-1]}。' for side,word in [('LEFT','左'),('RIGHT','右')] for grade in range(1,7)}
LINES.update(GRADE_LINES)
def main():
    parser=argparse.ArgumentParser()
    selection=parser.add_mutually_exclusive_group()
    selection.add_argument("--only", choices=list(LINES))
    selection.add_argument("--grades", action="store_true")
    args=parser.parse_args()
    torch.set_num_threads(4)
    model=KModel(repo_id='hexgrad/Kokoro-82M-v1.1-zh').to('cpu').eval()
    pipeline=KPipeline(lang_code='z',repo_id='hexgrad/Kokoro-82M-v1.1-zh',model=model)
    selected=set(GRADE_LINES) if args.grades else ({args.only} if args.only else set(LINES))
    report=json.loads((ROOT/"lines.json").read_text()) if args.only or args.grades else []
    report=[entry for entry in report if entry["code"] not in selected]
    for kind,voice,speed in [('female','zf_001',1.12),('male','zm_010',1.03)]:
        folder=ROOT/kind; folder.mkdir(parents=True,exist_ok=True)
        for code,line in LINES.items():
            if code not in selected: continue
            audio=np.concatenate([r.audio.numpy() for r in pipeline(line,voice=voice,speed=speed)])
            active=np.where(np.abs(audio)>.008)[0]
            if len(active): audio=audio[max(0,active[0]-480):min(len(audio),active[-1]+1440)]
            audio=audio*.80/max(.1,float(np.max(np.abs(audio))))
            sf.write(folder/(code+'.wav'),audio,24000,subtype='PCM_16')
            report.append(dict(voice=kind,speaker=voice,code=code,text=line,seconds=len(audio)/24000))
            print(kind,code,round(len(audio)/24000,2),flush=True)
    (ROOT/'lines.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__': main()
