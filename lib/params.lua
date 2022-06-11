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

local map = {}
map.name = {}
map.id = {}

for k,v in pairs(params.params) do --read all params == lazy way
    if v.t == 3 then -- type is control
        table.insert(map.name, v.name or v.id)
        table.insert(map.id, v.id)
    end
end

local name_map = tab.invert(map.name)
-- local id_map = tab.invert(map.id)

local enc_defaults = {
    { name_map['time'], name_map['amp b'], name_map['pm c -> b'] },
    { name_map['span'], name_map['detune'], name_map['pm c -> a'] },
    { name_map['dry/wet'], name_map['samples'], name_map['bits'] },
}
map.option_id = {}

params:add_group('encoders', pages * 3)
for i = 1, pages do
    map.option_id[i] = {}
    enc_defaults[i] = enc_defaults[i] or {}
    for ii = 1,3 do
        local name = 'page '..i..', E'..ii..''
        local id = string.gsub(string.gsub(name, ' ', '_'), ',', '')
        map.option_id[i][ii] = id
        params:add {
            id = id, name = name, type = 'option',
            options = map.name, default = enc_defaults[i][ii] or name_map['none'],
        }        
        print(i, ii, id, params:get(id), map.name[params:get(id)])
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

return map
