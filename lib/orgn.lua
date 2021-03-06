--TODO
--add noteCycle, noteCyleGlide
--add env 'cyle' mode

local cs = require 'controlspec'

local ops = { 'a', 'b', 'c' }
local orgn = { params = {} }

local ids = {}
local vc = 'all'
local cb = function(id, v) end

-- adsr mixer object
local adsr = { a = {}, d = {}, s = {}, r = {}, c = -4, min = 0.001,
    update = function(s, ds)
        engine.batch('attack', vc, table.unpack(s.a))
        if s.ds then
            engine.batch('decay', vc, table.unpack(s.d))
            engine.batch('sustain', vc, table.unpack(s.s))
        end
        engine.batch('release', vc, table.unpack(s.r))
        engine.curve(vc, s.c)
    end
}
for i, op in ipairs(ops) do
    adsr.a[i] = 0.001
    adsr.d[i] = 0
    adsr.s[i] = 1
    adsr.r[i] = 0.2
end

local pitch = {
    off = 0,
    mod = 0,
    update = function(s)
        engine.pitch(vc, 2^(s.off) + s.mod/2)
    end
}
local lfo = { 
    rate = 0.4, mul = 0, phase = 0, quant = 0.01,
    shape = function(p) return math.sin(2 * math.pi * p) end,
    action = function(v)
        pitch.mod = v; pitch:update()
    end,
    init = function(s)
        clock.run(function()
            while true do
                clock.sleep(s.quant)

                local T = 1/s.rate
                local d = s.quant / T
                s.phase = s.phase + d
                while s.phase > 1 do s.phase = s.phase - 1 end

                s.action(s.shape(s.phase) * s.mul)
            end
        end)
    end
}

orgn.init = function()
    lfo:init()
end

local last = 440
local glide = 0
local spread = 0
local mode = 'sustain'

orgn.noteOn = function(id, hz, vel)
    -- engine.pan(<note id>, math.random()*2*spread - 1)
    
    local function hz2st(h) return 12*math.log(h/440, 2) end
    local d = hz2st(hz) - hz2st(last)
    d = util.linexp(0, 76, 0.01, 0.8, math.abs(d))
    local t = glide 
        + (math.random() * 0.2) 
        + ((d < math.huge) and d or 0)

    if mode == 'sustain' and glide <= 0 then
        engine.noteOn(id, hz, vel)
    elseif mode == 'sustain' and glide > 0 then
        engine.noteGlide(id, last, hz, t, vel)
    elseif mode == 'transient' and glide <= 0 then
        engine.noteTrig(id, hz, vel, math.max(adsr.a[1], 0.01))
    elseif mode == 'transient' and glide > 0 then
        engine.noteTrigGlide(id, last, hz, t, vel, adsr.a[1])
    end

    last = hz
end
orgn.noteOff = function(id)
    if mode == 'sustain' then
        engine.noteOff(id)
    end
end

-- param:add wrapper with some shortcuts
local function ctl(arg)
    arg.id = arg.id or string.gsub(arg.name, ' ', '_')
    if vc ~= 'all' then arg.id = arg.id .. '_' .. vc end
    arg.type = arg.type or 'control'

    local a = arg.action or function() end
    arg.action = function(v) 
        a(v)
        cb(arg.id, v)
    end

    params:add(arg)
    table.insert(ids, arg.id)
end

