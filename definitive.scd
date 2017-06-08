/*
************************
PROGETTO EDAM
Author: Ruben Caliandro
***********************

DESCRIPTION

This Project simulates two vehicles engines.
In the main menu you can choose between a formula1 vehicle, or a bike.
After you choose, you can ignite the engine, and then you are allowed to
accelerate, brake and change gears.

USAGE

The code is written in a single block. Just run it at once.
The code will already boot the server if needed.
*/

// Run This
(
/***** Local variables *****/
// Sound variables
var updateTime;     // The time interval at which parameters are updated
var tSynth;         // A reference to the Synth 'tSynth', which is instantiated once
var burstFreq;      // A reference to the Synth 'burstFreq', which is instantiated once
var engine;         // A reference to the Synth 'engine', which is instantiated once
var lowHigh;        // A reference to the Synth 'lowHigh', which is instantiated once
var t;              // The t parameter controls the burst frequency of the engine. It's normalized in [0,1]
var accel;          // The accel parameter controls the current acceleration of the vehicle. It's normalized in [0,1]
var filtered;       // A reference to the Synth 'filteredNoise', which is instantiated once
var brown;          // A reference to the Synth 'brownNoise', which is instantiated once
var saw;            // A reference to the Synth 'saw', which is instantiated once
var gear;           // The gear parameter contains the current engine gear, from 0 (N) to 6
var modulatedPulse; // A reference to the Synth 'modulatedPulse', which is instantiated once
var tOffset;        // This parameter is an amount in [0,1] used to variate the burst frequency at ignition time
var accelScale;     // This parameter tells how much 'accel' changes 't' each second

// GUI variables
var window, igniteBtn, rpmKnob, accelSlider,
accelZeroLabel, accelLabel, brakeLabel, curGearLabel,
menuBtnFormula1, menuBtnBike, menuText, changeDown, changeUp;

// Window size
var w = 1024; // Width of the window in pixels
var h = 768;  // Height of the window in pixels

/***** Initialization routine *****/
~initRoutine = Routine.new({ // Start everything in a routine

	s.boot;      // Boot the server
	1.wait;      // Wait for the server to start
	s.freqscope; // Show a freqscope



	/***** Busses *****/

	// This project makes a large use of busses. The idea is that all the Synths
	// continuously output in the busses...
	// The difference between engines is how they use busses (other than different parameter tuning)
	~saw = Bus.audio(s, 2);            // A channel with a sawtooth signal with percussive envelope
	~brown = Bus.audio(s, 2);          // A brown noise enveloped percussively
	~modulatedPulse = Bus.audio(s, 2); // An amplitude modulated pulse
	~filtered = Bus.audio(s, 2);       // A Low Pass filtered white noise enveloped percussively
	~t = Bus.control(s, 2);            // RPM of the engine, normalized in the interval [0,1]
	~lowHigh = Bus.control(s, 1);      // Parameter in [0,1], used to mix sounds between low and high RPM synthesis
	~freq = Bus.control(s, 1);         // Frequence of engine bursts



	/***** SynthDefs *****/

	/** t **/
	// Just output the parameter t to a control bus
	SynthDef(\t, {|out=2, t=0|
		Out.kr(out, t);
	}).add;


	/** burstFreq **/
	// Generate a control signal that represents the absolute frequency of the engine bursts
	// -- ARGS --
	// out: the output bus
	// min: the minimum output frequency, when the engine is idle
	// max: the maximum output frequency, when the engine is running at max speed
	// t: a [0,1] paramter used to lerp from 'min' to 'max'
	SynthDef(\burstFreq, {|out = 2, min = 10, max = 500, t = 0|
		Out.kr(out,
			LFNoise0.kr( // The output is perturbed with a low frequency noise, to achieve irregular burst frequency (especially at low rates)
				add: t.linlin(0,1,min,max),        // t.linlin(0,1,min,max) is the target frequency. We start from it
				mul: t.linlin(0.1,1,6,10),          // The current frequency affects the amount of noise
				freq: t.linlin(0,1,min,max) * 0.25 // Update the noise a quarter times the burst frequency (so that we always have at least 4 bursts at the same rate)
			)
		)
	}).add;

	/** lowHigh **/
	// Remap the engine normalized frequency (t) to an amount of low/high engine sound synthesis.
	// The output will be used to lerp between two sounds:
	// one for the low rate bursts and another for the high rate bursts
	// -- ARGS --
	// out: the output bus
	// min: the minimum output value, when the engine is idle
	// max: the maximum output value, when the engine is running at max speed
	// t: a [0,1] paramter used to lerp from 'min' to 'max'
	SynthDef(\lowHigh, {|out = 2, min = 0, max = 1, t = 0|
		Out.kr(out, t.linlin(min,max,0,1)); // Just a simple remapping
	}).add;

	/** saw **/
	// Although the name seams easy, this is not a simple sawtooth signal.
	// This is used for the low-frequency bursts of the formula 1 engine
	// -- ARGS --
	// out: the output bus
	// freq: the main (carrier) frequency of the signal
	SynthDef(\saw, {|out = 0, freq = 20|
		Out.ar(out, Array.fill(2, {
			LPF.ar( // Low pass filter the signal, mainly to avoid clicks
				EnvGen.ar( // This envelope is not used normally, but it adds many partials to the signal
					envelope: Env.perc,                // Percussive envelope
					gate: Impulse.ar(freq: freq * 4),  // Apply the envelope 4 times per cycle
					doneAction: 0,
					timeScale: (freq).reciprocal       // The envelope lasts for an entire cycle, so the
					                                   // result of the 4 evnvelopes summed up is a percussive
					                                   // signal that never reaches 0
				) *
				Saw.ar( // The main signal is a sawtooth
					freq: freq,
					mul: SinOsc.ar(0.25 * freq).unipolar // AM in order to expand the spectrum of the signal
				),
				freq.linlin(10,200,2000,10000), // The threshold frequency depends on the current frequency
			)
		}))
	}).add;

	/** modulatedPulse **/
	// Similar to saw, but starting from a Pulse signal and a power of sines.
	// It's used for the low-frequency bursts of the bike engine
	// -- ARGS --
	// out: the output bus
	// freq: the main (carrier) frequency of the signal
	SynthDef(\modulatedPulse, { |out=0, freq = 20|
		var sig = SinOsc.ar(freq); // Put a sine in a variable
		Out.ar(
			out,
			EnvGen.ar( // This behaves differently from 'saw': it's an actual envelope
				envelope: Env.perc,             // Percussive envelope
				gate: Impulse.ar(freq: freq*2), // two envelopes per cycle
				doneAction: 0,
				timeScale: (freq*2).reciprocal // An evelope lasts half of a cycle:
				                               // it reaches 0 before the next envelope starts
			) *
			(sig.pow(100/freq) - 0.7).clip(0,1) * 10 *  // The main signal is achieved clipping
			                                            // the positive spikes of a sine power
			LPF.ar(Pulse.ar(freq*2), freq*6, mul: 3) *  // The pulse is used mainly to add harmonics
			                                            // to the signal, and to pull the signal
			                                            // (which is unipolar) also below 0
			SinOsc.ar(freq * 0.66).unipolar;  // Finally, AM expands the spectrum
		);
	}).add;

	/** brownNoise **/
	// A filtered and percussively enveloped brown noise.
	// It's used for the high-frequency bursts of the bike engine.
	// Although it's enveloped with the target frequency, the output doesn't
	// actually have a 'pitch'
	// -- ARGS --
	// out: the output bus
	// freq: the main frequency of the signal
	SynthDef(\brownNoise, {|out = 0, freq = 2|
		Out.ar(out, Array.fill(2, {
			EnvGen.ar(
				envelope: Env.perc,            // Percussive envelope
				gate: Impulse.ar(freq: freq),  // Activated following the burst frequency
				doneAction: 0,
				timeScale: (freq).reciprocal   // The envelope terminates in a cycle
			) *
			LPF.ar(BrownNoise.ar,4000) // Low pass filter to avoid high-frequency noise
		}))

	}).add;

	/** filteredNoise **/
	// A filtered and percussively enveloped white noise.
	// It's used for the high-frequency bursts of the formula1 engine
	// Although it's enveloped with the target frequency, the output doesn't
	// actually have a 'pitch'
	// -- ARGS --
	// out: the output bus
	// freq: the main frequency of the signal
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

	/** engine **/
	// This is the actual engine Synth. It collects sounds and controls from other
	// busses and mix them together in the output bus (out to the speakers)
	// -- ARGS --
	// out:     the output bus
	// freq:    the main frequency of the signal
	// lowBus:  an input bus containing the low-rate bursts sound
	// highBus: an input bus containing the high-rate bursts sound (to be processed)
	// lowHigh: a lerp parameter used to mix inputs between lowBus and highBus
	// lowVol:  the maximum 'volume' of the low-rate bursts sound
	// highVol: the maximum 'volume' of the high-rate bursts sound
	// volume:  the output 'volume'
	SynthDef(\engine, {|out = 0, freq = 20, lowBus=2, highBus=2, lowHigh = 0, lowVol=1, highVol=1, volume=1|
		Out.ar(out,
			Mix.ar([ // Mix low-rate and high-rate busses
				In.ar(lowBus, 1) * (1.0 - lowHigh) * [lowVol,lowVol], // low-rate sound is left unchanged. Just adjusting volumes
				Pluck.ar( // The Karplus-Strong algorithm is used to 'tune' the high-rate bursts (which is basically a noise)
					in: In.ar(highBus, 2),              // The input taken from the bus
					trig: SinOsc.ar(freq: freq),        // Fill the table at the target frequency
					delaytime: (freq+1).reciprocal,     // delaytime and maxdelaytime are used to
					maxdelaytime: (freq+1).reciprocal,  // 'tune' the noise at almost the target frequency
					decaytime: 0.5,                     // decay is 0.5 seconds...
					coef: 0.2,                          // this value is taken empirically
					mul: lowHigh * highVol              // adjust volume
				)
			]) * volume;  // adjust output volume
		)
	}).add;

	/** ignition **/
	// The ignition sound. Although it took a lot of time to do this, it's not as good as I expected..
	// It's made partially with additive synthesis and partially with subtractive synthesis.
	// -- ARGS --
	// out:     the output bus
	// cFreq:   the main (carrier) frequency of the signal
	// amFreq:  the frequency of an AM applied to the signal
	// fmFreq:  the frequency of a FM applied to the signal
	// fmAmp:   the amplitude of a FM applied to the signal
	// signalAMount:  the maximum 'volume' of the low-rate bursts sound
	// highVol: the maximum 'volume' of the high-rate bursts sound
	// volume:  the output 'volume'
	SynthDef(\ignition, {|out=0, cFreq=600, amFreq=100, fmFreq=7, fmAmp=100, signalAmount=0.5, noiseAmount=0.5, volume=1|
		// This function outputs a signal useful to apply FM to another signal
		var fmod = {|freq, amp|  // The amplitude of the FM
			LPF.ar( // Low-pass the signal to achieve a smoother FM
				in: Saw.ar(freq: freq) * -1,
				freq: freq * 2,
				mul: amp
			)
		};

		Out.ar(out,
			// Mix the two complex signals
			Mix(
				[
					// This first signal is made with additive synthesis.
					Mix.fill(7, {|x| // Make a signal with 7 partials
						LPF.ar( // Low-pass filter everything to avoid noise
							in: Saw.ar(             // Each partial is actually a sawtooth.
								freq: cFreq * ((x+1) * 0.95) +        // 0.95 is used to avoid harmonicity between the partials
								fmod.(fmFreq, fmAmp),                 // Apply FM (as fmFreq is low, actually it's a vibrato)
								mul: 0.4 / (2+(x*x*x*x))              // Decrease the partial volume exponentially
							) * SinOsc.ar(amFreq, mul: 1).unipolar, // Apply AM to expand the spectrum
							freq: cFreq,            // Filter at the carrier frequency (smooth that saw!)
							mul: 10 * signalAmount  // Adjust volume
						)
					}),

					// This second signal is made with subtractive synthesis, starting from a white noise
					BPF.ar( // Band Pass Filter is actually used to apply a sort of FM to the noise
						in: WhiteNoise.ar(mul: 5),                 // Should I really comment this line? come on....
						freq: (2*cFreq) + fmod.(fmFreq, fmAmp * 2),// Filter at double the carrier frequency, then FM! (vibrato)
						rq: 50.reciprocal,                         // bandwidth/cutoff is 1/50
						mul: 2 * noiseAmount                       // Adjust volume
					)
				]
			) *
			[volume,volume] // Multichannel expansion!
		)
	}).add;

	1.wait; // Wait for server to receive SynthDefs

	~initializeGUI.play(AppClock); // Then initialize GUI
});
// ~initRoutine END



/***** Functions and routines *****/

// Initialize variables, synths and bus mappings
~initializeEngine = {
	// Initialize variables
	updateTime = 0.01;
	t = 0;
	accel = 0;

	// Initialize all the engine synths
	tSynth = Synth(\t, [\out, ~t]);
	burstFreq = Synth(\burstFreq, [\out, ~freq]);
	burstFreq.map(\t, ~t);
	lowHigh = Synth(\lowHigh, [\out, ~lowHigh]);
	lowHigh.map(\t, ~t);
	saw = Synth(\saw, [\out, ~saw]);
	saw.map(\freq, ~freq);
	brown = Synth(\brownNoise, [\out, ~brown]);
	brown.map(\freq, ~freq);
	modulatedPulse = Synth(\modulatedPulse, [\out, ~modulatedPulse]);
	modulatedPulse.map(\freq, ~freq);
	filtered = Synth(\filteredNoise, [\out, ~filtered]);
	filtered.map(\freq, ~freq);
	engine = Synth(\engine, [\lowBus, ~brown, \highBus, ~brown, \volume, 0], addAction:\addToTail);
	engine.map(\freq, ~freq);
	engine.map(\lowHigh, ~lowHigh);
};


// Release everything
~releaseEngine = {
	// free synths
	tSynth.free;
	burstFreq.free;
	lowHigh.free;
	saw.free;
	brown.free;
	modulatedPulse.free;
	filtered.free;
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

	menuBtnBike = GUI.button.new(window, Rect((2*w/3)-150,h/2 - 25,100,50)).states_([
		["Motorbike",Color.black,Color.white]
	]);
	menuBtnBike.action = {|x|
		~destroyMenuButtons.value;
		~initializeControls.value;
		~initializeBikeControls.value;
	};
};

~destroyMenuButtons = {
	menuText.destroy;
	menuBtnFormula1.destroy;
	menuBtnBike.destroy;
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
			~ignition.reset;
			~ignition.play(TempoClock);
		});
	};
};

