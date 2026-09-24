"""Render the approved original funk and game sounds for web/iOS builds.

No downloads, samples, packages or audio encoders required. Assets are cached
by the hash of both synthesis scripts. Music is rendered at each tempo so the
pitch never changes. Run automatically by bootstrap_platforms.py.
"""
from array import array
import hashlib
from math import exp, pi, sin
from pathlib import Path
import sys
import wave
import compose_funk_preview as synth

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'audio' / 'funk'
synth.RATE = 22050
RATE = synth.RATE
Mix = synth.Mix


def save(mix, name):
    # Mono keeps the full adaptive soundtrack small enough for mobile data.
    peak = max(abs((a+b)*.5) for a, b in zip(mix.left, mix.right))
    gain = .82 / max(.01, peak)
    pcm = array('h')
    for i, (a, b) in enumerate(zip(mix.left, mix.right)):
        edge = min(1, i/(RATE*.008), (len(mix.left)-1-i)/(RATE*.012))
        pcm.append(round((a+b)*.5*gain*edge*32767))
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(OUT / (name+'.wav')), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    print('Audio:', name, flush=True)


def music(bpm, chase):
    beat = 60 / bpm
    mix = Mix(24*4*beat)
    chords = [(57,60,64,67), (62,65,69,72), (55,59,62,65), (60,64,67,71)]
    roots = [33,38,31,36]
    for bar in range(24):
        t = bar*4*beat
        chord, root = chords[bar%4], roots[bar%4]
        for pos in [0, 1.75, 2.5, 3.5]:
            mix.note(t+pos*beat, .3, 'kick', volume=.61)
        for pos in [1,3]:
            mix.note(t+pos*beat+.009, .24, 'snare', volume=.35)
        for step in range(8):
            pos = step*.5 + (.025 if step%2 else 0)
            mix.note(t+pos*beat, .11, 'hat', volume=.12 if step%2 else .075)
        if chase or bar%8 >= 6:
            for pos in [.75,2.75,3.75]:
                mix.note(t+pos*beat,.1,'hat',volume=.10)
        for pos,interval,dur in [(0,0,.65),(.75,12,.22),(1.5,0,.30),(2.25,7,.27),(2.75,10,.22),(3.25,12,.35),(3.75,7,.18)]:
            mix.note(t+pos*beat,dur*beat,'bass',root+interval,.48)
        for pos in [.5,1.25,2.5,3.25]:
            for n in chord:
                mix.note(t+pos*beat,.17,'clav',n+12,.065)
        for pos in [0,2.75]:
            for n in chord:
                mix.note(t+pos*beat,.48,'keys',n,.055)
        if bar%2 and bar%8 >= 2:
            for pos,n in [(1.75,chord[2]+12),(2.5,chord[1]+12),(3.5,chord[0]+12)]:
                mix.note(t+pos*beat,.19,'brass',n,.12)
        if chase:
            for pos in [0,1.5,2.75]:
                mix.note(t+pos*beat,.16,'clav',root+24,.10)
        elif bar%8 == 7:
            for pos in [3.25,3.5,3.75]:
                mix.note(t+pos*beat,.11,'snare',volume=.10)
    save(mix, f'{"chase" if chase else "ride"}_{bpm}')


def effects():
    mix=Mix(1.4)
    mix.note(0,.8,'crash',volume=.55)
    for t in [.13,.28,.48]:
        mix.note(t,.28,'parcel',volume=.5)
    save(mix,'crash')
    for name,notes in [('upgrade',[60,64,67,72]),('escape',[67,72,76]),
                       ('delivery',[72,76,79]),('combo',[76,79,84]),
                       ('pickup',[79]),('bonus',[72,79]),('district',[60,67,72])]:
        mix=Mix(1.3 if len(notes)>1 else .18)
        for i,n in enumerate(notes):
            mix.note(i*.12,.28 if len(notes)>1 else .15,
                     'brass' if name=='upgrade' else 'keys',n,.2)
        save(mix,name)
    mix=Mix(1.45)
    mix.note(0,1.4,'siren',volume=.24)
    save(mix,'police')
    mix=Mix(.45)
    for t in [0,.12,.26]:
        mix.note(t,.15,'parcel',volume=.3)
    save(mix,'rattle')
    save(mix,'spill')
    for name,duration in [('brake',.35),('near_miss',.23)]:
        mix=Mix(duration)
        mix.note(0,duration,'hat',volume=.3)
        save(mix,name)
    mix=Mix(1.3)
    for i in range(7):
        mix.note(i*.13,.2,'bass',36-i*2,.25)
    save(mix,'broken')
    mix=Mix(.6)
    for t in [0,.12,.32]:
        mix.note(t,.12,'bass',29,.2)
    save(mix,'damage')
    for tier in range(4):
        mix=Mix(2)
        for i in range(len(mix.left)):
            t=i/RATE
            f=60-tier*8
            y=(sin(2*pi*f*t)+.25*sin(2*pi*f*2*t))
            y*=.65+.35*sin(2*pi*(16-tier*2)*t)
            mix.left[i]=mix.right[i]=y
        save(mix,f'engine_{tier}')
    for district in range(4):
        mix=Mix(8)
        if district in [1,2]:
            for t in [1.1,3.5,6.2]:
                mix.note(t,.35,'keys',86 if district==2 else 79,.10)
        else:
            for t in [1,4.3]:
                mix.note(t,.65,'brass',48+district*2,.08)
        save(mix,f'ambient_{district}')


def main():
    sources=[Path(__file__),Path(synth.__file__)]
    digest=hashlib.sha256(b''.join(p.read_bytes() for p in sources)).hexdigest()
    OUT.mkdir(parents=True,exist_ok=True)
    stamp=OUT/'generation.txt'
    if stamp.exists() and stamp.read_text()==digest and len(list(OUT.glob('*.wav'))) == 29:
        print('Audio assets are up to date.')
        return
    for bpm in [100,110,120]:
        for chase in [False,True]:
            music(bpm,chase)
    effects()
    stamp.write_text(digest)


if __name__=='__main__':
    main()
