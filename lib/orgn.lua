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
        p = 0,
        dt = 0,
        update = function(s)
            local p = 2^s.p
            local r = {}
            for i, op in ipairs(ops) do 
                local dt = (i-2) * (2^s.dt)
                r[i] = s[i] * dt * p
            end
            --print('ratio', vc, table.unpack(r))
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
            min = -1, max = 1,
            default = ratio.p
        },
        action = function(v)
            ratio.p = v
            ratio:update()
        end
    }
    ctl {
        name = 'detune',
        controlspec = cs.new(),
        action = function(v)
            ratio.dt = v
            ratio:update()
        end
    }
    -- these ones are accessed in the noteOn/noteOff functions
    ctl {
        name = 'glide',
        controlspec = cs.def { units = 's' }
    }
    ctl {
        name = 'spread',
        controlspec = cs.new()
        -- engine.pan(<note id>, math.random()*2*v - 1)
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
                    min = 0, max = 8, quantum = 0.01/8
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
    synth control defaults:
    [ amp, [ 1.0, 0.5, 0.25 ] ]
    [ ratio, [ 1.0, 2.0, 4.0 ] ]
    [ attack, [ 0.001, 0.001, 0.001 ] ]
    [ decay, [ 0, 0, 0 ] ]
    [ sustain, [ 1, 1, 1 ] ]
    [ release, [ 0.2, 0.2, 0.2 ] ]
    [ curve, -4 ]
    [ done, [ 1, 1, 1 ] ]
    [ bits, 11 ]
    [ samples, 26460 ]
    [ dustiness, 1.95 ]
    [ dust, 1 ]
    [ crackle, 0.1 ]
    [ drive, 0.05 ]
    [ drywet, 1 ]
    ]]

    params:add_separator('u-law')
    local scs = cs.def { min = 200, max = 44100, default = 26460, step = 0.01/4 }
    local bcs = cs.def { min = 4, max = 18, default = 11, step = 0.01/4 }

    if style == 'simple' then
        ctl {
            name = 'samples',
            controlspec = scs,
            action = function(v)
                engine.samples(v)
            end
        }
        ctl {
            name = 'bits',
            controlspec = bcs,
            action = function(v)
                engine.bits(v)
            end
        }
    else
        ctl {
            name = 'samples',
            controlspec = scs,
            action = engine.samples
        }
        ctl {
            name = 'bits',
            controlspec = bcs,
            action = engine.bits
        }
        ctl {
            name = 'drive',
            controlspec = cs.def { max = 0.3, default = 0.05 },
            action = engine.drive
        }
        ctl {
            name = 'crackle',
            controlspec = cs.def { min = 0, max = 3, default = 0.1 },
            action = engine.crackle
        }
        ctl {
            name = 'crinkle',
            controlspec = cs.def { min = 0, max = 2, default = 1.5 },
            action = engine.crinkle
        }
        ctl {
            name = 'dust',
            controlspec = cs.def { min = 0, max = 10, default = 1 },
            action = engine.dust
        }
        ctl {
            name = 'dustiness',
            controlspec = cs.def { min = 0, max = 20, default = 1.95 },
            action = engine.dustiness
        }
    end
    ctl {
        name = 'dry/wet',
        controlspec = cs.def { default = 1 },
        action = engine.drywet
    }

    return ids
end

orgn.adsr = adsr

return orgn
