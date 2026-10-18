"""Original deterministic rotor, rushing river and hoof loops; no external samples."""
from pathlib import Path
import wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/first_playable'
SR=22050
rng=np.random.default_rng(88417)
for kind,seconds in [('helicopter',4),('river',8),('hooves',.8)]:
    t=np.arange(round(seconds*SR))/SR
    noise=rng.normal(0,1,len(t))
    low=np.convolve(noise,np.ones(18)/18,'same')
    if kind=='helicopter':
        pulse=(.5+.5*np.sin(2*np.pi*18*t))**4
        data=(.28*np.sin(2*np.pi*72*t)+.14*np.sin(2*np.pi*144*t)+low*.7)*(.35+pulse)+noise*.025
    elif kind=='river':
        data=low*.52+noise*.09
        for f in [430,670,960]: data+=.025*np.sin(2*np.pi*f*t+2*np.sin(2*np.pi*.5*t))*(.5+.5*np.sin(2*np.pi*1.25*t))
    else:
        data=np.zeros(len(t))
        for start in [0,.17,.4,.57]:
            age=(t-start)%seconds
            data+=(.3*np.sin(2*np.pi*160*age)*np.exp(-age*46)+noise*.25*np.exp(-age*75))*np.minimum(age/.002,1)
    n=min(440,len(data)//20)
    data[:n]=data[-n:]*(1-np.arange(n)/n)+data[:n]*np.arange(n)/n
    data=data[:-n]
    data*=.78/max(.1,np.max(np.abs(data)))
    with wave.open(str(ROOT/(kind+'.wav')),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(SR);out.writeframes((data*32767).astype('<i2').tobytes())
