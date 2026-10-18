"""Art Rally original four-theme score. Generates editable type-1 MIDI and offline PCM.
Requires numpy for synthesis; MIDI uses only Python stdlib. No samples/soundfonts.
Run: python scripts/generate_music.py
"""
from pathlib import Path
import json, math, struct, wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/music'
SR, PPQ = 22050, 480
SCORES = {
    'menu': dict(title='Long Way Home', bpm=84, roots=[50,55,57,54,50,59,55,57],
                 melody=[2,6,9,14,9,6,4,2,0,4,7,11,7,4,2,0], pattern=[0,7,14,9,7,14,16,9], program=24, lead=11, mood='guitar'),
    'autumn': dict(title='Amber Switchbacks', bpm=112, roots=[45,50,52,45,54,50,47,52],
                   melody=[12,16,19,16,14,9,7,9,12,14,19,21,19,16,14,7], pattern=[0,12,7,16,0,7,12,19], program=10, lead=24, mood='mallet'),
    'coast': dict(title='Sails in the Sun', bpm=120, roots=[52,57,54,59,56,57,52,59],
                  melody=[7,11,14,16,14,11,9,4,7,9,11,19,16,14,11,9], pattern=[0,7,11,14,7,16,11,14], program=4, lead=11, mood='piano'),
    'highland': dict(title='Above the Morning Mist', bpm=76, roots=[50,53,48,55,50,57,53,55],
                     melody=[0,7,10,14,17,14,10,7,5,12,15,19,17,12,10,5], pattern=[0,7,10,14,0,7,17,14], program=88, lead=73, mood='pad'),
}

def vlq(n):
    out=[n & 127]; n >>= 7
    while n: out.insert(0,(n & 127)|128); n >>= 7
    return bytes(out)

def chunk(kind,data): return kind + struct.pack('>I',len(data)) + data

def midi(path, config, tracks, total_beats):
    tempo=int(60_000_000/config['bpm'])
    conductor=b'\x00\xff\x51\x03'+tempo.to_bytes(3,'big')+b'\x00\xff\x58\x04\x04\x02\x18\x08'+vlq(total_beats*PPQ)+b'\xff\x2f\x00'
    output=chunk(b'MThd',struct.pack('>HHH',1,len(tracks)+1,PPQ))+chunk(b'MTrk',conductor)
    for channel,(name,program,notes) in enumerate(tracks):
        events=[(0,b'\xff\x03'+vlq(len(name))+name.encode()),(0,bytes([0xc0+channel,program]))]
        for beat,duration,pitch,velocity in notes:
            events.extend([(round(beat*PPQ),bytes([0x90+channel,pitch,velocity])),(min(total_beats*PPQ,round((beat+duration)*PPQ)),bytes([0x80+channel,pitch,0]))])
        events.sort(key=lambda e:(e[0],0 if e[1][0]&0xf0==0x80 else 1))
        data=b''; previous=0
        for tick,event in events: data+=vlq(tick-previous)+event; previous=tick
        data+=vlq(max(0,total_beats*PPQ-previous))+b'\xff\x2f\x00'
        output+=chunk(b'MTrk',data)
    path.write_bytes(output)

def voice(program,pitch,duration):
    t=np.arange(int((duration+.5)*SR))/SR
    hz=440*2**((pitch-69)/12)
    attack=np.minimum(t/(.04 if program in [88,73] else .009),1)
    release=np.clip((duration+.5-t)/.5,0,1)
    if program==88:
        raw=np.sin(2*np.pi*hz*t)+.23*np.sin(2*np.pi*hz*2.002*t)+.14*np.sin(2*np.pi*hz*.998*t)
        env=attack*release*np.exp(-t*.4)
    elif program==73:
        raw=np.sin(2*np.pi*hz*t+np.sin(t*31)*.018)+.08*np.sin(2*np.pi*hz*2*t)
        env=attack*release*np.exp(-t*.5)
    elif program==32:
        raw=np.sin(2*np.pi*hz*t)+.18*np.sin(2*np.pi*hz*2*t)
        env=attack*np.exp(-t*3)*release
    elif program==24:
        raw=sum(a*np.sin(2*np.pi*hz*(i+1)*t) for i,a in enumerate([1,.38,.16,.08]))
        env=attack*np.exp(-t*5)*release
    else:
        raw=np.sin(2*np.pi*hz*t)+.24*np.sin(2*np.pi*hz*2*t)*np.exp(-t*5)+.10*np.sin(2*np.pi*hz*3.99*t)*np.exp(-t*8)
        env=attack*np.exp(-t*(3.5 if program==10 else 2.2))*release
    return raw*env

