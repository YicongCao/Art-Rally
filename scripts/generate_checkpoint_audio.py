"""Original periodic blower motor/air loop; no external samples or runtime synthesis."""
from pathlib import Path
import math, random, struct, wave
root=Path(__file__).resolve().parents[1]
rng=random.Random(9047);rate=22050;seconds=4
# Exact quarter-Hz frequencies make all components periodic over four seconds.
components=[(f,rng.random()*math.tau,.012) for f in range(113,1900,43)]
frames=bytearray()
for i in range(rate*seconds):
 t=i/rate
 motor=.18*math.sin(math.tau*72*t)+.065*math.sin(math.tau*144*t)
 air=sum(amplitude*math.sin(math.tau*f*t+phase) for f,phase,amplitude in components)
 value=(motor+air)*(.92+.08*math.sin(math.tau*.5*t))
 frames+=struct.pack('<h',int(max(-.8,min(.8,value))*32767))
path=root/'assets/audio/first_playable/checkpoint_blower.wav'
with wave.open(str(path),'wb') as audio:
 audio.setnchannels(1);audio.setsampwidth(2);audio.setframerate(rate);audio.writeframes(frames)
print('Generated',path)