-- voice:
-- 'all': add param control over all voices (for using the engine as a single polysynth)
-- <number>: add params for this voice only
--
-- env:
-- 'asr': control over attack & release
-- 'adsr': full control of the adsr envelope
--
-- envstyle:
-- 'linked': single controls with span across operators
-- 'independent': unique control per-operator
--
-- callback: runs at the end of evey action function (args: id, value)
orgn.params.synth = function(voice, env, envstyle, callback)
    voice = voice or 'all'
    env = env  or 'asr'
    envstyle = envstyle or 'linked'

    ids = {}
    cb = callback or cb
    
    vc = voice

    --mixer objects
    local ratio = { 1, 2, 4,
        dt = 0,
        update = function(s)
            local r = {}
            for i, op in ipairs(ops) do 
                local dt =  2^(s.dt * (i-1))
                r[i] = s[i] * dt
            end
            engine.batch('ratio', vc, table.unpack(r))
        end
    }
    local amp = { 1, 0.5, 0.25,
        l = 0,
        update = function(s)
            local a = {}
            for i, op in ipairs(ops) do 
                a[i] = util.dbamp(s.l) * s[i]
            end
            engine.batch('amp', vc, table.unpack(a))
        end
    }

    params:add_separator('synth')
    ctl {
        name = 'level',
        controlspec = cs.new(-math.huge, 6, 'db', nil, amp.l, 'dB'),
        action = function(v)
            amp.l = v
            amp:update()
        end
    }
    ctl {
        name = 'pitch',
        controlspec = cs.def {
            min = -1, max = 1
        },
        action = function(v)
            pitch.off = v
            pitch:update()
        end
    }
    ctl {
        name = 'detune',
        controlspec = cs.def { quant = 0.01/10, step = 0 },
        action = function(v)
            ratio.dt = v
            ratio:update()
        end
    }
    ctl {
        name = 'glide',
        controlspec = cs.def { units = 's' },
        action = function(v) glide = v end
    }
    ctl {
        name = 'spread',
        controlspec = cs.new(),
        action = function(v) spread = v end
    }


    params:add_separator('env')

    local ds = env == 'adsr'
    local cstime = cs.new(0.001, 6, 'exp', 0, 0.2, "s")

    if envstyle == 'linked' then

        -- env mixer
        local emx = {
            time = 0.2, ramp = 1, curve = -4, span = 0, sustain = 0.75, 
            update = function(s)
                for i, op in ipairs(ops) do
                    local j = i - 2
                    local a, r
                    if s.ramp > 0 then
                        r = s.time
                        a = s.time * (1 - s.ramp)
                    else
                        r = s.time * (1 - s.ramp)
                        a = s.time
                    end

                    adsr.a[i] = math.max(a * (1 + j*math.abs(s.span)), adsr.min)
                    adsr.d[i] = math.max(r * (1 + j*s.span), adsr.min)
                    adsr.s[i] = s.sustain * (1 + j*s.span)
                    adsr.r[i] = math.max(r * (1 + j*s.span), adsr.min)
                end

                adsr:update(ds)
            end
        }

        ctl {
            name = 'time',
            controlspec = cstime,
            action = function(v) emx.time = v; emx:update() end
        }
        ctl {
            name = 'ramp',
            controlspec = cs.def { min = -1, max = 1, default = 1 },
            action = function(v) emx.ramp = v; emx:update() end
        }
        if ds then
            ctl {
                name = 'sustain',
                controlspec = cs.new(),
                action = function(v) emx.sustain = v; emx:update() end
            }
        else
            local mop = { 'sustain', 'transient' }
            ctl {
                name = 'mode', type = 'option', options = mop,
                action = function(v)
                    mode = mop[v]
                end
            }
        end
        ctl {
            name = 'span',
            controlspec = cs.def { min = -1, max = 1, default = 0 },
            action = function(v) emx.span = v; emx:update() end
        }
        ctl {
            name = 'curve',
            controlspec = cs.def { min = -8, max = 8, default = -4 },
            action = function(v) emx.curve = v; emx:update() end
        }

    else
        for i, op in ipairs(ops) do
            ctl {
                name = 'attack ' ..op,
                controlspec = cstime,
                action = function(v) adsr.a = v; adsr:update() end
            }
            if ds then
                ctl {
                    name = 'decay ' ..op,
                    controlspec = cstime,
                    action = function(v) adsr.d = v; adsr:update() end
                }
                ctl {
                    name = 'sustain',
                    controlspec = cs.new(),
                    action = function(v) adsr.s = v; adsr:update() end
                }
            end
            ctl {
                name = 'release ' ..op,
                controlspec = cstime,
                action = function(v) adsr.r = v; adsr:update() end
            }
        end
    end
    
    params:add_separator('lfo')
    ctl {
        name = 'depth', controlspec = cs.def { quant = 0.01/10 },
        action = function(v) lfo.mul = v end
    }
    ctl {
        name = 'rate', controlspec = cs.def { min = 0, default = 0.4, max = 40, quant = 40/1000 },
        action = function(v) lfo.rate = v end
    }

    params:add_separator('osc')

    for i, op in ipairs(ops) do
        ctl {
            name = 'amp ' .. op,
            controlspec = cs.def { default = 1/(2^(i - 1)) },
            action = function(v) engine.amp(vc, i, v * util.dbamp(params:get('level'))) end
        }
    end
    for i, op in ipairs(ops) do
        ctl {
            name = 'ratio ' .. op,
            type = 'number',
            min = 1, max = 24, default = ratio[i],
            action = function(v)
                ratio[i] = v
                ratio:update()
            end
        }
    end
    for carrier = #ops, 1, -1 do
        for modulator = 1, #ops do
            ctl {
                id = 'pm_' .. ops[carrier] .. '_' .. ops[modulator],
                name = 'pm ' .. ops[carrier] .. ' -> ' .. ops[modulator],
                controlspec = cs.def {
                    min = 0, max = 10, quantum = 0.01/10
                },
                action = function(v)
                    engine.mod(vc, carrier, modulator, v)
                end
            }
        end
    end

    return ids --return table of the ids
