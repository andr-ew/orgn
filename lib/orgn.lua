local cs = require 'controlspec'

local envgraph = include 'orgn/lib/envgraph' -- modified version
local graph = require 'graph'

local ops = { 'a', 'b', 'c' }
local spo = tab.invert(ops)
local orgn = { params = {} }

local ids = {}
local last = 440
local last_id = nil
local glide = 0
local spread = 0
local mode = 'sustain'
local ratio = { 1, 2, 4 }
local lvl = { 1, 0.5, 0 }

local gfx

-- adsr mixer object
local adsr = { a = {}, d = {}, s = {}, r = {}, c = -4, min = 0.001,
    update = function(s, ds)
        engine.batch('attack', table.unpack(s.a))
        if s.ds then
            engine.batch('decay', table.unpack(s.d))
            engine.batch('sustain', table.unpack(s.s))
        end
        engine.batch('release', table.unpack(s.r))
        engine.curve(s.c)
        
        gfx.env:update()
    end
}
for i, op in ipairs(ops) do
    adsr.a[i] = 0.001
    adsr.d[i] = 0
    adsr.s[i] = 1
    adsr.r[i] = 0.2
end

local fps = 30
gfx = {
    env = {
        graph = {},
        init = function(s, x, y, w, h, env)
            env = env or 'asr'
            for i,_ in ipairs(ops) do
                if env == 'asr' then
                    s.env = 'asr'
                    s.graph[i] = {
                        sustain = envgraph.new_asr(0, 20, 0, 1),
                        transient = envgraph.new_ar(0, 20, 0, 1)
                    }
                    s.graph[i].sustain:set_position_and_size(x, y, w, h)
                    s.graph[i].transient:set_position_and_size(x, y, w*2, h)
                end
            end
        end,
        update = function(s)
            for i,_ in ipairs(ops) do
                if s.env == 'asr' then
                    s.graph[i].sustain:edit_asr(adsr.a[i], adsr.r[i], 1, adsr.c)
                    s.graph[i].transient:edit_ar(adsr.a[i], adsr.r[i], 1, adsr.c)
                end
            end
        end
    },
    osc = {
        -- graph = {},
        pos = {},
        rate = 1,
        slip = 0.0,
        slip_max = 0.005,
        phase = { 0, 0, 0 },
        --TODO: envelope emulation 
        lvl = { 1, 1, 1 },
        -- reslip = function(s)
        --     s.slip = (math.random()*2 - 1) * s.slip_max
        -- end,
        -- reslip_max = function(s)
        --     s.slip_max = math.random() * 0.00125
        -- end,
        init = function(s, ...)
            local pos = { ... } --pos[op] = { x, y, w, h }
            s.pos = pos
        end,
        draw = function(s)
            local l = { 0, 0, 0 }
            local f = {}
            local idx = {}

            for i,v in ipairs(ops) do
                idx[i] = {}
                for ii,vv in ipairs(ops) do
                    idx[i][ii] = params:get('pm_'..vv..'_'..v)
                end

                f[i] = function(x) 
                    local y = math.sin((
                         x + s.phase[i] 
                         + l[1]*idx[i][1]
                         + l[2]*idx[i][2]
                         + l[3]*idx[i][3]
                    ) * 2 * math.pi)
                    l[i] = y
                    return y
                end
            end

            local T = 1 + 1/2
            local w, h = s.pos[1].w, s.pos[1].h
            screen.level(15)

            local fpf = fps*2 - 1
            for iii = 1, fpf do
                for i,_ in ipairs(ops) do
                    s.phase[i] = s.phase[i] + (ratio[i] * 1/fps * fpf) % 1
                end

                for ii = 1,w do
                    for i,_ in ipairs(ops) do
                        local left, top = s.pos[i].x, s.pos[i].y

                        local x = ii / w * T
                        local y = f[i](x)
                        if iii % fpf == 0 then 

                            local a = math.max(lvl[i], util.explin(0.0001, 1, 0, 1, 
                                (math.max(idx[1][i], idx[2][i], idx[3][i])/10)^2
                            ))
                            screen.pixel(ii + left, (((y * a)+1) * h / 2) + top) 
                        end
                    end
                end
            end
            screen.fill()
        end
    },
    samples = {
        pos = {},
        count = 0,
        init = function(s, ...)
            s.x, s.y, s.h = ... 
        end,
        draw = function(s)
            local samps, bits = params:get_raw('samples'), params:get_raw('bits')

            screen.level(math.floor(util.explin(0.001, 1, 0.001, 14.9, params:get_raw('dry/wet')^2)))
            screen.font_size(math.ceil(util.expexp(0.001, 1, 0.001, 40, samps)))
            screen.font_face(math.floor(7.9 * bits))
            screen.move(s.x + 10, s.y + 20 + (2 * (1 - (samps/2))))
            screen.text_center('*')
        end
    },
    draw = function(s)
        for i,_ in ipairs(ops) do
            --math.max(i-1, 1)
            s.env.graph[i][mode]:redraw(({2, 4, 15})[i])
        end
        s.osc:draw()
        s.samples:draw()
    end
}