~initializeBikeControls = {
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
			~bike.value;
			~updateLoop.reset;
			~updateLoop.play(SystemClock);
			~ignition.reset;
			~ignition.play(TempoClock);
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
	rpmKnob = Knob(window, Rect(w/2 - 100, h/2 - 70, 200, 200))
	.color_([Color.black, Color.white, Color.white, Color.yellow]);


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
	burstFreq.set(\min, 2 * 1000 / 60); // min 1000 rpm
	burstFreq.set(\max, 2 * 18000 / 60); // max 18000 rpm
	lowHigh.set(\min, 0.3);
	lowHigh.set(\max, 2);
	engine.set(\lowBus, ~saw);
	engine.set(\highBus, ~filtered);
	engine.set(\lowVol, 0.5);
	engine.set(\highVol, 1);
	engine.set(\volume, 0);
	tOffset = 0.1;
};

// Set formula1 parameters and synths
~bike = {
	burstFreq.set(\min, 2 * 1200 / 60); // min 1000 rpm
	burstFreq.set(\max,  2 * 8000 / 60); // max 8000 rpm
	lowHigh.set(\min, 0.2);
	lowHigh.set(\max, 2);
	engine.set(\lowBus, ~modulatedPulse);
	engine.set(\highBus, ~brown);
	engine.set(\lowVol, 0.7);
	engine.set(\highVol, 0.2);
	engine.set(\volume, 0);
	tOffset = 0.3;
};

