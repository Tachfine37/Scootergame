"""Original synthesized funk audition; does not replace the published soundtrack.

Run with Python 3. No external samples or dependencies.
Outputs 16-bit stereo WAVs under outputs/audio-preview.
"""
from array import array
from math import exp, pi, sin, sqrt, tanh
from pathlib import Path
from random import Random
import sys
import wave

RATE = 32000
TAU = 2 * pi
OUT = Path(__file__).resolve().parents[2] / 'audio-preview'
RNG = Random(704)


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


class Mix:
    def __init__(self, seconds):
        self.left = array('f', [0]) * int(seconds * RATE)
        self.right = array('f', [0]) * int(seconds * RATE)

    def note(self, start, duration, kind, note=60, volume=.2, pan=0):
        first = round(start * RATE)
        count = round(duration * RATE)
        frequency = hz(note)
        low = 0
        last = 0
        gl = sqrt((1 - pan) / 2) * volume
        gr = sqrt((1 + pan) / 2) * volume
        for j in range(count):
            index = first + j
            if not 0 <= index < len(self.left):
                continue
            t = j / RATE
            p = TAU * frequency * t
            attack = min(1, t / .004)
            release = min(1, (duration - t) / .025)
            noise = RNG.uniform(-1, 1)
            if kind == 'bass':
                y = (sin(p) + .30 * sin(2*p) + .12 * sin(3*p))
                y *= attack * release * exp(-t * 4)
                y += noise * .06 * exp(-t * 100)
            elif kind == 'clav':
                y = (sin(p) + .4 * sin(2*p + 1) + .22 * sin(3*p))
                y *= attack * release * exp(-t * 18)
            elif kind == 'keys':
                y = (sin(p + 1.8 * sin(2*p) * exp(-t*8)) + .15*sin(p*2))
                y *= attack * release * exp(-t * 5)
            elif kind == 'brass':
                vibrato = .025 * sin(TAU * 5 * t)
                y = sum(sin(p*k + vibrato*k) / (k ** 1.35) for k in range(1, 6))
                y *= min(1, t/.035) * release * (.8 + .2*exp(-t*10))
            elif kind == 'kick':
                phase = TAU * (48*t + 1.65*(1-exp(-t*35)))
                y = sin(phase) * exp(-t*14) + noise*.07*exp(-t*160)
            elif kind == 'snare':
                low += .22 * (noise - low)
                y = (noise-low)*exp(-t*24) + .28*sin(TAU*180*t)*exp(-t*30)
            elif kind == 'hat':
                y = (noise-last)*.5*exp(-t*65)
                last = noise
            elif kind == 'crash':
                y = noise*exp(-t*7) + .5*sin(TAU*87*t)*exp(-t*12)
                y += .15*sin(TAU*713*t)*exp(-t*5)
            elif kind == 'parcel':
                low += .08*(noise-low)
                y = low*3*exp(-t*35) + .35*sin(TAU*140*t)*exp(-t*45)
            elif kind == 'siren':
                # Integrated pitch modulation, rather than a discontinuous pitch jump.
                phase = TAU*690*t + 145/1.4 * (1 - __import__('math').cos(TAU*1.4*t))
                y = (sin(phase)+.16*sin(phase*3))*min(1,t/.12)*release
            else:
                raise ValueError(kind)
            self.left[index] += y*gl
            self.right[index] += y*gr

    def add(self, other, start, gain=1):
        offset = round(start*RATE)
        for i in range(min(len(other.left), len(self.left)-offset)):
            self.left[offset+i] += other.left[i]*gain
            self.right[offset+i] += other.right[i]*gain

    def save(self, name):
        peak = max(max(abs(x) for x in self.left), max(abs(x) for x in self.right))
        gain = .88/max(peak, .01)
        pcm = array('h')
        for i, (left, right) in enumerate(zip(self.left, self.right)):
            # Short edge ramps protect audition playback from clicks.
            edge = min(1, i/(RATE*.012), (len(self.left)-1-i)/(RATE*.025))
            pcm.append(round(left*gain*edge*32767))
            pcm.append(round(right*gain*edge*32767))
        if sys.byteorder != 'little':
            pcm.byteswap()
        path = OUT / name
        with wave.open(str(path), 'wb') as wav:
            wav.setnchannels(2)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm.tobytes())
        print(f'{name}: {len(self.left)/RATE:.2f}s; peak before normalization {peak:.3f}')
        return path


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Eight bars: four at 100 BPM, two at 110, two at 120.
    tempos = [100]*4 + [110]*2 + [120]*2
    length = sum(4*60/bpm for bpm in tempos)
    music = Mix(length + .45)
    chords = [(57,60,64,67), (62,65,69,72), (55,59,62,65), (60,64,67,71)]
    roots = [33,38,31,36]
    time = 0
    for bar, bpm in enumerate(tempos):
        beat = 60/bpm
        chord = chords[bar%4]
        root = roots[bar%4]
        # Backbeat, syncopated kick and lightly swung eighth-note hats.
        for pos in [0, 1.75, 2.5, 3.5]:
            music.note(time+pos*beat, .3, 'kick', volume=.61)
        for pos in [1, 3]:
            music.note(time+pos*beat+.009, .24, 'snare', volume=.35, pan=.07)
        for step in range(8):
            pos = step*.5 + (.025 if step%2 else 0)
            music.note(time+pos*beat, .11, 'hat', volume=.12 if step%2 else .075, pan=.34)
        if bar >= 6:
            for pos in [.75, 2.75, 3.75]:
                music.note(time+pos*beat, .1, 'hat', volume=.09, pan=-.35)
        for pos, interval, dur in [(0,0,.65),(.75,12,.22),(1.5,0,.30),(2.25,7,.27),(2.75,10,.22),(3.25,12,.35),(3.75,7,.18)]:
            music.note(time+pos*beat, dur*beat, 'bass', root+interval, .48)
        for pos in [.5, 1.25, 2.5, 3.25]:
            for note in chord:
                music.note(time+pos*beat, .17, 'clav', note+12, .065, -.4)
        for pos in [0, 2.75]:
            for note in chord:
                music.note(time+pos*beat, .48, 'keys', note, .055, .4)
        # A sparse call-and-response hook leaves space for gameplay sounds.
        hook = [(1.75, chord[2]+12), (2.5, chord[1]+12), (3.5, chord[0]+12)]
        if bar%2 == 1:
            for pos, note in hook:
                music.note(time+pos*beat, .19, 'brass', note, .12, -.08)
        time += 4*beat
    music.save('01-urban-funk.wav')

    accident = Mix(1.4)
    accident.note(0, .8, 'crash', volume=.55)
    for when, pan in [(.13,-.5),(.28,.45),(.48,-.2)]:
        accident.note(when, .28, 'parcel', volume=.5, pan=pan)
    accident.save('02-accident.wav')
    upgrade = Mix(1.5)
    for when, note in [(0,60),(.12,64),(.24,67),(.38,72)]:
        upgrade.note(when, .3, 'brass', note, .19)
    for note in [60,64,67,72]:
        upgrade.note(.72, .45, 'keys', note, .13, .15)
    upgrade.save('03-upgrade.wav')
    police = Mix(2.8)
    police.note(0, 2.7, 'siren', volume=.24, pan=-.2)
    police.save('04-police.wav')

    demo = Mix(28)
    demo.add(music, 0, .85)
    demo.add(police, 15, .45)
    demo.add(accident, 20.2, .65)
    demo.add(upgrade, 22, .8)
    demo.add(police, 24.5, .6)
    demo.save('urban-funk-demo.wav')


if __name__ == '__main__':
    main()
