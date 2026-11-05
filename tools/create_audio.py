"""Original synthesised sounds, encoded to MP3; no external audio assets."""
import pathlib,sys,math,struct
ROOT=pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'.tools/pylibs'))
import lameenc
RATE=22050
out=ROOT/'assets/audio';out.mkdir(exist_ok=True)
def encode(name,seconds,fn):
    samples=[]
    for i in range(int(seconds*RATE)):
        value=max(-1,min(1,fn(i/RATE)))
        samples.append(struct.pack('<h',int(value*16000)))
    encoder=lameenc.Encoder();encoder.set_bit_rate(48);encoder.set_in_sample_rate(RATE)
    encoder.set_channels(1);encoder.set_quality(2)
    (out/(name+'.mp3')).write_bytes(encoder.encode(b''.join(samples))+encoder.flush())
def tone(t,f,duration):
    return math.sin(math.tau*f*t)*max(0,1-t/duration)**2
encode('coin',.18,lambda t:tone(t,1046 if t<.07 else 1568,.18)*.6)
encode('jump',.22,lambda t:tone(t,330+t*1400,.22)*.22)
encode('boost',.42,lambda t:(tone(t,400+t*2200,.42)+tone(t,600+t*1100,.42))*.3)
encode('hit',.2,lambda t:tone(t,110-t*260,.2)*.35)
notes=[523.25,659.25,783.99,1046.5]
encode('finish',1.05,lambda t:tone(t% .24,notes[min(3,int(t/.24))],.30)*.5)
def music(t):
    step=.375;index=int(t/step);phase=t%step
    melody=[659,0,784,0,880,784,659,0,523,0,659,784,587,0,523,0]
    hz=melody[index%len(melody)]
    bass=[130.81,164.81,174.61,146.83][int(t/1.5)%4]
    return (tone(phase,hz,.27)*.23 if hz else 0)+tone(t%1.5,bass,1.5)*.15
encode('city_loop',12,music)
print('AUDIO_BUILD_OK',sum(p.stat().st_size for p in out.glob('*.mp3')))
