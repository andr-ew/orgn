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

local cs = require 'controlspec'

local opnames = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' }
local adsr = { a = {}, d = {}, s = {}, r = {}, c = -4 }

local porta = { params = {} }

local ids = {}
local cb = function(id, v) end

local function ctl(arg)
    arg.id = arg.id or string.gsub(arg.name, ' ', '_')
    arg.type = arg.type or 'control'

    local a = arg.action or function() end
    arg.action = function(v) 
        a(v)
        cb(arg.id, v)
    end

    params:add(arg)
    table.insert(ids, arg.id)
end

--[[
local mix = function(...)
    local vars = { ... }
    local default = table.remove(vars, #vars)
    local action = table.remove(vars, #vars)
    local vals = {}
    local funcs = {}
    for _,k in ipairs(vars) do 
        vals[k] = default
        funcs[k] = function(v)
            vals[k] = v
            action(table.unpack(vals))
        end
    end
    return funcs
end
]]

-- opcount: operator count
-- voice:
-- 'all': add param control over all voices (for using the engine as a single polysynth)
-- <number>: add params for this voice only
--
-- env:
-- 'asr': a single asr envelope with span controls for each osc
-- 'adsr': independent adsr envelopes per-operator
--
-- envstyle:
-- 'linked': single controls with span across operators
-- 'independent': unique control per-operator
--
-- callback: runs at the end of evey action function (args: id, value)
porta.params.synth = function(opcount, voice, env, envstyle, callback)
    opcount = opcount or 3
    voice = voice or 'all'
    env = env  or 'asr'
    envstyle = envstyle or 'linked'

    ids = {}
    cb = callback or cb
    
    local ops = {}
    for i = 1, opcount do ops[i] = opnames[i] end
    if opcount < 3 then engine.amp('all', 3, 0) -- good 'nuf

    for i, op in ipairs(ops) do
        adsr.a[i] = 0.001,
        adsr.d[i] = 0,
        adsr.s[i] = 1,
        adsr.r[i] = 0.2
    end
    
    local vc = voice

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
    if envstyle == 'linked' then

        -- env mixer
        local emx = {
            time = 0.2, ramp = 1, curve = -4, span = 0, sustain = 0.75,
            update = function(s)
                for i, op in ipairs(ops) do
                    local j = i - 2
                    local a, r
                    if ramp > 0 then
                        r = s.time
                        a = s.time * (1 - s.ramp)
                    else
                        r = s.time * (1 - s.ramp)
                        a = s.time
                    end

                    adsr.a = a * (1 + j*math.abs(s.span))
                    adsr.d = r * sp * (1 + j*s.span)
                    adsr.s = s.sustain * (1 + j*s.span)
                    adsr.r = r * sp * (1 + j*s.span)
                end

                engine.batch('attack', vc, table.unpack(adsr.a))
                if ds then
                    engine.batch('decay', vc, table.unpack(adsr.d))
                    engine.batch('sustain', vc, table.unpack(adsr.s))
                end
                engine.batch('release', vc, table.unpack(adsr.r))
                engine.curve(vc, adsr.c)
            end
        }

    else
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

return porta
