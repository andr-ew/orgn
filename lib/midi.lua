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


--osc note code 
local function osc_note_off(note, sleep_time)
  clock.sleep(sleep_time or 0.25)
  orgn.noteOff(note)
end

local function on_osc_event(path, args, from)
  if path == "/play_note" and orgn then
    orgn.noteOn(args[2], mu.note_num_to_freq(args[2]), (args[3] / 127)*0.2 + 0.85)
    clock.run(osc_note_off,args[2], 0.25)
  elseif path == "/note_on" and orgn then
    local midi_note = args[2]
    local vel = args[3]
    orgn.noteOn(midi_note, mu.note_num_to_freq(args[2]), (args[3] / 127)*0.2 + 0.85)
    -- Grab the chosen nb voice's player off your param
    local player1 = params:lookup_param("nb_voice1"):get_player()
    local player2 = params:lookup_param("nb_voice2"):get_player()
    player1:note_on(midi_note, vel) 
    player2:note_on(midi_note, vel) 
    print('note on', midi_note, vel)
    
  elseif path == "/note_off" and orgn then
    local midi_note = args[2]
    orgn.noteOff(midi_note)
    -- Grab the chosen nb voice's player off your param
    local player1 = params:lookup_param("nb_voice1"):get_player()
    local player2 = params:lookup_param("nb_voice2"):get_player()
    player1:note_off(midi_note) 
    player2:note_off(midi_note) 
    print('note off', midi_note)
  elseif path == "/all_off" and orgn then
    print("all off")
    for i=0,100 do engine.noteOff(i) end
  end
end



local function osc_connect()
  print("osc connect!!!")
  osc.event = on_osc_event
end
osc_connect()

return m

