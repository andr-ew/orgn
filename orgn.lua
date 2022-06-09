-- a toy keyboard

--globals

local pages = 3

--includes

tab = require 'tabutil'
cs = require 'controlspec'

tune, Tune = include 'lib/tune/tune' 
tune.setup { presets = 8, scales = include 'lib/tune/scales' }

mu = require 'musicutil'
orgn = include 'lib/orgn'
demo = include 'lib/demo'

engine.name = "Orgn"

--add params

params:add { id = 'none', type = 'control', contolspec = cs.new() }
params:hide 'none'

orgn.params()

params:add_separator('tuning')
params:add {
    type='number', name='scale preset', id='scale_preset', min = 1, max = 8,
    default = 1, action = function() redraw() end
}

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
    { name_map['dry/wet'], name_map['samples'], name_map['bits'] },
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

params:add_separator('')
params:add {
    id = 'demo start/stop', type = 'binary', behavior = 'toggle',
    action = function(v)
        if v > 0 then 
            params:delta('reset')
            demo.start() 
        else demo.stop() end
        
        --grid_redraw()
    end
}

--midi keyboard

m = midi.connect()
m.event = function(data)
    local msg = midi.to_msg(data)

    if msg.type == "note_on" then
        --TODO: velocity range params
        orgn.noteOn(msg.note, mu.note_num_to_freq(msg.note), ((msg.vel or 127)/127)*0.2 + 0.85)
    elseif msg.type == "note_off" then
        orgn.noteOff(msg.note)
    end
end

--ui

--init/cleanup

function init()
    orgn.init()
    --params:read()
    params:set('demo start/stop', 0)
    params:bang()
end

function cleanup() 
    params:write()
end
