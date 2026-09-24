"""Reproducible offline instrument-sample arrangements; runtime needs only FLAC assets.
Requires numpy, scipy, soundfile, a FluidSynth shared library and GeneralUser GS 2.0.3.
No audio device is opened. See PRESET-MUSIC.md for provenance and limitations.
"""
from pathlib import Path
import argparse, ctypes as C, hashlib, json, math, os
import numpy as np
import soundfile as sf
from scipy.signal import welch, butter, sosfilt

RATE=48000
NAMES=['Classic','Balanced','Electronic','Acoustic','POP','Rock','Metal']
BPM=[90,100,112,96,112,128,160]
BARS=[21,16,28,24,28,32,40]
BANDS=[(20,60),(60,250),(250,500),(500,2000),(2000,4000),(4000,6000),(6000,16000)]

def rms(x):return float(np.sqrt(np.mean(np.square(x.astype(np.float64)))))
def spectrum(x):
    f,p=welch(x,fs=RATE,nperseg=16384,axis=0)
    p=p.mean(axis=1)
    energy=np.array([np.sum(p[(f>=lo)&(f<hi)]) for lo,hi in BANDS])
    return energy/energy.sum()

class Renderer:
    def __init__(self,library,bank):
        if os.name=='nt':self.dll_directory=os.add_dll_directory(str(library.parent.resolve()))
        self.lib=C.CDLL(str(library.resolve()))
        specs={
            'new_fluid_settings':(C.c_void_p,[]), 'delete_fluid_settings':(None,[C.c_void_p]),
            'fluid_settings_setnum':(C.c_int,[C.c_void_p,C.c_char_p,C.c_double]),
            'fluid_settings_setint':(C.c_int,[C.c_void_p,C.c_char_p,C.c_int]),
            'new_fluid_synth':(C.c_void_p,[C.c_void_p]),'delete_fluid_synth':(None,[C.c_void_p]),
            'fluid_synth_sfload':(C.c_int,[C.c_void_p,C.c_char_p,C.c_int]),
            'fluid_synth_program_select':(C.c_int,[C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_int]),
            'fluid_synth_cc':(C.c_int,[C.c_void_p,C.c_int,C.c_int,C.c_int]),
            'fluid_synth_noteon':(C.c_int,[C.c_void_p,C.c_int,C.c_int,C.c_int]),
            'fluid_synth_noteoff':(C.c_int,[C.c_void_p,C.c_int,C.c_int]),
            'fluid_synth_write_float':(C.c_int,[C.c_void_p,C.c_int,C.c_void_p,C.c_int,C.c_int,C.c_void_p,C.c_int,C.c_int])}
        for name,(restype,args) in specs.items():
            fn=getattr(self.lib,name);fn.restype=restype;fn.argtypes=args
        self.bank=bank
    def render(self,preset,events,instruments):
        lib=self.lib;settings=lib.new_fluid_settings();synth=None
        assert settings
        try:
            room_size=[.84,.48,.25,.48,.50,.43,.35][preset]
            room_level=[.24,.13,.065,.11,.14,.085,.065][preset]
            for key,value in [('synth.sample-rate',RATE),('synth.gain',.4),('synth.reverb.room-size',room_size),('synth.reverb.damp',.60),('synth.reverb.width',85),('synth.reverb.level',room_level)]:
                assert lib.fluid_settings_setnum(settings,key.encode(),value)==0,key
            for key,value in [('synth.polyphony',256),('synth.chorus.active',0),('synth.reverb.active',1),('synth.cpu-cores',1)]:
                assert lib.fluid_settings_setint(settings,key.encode(),value)==0,key
            synth=lib.new_fluid_synth(settings);assert synth
            bankid=lib.fluid_synth_sfload(synth,str(self.bank.resolve()).encode(),0);assert bankid>=0
            for channel,(program,pan,volume) in instruments.items():
                assert lib.fluid_synth_program_select(synth,channel,bankid,128 if channel==9 else 0,program)==0
                assert lib.fluid_synth_cc(synth,channel,10,pan)==0
                assert lib.fluid_synth_cc(synth,channel,7,volume)==0
            frames=round(BARS[preset]*4*60/BPM[preset]*RATE)
            events=sorted(events)
            output=np.empty((frames,2),np.float32)
            scratch=np.empty((8192,2),np.float32)
            # The first whole arrangement establishes previous-note and room tails.
            for repeat in range(2):
                position=0
                for end,kind,channel,key,velocity in events+[(frames,2,0,0,0)]:
                    end=min(frames,end)
                    while position<end:
                        count=min(len(scratch),end-position)
                        assert lib.fluid_synth_write_float(synth,count,scratch.ctypes.data,0,2,scratch.ctypes.data,1,2)==0
                        if repeat:output[position:position+count]=scratch[:count]
                        position+=count
                    if kind==0:lib.fluid_synth_noteoff(synth,channel,key)
                    elif kind==1:assert lib.fluid_synth_noteon(synth,channel,key,velocity)==0
            return output
        finally:
            if synth:lib.delete_fluid_synth(synth)
            lib.delete_fluid_settings(settings)

