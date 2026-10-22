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
    'menu': dict(title='Ignition / Grid Lights', bpm=126, roots=[45,45,41,43,45,48,41,43],
                 melody=[12,15,19,22,19,15,10,7,12,19,24,22,19,15,10,7], pattern=[0,7,12,15,7,12,19,10], program=81, lead=30),
    'autumn': dict(title='Amber Gravel / Garage Rock', genre='garage-rock', bpm=156, roots=[40,40,43,45,40,47,43,38],
                   melody=[12,15,19,24,22,19,15,10,12,19,22,24,19,15,10,7], pattern=[0,12,7,15,0,7,12,19], program=30, lead=81),
    'coast': dict(title='Golden Wake / Electro House', genre='electro-house', bpm=140, roots=[45,48,41,43,45,52,48,43],
                  melody=[12,19,24,27,24,22,19,15,12,15,19,22,24,19,15,10], pattern=[0,7,12,19,15,7,10,12], program=81, lead=80),
    'highland': dict(title='Stone and Thunder / Mountain Drums', genre='cinematic-percussion', bpm=132, roots=[38,38,41,36,38,45,41,36],
                     melody=[12,19,22,24,19,15,12,10,7,12,15,19,22,19,15,10], pattern=[0,12,7,10,0,12,15,7], program=80, lead=30),
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
    for track_index,(name,program,notes) in enumerate(tracks):
        channel=9 if name=='Drums' else track_index
        events=[(0,b'\xff\x03'+vlq(len(name))+name.encode())]
        if name!='Drums': events.append((0,bytes([0xc0+channel,program])))
        for beat,duration,pitch,velocity in notes:
            events.extend([(round(beat*PPQ),bytes([0x90+channel,pitch,velocity])),(min(total_beats*PPQ,round((beat+duration)*PPQ)),bytes([0x80+channel,pitch,0]))])
        events.sort(key=lambda e:(e[0],0 if e[1][0]&0xf0==0x80 else 1))
        data=b''; previous=0
        for tick,event in events: data+=vlq(tick-previous)+event; previous=tick
        data+=vlq(max(0,total_beats*PPQ-previous))+b'\xff\x2f\x00'
        output+=chunk(b'MTrk',data)
    path.write_bytes(output)

def voice(program,pitch,duration):
    t=np.arange(int((duration+.16)*SR))/SR
    hz=440*2**((pitch-69)/12)
    attack=np.minimum(t/.006,1)
    release=np.clip((duration+.16-t)/.16,0,1)
    if program==128:
        noise=np.random.default_rng(pitch*173+len(t)).normal(0,.4,len(t))
        if pitch==36:
            phase=2*np.pi*(47*t+85*.035*(1-np.exp(-t/.035)))
            return np.sin(phase)*np.exp(-t*14)+noise*np.exp(-t*140)*.2
        if pitch==38:
            return (noise*.85+np.sin(2*np.pi*180*t)*.22)*attack*np.exp(-t*22)
        if pitch in [41,45,47]:
            return (np.sin(2*np.pi*(55+(pitch-41)*7)*t)+noise*.17)*attack*np.exp(-t*9)
        high=noise-np.roll(noise,1)
        return high*attack*np.exp(-t*(60 if pitch==42 else 13))*.32
    if program==38:
        raw=np.sin(2*np.pi*hz*t)+.3*np.sin(2*np.pi*hz*2*t)+.12*np.sin(2*np.pi*hz*3*t)
        return np.tanh(raw*1.7)*attack*release*np.exp(-t*2.5)
    if program==10:  # Glassy FM mallets, no piano envelope or samples.
        return np.sin(2*np.pi*hz*t+2.1*np.sin(2*np.pi*hz*3*t)*np.exp(-t*10))*attack*release*np.exp(-t*4)
    if program==48:
        return (np.sin(2*np.pi*hz*t)+.3*np.sin(2*np.pi*hz*1.004*t)+.12*np.sin(2*np.pi*hz*3*t))*np.minimum(t/.12,1)*release*.6
    if program==60:
        return (np.sin(2*np.pi*hz*t)+.44*np.sin(2*np.pi*hz*2*t)+.15*np.sin(2*np.pi*hz*3*t))*np.minimum(t/.07,1)*release*.7
    if program==29:
        return np.tanh((np.sin(2*np.pi*hz*t)+.22*np.sin(2*np.pi*hz*3*t))*1.4)*attack*release*np.exp(-t*3)
    harmonics=range(1,min(15,int(SR*.46/hz))+1)
    raw=sum(np.sin(2*np.pi*hz*k*t)*((1/k) if program!=80 or k%2 else 0) for k in harmonics)
    if program==30:
        raw=np.tanh(raw*2.6)+.18*np.sin(2*np.pi*hz*1.5*t)
    else:
        raw+=.16*np.sin(2*np.pi*hz*1.003*t)
    return raw*attack*release*np.exp(-t*(6 if program==30 else 4))*.65

