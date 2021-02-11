-- a toy keyboard

function r() norns.script.load(norns.state.script) end

mu = require 'musicutil'
porta = include 'lib/orgn'

engine.name = "Orgn"
engine.list_commands()

m = midi.connect()

function init()
    porta.params.synth('all', 'asr', 'linked');
    --params:read()

    m.event = function(data)
        local msg = midi.to_msg(data)
        if msg.type == "note_on" then
            engine.noteOn(msg.note, mu.note_num_to_freq(msg.note), 1)
        elseif msg.type == "note_off" then
            engine.noteOff(msg.note)
        end
    end
end

function cleanup() 
    --params:write()
    m.cleanup() 
end

