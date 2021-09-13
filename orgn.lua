-- a toy keyboard

function r() norns.script.load(norns.state.script) end

include 'orgn/lib/nest/core'
include 'orgn/lib/nest/norns'
include 'orgn/lib/nest/grid'
mu = require 'musicutil'
orgn = include 'orgn/lib/orgn'

engine.name = "Orgn"
local hl = { 4, 15 }

--add params
orgn.params.synth('all', 'asr', 'linked', function() grid_redraw() end);
orgn.params.ulaw('complex')

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

root = 110 * 2^(5/12) -- d
intervals = { 
    -- { 0, 2, 5, 7, 9 },
    -- { 0, 2, 5, 7, 11 },
    { 0, 2, 4, 7, 9 },
    { 0, 2, 5, 7, 10 },
}

g = grid.connect()

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
        keyboard = _grid.momentary { x = { 1, 8 }, y = { 3, 8 }, action = key }
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
            a = _grid.number { x = { 1, 4 }, y = 3 } :param('ratio_a'),
        },
        mode = _grid.toggle { x = 5, y = 3, lvl = hl } :param('mode'),
        --TODO: preset
        ramp = _grid.control { x = { 14, 16 }, y = 3 } :param('ramp'),

        --TODO: use count for polyphony limit
        keyboard = _grid.momentary { x = { 1, 13 }, y = { 4, 8 }, action = key },
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

--ui
orgn_ = nest_ {
    grid = (g.device.cols==8 and grid64_ or grid128_):connect { g = g }
}

function init()
    orgn.init()
    params:read()
    orgn_:init()
end

function cleanup() 
    params:write()
end
