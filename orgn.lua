-- a toy keyboard

function r() norns.script.load(norns.state.script) end

tab = require 'tabutil'
cs = require 'controlspec'

include 'orgn/lib/nest/core'
include 'orgn/lib/nest/norns'
include 'orgn/lib/nest/grid'
include 'orgn/lib/nest/txt'

mu = require 'musicutil'
orgn = include 'orgn/lib/orgn'

engine.name = "Orgn"

pages = 2 --number of encoder control pages

local hl = { 4, 15 }

--add params
params:add { id = 'none', type = 'control', contolspec = cs.new() }
params:hide 'none'

orgn.params.synth('all', 'asr', 'linked', function() grid_redraw() end)
orgn.params.fx('complex')

params:add_separator('map')

local map_name = {}
local map_id = {}

for k,v in pairs(params.params) do --read all params == lazy way
    if v.t == 3 then -- type is control
        table.insert(map_name, v.name or v.id)
        table.insert(map_id, v.id)
    end
end

local name_map = tab.invert(map_name)
-- local id_map = tab.invert(map_id)

local enc_defaults = {
    { name_map['time'], name_map['amp b'], name_map['pm c -> b'] },
    { name_map['span'], name_map['detune'], name_map['pm c -> a'] },
}
local enc_map_option_id = {}

params:add_group('encoders', pages * 3)
for i = 1, pages do
    enc_map_option_id[i] = {}
    enc_defaults[i] = enc_defaults[i] or {}
    for ii = 1,3 do
        local name = 'page '..i..', E'..ii..''
        local id = string.gsub(string.gsub(name, ' ', '_'), ',', '')
        enc_map_option_id[i][ii] = id
        params:add {
            id = id, name = name, type = 'option',
            options = map_name, default = enc_defaults[i][ii] or name_map['none'],
        }        
        print(i, ii, id, params:get(id), map_name[params:get(id)])
    end
end


--midi keyboard
m = midi.connect()
m.event = function(data)
    local msg = midi.to_msg(data)
    if msg.type == "note_on" then
        orgn.noteOn(msg.note, mu.note_num_to_freq(msg.note), msg.velocity)
    elseif msg.type == "note_off" then
        orgn.noteOff(msg.note)
    end
end

--grid
g = grid.connect()

root = 110 * 2^(5/12) -- d
intervals = { 
    -- { 0, 2, 5, 7, 9 },
    -- { 0, 2, 5, 7, 11 },
    { 0, 2, 4, 7, 9 },
    { 0, 2, 5, 7, 10 },
}

local function key(s, v, t, d, add, rem)
    local k = add or rem
    local id = k.y * k.x
    local iv = intervals[s.p.scale.v]
    local oct = k.y-3 + k.x//(#iv+1)
    local deg = (k.x-1)%#iv+1
    local hz = root * 2^oct * 2^(iv[deg]/12)
    local vel = math.random()*0.2 + 0.85

    if add then orgn.noteOn(id, hz, vel)
    elseif rem then orgn.noteOff(id) end
end

local grid64_ = nest_ {
    play = nest_ {
        scale = _grid.number { x = { 3, 4 }, y = 1 },
        ramp = _grid.control { x = { 5, 7 }, y = 1, v = -1 } :param('ramp'),
        mode = _grid.toggle { x = 8, y = 1 } :param('mode'),
        glide = _grid.number {
            x = { 1, 3 }, y = 2,
            action = function(s, v)
                params:set('glide', ({ 0, 0.2, 0.4 })[v])
            end
        },
        ratio = _grid.number {
            x = { 4, 8 }, y = 2,
            action = function(s, v)
                params:set('ratio_c', ({ 2, 4, 7, 8, 10 })[v])
            end
        },
        keyboard = _grid.momentary { x = { 1, 8 }, y = { 3, 8 }, count = 8, action = key }
    },
    p = _grid.pattern {
        x = { 1, 2 }, y = 1,
        lvl = {
            0, ------------------ 0 empty
            function(s, d) ------ 1 empty, recording, no playback
                while true do
                    d(15)
                    clock.sleep(0.25)
                    d(0)
                    clock.sleep(0.25)
                end
            end,
            0, ------------------ 2 filled, paused
            15, ----------------- 3 filled, playback
            function(s, d) ------ 4 filled, recording, playback
                while true do
                    d(15)
                    clock.sleep(0.1)
                    d(0)
                    clock.sleep(0.1)
                    d(15)
                    clock.sleep(0.1)
                    d(0)
                    clock.sleep(0.3)
                end
            end,
        },
        target = function(s) return s.p.play end
    }
}