local pitch = {
    off = 0,
    mod = 0,
    oct = 0,
    update = function(s)
        engine.pitch((2^(s.off) * (2^s.oct)) + s.mod/2)
    end
}
local lfo = { 
    rate = 0.4, mul = 0, phase = 0, quant = 0.05,
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

local function hz2st(h) return 12*math.log(h/440, 2) end

orgn.noteOn = function(id, hz, vel)
    local i = voicing == 'mono' and -1 or id
    local pan = math.random() * spread * (math.random() > 0.5 and -1 or 1)

    --local d = hz2st(hz) - hz2st(last)
    --d = util.linexp(0, 76, 0.01, 1.2, math.abs(d))
    local t = glide 
        + (math.random() * 0.2) 
        -- + ((d < math.huge) and d or 0)

    if mode == 'sustain' and glide <= 0 then
        engine.noteOn(i, hz, vel, pan)
    elseif mode == 'sustain' and glide > 0 then
        engine.noteGlide(i, last, hz, t, vel, pan)
    elseif mode == 'transient' and glide <= 0 then
        engine.noteTrig(i, hz, vel, pan, math.max(adsr.a[1], 0.01))
    elseif mode == 'transient' and glide > 0 then
        engine.noteTrigGlide(i, last, hz, t, vel, pan, adsr.a[1])
    end

    last = hz
    last_id = id
end

orgn.noteOff = function(id)
    if voicing == 'mono' then
        if id == last_id then
            engine.noteOff(-1)
        end
    elseif mode == 'sustain' then
        engine.noteOff(id)
    end
end

-- param:add wrapper with some shortcuts
local function ctl(arg)
    arg.id = arg.id or string.gsub(arg.name, ' ', '_')
    arg.type = arg.type or 'control'

    params:add(arg)
    table.insert(ids, arg.id)
end

orgn.params = function(env, envstyle, fxstyle)
    env = env or 'asr'
    envstyle = envstyle or 'linked'

    -- ids = {}
    
    --mixer objects
    local ratio = { 1, 2, 4,
        dt = 0,
        update = function(s)
            local r = {}
            for i, op in ipairs(ops) do 
                local dt =  2^(s.dt * (i-1))
                r[i] = s[i] * dt
                ratio[i] = r[i]
            end
            engine.batch('ratio', table.unpack(r))
        end
    }
    local amp = { 1, 0.5, 0.25,
        l = 0,
        update = function(s)
            local a = {}
            for i, op in ipairs(ops) do 
                a[i] = util.dbamp(s.l) * s[i]
                lvl[i] = a[i]
            end
            engine.batch('amp', table.unpack(a))
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
        name = 'oct',
        type = 'number',
        min = -5, max = 5,
        action = function(v)
            pitch.oct = v
            pitch:update()
        end
    }
    ctl {
        name = 'detune',
        controlspec = cs.def { default = 0, quantum = 1/100/10, step = 0 },
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
    do
        local vops = { 'poly', 'mono' }
        ctl {
            name = 'voicing', type = 'option', options = vops,
            action = function(v)
                voicing = vops[v]
            end
        }
    end

    params:add {
        id = 'reset', type = 'binary', behavior = 'trigger',
        action = function()
            for i,id in ipairs(ids) do
                local p = params:lookup_param(id)
                params:set(id, p.default or (p.controlspec and p.controlspec.default) or 0)
            end
        end
    }

    params:add_separator('env')

    local ds = env == 'adsr'
    local cstime = cs.new(0.001, 10, 'exp', 0, 0.04, "s")

    if envstyle == 'linked' then

        -- env mixer
        -- TODO: fix ramp = -1
        local emx = {
            time = 0.2, ramp = 1, curve = -4, span = 0, sustain = 0.75, 
            update = function(s)
                for i, op in ipairs(ops) do
                    local j = i - 1
                    local k = #ops - i
                    local a, r
                    if s.ramp > 0 then
                        r = s.time
                        a = s.time * (1 - s.ramp)
                    else
                        r = s.time * (1 + s.ramp)
                        a = s.time
                    end

                    adsr.a[i] = math.max(a * (1 + math.abs(k*s.span)), adsr.min)
                    adsr.d[i] = math.max(r * (1 + k*s.span), adsr.min)
                    adsr.s[i] = s.sustain
                    adsr.r[i] = math.max(r * (1 + k*s.span), adsr.min)
                end
                adsr.c = s.curve

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
            controlspec = cs.def { min = -1, max = 1, default = 0 },
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
            action = function(v) emx.span = -v; emx:update() end
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
        name = 'depth', controlspec = cs.def { default = 0, quantum = 1/100/10, step = 0 },
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
            controlspec = cs.def { default = ({ 1, 0.5, 0 })[i] },
            action = function(v) amp[i] = v; amp:update(i) end
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
                    engine.mod(carrier, modulator, v)
                end
            }
        end
    end

    local style = fxstyle or 'complex'

    params:add_separator('fx')
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

return orgn, gfx
