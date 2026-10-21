"""Original synthesized expansion engine / EV loops; no sampled commercial audio."""
from pathlib import Path
import math,random,wave,array
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/first_playable'
SR=22050
rng=random.Random(86204)
for car,base,harm in [('I20',100,[1,.3,.4,.18,.22]),('DELTA',100,[1,.55,.28,.38,.1]),('EVO6',100,[1,.36,.47,.3,.15]),('WRX',50,[1,.75,.3,.55,.1,.25]),('P7',180,[1,.2,.08])]:
 for layer,gain in [('idle',.25),('low',.5),('mid',.75),('high',1),('lift',.2)]:
  samples=[];noise=0
  white=[rng.uniform(-1,1) for _ in range(SR*2)]
  # Warm the filter with one identical period, giving periodic noise state.
  # All tonal and modulation frequencies also complete integer cycles in 2 s.
  for value in white: noise=.85*noise+.15*value
  for i in range(SR*2):
   t=i/SR;noise=.85*noise+.15*white[i]
   if car=='P7':
    v=(math.sin(math.tau*base*t)*.14+math.sin(math.tau*base*4*t)*.06+math.sin(math.tau*base*8*t)*.022)*gain
    if layer=='idle':v=0
   else:
    phase=t+.0004*math.sin(math.tau*25*t)
    v=sum(a*math.sin(math.tau*base*(k+1)*phase)*gain**(k*.25) for k,a in enumerate(harm))*.24+noise*.08*gain
    v=math.tanh(v*1.6)*.6
   samples.append(v)
  pcm=array.array('h',(int(max(-.95,min(.95,v))*32767) for v in samples))
  with wave.open(str(ROOT/(car+'_'+layer+'.wav')),'wb') as f:
   f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(pcm.tobytes())