def compose_motor(config):
    pulse=[]; bass=[]; lead=[]; drums=[]
    for bar in range(16):
        root=config['roots'][(bar//2)%8]
        # Muted eighth-note motor, syncopated bass and a four-bar call/response.
        for i,interval in enumerate(config['pattern']):
            pulse.append((bar*4+i*.5,.22,root+12+interval,66 if i%2 else 83))
            if i in [0,2,3,4,6,7]: bass.append((bar*4+i*.5,.30,root-12+(7 if i==7 else 0),83))
        if bar%4 in [1,2,3]:
            for i in range(4):
                lead.append((bar*4+i+.25,.45,root+12+config['melody'][(bar*3+i)%16],67 if bar<8 else 78))
        for beat in [0,1.5,2,3.5]: drums.append((bar*4+beat,.22,36,100))
        for beat in [1,3]: drums.append((bar*4+beat,.18,38,92))
        for i in range(8): drums.append((bar*4+i*.5,.07,42 if i!=7 else 46,52 if i%2 else 65))
        if bar%4==3:
            for i in [0,.25,.5,.75]: drums.append((bar*4+3+i,.10,38,50+int(i*42)))
        if bar in [0,8]: drums.append((bar*4,.6,49,70))
    return [('Pulse',config['program'],pulse),('Bass',38,bass),('Lead',config['lead'],lead),('Drums',128,drums)]

def compose(config):
    genre=config.get('genre','menu')
    if genre=='menu': return compose_motor(config)
    pulse=[];bass=[];lead=[];drums=[]
    for bar in range(16):
        root=config['roots'][(bar//2)%8]
        if genre=='garage-rock':
            for beat in [0,.75,1.5,2,2.75,3.5]:
                for interval in [0,7,12]: pulse.append((bar*4+beat,.18,root+interval,72))
            for i in range(8): bass.append((bar*4+i*.5,.32,root-12+(12 if i==7 and bar%2 else 0),100 if i%2==0 else 88))
            if bar%4>=2:
                for i in range(4): lead.append((bar*4+i*.75,.42,root+24+[0,3,7,10][i],82))
            for beat in [0,1.5,2,2.75]: drums.append((bar*4+beat,.23,36,108))
            for beat in [1,3]: drums.append((bar*4+beat,.2,38,104))
            for i in range(8): drums.append((bar*4+i*.5,.08,42,72 if i%2==0 else 57))
            if bar%4==3:
                for beat in [3.25,3.75]: drums.append((bar*4+beat,.08,38,72))
        elif genre=='electro-house':
            root=[48,55,53,50][(bar//2)%4]
            for beat in [.5,1.5,2.5,3.5]:
                for interval in [0,4,7,11]: pulse.append((bar*4+beat,.28,root+12+interval,65))
            for i in range(8): bass.append((bar*4+i*.5,.30,root-12+(7 if i==7 else 0),102 if i%2 else 78))
            for i,interval in enumerate([12,19,24,23,19,16,14,19]):
                if bar%4!=3 or i<4: lead.append((bar*4+i*.5,.17,root+interval,65))
            for beat in range(4): drums.append((bar*4+beat,.24,36,105))
            for beat in [1,3]: drums.append((bar*4+beat,.12,38,65))
            for beat in [.5,1.5,2.5,3.5]: drums.append((bar*4+beat,.12,46,65))
        else:
            root=[38,36,41,38][(bar//4)%4]
            for interval in [0,7]: pulse.append((bar*4,3.8,root+12+interval,65))
            for i in range(8): bass.append((bar*4+i*.5,.34,root-12+(12 if i in [3,7] else 0),100 if i%2==0 else 83))
            for beat in range(4): drums.append((bar*4+beat,.24,36,108))
            for beat in [1,3]: drums.append((bar*4+beat,.16,38,80))
            for i in range(8): drums.append((bar*4+i*.5,.07,42,56 if i%2 else 64))
            if bar%4 in [1,3]:
                for i,interval in enumerate([12,19,15]): lead.append((bar*4+i*1.25,.95,root+interval,78))
            for beat,pitch in [(0,41),(.75,45),(1.5,41),(2.5,47),(3,45),(3.5,41)]: drums.append((bar*4+beat,.34,pitch,100 if beat in [0,1.5] else 70))
            if bar%4==3:
                for beat in [2,2.25,2.5,2.75,3,3.25,3.5,3.75]: drums.append((bar*4+beat,.18,45,65+int(beat*7)))
    programs={'garage-rock':(30,29),'electro-house':(10,81),'cinematic-percussion':(48,60)}[genre]
    return [('Pulse',programs[0],pulse),('Bass',38,bass),('Lead',programs[1],lead),('Drums',128,drums)]

def generate():
    ROOT.mkdir(parents=True,exist_ok=True)
    report=[]
    for key,config in SCORES.items():
        tracks=compose(config); beat_seconds=60/config['bpm']; duration=64*beat_seconds; count=round(duration*SR)
        stems={}
        racing=key!='menu'
        gains={'Pulse':.14,'Bass':.40,'Lead':.11,'Drums':.48} if racing else {'Pulse':.18,'Bass':.26,'Lead':.13,'Drums':.38}
        for name,program,notes in tracks:
            stem=np.zeros(count)
            for beat,length,pitch,velocity in notes:
                data=voice(program,pitch,length*beat_seconds)*(velocity/127)*gains[name]
                start=round(beat*beat_seconds*SR)
                np.add.at(stem,(np.arange(len(data))+start)%count,data)
            stems[name]=stem
        if racing:
            # Make room for each kick transient rather than simply turning up
            # the whole mix. Circular envelopes also cover the loop boundary.
            duck=np.ones(count)
            for beat,length,pitch,velocity in tracks[-1][2]:
                if pitch!=36: continue
                start=round(beat*beat_seconds*SR)
                tail=np.arange(round(.13*SR))/SR
                envelope=1-.48*np.exp(-tail/.045)
                indices=(start+np.arange(len(tail)))%count
                duck[indices]=np.minimum(duck[indices],envelope)
            stems['Bass']*=duck
            stems['Pulse']*=duck
        audio=sum(stems.values())
        # Keep the racing rhythm dry and defined; echo only melodic layers.
        dry=(stems['Pulse']+stems['Lead']) if racing else audio.copy()
        for delay,gain in [(beat_seconds*.75,.10),(beat_seconds*1.5,.055)]: audio+=np.roll(dry,round(delay*SR))*gain
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
        report.append(dict(theme=key,title=config['title'],genre=config.get('genre','synth-rock'),bpm=config['bpm'],bars=16,seconds=duration,notes=sum(len(t[2]) for t in tracks),peak=float(np.max(np.abs(audio))),rms=float(np.sqrt(np.mean(audio**2))),seam_jump=float(abs(audio[0]-audio[-1]))))
    (ROOT/'scores.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__': generate()
