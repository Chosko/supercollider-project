s.boot;
s.scope;
s.freqscope;


// saw
({
	var freq = MouseX.kr(20,500);
	Array.fill(2, {
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
	})
}.play)

// modulated pulse
({
	var freq = MouseX.kr(20,500);
	var sig = SinOsc.ar(freq); // Put a sine in a variable
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
}.play)


// brown noise
({
	var freq = MouseX.kr(20,500);
	EnvGen.ar(
		envelope: Env.perc,            // Percussive envelope
		gate: Impulse.ar(freq: freq),  // Activated following the burst frequency
		doneAction: 0,
		timeScale: (freq).reciprocal   // The envelope terminates in a cycle
	) *
	LPF.ar(BrownNoise.ar,4000) // Low pass filter to avoid high-frequency noise
}.play)


// filtered noise
({
	var freq = MouseX.kr(20,500);
	EnvGen.ar(
		envelope: Env.perc,
		gate: Impulse.ar(freq: freq),
		doneAction: 0,
		timeScale: (freq).reciprocal
	) *
	LPF.ar(WhiteNoise.ar, 5000)
}.play)


// brown noise with karplus-strong
({
	var freq = MouseX.kr(20,500);
	Pluck.ar( // The Karplus-Strong algorithm is used to 'tune' the high-rate bursts (which is basically a noise)
		in: EnvGen.ar(
			envelope: Env.perc,            // Percussive envelope
			gate: Impulse.ar(freq: freq),  // Activated following the burst frequency
			doneAction: 0,
			timeScale: (freq).reciprocal   // The envelope terminates in a cycle
		) * LPF.ar(BrownNoise.ar,4000), // Low pass filter to avoid high-frequency noise
		trig: SinOsc.ar(freq: freq),        // Fill the table at the target frequency
		delaytime: (freq+1).reciprocal,     // delaytime and maxdelaytime are used to
		maxdelaytime: (freq+1).reciprocal,  // 'tune' the noise at almost the target frequency
		decaytime: 0.5,                     // decay is 0.5 seconds...
		coef: 0.2,                          // this value is taken empirically
		mul: 0.5
	);
}.play)


// filtered noise with karplus-strong
({
	var freq = MouseX.kr(20,500);
	Pluck.ar( // The Karplus-Strong algorithm is used to 'tune' the high-rate bursts (which is basically a noise)
		in: EnvGen.ar(
			envelope: Env.perc,
			gate: Impulse.ar(freq: freq),
			doneAction: 0,
			timeScale: (freq).reciprocal
		) *
		LPF.ar(WhiteNoise.ar, 5000), // Low pass filter to avoid high-frequency noise
		trig: SinOsc.ar(freq: freq),        // Fill the table at the target frequency
		delaytime: (freq+1).reciprocal,     // delaytime and maxdelaytime are used to
		maxdelaytime: (freq+1).reciprocal,  // 'tune' the noise at almost the target frequency
		decaytime: 0.5,                     // decay is 0.5 seconds...
		coef: 0.2,                          // this value is taken empirically
		mul: 0.5
	);
}.play)

// ignition signal 1
({
	var cFreq=600;
	var amFreq=100;
	var fmFreq=7;
	var fmAmp=200;
	var volume=1;

	// This function outputs a signal useful to apply FM to another signal
	var fmod = {|freq, amp|  // The amplitude of the FM
		LPF.ar( // Low-pass the signal to achieve a smoother FM
			in: Saw.ar(freq: freq) * -1,
			freq: freq * 2,
			mul: amp
		)
	};

	// This first signal is made with additive synthesis.
	Mix.fill(7, {|x| // Make a signal with 7 partials
		LPF.ar( // Low-pass filter everything to avoid noise
			in: Saw.ar(             // Each partial is actually a sawtooth.
				freq: cFreq * ((x+1) * 0.95) +        // 0.95 is used to avoid harmonicity between the partials
				fmod.(fmFreq, fmAmp),                 // Apply FM (as fmFreq is low, actually it's a vibrato)
				mul: 0.4 / (2+(x*x*x*x))              // Decrease the partial volume exponentially
			) * SinOsc.ar(amFreq, mul: 1).unipolar, // Apply AM to expand the spectrum
			freq: cFreq,            // Filter at the carrier frequency (smooth that saw!)
			mul: 10  // Adjust volume
		)
	})
}.play)

// ignition noise signal
({
	var cFreq=600;
	var amFreq=100;
	var fmFreq=7;
	var fmAmp=200;
	var volume=1;

	// This function outputs a signal useful to apply FM to another signal
	var fmod = {|freq, amp|  // The amplitude of the FM
		LPF.ar( // Low-pass the signal to achieve a smoother FM
			in: Saw.ar(freq: freq) * -1,
			freq: freq * 2,
			mul: amp
		)
	};

	// This second signal is made with subtractive synthesis, starting from a white noise
	BPF.ar( // Band Pass Filter is actually used to apply a sort of FM to the noise
		in: WhiteNoise.ar(mul: 5),                 // Should I really comment this line? come on....
		freq: (2*cFreq) + fmod.(fmFreq, fmAmp * 2),// Filter at double the carrier frequency, then FM! (vibrato)
		rq: 50.reciprocal,                         // bandwidth/cutoff is 1/50
		mul: 2                                     // Adjust volume
	)
}.play)
s.scope;
// shape of ignition FM signal
({
	LPF.ar( // Low-pass the signal to achieve a smoother FM
		in: Saw.ar(freq: 100) * -1,
		freq: 200,
		mul: 2
	)
}.play)

// ignition
({
	var cFreq=600;
	var amFreq=100;
	var fmFreq=7;
	var fmAmp=200;
	var signalAmount=0.5;
	var noiseAmount=0.5;
	var volume=1;

	// This function outputs a signal useful to apply FM to another signal
	var fmod = {|freq, amp|  // The amplitude of the FM
		LPF.ar( // Low-pass the signal to achieve a smoother FM
			in: Saw.ar(freq: freq) * -1,
			freq: freq * 2,
			mul: amp
		)
	};

	// Mix the two complex signals
	Mix([
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
	]) * [1,1]
}.play)