def score(preset):
    """Original phrases with recurring themes, transitions and restrained density."""
    if preset==2:raise ValueError('Electronic uses its dedicated synthesizer')
    rng=np.random.default_rng(93000+preset);beat=60/BPM[preset];events=[]
    def note(at,ch,key,length,velocity=80,human=True):
        at=max(0,at*beat+(rng.uniform(-.003,.003) if human else 0))
        frame=round(at*RATE);end=round((at+max(.045,length*beat))*RATE)
        velocity=max(1,min(127,int(velocity)))
        events.extend([(frame,1,ch,int(key),velocity),(end,0,ch,int(key),0)])
    def chord(at,ch,keys,length,velocity=76,strum=0):
        for j,key in enumerate(keys):note(at+j*strum/beat,ch,key,length,velocity+rng.integers(-3,4))
    def drum(at,key,vel):note(at,9,key,.20,vel,False)
    if preset==0:
        inst={0:(0,64,98),1:(46,38,76),2:(48,28,94),3:(42,96,98),4:(43,60,111),5:(60,83,99),6:(73,73,73),7:(9,80,67),8:(47,64,103),9:(0,64,68),10:(72,50,65)}
        # C minor: tonic, subdominant, relative major, dominant, return,
        # development and a dominant turnaround; the motif passes between voices.
        roots=[36,41,39,43,36,44,43]
        thirds=[3,3,4,4,3,4,4]
        for section,(root,third) in enumerate(zip(roots,thirds)):
            start=section*12;strength=[93,79,65,77,100,85,94][section]
            chord(start,2,[root+12,root+19,root+24+third,root+31],10.8,strength-17)
            chord(start+.12,5,[root+12,root+19,root+24],6.7,strength-12)
            for at,length in [(0,3.6),(4,3.4),(8,3.8)]:
                note(start+at,4,root-12 if section==0 else root,length,strength)
                note(start+at,3,root+12,length,strength-10)
            # A measured dotted motif, answered by a longer line; no high arpeggio loop.
            motif=[(0,0,.65),(1,3,.40),(1.75,7,2.1),(4.5,5,1.15),(6,3,2.1),(9,2,1),(10.5,0,1.25)]
            register=[12,12,24,24,24,36,36][section]
            for at,interval,length in motif:
                key=root+register+interval
                note(start+at,0,key,length,strength-4)
                if section in [0,1,4]:note(start+at,3,root+12+interval,length,strength-18)
                if section in [3,5,6]:note(start+at,6,min(96,key+12),length,strength-25)
            for at,keys in [(0,[root+12,root+19,root+24+third]),(6,[root+19,root+24+third,root+31])]:
                chord(start+at+.2,0,keys,4.7,62,.012)
            for j,interval in enumerate([12,19,24+third,31,36,31]):
                note(start+j*1.5+.5,1,root+interval+(12 if section>4 else 0),2.8,68 if section<4 else 82)
            if section in [0,3,4,6]:
                note(start,8,root,2.4,strength);note(start+8,8,root,2.8,strength-8)
            if section>=4:
                for at,interval in [(1.75,0),(6,7),(10.5,3)]:note(start+at,7,root+48+interval,2.5,65)
            if section>=5:
                for at,interval in [(0,7),(4.5,5),(9,2)]:note(start+at,10,root+48+interval,2.4,61)
            if section==6:
                drum(start,49,61);drum(start+8,55,52)
                for at in [1,3,5,7,9,11]:drum(start+at,51,47)
        return events,inst

    if preset==3:
        inst={0:(25,32,106),1:(24,94,91),2:(31,78,60),3:(32,64,76),4:(0,57,54)}
        voicings=[[40,47,54,55,59,64],[36,43,50,52,59,64],[43,50,54,57,62,67],[38,45,52,54,57,64],[45,52,55,59,64,67],[35,42,49,51,57,63]]
        progression=[0,1,2,3,0,1,4,5,0,1,3,5]
        for bar in range(BARS[preset]):
            at=bar*4;keys=voicings[progression[bar//2]]
            # Let notes ring; alternate bass and inner strings support a top line.
            for offset,string,length in [(0,0,2.5),(.75,2,1.8),(1.5,3,1.7),(2,1,2),(2.75,4,1.3)]:
                note(at+offset,0,keys[string],length,78 if string<2 else 65)
            if bar%2==0:note(at+1,1,keys[-1],2.1,79)
            else:
                note(at+.5,1,keys[-1]-2,1.3,73);note(at+2.5,1,keys[-2],1.9,67)
            if bar in [7,15,23]:chord(at+3,0,keys[1:],2.4,55,.023)
            note(at,3,keys[0]-12,3.2,63)
            if 8<=bar<16 and bar%2==0:chord(at+.2,4,[keys[2],keys[4]],5.6,46)
            if bar in [3,11,19]:note(at+3,2,keys[-1]+12,3.2,53)
        return events,inst

    heavy=preset in [5,6];metal=preset==6
    if heavy:
        inst={0:(28 if metal else 29,23,107),1:(30,105,102),2:(34,64,115),3:(48,76,70),4:(30 if metal else 0,51,92),9:(0,64,113)}
        roots=([38,38,34,36,38,34,31,33,38,33] if metal else [40,36,43,38,40,36,45,35])
        for bar in range(BARS[preset]):
            at=bar*4;root=roots[bar//4];minor=root in ([38,31] if metal else [40,45])
            quiet=(12<=bar<16) or (metal and 28<=bar<32)
            climax=(32<=bar if metal else 24<=bar)
            # Intro and breakdown expose the harmony before the full riff returns.
            if bar%4==0:chord(at,3,[root+12,root+19,root+24+(3 if minor else 4)],14.4,62 if quiet else 53)
            if quiet or (not metal and bar<4):
                for offset,interval,length in [(0,12,1.7),(2,19,1.3),(3,24,1.8)]:
                    note(at+offset,4,root+interval,length,74 if quiet else 66)
                chord(at,0,[root,root+7],3.4,61)
                note(at,2,root-12,3.3,84)
            else:
                if metal:
                    rhythm=[(0,.34),(.5,.17),(.75,.17),(1.5,.35),(2,.34),(2.5,.17),(2.75,.17),(3.5,.36)]
                    if bar%4==3:rhythm=[(0,.42),(.75,.42),(1.5,.42),(2.25,1.55)]
                else:rhythm=[(0,.68),(1,.38),(1.75,.65),(2.75,.35),(3.5,.42)]
                for j,(offset,length) in enumerate(rhythm):
                    shift=(3 if j==len(rhythm)-2 else 2) if bar%4==3 and j>=len(rhythm)-2 else 0
                    velocity=(108 if j==0 else 95)+int(rng.integers(-3,4))
                    chord(at+offset,0,[root+shift,root+7+shift],length,velocity)
                    chord(at+offset+.012,1,[root+shift,root+12+shift],length,velocity-6)
                    note(at+offset,2,root-12+shift,length+.08,109)
                if climax and bar%2==0:
                    for offset,interval,length in [(0,24,1.7),(2,27 if minor else 28,1.5)]:
                        note(at+offset,4,root+interval,length,70)
            if quiet:
                drum(at,36,92);drum(at+2,38,73)
                for j in [0,2]:drum(at+j,42,45)
            else:
                kicks=([0,.5,1.5,2,2.5,3.5] if metal else [0,1.5,2,3.5])
                for j,offset in enumerate(kicks):drum(at+offset,36,117 if j%2==0 else 102)
                # Half-time refrain alternates with a driving backbeat.
                for offset in ([2] if metal and (bar//4)%2 else [1,3]):drum(at+offset,38,114)
                for j in range(8):drum(at+j*.5,51 if climax else 42,69 if j%2 else 58)
                if bar%4==0:drum(at,49,91)
                if bar%8==7:
                    for j,key in enumerate([50,47,45,41]):drum(at+3+j*.25,key,83+j*4)
        return events,inst

    # POP: a lyrical major/minor melody with a bridge and a fuller return.
    # Balanced: the same care in voice leading, with a quieter electric-piano mix.
    pop=preset==4
    inst={0:(0 if pop else 4,47,94),1:(25 if pop else 27,93,76),2:(33,64,94),3:(48 if pop else 89,28,65),4:(27 if pop else 11,67,80),9:(0,64,91)}
    roots=[48,43,45,41,38,43,48] if pop else [45,41,48,43]
    for bar in range(BARS[preset]):
        at=bar*4;section=bar//4;root=roots[section];minor=root in [45,38]
        third=3 if minor else 4;bridge=pop and 16<=bar<20;full=pop and bar>=20
        voicing=[root,root+7,root+12+third,root+23 if not minor else root+22]
        chord(at,0,voicing,3.65,64 if bridge else 74,.008)
        if bar%2==0:chord(at+.12,3,[root+12,root+19,root+24+third],7.4,52 if full else 43)
        for offset in ([1.5,3] if pop else [2.5]):chord(at+offset,1,[root+12,root+19,root+24+third],1.3,58,.012)
        for offset,length in [(0,1.8),(2.5,1.1)]:note(at+offset,2,root-24,length,87)
        # Each four-bar phrase asks and answers; longer notes leave room to breathe.
        shape=[[(.5,12+third,1.4),(2.5,19,1.15)],[(0,21 if minor else 23,2),(2.5,19,1.25)],[(.5,17,1.2),(2,12+third,1.7)],[(0,14,1.5),(2,12,2.2)]][bar%4]
        for offset,interval,length in shape:
            note(at+offset,4,root+interval,length,75 if pop else 57)
            if full:note(at+offset,0,root+interval,length,64)
        if not bridge:
            for offset in [0,2,3.5]:drum(at+offset,36,91 if pop else 76)
            for offset in [1,3]:drum(at+offset,38 if pop else 37,87 if pop else 58)
            for j in range(8 if full else 4):drum(at+j*(.5 if full else 1)+(.25 if full else .5),42,49+j%2*7)
            if full and bar%4==0:drum(at,49,67)
        else:drum(at,36,68)
    return events,inst


def electronic_edm():
    """Restrained, harmonically connected electronic arrangement with long tails.

    A small motif develops over sustained minor ninth/suspended voicings. Bass,
    drums, and room remain separate so synth ducking never gates the reverb.
    Every voice and delay wraps around the sixty-second master.
    """
    rng=np.random.default_rng(1122026);beat=60/BPM[2]
    n=round(BARS[2]*4*beat*RATE)
    bass=np.zeros((n,2),np.float32);pads=np.zeros_like(bass)
    melody=np.zeros_like(bass);drums=np.zeros_like(bass);events=0
    def add(track,at,voice,level=1):
        nonlocal events
        start=round(at*beat*RATE)%n;voice=np.asarray(voice,dtype=np.float32)*level
        if voice.ndim==1:voice=np.column_stack([voice,voice])
        assert len(voice)<n
        first=min(len(voice),n-start);track[start:start+first]+=voice[:first]
        if first<len(voice):track[:len(voice)-first]+=voice[first:]
        events+=1
    def filt(x,cutoff,kind='lowpass'):
        return sosfilt(butter(2,cutoff,fs=RATE,btype=kind,output='sos'),x,axis=0)
    def voice(key,length,kind):
        freq=440*2**((key-69)/12);hold=length*beat
        release={'bass':.34,'pad':3.8,'lead':2.9,'chord':.65}[kind]
        attack={'bass':.023,'pad':.85,'lead':.095,'chord':.025}[kind]
        t=np.arange(round((hold+release)*RATE))/RATE
        attack_env=np.sin(np.minimum(1,t/attack)*np.pi/2)**2
        release_env=np.exp(-np.maximum(t-hold,0)/(release/5))
        env=attack_env*release_env
        env[-240:]*=np.linspace(1,0,240)
        out=np.zeros((len(t),2))
        if kind=='bass':
            fundamental=np.sin(2*np.pi*freq*t)
            # The octave/third harmonic lend weight on smaller earphones without
            # depending on extreme sub-bass or a bright clipped saw.
            signal=.70*fundamental+.24*np.sin(4*np.pi*freq*t)+.06*np.sin(6*np.pi*freq*t)
            out[:]=signal[:,None]
        else:
            for ch in range(2):
                if kind in ['pad','chord']:
                    for cents,offset in [(-5,.13),(0,.31),(5,.57)]:
                        phase=2*np.pi*freq*2**((cents+(ch*2-1)*1.2)/1200)*t+offset+ch*.17
                        # Soft triangle-like harmonics, with slow tonal movement.
                        wave=sum(((-1)**j)*np.sin((2*j+1)*phase)/(2*j+1)**2 for j in range(6))
                        out[:,ch]+=wave/3
                    out[:,ch]*=.94+.06*np.sin(2*np.pi*.13*t+key*.2+ch*.4)
                else:
                    phase=2*np.pi*freq*2**((ch*2-1)*2/1200)*t
                    modulation=.30*np.exp(-t/1.6)*np.sin(2*phase)
                    out[:,ch]=.83*np.sin(phase+modulation)+.12*np.sin(2*phase)+.05*np.sin(3*phase)
            out=filt(out,2400 if kind=='pad' else 3600)
        if kind=='chord':
            bright=filt(out,3100);dark=filt(out,430)
            sweep=np.exp(-t/.28)
            out=dark+(bright-dark)*sweep[:,None]
        return out*env[:,None]

    # Seven four-bar phrases. Common upper notes carry through the changes;
    # the final suspended dominant leads naturally back to the opening D minor.
    harmony=[
        (38,[50,57,60,64,69]), # Dm9
        (34,[50,57,60,65,70]), # Bbmaj9
        (31,[50,53,58,62,69]), # Gm9
        (33,[52,55,57,62,64]), # A7sus4
        (38,[50,57,60,64,69]),
        (34,[50,57,60,65,70]),
        (33,[52,55,57,61,64]), # A7: C# resolves to D across the loop.
    ]
    for phrase,(root,keys) in enumerate(harmony):
        start=phrase*16
        for j,key in enumerate(keys):
            add(pads,start+j*.055,voice(key,14.2,'pad'),[.20,.16,.14,.115,.08][j])
        for bar in range(4):
            at=start+bar*4;quiet=phrase==3 or (phrase==6 and bar>=2)
            for offset,length,level in [(0,.85,.55),(1.25,.40,.38),(2,.60,.47),(3.25,.45,.40)]:
                add(bass,at+offset,voice(root-12 if root==38 else root,length,'bass'),level*(.72 if quiet else 1))
            if not quiet:
                for offset in [.75,2.5]:
                    for key in keys[1:4]:add(melody,at+offset,voice(key,.40,'chord'),.085)
    # Sparse, related phrases leave several beats for the previous note to decay.
    phrases=[
        [(4,69,2.4),(9,64,3.1)],
        [(3,65,3.0),(10,62,2.2)],
        [(4,62,2.6),(10,57,3.4)],
        [(6,64,4.0)],
        [(2,69,3.1),(8,72,2.6),(12,69,2.4)],
        [(3,65,3.1),(10,62,3.2)],
        [(2,64,3.0),(9,61,3.6)],
    ]
    for phrase,notes in enumerate(phrases):
        for at,key,length in notes:add(melody,phrase*16+at,voice(key,length,'lead'),.12 if phrase==3 else .17)

    # Rounded electronic kick, a low soft snare, and understated filtered hats.
    t=np.arange(round(.64*RATE))/RATE
    pitch=45+66*np.exp(-t/.018)
    kick=np.sin(2*np.pi*np.cumsum(pitch)/RATE)*np.exp(-t/.17)
    kick*=np.minimum(1,t/.004);kick[-480:]*=np.linspace(1,0,480)
    t=np.arange(round(.30*RATE))/RATE
    snare_noise=filt(rng.normal(size=(len(t),2)),[850,5200],'bandpass')
    snare=(snare_noise*.14+.15*np.sin(2*np.pi*185*t)[:,None])*np.exp(-t[:,None]/.050)
    snare[:96]*=np.linspace(0,1,96)[:,None];snare[-480:]*=np.linspace(1,0,480)[:,None]
    def hat(opened):
        t=np.arange(round((.30 if opened else .12)*RATE))/RATE
        noise=filt(rng.normal(size=(len(t),2)),[4700,12500],'bandpass')
        env=np.exp(-t/(.07 if opened else .025))*np.minimum(1,t/.003)
        env[-240:]*=np.linspace(1,0,240)
        return noise*env[:,None]
    closed,opened=hat(False),hat(True)
    for bar in range(BARS[2]):
        at=bar*4;quiet=12<=bar<16 or bar>=26
        for offset in ([0,2] if quiet else [0,1,2,3]):add(drums,at+offset,kick,.48 if quiet else .63)
        if not quiet:
            add(drums,at+2,snare,.72)
            for j in range(4):add(drums,at+j+.5,opened if j==3 and bar%4==3 else closed,.065+(j%2)*.012)
        elif bar%2:add(drums,at+2.5,closed,.035)

    # A soft pad swell connects sections. No noise riser, clap roll or sudden drop.
    dry=pads+melody
    room_input=filt(dry,3700).astype(np.float32)
    room=np.zeros_like(dry)
    # Distributed reflections retain stereo width and audible decays without
    # pumping the reverberation or adding a bright resonant feedback comb.
    times=np.linspace(.047,3.4,44)+rng.uniform(-.013,.013,44)
    gains=np.exp(-times/1.05);gains*=.65/gains.sum()
    for j,(seconds,gain) in enumerate(zip(times,gains)):
        room+=np.roll(room_input[:,::-1] if j%2 else room_input,round(seconds*RATE),axis=0)*gain
    for beats,gain in [(.75,.16),(1.5,.075),(2.25,.035)]:
        room+=np.roll(filt(melody,2600).astype(np.float32)[:,::-1],round(beats*beat*RATE),axis=0)*gain
    phase=(np.arange(n)/RATE)%beat
    duck=.86+.14*(1-np.exp(-phase/.12))
    bass_duck=.72+.28*(1-np.exp(-phase/.09))
    mixed=dry*duck[:,None]+bass*bass_duck[:,None]+drums+room
    return mixed.astype(np.float32),events


def classic_focus(x):
    n=len(x);t=np.arange(n)/RATE
    f=np.fft.rfftfreq(n,1/RATE);transform=np.fft.rfft(x,axis=0)
    mixed=x.astype(np.float64).copy()
    for j,(lo,hi) in enumerate(BANDS):
        width=min(30,(hi-lo)*.08)
        mask=np.sin(np.clip((f-lo)/width,0,1)*np.clip((hi-f)/width,0,1)*np.pi/2)**2
        part=np.fft.irfft(transform*mask[:,None],n=n,axis=0)
        distance=np.abs((t-(j*8+4)+28)%56-28)
        focus=np.where(distance<=3.5,1,np.where(distance>=4.5,0,.5+.5*np.cos(np.pi*(distance-3.5))))
        # At most about +3.5 dB within the focus window; retain the entire orchestra.
        mixed+=part*focus[:,None]*.5
    return mixed


def genre_balance(x,target):
    f=np.fft.rfftfreq(len(x),1/RATE)
    centers=np.array([math.sqrt(lo*hi) for lo,hi in BANDS])
    transform=np.fft.rfft(x,axis=0);logs=np.zeros(7)
    for _ in range(7):
        curve=np.exp(np.interp(np.log(np.maximum(f,1)),np.log(centers),logs))
        curve*=f**4/(f**4+18**4)/(1+(f/18000)**16)
        mixed=np.fft.irfft(transform*curve[:,None],n=len(x),axis=0)
        logs+=.4*np.log(np.asarray(target)/spectrum(mixed))
        logs=np.clip(logs,-.518,.518) # Limit cumulative correction to 4.5 dB.
    return mixed

def master(x,preset):
    x=x.astype(np.float64);x-=x.mean(axis=0)
    if preset==0:x=classic_focus(x).astype(np.float64)
    elif preset in [2,5,6]:
        targets={2:[.22,.24,.17,.22,.08,.04,.03],5:[.16,.24,.17,.25,.10,.05,.03],6:[.18,.25,.14,.24,.10,.05,.04]}
        x=genre_balance(x,targets[preset])
    else:
        f=np.fft.rfftfreq(len(x),1/RATE)
        gain=np.ones_like(f)
        if preset==3:
            gain*=1+.24*np.exp(-.5*((np.log2(np.maximum(f,1)/3200))/1.1)**2)
        gain*=1/(1+(f/18500)**16)
        gain*=f**4/(f**4+18**4)
        x=np.fft.irfft(np.fft.rfft(x,axis=0)*gain[:,None],n=len(x),axis=0)
    # Crossfade only the last few milliseconds of room-state mismatch, not a fade to silence.
    # Matching endpoint offsets with a short smooth correction avoids audible boundary clicks.
    count=round(RATE*.012);delta=x[0]-x[-1]
    x[-count:]+=np.linspace(0,1,count)[:,None]**2*delta
    x-=x.mean(axis=0)
    gain=min(.105/rms(x),.46/float(np.max(np.abs(x))))
    return (x*gain).astype(np.float32)

def main():
    p=argparse.ArgumentParser();p.add_argument('--library',type=Path,required=True);p.add_argument('--bank',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--previews',type=Path,required=True);p.add_argument('--only',type=str)
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True);args.previews.mkdir(parents=True,exist_ok=True)
    renderer=Renderer(args.library,args.bank)
    manifest=args.output/'preset-music-v2.json'
    report=json.loads(manifest.read_text())['presets'] if args.only and manifest.exists() else []
    for preset,name in enumerate(NAMES):
        if args.only and name not in args.only.split(','):continue
        if preset==2:
            rendered,event_count=electronic_edm()
        else:
            events,instruments=score(preset)
            rendered=renderer.render(preset,events,instruments);event_count=len(events)//2
        x=master(rendered,preset)
        file=args.output/f'preset-{name.lower()}.flac';sf.write(file,x,RATE,subtype='PCM_24')
        decoded,sr=sf.read(file,dtype='float32',always_2d=True)
        assert sr==RATE and decoded.shape==x.shape and np.isfinite(decoded).all()
        assert np.max(np.abs(decoded))<=.46001 and abs(decoded.mean())<1e-5
        preview=np.concatenate([decoded,decoded[:RATE*4]]).copy()*.2511886432
        edge=RATE//10;preview[:edge]*=np.linspace(0,1,edge)[:,None];preview[-edge:]*=np.linspace(1,0,edge)[:,None]
        sf.write(args.previews/f'{name}.wav',preview,RATE,subtype='PCM_16')
        row={'preset':name,'bpm':BPM[preset],'bars':BARS[preset],'seconds':len(x)/RATE,'frames':len(x),'file_bytes':file.stat().st_size,
             'peak':float(np.max(np.abs(decoded))),'rms_db':20*math.log10(rms(decoded)),
             'seam_step':float(np.max(np.abs(decoded[0]-decoded[-1]))),'band_energy_percent':(spectrum(decoded)*100).tolist(),
             'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'note_events':event_count}
        row['arrangement_revision']=4
        if preset==2:row['arrangement']='Warm electronic groove: syncopated bass, filtered chord stabs, sustained minor-ninth pads, restrained lead and long tails'
        if preset==0:row['balance_policy']='Equal eight-second focus windows; natural source energy, no equal-energy normalization'
        if preset==0:
            row['sections']=[{'start':i*8,'end':(i+1)*8,'focus_hz':list(band),'measured_band_percent':(spectrum(decoded[i*8*RATE:(i+1)*8*RATE])*100).tolist()} for i,band in enumerate(BANDS)]
        report=[r for r in report if r['preset']!=name]+[row];print(json.dumps(row),flush=True)
    report.sort(key=lambda row:NAMES.index(row['preset']))
    manifest.write_text(json.dumps({'sample_rate':RATE,'channels':2,'bits':24,'bands_hz':BANDS,'presets':report},indent=2)+'\n')

if __name__=='__main__':main()
