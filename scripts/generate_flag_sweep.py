"""Original short cloth snap + air sweep at the chequered transition's midpoint."""
from pathlib import Path
import array, math, random, wave
sr=22050
rng=random.Random(9303)
values=[]
low=0
for i in range(round(sr*.32)):
    t=i/sr
    noise=rng.uniform(-1,1)
    low=.87*low+.13*noise
    attack=min(t/.008,1)
    cloth=(noise-low)*.20*math.exp(-t*34)+low*1.1*math.exp(-t*11)
    thump=math.sin(math.tau*(110*t-85*t*t))*.24*math.exp(-t*30)
    values.append(int((cloth+thump)*attack*min((.32-t)/.035,1)*32767))
path=Path(__file__).resolve().parents[1]/'assets/audio/first_playable/flag_sweep.wav'
with wave.open(str(path),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes(array.array('h',values).tobytes())