def compose(config):
    arp=[]; bass=[]; melody=[]; pad=[]
    for bar in range(16):
        root=config['roots'][(bar//2)%8]
        for i,interval in enumerate(config['pattern']):
            # The highland theme leaves longer gaps; coast uses light syncopation.
            if config['mood']=='pad' and i%2: continue
            beat=bar*4+i*.5+(.15 if config['mood']=='piano' and i%2 else 0)
            arp.append((beat,.38 if config['mood']!='pad' else .85,root+12+interval,48 if config['mood']=='pad' else 64))
        bass.extend([(bar*4,1.4,root-12,68),(bar*4+2.5,.8,root-5,50)])
        for i in range(2 if config['mood']=='pad' else 4):
            interval=config['melody'][(bar*3+i)%len(config['melody'])]
            beat=bar*4+i*(2 if config['mood']=='pad' else 1)+(.5 if bar%2 and config['mood']=='piano' else 0)
            if beat<64: melody.append((beat,1.5 if config['mood']=='pad' else .65,root+12+interval,60))
        if bar%2==0:
            for offset in [0,7,14 if config['mood']!='pad' else 10]: pad.append((bar*4,5.8,root+offset,34))
    return [('Arpeggio',config['program'],arp),('Bass',32,bass),('Melody',config['lead'],melody),('Air',88,pad)]

def generate():
    ROOT.mkdir(parents=True,exist_ok=True)
    report=[]
    for key,config in SCORES.items():
        tracks=compose(config); beat_seconds=60/config['bpm']; duration=64*beat_seconds; count=round(duration*SR)
        audio=np.zeros(count)
        for name,program,notes in tracks:
            for beat,length,pitch,velocity in notes:
                data=voice(program,pitch,length*beat_seconds)*(velocity/127)*(.13 if name=='Air' else .18)
                start=round(beat*beat_seconds*SR)
                np.add.at(audio,(np.arange(len(data))+start)%count,data)
        # Circular delays preserve the score's exact loop and keep the reverb tail at the start.
        dry=audio.copy()
        for delay,gain in [(.143,.14),(.289,.10),(.431,.06)]: audio+=np.roll(dry,round(delay*SR))*gain
        audio=np.tanh(audio*1.4)
        audio*=.70/max(.7,np.max(np.abs(audio)))
        # A 2ms endpoint taper removes sub-sample phase jumps without shortening the MIDI grid.
        edge=round(.002*SR)
        audio[:edge]*=np.linspace(0,1,edge)
        audio[-edge:]*=np.linspace(1,0,edge)
        pcm=(np.clip(audio,-1,1)*32767).astype('<i2')
        with wave.open(str(ROOT/f'theme_{key}.wav'),'wb') as f:
            f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(pcm.tobytes())
        midi(ROOT/f'theme_{key}.mid',config,tracks,64)
        report.append(dict(theme=key,title=config['title'],bpm=config['bpm'],bars=16,seconds=duration,notes=sum(len(t[2]) for t in tracks),peak=float(np.max(np.abs(audio))),rms=float(np.sqrt(np.mean(audio**2))),seam_jump=float(abs(audio[0]-audio[-1]))))
    (ROOT/'scores.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__': generate()
