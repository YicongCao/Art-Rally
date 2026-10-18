"""Original deterministic offline sound library. Python stdlib, no samples or third-party rights.
Engine pulse trains use different harmonic/combustion profiles per car, at a 3000 RPM reference.
Noise loops are crossfaded at the seam; musical loop uses an exact 8-bar grid.
"""
from pathlib import Path
import wave, math, random, array
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/first_playable'
ROOT.mkdir(parents=True,exist_ok=True)
SR=22050; TAU=math.tau
rng=random.Random(1944)
def save(name,v,loop=False):
    if loop:
        n=min(1102,len(v)//10)
        # Overlap tail into head, then remove tail; equal endpoints and continuous transitions.
        for i in range(n):v[i]=v[-n+i]*(1-i/n)+v[i]*(i/n)
        v=v[:-n]
    peak=max(abs(x) for x in v) or 1
    scale=.74/max(1,peak)
    pcm=array.array('h',(int(max(-.97,min(.97,x*scale))*32767) for x in v))
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(pcm.tobytes())
def tone(f,t):return math.sin(TAU*f*t)
for car,base,harm in [('F160',100,[1,.45,.13,.21,.07]),('R200',75,[1,.62,.4,.25,.2,.1]),('A240',100,[1,.28,.50,.13,.27,.06,.12])]:
    for layer in ['idle','low','mid','high','lift']:
        values=[];filt=0
        for i in range(SR*2+1102):
            t=i/SR;filt=.8*filt+.2*rng.uniform(-1,1)
            weights={'idle':.35,'low':.6,'mid':.85,'high':1.1,'lift':.22}
            v=sum(a*tone(base*(k+1),t+.0004*tone(25,t))*(weights[layer]**(k*.35)) for k,a in enumerate(harm))*.35
            v+=filt*({'idle':.05,'low':.10,'mid':.17,'high':.22,'lift':.08}[layer])
            if car=='A240':v+=tone(1350,t)*.035*(1 if layer=='high' else .2)
            values.append(math.tanh(v*1.6)*.65)
        save(car+'_'+layer,values,True)
for kind in ['forest','coast','highland']:
    values=[];filt=0;slow=0
    for i in range(SR*12+1102):
        t=i/SR;n=rng.uniform(-1,1);filt=.94*filt+.06*n;slow=.997*slow+.003*n
        v=filt*(.4+.2*tone(.25,t))+slow*.5
        if kind=='coast':v+=n*.08*(.5+.5*tone(.125,t))
        if kind=='forest':
            bird=(t%4);v+=tone(1800+400*tone(5,t),t)*math.exp(-bird*8)*.14 if bird<.7 else 0
        if kind=='highland':v+=n*.035+tone(85,t)*.025
        values.append(v*2)
    save(kind,values,True)
for name,notes in {'ui':[660],'start':[392,523,784],'note':[660,880],'warning':[330,330,440],'finish':[392,494,587,784],'medal':[523,659,784,1046],'record':[523,784,1046,1318],'shift':[120],'brake':[1150],'collision':[65]}.items():
    values=[]
    for i in range(int(SR*len(notes)*.14)):
        t=i/SR;j=min(len(notes)-1,int(t/.14));local=t% .14;env=min(local/.004,1)*math.exp(-local*22)
        v=(tone(notes[j],t)+.17*tone(notes[j]*2,t))*.38*env
        if name in ['shift','collision','brake']:v=(rng.uniform(-1,1)*.35+tone(notes[j],t)*.5)*env
        values.append(v)
    save(name,values)
# Eight bars at 100 BPM: restrained pentatonic electric-piano/plucked arrangement.
values=[];duration=19.2
for i in range(int(SR*duration)):
    t=i/SR;beat=int(t/.6);sub=int(t/.3);local=t% .3;chord=(beat//4)%4
    roots=[130.8128,174.6141,146.8324,195.9977];root=roots[chord]
    notes=[1,1.5,2,2.5,3,2.5,2,1.5];f=root*notes[sub%8]
    v=(tone(f,t)+.24*tone(f*2,t)+.09*tone(f*3,t))*.13*math.exp(-local*9)*min(local/.008,1)
    basslocal=t%2.4;v+=tone(root/2,t)*.14*math.exp(-basslocal*1.8)*min(basslocal/.015,1)
    v+=rng.uniform(-1,1)*.018*math.exp(-(t%.6)*45)
    values.append(v)
save('menu_music',values)
print('Generated',len(list(ROOT.glob('*.wav'))),'original WAV assets')