local grid128_ = nest_ {
    play = nest_ {
        ratio = nest_ {
            c = _grid.number { x = { 1, 16 }, y = 1 } :param('ratio_c'),
            b = _grid.number { x = { 1, 16 }, y = 2 } :param('ratio_b'),
            a = _grid.number { x = { 1, 7 }, y = 3 } :param('ratio_a'),
        },
        mode = _grid.toggle { x = 8, y = 3, lvl = hl } :param('mode'),
        --TODO: preset
        ramp = _grid.control { x = { 14, 16 }, y = 3 } :param('ramp'),

        keyboard = _grid.momentary { x = { 1, 13 }, y = { 4, 8 }, count = 8, action = key },
        scale = _grid.number { x = 14, y = { 4, 8 }, lvl = hl },
        glide = _grid.number {
            x = 15, y = { 4, 8 },
            action = function(s, v)
                params:set('glide', ({ 0, 0.1, 0.2, 0.4, 1 })[v])
            end
        },
    },
    pattern = _grid.pattern {
        x = 16, y = { 4, 8 }, target = function(s) return s.p.play end
    }
}

local mar = { left = 2, top = 4, right = 0, bottom = 1 }
local gap = 4
local split = { y = 64 * 3/4 }
local div = { x = { ctl = 3, gfx = 2 }, y = { ctl = 1, gfx = 2 } }
local mul = { 
    ctl = { x = (128 - mar.left - mar.right - (div.x.ctl - 1)*gap) / div.x.ctl }, 
    gfx = { 
        x = (128 - mar.left - mar.right - (gap * (div.x.gfx - 1))) / div.x.gfx,
        y = (split.y - mar.top - mar.bottom - (gap * (div.y.gfx - 1))) / div.y.gfx,
    }
}
local x = { 
    ctl = { mar.left, mar.left + mul.ctl.x, mar.left + mul.ctl.x*2, 128 - mar.right },
    gfx = { mar.left, mar.left + mul.gfx.x }
}
local y = {
    ctl = { split.y, 64 - mar.bottom },
    gfx = { mar.top, mar.top + mul.gfx.y }
}
local w = { 
    gfx = ((128 - mar.left - mar.right) / div.x.gfx) - gap*2, 
    ctl = ((128 - mar.left - mar.right) / div.x.ctl) - gap*2
}
local h = { gfx = (split.y - mar.left - mar.right) / div.y.gfx - gap*2 }

orgn.gfx.env:init(x.gfx[2], y.gfx[2], mul.gfx.x, mul.gfx.y, 'asr')
orgn.gfx.osc:init(
    { x = x.ctl[1], y = y.gfx[1], w = w.ctl, h = h.gfx }, 
    { x = x.ctl[2], y = y.gfx[1], w = w.ctl, h = h.gfx }, 
    { x = x.ctl[3], y = y.gfx[1], w = w.ctl, h = h.gfx }
)
orgn.gfx.samples:init(x.gfx[1], y.gfx[2], h.gfx)

--ui
orgn_ = nest_ {
    grid = (g.device.cols==8 and grid64_ or grid128_):connect { g = g },
    norns = nest_ {
        gfx = _screen {
            redraw = function() 
                orgn.gfx:draw()
                return true -- return high dirty flag to redraw every frame
            end
        },
        tab = _txt.key.option {
            n = { 2, 3 }, x = 128, y = 64, align = {'right', 'bottom' }, 
            font_size = 16, margin = 3,
            options = function() 
                local t = {}; for i = 1, pages do t[i] = '.' end; return t
            end
        },
        page = nest_(pages):each(function(i) 
            return nest_(3):each(function(ii) 
                local id = function() return map_id[params:get(
                    enc_map_option_id[i][ii]
                )] end
                print(ii, id())
                return _txt.enc.control {
                    n = ii, x = x.ctl[ii], y = y.ctl[1], flow = 'y',
                    value = function() return params:get(id()) end,
                    action = function(s, v) params:set(id(), v) end,
                    controlspec = function() return params:lookup_param(id()).controlspec end,
                    label = function() return map_name[
                        params:get(enc_map_option_id[i][ii])
                    ] end,
                    step = 0.01
                }
            end):merge { enabled = function() return orgn_.norns.tab.value == i end }
        end)
    } :connect { screen = screen, key = key, enc = enc }
}

function init()
    orgn.init()
    -- params:read()
    params:bang()
    orgn_:init()
end

function cleanup() 
    params:write()
end