end

-- style:
-- 'simple': three controls, the rest are parametized from the "bits" control
-- 'complex': individual parameter for each control under the hood
-- callback: runs at the end of evey action function (args: id, value)
orgn.params.ulaw = function(style, callback)
    style = style or 'simple'
    cb = callback or cb
    ids = {}

    --[[
    [ gate, 0  ]
    [ pan, 0  ]
    [ hz, [ 440, 440, 0  ]  ]
    [ amp, [ 1.0, 0.5, 0.25  ]  ]
    [ velocity, 1  ]
    [ ratio, [ 1.0, 2.0, 4.0  ]  ]
    [ mod0, [ 0, 0, 0  ]  ]
    [ mod1, [ 0, 0, 0  ]  ]
    [ mod2, [ 0, 0, 0  ]  ]
    [ attack, [ 0.001, 0.001, 0.001  ]  ]
    [ decay, [ 0, 0, 0  ]  ]
    [ sustain, [ 1, 1, 1  ]  ]
    [ release, [ 0.2, 0.2, 0.2  ]  ]
    [ curve, -4  ]
    [ done, [ 1, 1, 1  ]  ]
    [ outbus, 0  ]
    [ inbus, 0.0  ]
    [ adc_mono, 0  ]
    [ adc_in_amp, 1  ]
    [ bits, 11  ]
    [ samples, 26460  ]
    [ samples_lag, 0.2  ]
    [ dustiness, 1.95  ]
    [ dust, 1  ]
    [ crinkle, 0  ]
    [ crackle, 0.1  ]
    [ drive, 0.025  ]
    [ outbus, 0  ]
    [ drywet, 1  ]
    ]]

    params:add_separator('u-law')
    ctl {
        name = 'dry/wet',
        controlspec = cs.def { default = 0.25 },
        action = function(v) engine.drywet(v) end
    }
    ctl {
        name = 'adc in',
        controlspec = cs.def { default = 1 },
        action = function(v) engine.adc_in_amp(v) end
    }

    local scs = cs.def { min = 10, max = 48000, default = 26460, quantum = 1/1000, warp = 'exp' }
    local bcs = cs.def { min = 0, max = 18, default = 11, quantum = 0.01/2 }

    if style == 'simple' then
        ctl {
            name = 'samples',
            controlspec = scs,
            action = function(v) engine.samples(v) end
        }
        ctl {
            name = 'bits',
            controlspec = bcs,
            action = function(v) engine.bits(v) end
        }
    else
        ctl {
            name = 'samples',
            controlspec = scs,
            action = function(v) engine.samples(v) end
        }
        ctl {
            name = 'bits',
            controlspec = bcs,
            action = function(v) engine.bits(v) end
        }
        ctl {
            name = 'drive',
            controlspec = cs.def { min = 0, max = 1, default = 0.01, step = 1/1000, quant = 1/1000 },
            action = function(v) engine.drive(v) end
        }
        ctl {
            name = 'crackle',
            controlspec = cs.def { min = 0, max = 3, default = 0.1 },
            action = function(v) engine.crackle(v) end
        }
        ctl {
            name = 'crinkle (!)',
            controlspec = cs.def { min = -4, max = 1.12, default = 0, 1/5.12/100 },
            action = function(v) engine.crinkle(v) end
        }
        ctl {
            name = 'dust',
            controlspec = cs.def { min = 0, max = 10, default = 1 },
            action = function(v) engine.dust(v) end
        }
        ctl {
            name = 'dustiness',
            controlspec = cs.def { min = 0, max = 20, default = 1.95 },
            action = function(v) engine.dustiness(v) end
        }
    end

    return ids
end

orgn.adsr = adsr

return orgn
