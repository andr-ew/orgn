--midi keyboard input

local m = midi.connect()
m.event = function(data)
    local msg = midi.to_msg(data)

    if msg.type == "note_on" then
        --TODO: velocity range params
        orgn.noteOn(msg.note, mu.note_num_to_freq(msg.note), ((msg.vel or 127)/127)*0.2 + 0.85)
    elseif msg.type == "note_off" then
        orgn.noteOff(msg.note)
    end
end

return m