~ignition = Routine.new({
	var updateInterval = 0.01;
	var ignitionDuration = 1 + 1.rand;
	var ignitionVolume = 0.5;
	var engineDuration = 0.3;
	var engineDelay = ignitionDuration - engineDuration;
	var engineSteps = engineDuration/updateInterval;
	var tDuration = 1.2;
	var tSteps = tDuration/updateInterval;

	var ignition = Synth(\ignition, [
		\out, 0,
		\cFreq, 600,
		\amFreq, 100,
		\fmFreq, 7,
		\fmAmp, 200,
		\signalAmount, 0.5,
		\noiseAmount, 0.5,
		\volume, ignitionVolume
	]);

	engine.set(\volume, 0);

	engineDelay.wait;
	engineSteps.do {|x|
		engine.set(\volume, (x+1)/engineSteps);
		t = tOffset * (x+1)/engineSteps;
		updateInterval.wait;
	};
	ignition.set(\volume, 0);
	ignition.free;

	tSteps.do {|x|
		t = tOffset * (tSteps-x+1)/tSteps;
		updateInterval.wait;
	}
});

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
	var screen, stethoscope, freqscope;

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
		freqscope.free;
		s.freeAll;
		s.quit;
	};

	window.front;
});

~initRoutine.play(SystemClock); // Initialize everything
)
