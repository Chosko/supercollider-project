// Globals, Busses, Synthdefs
(
// Busses
~t = Bus.control(s, 1);
~brownWhite = Bus.control(s, 1);
~rpm = Bus.control(s, 1);      // Rounds per minute
~freq = Bus.control(s, 1);     // Frequence of bursts


// Functions
~r2f = {|rpm| rpm / 60}; // RPM to frequency

// SynthDefs

// Burst frequence
SynthDef(\burstFrequence, {|out=0, rpm=0|
	Out.kr(
		out,
		LFNoise0.kr(
			freq: ~r2f.(rpm) * 0.5,
			mul: 2,
			add: ~r2f.(rpm)
		)
	)
}).add;


// Burst sound
SynthDef(\bursts, {|out = 0, freq = 0|
	Out.ar(out,
		EnvGen.ar(
			envelope: Env.perc,
			gate: Impulse.ar(freq: freq),
			doneAction: 0,
			timeScale: (1.0/~r2f.(MouseX.kr(1, 7000)))
		) * BrownNoise.ar(mul: 0.2),
	)
}).add;

SynthDef(\tMouse, {|out = 2|
	Out.kr(out, MouseX.kr);
}).add;

SynthDef(\burstFreq, {|out = 2, min = 10, max = 500, t = 0|
	Out.kr(out,
		LFNoise0.kr(
			freq: t.linlin(0,1,min,max) * 0.5,
			mul: 4,
			add: t.linlin(0,1,min,max)
		)
	)
}).add;

SynthDef(\brownWhite, {|out = 2, min = 0, max = 1, t = 0|
	Out.kr(out, t.linlin(min,max,0,1));
}).add;

SynthDef(\engine, {|out = 0, trigger = 0, freq = 20, brownWhite = 0|
	Out.ar(out,
		Array.fill(2, {
			Pluck.ar(
				in: EnvGen.ar(
					envelope: Env.perc,
					gate: Impulse.ar(freq: freq+1),
					doneAction: 0,
					timeScale: (freq+1).reciprocal
				) * Mix.ar([
					Pulse.ar(
						freq: freq+1,
						width: SinOsc.ar(0.75*(freq+1)).range(0.01,0.99)
						mul: 0.2 * (1.0 - brownWhite),

					),
					LPF.ar(WhiteNoise.ar, 5000, mul: 1 * brownWhite)//WhiteNoise.ar(mul: 1 * brownWhite)
				]),
				trig: Impulse.ar(freq: freq),
				delaytime: (freq + 1).reciprocal,
				maxdelaytime: (freq + 1).reciprocal,
				decaytime: 0.5,
				coef:  MouseY.kr(-0.28, 0.5)
			)
		})
	)
}).add;
)

{ Pulse.ar(200, SinOsc.ar(150).range(0.01, 0.99), 0.2) }.play;

{ MouseX.kr(0,1).linexp(0,1,0.1,1.1) - 0.1 }.scope

{ BrownNoise.ar }.play;
{ LPF.ar(WhiteNoise.ar, MouseX.kr(0,22050).poll, mul: MouseX.kr(1,0.1, 'exponential')) }.freqscope

// TEST
(
var burstFreq, engine, mouse, brownWhite;
mouse = Synth(\tMouse, [\out, ~t]);
burstFreq = Synth(\burstFreq, [\out, ~freq, \min, 11, \max, 532]);
burstFreq.map(\t, ~t);
brownWhite = Synth(\brownWhite, [\out, ~brownWhite, \min, 0.4, \max, 1]);
brownWhite.map(\t, ~t);
engine = Synth(\engine, [\f, 0]);
engine.map(\freq, ~freq);
engine.map(\brownWhite, ~brownWhite);
)

// Create Synths and map busses
(
var imp, bur, freq;
freq = Synth(\burstFrequence, [\out, ~freq]);
freq.map(\rpm, ~rpm);
bur = Synth(\bursts);
bur.map(\freq, ~freq);
)

s.scope

// Test
// Mouse controls RPM
{ Out.kr(~rpm, MouseX.kr(1000, 7000)) }.play;

~impulses.scope
s.scope


// Inviluppo percussivo della marmitta, con gate impulsivo
{
	EnvGen.kr(
		envelope: Env.perc,
		gate: ,
		doneAction: 0) * SinOsc.ar(mul: 0.5) }.play ;
}.play


