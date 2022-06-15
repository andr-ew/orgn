// toy keyboard inspired fm synth + lofi effects - effects will also process ADC in.

Engine_Orgn : CroneEngine {

	var <polyDef;
    var <fxDef;
    var <fxBus;
    var <fx;

    //TODO: raise polyphony and/or impliment voice stealing
	var <maxNumVoices = 16;

    var <ops = 3;
    var <tf;
    var <tfBuf;

	var <ctlBus; // collection of control busses
	var <gr; // parent group for voice nodes
	var <voices; // collection of voice nodes

	*new { arg context, callback;
		^super.new(context, callback);
	}

	alloc {
        var batchformat = '';

        //contols not to map to control busses (i.e. these are either unique for each voice or constants)
        var doNotMap = [\gate, \glideGate, \hz, \outbus, \pan, \velocity];

        //fm synth synthdef - number of operators is set by ops
        polyDef = SynthDef.new(\fm, {

            //named controls (inputs) - many are multichannel (channel per operator).
            var gate = \gate.kr(1), glideGate = \glideGate.kr(1), pan = \pan.kr(0), hz = \hz.kr([440, 440, 0]),
            amp = \amp.kr(Array.fill(ops, { arg i; 1/(2.pow(i)) })), vel = \velocity.kr(1),
            ratio = \ratio.kr(Array.fill(ops, { arg i; (2.pow(i)) })),
            mod = Array.fill(ops, { arg i; NamedControl.kr(\mod ++ i, 0!ops) }),
        	a = \attack.kr(0.001!ops), d = \decay.kr(0!ops), s = \sustain.kr(1!ops),
            r = \release.kr(0.2!ops), curve = \curve.kr(-4),
            done = \done.kr(1!ops); // done needs to be set based on release times (longest relsease channel gets a 1)

            //hz envelope (for glides)
            var start = hz[0], end = hz[1], dur = hz[2];
            var glide = EnvGen.kr(Env.pairs([[0, start], [dur, end]], \exp), glideGate, doneAction: 0);
            var frq = glide * Lag.kr(\pitch.kr(1), \pitch_lag.kr(0.1));
            //var frq = hz[1] * Lag.kr(\pitch.kr(1), \pitch_lag.kr(0.1));

            //the synth sound (3 lines!!!)
        	var env = EnvGen.kr(Env.adsr(a, d, s, r, 1, curve), gate, doneAction: (done * 2)); //adsr envelopes
        	var osc = SinOsc.ar(frq * ratio, Mix.ar(LocalIn.ar(ops) * mod)) * env; //oscs from the last cycle phase modulate current cycle
        	LocalOut.ar(osc); //send oscs to the nest cycle

        	//pan/amp/output
            Out.ar(\outbus.kr(0), Pan2.ar(Mix.ar((osc / ops) * amp * vel * 0.15), pan));
        }).add;

        //group for voices
        gr = ParGroup.new(context.xg);

        //analog waveshaper table by @ganders
        tf = (Env([-0.7, 0, 0.7], [1,1], [8,-8]).asSignal(1025) + (
            Signal.sineFill(
                1025,
                (0!3) ++ [0,0,1,1,0,1].scramble,
                    {rrand(0,2pi)}!9
                )/10;
        )).normalize;
        tfBuf = Buffer.loadCollection(context.server, tf.asWavetableNoWrap);

        context.server.sync;

        //ulaw synthdef
        fxDef = SynthDef.new(\ulaw, {
            var in = Mix.ar([
                In.ar(\inbus.kr(), 2),
                XFade2.ar(
                    SoundIn.ar([0,1]),
                    SoundIn.ar(0!2),
                    (\adc_mono.kr(0)*2) - 1
                ) * \adc_in_amp.kr(0)
            ]),
            steps = 2.pow(\bits.kr(11)), r = 700,
            samps = Lag.kr(\samples.kr(26460), \samples_lag.kr(0.02));
            var sig = in;
            var mu = steps.sqrt;

            sig = Mix.ar([
                sig,
                EnvFollow.ar(in, 0.99)* Mix.ar([
                    GrayNoise.ar(1) * Dust.ar(\dustiness.kr(1.95)) * \dust.kr(1), //add dust
                    Crackle.ar(((\crinkle.kr(0)*0.25) + 1.75 )) * \crackle.kr(0.1) //add crackle
                ])
            ]);
            // sig = LPF.ar(sig, samps/2); //anti-aliasing filter
            sig = Compander.ar(sig, sig, //limiter/compression
                thresh: 1,
                slopeBelow: 1,
                slopeAbove: 0.5,
                clampTime:  0.01,
                relaxTime:  0.01
            );
            sig = Decimator.ar(sig, samps, 31); //sample rate reduction

            //noisy bitcrushing
            sig = sig.sign * log(1 + (mu * sig.abs)) / log(1 + mu);
            sig = (
                (sig.abs * steps) + (
                    \bitnoise.kr(0.5) * GrayNoise.ar()
                    * (0.25 + CoinGate.ar(0.125, Dust.ar()!2))
                )
            ).round * sig.sign / steps;
            sig = sig.sign / mu * ((1+mu)**(sig.abs) - 1);

            sig = Slew.ar(sig, r, r); //filter out some rough edges

            //waveshaper drive (using the tf wavetable)
            sig = XFade2.ar(sig,
                Shaper.ar(tfBuf, sig), (\drive.kr(0.025)*2) - 1
            );

            Out.ar(\outbus.kr(0), XFade2.ar(in, sig, (\drywet.kr(0.25)*2) - 1)); //drywet out
        }).add;

        //ulaw synth & bus
        fxBus = Bus.audio(context.server, 2);
        context.server.sync;

        fx = Synth.new(\ulaw, args: [\inbus, fxBus], addAction: \addToTail);

        context.server.sync;

        //create voices dict
		voices = Dictionary.new;

        //create / initialize control busses
		ctlBus = Dictionary.new;
		polyDef.allControlNames.do({ arg ctl;
			var name = ctl.name, value = ctl.defaultValue;

			postln("control name: " ++ name);

			if(doNotMap.indexOf(name).isNil, {
                if(value.size == 0,
                    {
                        ctlBus.add(name -> Bus.control(context.server, 1));
                        ctlBus[name].set(value);
                    },{
                        ctlBus.add(name -> Bus.control(context.server, value.size));
                        ctlBus[name].setn(value);
                    }
                );

			});
		});

		ctlBus.postln;

		//--------------
		//--- voice control, all are indexed by arbitarry ID number
		// (voice allocation should be performed by caller)

		// start a new voice. args: id, hz, velocity, pan
		this.addCommand(\noteOn, "ifff", { arg msg;
            var id = msg[1], start = msg[2], end = msg[2], dur = 0, vel = msg[3], pan = msg[4];
            this.addVoice(id, [start, end, dur], vel, pan);
		});

        // start a new voice w/ a glide envelope. args: id, start hz, end hz, glide duration, velocity, pan
		this.addCommand(\noteGlide, "ifffff", { arg msg;
            var id = msg[1], start = msg[2], end = msg[3], dur = msg[4], vel = msg[5], pan = msg[6];
            this.addVoice(id, [start, end, dur], vel, pan);
		});

		// stop a voice. args: id
		this.addCommand(\noteOff, "i", { arg msg;
			this.removeVoice(msg[1]);
		});

        // start a new voice + release after specified duration. args: id, hz, velocity, pan, duration
        this.addCommand(\noteTrig, "iffff", { arg msg;
            var id = msg[1], start = msg[2], end = msg[2], dur = 0, vel = msg[3], pan = msg[4], delay = msg[5];
            Routine {
                this.addVoice(id, [start, end, dur], vel, pan);
                delay.max(0.01).yield;
                this.removeVoice(id);
            }.play
        });

        // start a new voice + release after specified duration w/ glide envelope. args: id, start hz, end hz, glide duration, velocity, pan, duration
        this.addCommand(\noteTrigGlide, "iffffff", { arg msg;
            var id = msg[1], start = msg[2], end = msg[3], dur = msg[4], vel = msg[5], pan = msg[6], delay = msg[7];
            Routine {
                this.addVoice(id, [start, end, dur], vel, pan);
                delay.max(0.01).yield;
                this.removeVoice(id);
            }.play
        });

		// free all synths
		this.addCommand(\stopAll, "", {
			gr.set(\gate, 0);
			voices.clear;
		});

		// generate commands to set each control bus
        polyDef.allControlNames.do({ arg c;
            var l = c.numChannels, name = c.name;
            if((doNotMap ++ [\mod0, \mod1, \mod2, \done, \release]).indexOf(name).isNil, {
                arg f = \,
                cb = if(l > 1, {
                    f = f ++ \i;
                    { arg msg;
                        var idx = msg[2];
                        msg.removeAt(0);
                        msg.removeAt(0);

                        ctlBus[name].setAt(idx - 1, *msg)
                    }
                },
                {
                    { arg msg;
                        msg.removeAt(0);
                        ctlBus[name].setSynchronous(*msg)
                    }
                });

                //l.do({ f = f ++ \f; });
                f = f ++ \f;
                this.addCommand(name, f, cb);
            });
        });

        //combine mod0/mod1/mod2 into a single mod command
        this.addCommand(\mod, \iif, { arg msg;
            var modulator = msg[2], carrier = msg[1], amt = msg[3];

            ctlBus[(\mod ++ (carrier - 1)).asSymbol].setAt(modulator - 1, amt);
        });

        //the release command must manually set the doneAction for each operator via \done
        this.addCommand(\release, \if, { arg msg;
            var idx = msg[1], amt = msg[2];

            ctlBus[\release].setAt(idx - 1, amt);
            this.updateDone();
        });

        ops.do({ batchformat = batchformat ++ \f; });

        //set a control for all operators in one go
        this.addCommand(\batch, \s ++ batchformat, { arg msg;
            var name = msg[1].asSymbol;
            msg.removeAt(0);
            msg.removeAt(0);

            if(ctlBus[name].notNil, {
                msg.postln;
                ctlBus[name].setSynchronous(*msg);

                if(name == \release, { this.updateDone(); });
            });
        });

        //auto-add fx commands
        fxDef.allControlNames.do({ arg c;
            var n = c.name;
            if((n != \inbus) && (n != \outbus), { this.addCommand(n, \f, { arg msg; fx.set(n, msg[1]) })});
        });

        //print synth default values - will be useful when I'm making the controlspecs
        "synth control defaults:".postln;
        (polyDef.allControlNames ++ fxDef.allControlNames).do({ arg c;
            [c.name, c.defaultValue].postln;
        });
	}

    //start a new voice at an id
	addVoice { arg id, hz, vel, pan;
        var params = List.with(\outbus, fxBus, \hz, hz, \velocity, vel, \pan, pan);
		var numVoices = voices.size;

		if(voices[id].notNil, {
            //behavior: retrigger glide envelope, don't retrigger operator envelopes
            Routine {
                voices[id].set(\gate, 1);
                voices[id].set(\hz, hz);
                voices[id].set(\glideGate, -1);
                context.server.sync;

                voices[id].set(\glideGate, 1);
            }.play
		}, {
			if(numVoices < maxNumVoices, {
				ctlBus.keys.do({ arg name;
					params.add(name);
                    params.add(ctlBus[name].getnSynchronous(ctlBus[name].numChannels));
				});

                voices.add(id -> Synth.new(\fm, params, gr));
				NodeWatcher.register(voices[id]);
				voices[id].onFree({
					voices.removeAt(id);
				});

                ctlBus.keys.do({ arg name;
                    voices[id].map(name, ctlBus[name]);
                });
			});
		});
	}

    //remove voice at id
	removeVoice { arg id;
        voices[id].set(\gate, 0);
	}

    //update which envelope frees the voice (the longest one)
    updateDone {
        var rel = ctlBus[\release].getnSynchronous(ctlBus[\release].numChannels);
        var done = 0!(rel.size);
        var max = 0, idx = 0;

        rel.do({ arg v, i; if(v > max, { max = v; idx = i; }) });
        done[idx] = 1;

        ctlBus[\done].setSynchronous(*done);
    }

	free {
		gr.free;
		ctlBus.do({ arg bus, i; bus.free; });
        fx.free;
		fxBus.free;
        tfBuf.free;
	}
}
