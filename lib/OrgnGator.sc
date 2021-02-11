OrgnGator {
    var <constants;
    var <voice;
    var <all;
    var <local;
    var <target;
    var <addAction;

    var synthDef;
    var controlNames;
    var server;

    *new { arg server, synthDef, constantArgs = [], target, addAction;
        ^super.new.init(server, synthDef, constantArgs, target, addAction);
    }

    makebus { arg v;
        if(v.size == 0,
            {
                ^Bus.control(server, 1).setSynchronous(v)
            },{
                ^Bus.control(server, v.size).setnSynchronous(v)
            }
        );
    }

    init { arg s, sd, ca, t, aa;
        server = s;
        synthDef = sd;
        constants = ca;
        target = t;
        addAction = aa;

        voice = Dictionary.new;
        all = Dictionary.new;
        local = Dictionary.new;
        controlNames = List[];

        sd.allControlNames.do({ arg c, i;
            if(constants.indexOf(c.name).isNil, { controlNames.add(c) });
        });

        controlNames.do({ arg c;
            var v = c.defaultValue, n = c.name;
            all.put(n, this.makebus(v));
        });
    }

    localdict { arg id, name;
        if(local[id].isNil, { local.put(id, Dictionary.new) });
        if(local[id][name].isNil, {
            local[id].put(name, Dictionary.new);

            controlNames.do({ arg c;
                var v = c.defaultValue, n = c.name;
                if(n == name, { local[id].put(n, this.makebus(v)) });
            });
        })
    }

    getAll { arg id;
        var ret = Dictionary.new;
        all.keysValuesDo({ arg k, v; ret.add(k -> v.getnSynchronous(v.numChannels)) });
        if((id == \all).not, {
            local[id].keysValuesDo({ arg k, v; ret[k] = v.getnSynchronous(v.numChannels) })
        });
        ^ret;
    }

    get { arg name, id;
        ^this.getAll(id)[name];
    }

    //offset is 1-based !
    getAt { arg name, id, offset;
        ^this.get(name, id)[offset - 1];
    }

    setAt { arg name, id, offset ...vals;
        if(id == \all, {
            all[name].setnAt(offset - 1, vals);
        }, {
            this.localdict(id, name);
            local[id][name].setnAt(offset - 1, vals);
        });
    }

    set { arg name, id ...vals;
        if(id == \all, {
            all[name].setnSynchronous(vals);
        }, {
            this.localdict(id, name);

            local[id][name].setnSynchronous(vals);
            if((name == \gate) && (vals[0] > 0), {
                var init = this.getAll(id);
                var x = Synth.new(synthDef.name, init.getPairs ++ constants, target, addAction).register;

                if(voice[id].isPlaying, {
                    var killbus = Bus.control(server, 1).set(-1.1);
                    voice[id].map(\gate,  killbus);
                    voice[id].onFree({ killbus.free; });
                });
                all.keys.do({ arg name;
                    var bus = all[name];
                    if(local[id].notNil, {
                        if(local[id][name].notNil, { bus = local[id][name]; });
                    });
                    x.map(name, bus);
                });

                voice.put(id, x);
            });
        });
    }

    addCommands { arg engine, exclude = [];
        synthDef.allControlNames.do({ arg c;
            var l = c.numChannels, n = c.name;
            if(exclude.indexOf(n).isNil, {
                arg f = \s, cb = if(l > 1,
                    { f = f ++ \i; { arg msg; msg.removeAt(0); this.setAt(n, *msg) } },
                    { { arg msg; msg.removeAt(0); [n, msg].postln; this.set(n, *msg) } });

                //l.do({ f = f ++ \f; });
                f = f ++ \f;
                engine.addCommand(n, f, cb);
            });
        });
    }

    free {
        voice.do({ arg v;
            v.free;
        });
        
        all.do({ arg v;
            v.free;
        });
        
        local.do({ arg v;
            v.do({ arg w;
                w.free;
            });
        });
    }
}
