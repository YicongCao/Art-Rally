"""Offline Mandarin co-driver lines. Build-only dependencies: kokoro==0.9.4, misaki[zh]==0.9.4, soundfile.
Model: hexgrad/Kokoro-82M-v1.1-zh (Apache-2.0, permissively supplied Chinese dataset).
Game ships only rendered clips, no runtime model, network or Python dependency.
"""
from pathlib import Path
import json
import numpy as np
import soundfile as sf
import torch
from kokoro import KModel, KPipeline
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/voice'
LINES={'LEFT_MEDIUM':'左三。','RIGHT_MEDIUM':'右三。','LEFT_TIGHT':'左急弯。','RIGHT_TIGHT':'右急弯。','CAUTION_NARROW':'注意收窄，不要切弯。','CUT':'可以小切。','MUD_NARROW':'泥地收窄。','WATER':'前方积水。','ASPHALT':'进入柏油。','GRAVEL':'进入砂石。','CREST_JUMP':'坡顶，准备跳跃。','FINISH':'前方终点。','preview':'准备好了吗？左三，接右三。'}
def main():
    torch.set_num_threads(4)
    model=KModel(repo_id='hexgrad/Kokoro-82M-v1.1-zh').to('cpu').eval()
    pipeline=KPipeline(lang_code='z',repo_id='hexgrad/Kokoro-82M-v1.1-zh',model=model)
    report=[]
    for kind,voice,speed in [('female','zf_001',1.12),('male','zm_010',1.03)]:
        folder=ROOT/kind; folder.mkdir(parents=True,exist_ok=True)
        for code,line in LINES.items():
            audio=np.concatenate([r.audio.numpy() for r in pipeline(line,voice=voice,speed=speed)])
            active=np.where(np.abs(audio)>.008)[0]
            if len(active): audio=audio[max(0,active[0]-480):min(len(audio),active[-1]+1440)]
            audio=audio*.80/max(.1,float(np.max(np.abs(audio))))
            sf.write(folder/(code+'.wav'),audio,24000,subtype='PCM_16')
            report.append(dict(voice=kind,speaker=voice,code=code,text=line,seconds=len(audio)/24000))
            print(kind,code,round(len(audio)/24000,2),flush=True)
    (ROOT/'lines.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__': main()