(
{
	EnvGen.ar(
		envelope: Env.perc,
		gate: Impulse.ar(
			freq: LFNoise0.kr(
				freq: ~r2f.(MouseX.kr(1000, 7000)) * 0.5,
				mul: 2,
				add: ~r2f.(MouseX.kr(1000, 7000))
			)
		),
		doneAction: 0,
		timeScale: (1.0/~r2f.(MouseX.kr(1000, 7000)))
	) * BrownNoise.ar(mul: 0.5)
}.play
)

// Notbad
(
{ Pluck.ar(
	in:EnvGen.ar(
		envelope: Env.perc,
		gate: Impulse.ar(
			freq: LFNoise0.kr(
				freq: ~r2f.(MouseX.kr(700, 7000)) * 0.5,
				mul: 2,
				add: ~r2f.(MouseX.kr(700, 7000))
			)
		),
		doneAction: 0,
		timeScale: (1.0/~r2f.(MouseX.kr(700, 7000)))
	) * BrownNoise.ar(mul: 0.2),
	trig: Impulse.ar(
		freq: LFNoise0.kr(
			freq: ~r2f.(MouseX.kr(700, 7000)) * 0.5,
			mul: 2,
			add: ~r2f.(MouseX.kr(700, 7000))
		)
	),
	delaytime: LFNoise0.kr(
		freq: ~r2f.(MouseX.kr(700, 7000)) * 0.5,
		mul: 2,
		add: ~r2f.(MouseX.kr(700, 7000))
	).reciprocal,
	maxdelaytime: LFNoise0.kr(
		freq: ~r2f.(MouseX.kr(700, 7000)) * 0.5,
		mul: 2,
		add: ~r2f.(MouseX.kr(700, 7000))
	).reciprocal,
	decaytime: 0.5,
	coef:MouseX.kr(-0.28, 0.5).poll)
}.play ;
)

s.freqscope



// Test

(
// Busses and synthdefs
~orig = Bus.audio(s,1);
~a0 = Bus.audio(s,1);
~a1 = Bus.audio(s,1);
~a2 = Bus.audio(s,1);
~a3 = Bus.audio(s,1);
~k0 = Bus.control(s,1);
~k1 = Bus.control(s,1);
~k2 = Bus.control(s,1);
~k3 = Bus.control(s,1);
~mouseX = Bus.control(s,1);
~mouseY = Bus.control(s,1);

// Buffer of harley
b = Buffer.read(s, Platform.resourceDir +/+ "sounds/harleyIgnition.wav") ;
)
(
// Harley
SynthDef(\source, {|outBus=3|
	Out.ar(outBus, {
		PlayBuf.ar(1, b, startPos: 150000, loop: 1, rate: 0.8);
	})
}).add;

// Controllo con il mouse della soglia spettrale
SynthDef(\magAbove, {|inBus = 2, outBus=0, thresh=1|
	var in, chain;
	var fftBuf = LocalBuf(2048, 1) ;
	in = In.ar(inBus, 1);
	chain = FFT(fftBuf, in);
	chain = PV_MagAbove(chain, thresh.linlin(0,1,0,60));
	Out.ar(outBus, 0.5 * IFFT(chain));
}).add;

// BrickWall
SynthDef(\brickWall, {|inBus = 2, outBus=0|
	var in, chain;
	var fftBuf = LocalBuf(2048, 1) ;
	in = In.ar(inBus, 1);
	chain = FFT(fftBuf, in);
	chain = PV_BrickWall(chain, MouseX.kr(-1.0,1.0, 0));
	// -1.0 --> 0.0: LoPass ; 0.0 --> 1.0: HiPass
	Out.ar(outBus, Normalizer.ar(IFFT(chain), level:1));
}).add;

// Mouse
SynthDef(\mouse, {
	Out.kr(~mouseX, MouseX.kr);
	Out.kr(~mouseY, MouseY.kr);
}).add;
)

(
var mag;
Synth(\source, [\outBus, ~orig]);
Synth(\mouse);mag = Synth(\magAbove, [\inBus,~orig], addAction:\addToTail);

mag.map(\thresh, ~mouseX)
)
Synth(\brickWall, [\inBus,~orig], addAction:\addToTail);
