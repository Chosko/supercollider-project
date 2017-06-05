/*
************************
PROGETTO EDAM
Author: Ruben Caliandro
***********************

DESCRIPTION

blah


USAGE

Run everything (it's a single block):
*/

(
/***** Local variables *****/
// Sound variables
var updateTime, tSynth, burstFreq, engine, lowHigh, t, accel, filtered, brown, saw, gear;
// GUI variables
var window, igniteBtn, rpmKnob, accelSlider,
accelZeroLabel, accelLabel, brakeLabel, curGearLabel,
menuBtnFormula1, menuBtnHarley, menuText, changeDown, changeUp;
// Window size
var w = 1024;
var h = 768;
var accelScale = 0;

// Start everything in a routine
~initRoutine = Routine.new({

	s.boot;
	3.wait; // Wait for the server to boot

	/***** Busses *****/
	~saw = Bus.audio(s, 2);       // A channel with a sawtooth signal with percussive envelope
	~brown = Bus.audio(s, 2);     // A brown noise enveloped percussively
	~filtered = Bus.audio(s, 2);  // A Low Pass filtered white noise enveloped percussively
	~t = Bus.control(s, 2);       // RPM of the engine, normalized in the interval [0,1]
	~lowHigh = Bus.control(s, 1); // Parameter in [0,1], used to mix sounds between low and high RPM synthesis
	~freq = Bus.control(s, 1);    // Frequence of engine bursts
	~gear = Bus.control(s,1);     // Gear number, in [0,6]


	/***** SynthDefs *****/

	// Simply outputs t in a control bus
	SynthDef(\t, {|out=2, t=0|
		Out.kr(out, t);
	}).add;

	// Generate a control signal that represents the absolute frequency of the engine bursts
	// -- ARGS --
	// out: the output bus
	// min: the minimum output frequency, when the engine is idle
	// max: the maximum output frequency
	// t: a [0,1] paramter used to lerp from 'min' to 'max'
	SynthDef(\burstFreq, {|out = 2, min = 10, max = 500, t = 0|
		Out.kr(out,
			LFNoise0.kr( // The output is perturbed with a low frequency noise
				add: t.linlin(0,1,min,max),        // Start from the expected frequency
				mul: t.linlin(0.1,1,4,8),          // The frequency affects the amount of perturbation
				freq: t.linlin(0,1,min,max) * 0.25 // Update the noise a quarter times the burst frequency
			)
		)
	}).add;

	// Remap the engine normalized frequency (t) to an amount of low/high engine sound synthesis
	SynthDef(\lowHigh, {|out = 2, min = 0, max = 1, t = 0|
		Out.kr(out, t.linlin(min,max,0,1));
	}).add;

	SynthDef(\saw, {|out = 0, freq = 20|
		Out.ar(out, Array.fill(2, {
			LPF.ar(
				EnvGen.ar(
					envelope: Env.perc,
					gate: Impulse.ar(freq: freq * 4),
					doneAction: 0,
					timeScale: (freq).reciprocal
				) *
				Saw.ar(
					freq: freq,
					mul: SinOsc.ar(0.5 * freq).range(0.01,0.99)
				),
				freq.linlin(10,200,2000,10000),
			)
		}))
	}).add;

	SynthDef(\brownNoise, {|out = 0, freq = 2|
		Out.ar(out, Array.fill(2, {
			EnvGen.ar(
				envelope: Env.perc,
				gate: Impulse.ar(freq: freq),
				doneAction: 0,
				timeScale: (freq).reciprocal
			) *
			BrownNoise.ar
		}))

	}).add;

	SynthDef(\filteredNoise, {|out = 0, freq = 2|
		Out.ar(out, Array.fill(2, {
			EnvGen.ar(
				envelope: Env.perc,
				gate: Impulse.ar(freq: freq),
				doneAction: 0,
				timeScale: (freq).reciprocal
			) *
			LPF.ar(WhiteNoise.ar, 5000)
		}))
	}).add;

	SynthDef(\engine, {|out = 0, freq = 20, lowBus=2, highBus=2, lowHigh = 0|
		Out.ar(out,
			Pluck.ar(
				in: Mix.ar([
					In.ar(lowBus, 1) * (1.0 - lowHigh) * [0.1, 0.1],
					In.ar(highBus, 2) * lowHigh * 0.5
				]),
				trig: SinOsc.ar(freq: freq),
				delaytime: (freq + 1).reciprocal,
				maxdelaytime: (freq+1).reciprocal,
				decaytime: 0.5,
				coef:  MouseX.kr(0, 0.4)
			)
		)
	}).add;

	1.wait;

	~initializeGUI.play(AppClock);
});

/***** Functions and routines *****/
// Initialize variables, synths and bus mappings
~initializeEngine = {
	// Initialize variables
	updateTime = 0.01;
	t = 0;
	accel = 0;

	// Initialize synths
	tSynth = Synth(\t, [\out, ~t]);
	burstFreq = Synth(\burstFreq, [\out, ~freq]);
	burstFreq.map(\t, ~t);
	lowHigh = Synth(\lowHigh, [\out, ~lowHigh]);
	lowHigh.map(\t, ~t);
	saw = Synth(\saw, [\out, ~saw]);
	saw.map(\freq, ~freq);
	brown = Synth(\brownNoise, [\out, ~brown]);
	brown.map(\freq, ~freq);
	filtered = Synth(\filteredNoise, [\out, ~filtered]);
	filtered.map(\freq, ~freq);
	engine = Synth(\engine, [\lowBus, ~brown, \highBus, ~brown], addAction:\addToTail);
	engine.map(\freq, ~freq);
	engine.map(\lowHigh, ~lowHigh);
};

// Release everything
~releaseEngine = {
	// free synths
	tSynth.free;
	burstFreq.free;
	lowHigh.free;
	engine.free;
};

~initializeMenuButtons = {
	menuText = StaticText(window, Rect((w/2) - 50, h/3 + 50, 100, 20))
	.string_("Choose your vehicle")
	.stringColor_(Color.white);

	menuBtnFormula1 = GUI.button.new(window, Rect((w/3)+50,h/2 - 25,100,50)).states_([
		["Formula 1",Color.black,Color.white]
	]);
	menuBtnFormula1.action = {|x|
		~destroyMenuButtons.value;
		~initializeControls.value;
		~initializeFormula1Controls.value;
	};

	menuBtnHarley = GUI.button.new(window, Rect((2*w/3)-150,h/2 - 25,100,50)).states_([
		["Harley Davidson",Color.black,Color.white]
	]);
	menuBtnHarley.action = {|x|
		~destroyMenuButtons.value;
		~initializeControls.value;
		~initializeHarleyControls.value;
	};
};

~destroyMenuButtons = {
	menuText.destroy;
	menuBtnFormula1.destroy;
	menuBtnHarley.destroy;
};

~initializeFormula1Controls = {
	igniteBtn.action = {|x|
		if ( x.value == 0, {
			// Stop
			~updateLoop.stop;
			~releaseEngine.value;
			~destroyControls.value;
			~initializeMenuButtons.value;
		},
		{
			// Ignite
			~initializeEngine.value;
			~formula1.value;
			~updateLoop.reset;
			~updateLoop.play(SystemClock);
		});
	};
};

~initializeHarleyControls = {
	igniteBtn.action = {|x|
		if ( x.value == 0, {
			// Stop
			~updateLoop.stop;
			~releaseEngine.value;
			~destroyControls.value;
			~initializeMenuButtons.value;
		},
		{
			// Ignite
			~initializeEngine.value;
			~harley.value;
			~updateLoop.reset;
			~updateLoop.play(SystemClock);
		});
	};
};

~initializeControls = {
	// Start Stop button
	igniteBtn = GUI.button.new(window, Rect((w/2)-50,h/3 - 30,100,50)).states_([
		["Ignite",Color.black,Color.white],
		["Stop",Color.white,Color.black]
	]);

	// RPM
	rpmKnob = Knob(window, Rect(w/2 - 100, h/2 - 70, 200, 200));


	// Acceleration slider
	accelSlider = Slider(window, Rect((2*w/3) - 20, (h/3) + 50, 20, (h/3 - 50)))
	.value_(0.5)
	.action_({|sl|
		accel = sl.value.linlin(0,1,-1,1);
	});
	accelZeroLabel = StaticText(window, Rect((2*w/3) - 35, (h/3) + 50 + (((h/3) - 50) / 2) - 11, 20, 20))
	.string_("0 -")
	.stringColor_(Color.white);
	accelLabel = StaticText(window, Rect((2*w/3) - 40, (h/3) + 20, 70, 20))
	.string_("ACCELERATE")
	.stringColor_(Color.white);
	brakeLabel = StaticText(window, Rect((2*w/3) - 25, (2*h/3) + 12, 70, 20))
	.string_("BRAKE")
	.stringColor_(Color.white);

	changeUp = GUI.button.new(window, Rect((2*w/3 + 20),h/2 - 30,100,50))
	.string_("Change UP");
	changeDown = GUI.button.new(window, Rect((2*w/3 + 20),h/2 + 30,100,50))
	.string_("Change DOWN");

	changeUp.action_({
		if(gear < 6 && gear > 0, {
			~switchGear.(gear + 1);
			{
				15.do {
					t = (t - (0.25/15)).clip(0,1);
					0.01.wait;
				}
			}.fork
		});
	});

	changeDown.action_({
		if(gear > 1, {
			~switchGear.(gear - 1);
			{
				25.do {
					t = (t + (0.25/25)).clip(0,1);
					0.01.wait;
				}
			}.fork
		});
	});

	curGearLabel = StaticText(window, Rect((w/2) - 25, 2 * h/3 - 10, 50, 50))
	.stringColor_(Color.white)
	.font_(Font(size: 40))
	.align_(\center);

	~switchGear.(0);
};

~switchGear = {|target=1|
	switch(target,
		// Change to N
		0, {
			accelScale = 0;
			defer{curGearLabel.string_("N")};
		},
		// Change to 1
		1, {
			accelScale = 0.2;
			defer{curGearLabel.string_("1")};
		},
		// Change to 2
		2, {
			accelScale = 0.16;
			defer{curGearLabel.string_("2")};
		},
		// Change to 3
		3, {
			accelScale = 0.12;
			defer{curGearLabel.string_("3")};
		},
		// Change to 4
		4, {
			accelScale = 0.08;
			defer{curGearLabel.string_("4")};
		},
		// Change to 5
		5, {
			accelScale = 0.05;
			defer{curGearLabel.string_("5")};
		},
		6, {
			accelScale = 0.03;
			defer{curGearLabel.string_("6")};
		}
	);
	gear = target;
};

~destroyControls = {
	// Start Stop button
	igniteBtn.destroy;
	rpmKnob.destroy;
	accelSlider.destroy;
	accelZeroLabel.destroy;
	accelLabel.destroy;
	brakeLabel.destroy;
	changeUp.destroy;
	changeDown.destroy;
	curGearLabel.destroy;
};

// Set formula1 parameters and synths
~formula1 = {
	burstFreq.set(\min, 1500 / 60); // min 1500 rpm
	burstFreq.set(\max, 2 * 18000 / 60); // max 18000 rpm
	lowHigh.set(\min, 0.4);
	lowHigh.set(\max, 1);
	engine.set(\lowBus, ~saw);
	engine.set(\highBus, ~filtered);
};

// Set formula1 parameters and synths
~harley = {
	burstFreq.set(\min, 700 / 60); // min 1000 rpm
	burstFreq.set(\max,  2 * 8000 / 60); // max 8000 rpm
	lowHigh.set(\min, 0.4);
	lowHigh.set(\max, 1);
	engine.set(\lowBus, ~brown);
	engine.set(\highBus, ~brown);
};


// Main update loop
~updateLoop = Routine.new({
	var factor;
	inf.do({
		if(accel > 0, { factor = 1; }, { factor = 3; });
		t = (t + (accel * factor * updateTime * accelScale)).clip(0,1);
		tSynth.set(\t, t);
		defer{rpmKnob.valueAction_(t)};
		if(accel > 0 && gear == 0, {
			~switchGear.(1);
		});
		if(accel < 0 && gear == 1 && t == 0, {
			~switchGear.(0);
		});
		updateTime.wait;
	})
});

// GUI
~initializeGUI = Routine.new({
	var screen, stethoscope;

	/*** GUI creation ***/

	// main container
	window = GUI.window.new("Progetto Ruben Caliandro", Rect(0,0,w,h)) ;
	screen = GUI.compositeView.new(window,Rect(0,0, w,h));
	stethoscope = Stethoscope.new(s, view:window.view);
	stethoscope.view.bounds = Rect(0,0,w,h);

	// main buttons
	~initializeMenuButtons.value;

	// Detect onClose and stop everything
	window.onClose = {
		~updateLoop.stop;
		~updateLoop.reset;
		~releaseEngine.value;
		stethoscope.free;
		s.freeAll;
		s.quit;
	};

	window.front;
});

~initRoutine.play(SystemClock);
)

Server.killAll;
s.plotTree;