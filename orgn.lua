include 'orgn/lib/crops'
musicutil = require "musicutil"
controlspec = require 'controlspec'
voice_lib = require 'voice'

engine.name = 'R'
r = require 'r/lib/r'

orgn = {}

orgn.poly = 4
orgn.voice = voice_lib.new(orgn.poly)

function orgn.init()
  
  r.engine.poly_new("fg", "FreqGate", orgn.poly)
  r.engine.poly_new("glide", "Slew", orgn.poly)
  r.engine.poly_new("osca", "SineOsc", orgn.poly)
  r.engine.poly_new("oscb", "SineOsc", orgn.poly)
  r.engine.poly_new("oscc", "SineOsc", orgn.poly)
  r.engine.poly_new("lvla", "MGain", orgn.poly)
  r.engine.poly_new("lvlb", "MGain", orgn.poly)
  r.engine.poly_new("lvlc", "MGain", orgn.poly)
  r.engine.poly_new("env", "ADSREnv")
  r.engine.poly_new("amp", "Amp", orgn.poly)
  r.engine.poly_new("pan", "Pan", orgn.poly)
  r.engine.poly_new("lvl", "SGain", orgn.poly)
  
  engine.new("soundin", "SoundIn")
  engine.new("inlvl", "SGain")
  engine.new("decil", "Decimator")
  engine.new("decir", "Decimator")
  engine.new("eql", "EQBPFilter")
  engine.new("eqr", "EQBPFilter")
  engine.new("xfade", "XFader")
  engine.new("outlvl", "SGain")
  engine.new("soundout", "SoundOut")
  
  r.engine.poly_connect("fg/Frequency", "glide/In", orgn.poly)
  r.engine.poly_connect("fg/Gate", "env/Gate", orgn.poly)
  r.engine.poly_connect("glide/Out", "osca/FM", orgn.poly)
  r.engine.poly_connect("glide/Out", "oscb/FM", orgn.poly)
  r.engine.poly_connect("glide/Out", "oscc/FM", orgn.poly)
  r.engine.poly_connect("osca/Out", "lvla/In", orgn.poly)
  r.engine.poly_connect("oscb/Out", "lvlb/In", orgn.poly)
  r.engine.poly_connect("oscc/Out", "lvlc/In", orgn.poly)
  r.engine.poly_connect("lvla/Out", "amp/In", orgn.poly)
  r.engine.poly_connect("lvlb/Out", "amp/In", orgn.poly)
  r.engine.poly_connect("lvlc/Out", "amp/In", orgn.poly)
  r.engine.poly_connect("env/Out", "amp/Exp", orgn.poly)
  r.engine.poly_connect("amp/Out", "pan/In", orgn.poly)
  r.engine.poly_connect("pan/Left", "lvl/Left", orgn.poly)
  r.engine.poly_connect("pan/Right", "lvl/Right", orgn.poly)

  for voicenum=1, orgn.poly do
    engine.connect("lvl"..voicenum.."/Left", "decil/In")
    engine.connect("lvl"..voicenum.."/Right", "decir/In")
    engine.connect("lvl"..voicenum.."/Left", "xfade/InBLeft")
    engine.connect("lvl"..voicenum.."/Right", "xfade/InBRight")
  end
  
  engine.connect("soundin/Left", "inlvl/Left")
  engine.connect("soundin/Right", "inlvl/Right")
  engine.connect("inlvl/Left", "decil/In")
  engine.connect("inlvl/Right", "decir/In")
  engine.connect("inlvl/Left", "xfade/InBLeft")
  engine.connect("inlvl/Right", "xfade/InBRight")
  engine.connect("decil/Out", "eql/In")
  engine.connect("decir/Out", "eqr/In")
  engine.connect("eql/Out", "xfade/InALeft")
  engine.connect("eqr/Out", "xfade/InARight")
  engine.connect("xfade/Left", "outlvl/Left")
  engine.connect("xfade/Right", "outlvl/Right")
  engine.connect("outlvl/Left", "soundout/Left")
  engine.connect("outlvl/Right", "soundout/Right")
  
  r.engine.poly_set("osca.FM", 1, orgn.poly)
  r.engine.poly_set("oscb.FM", 1, orgn.poly)
  r.engine.poly_set("oscc.FM", 1, orgn.poly)
  
  params:read()
end

orgn.noteon = function(note)
  local slot = orgn.voice:get()
  orgn.voice:push(note, slot)
  
  engine.bulkset("FreqGate"..slot.id..".Gate 1 FreqGate"..slot.id..".Frequency "..musicutil.note_num_to_freq(note))
end

orgn.noteoff = function(note)
  local slot = orgn.voice:pop(note)
  if slot then
    
    orgn.voice:release(slot)
    engine.bulkset("FreqGate"..slot.id..".Gate 0")
  end
end

orgn.scales = { -- 4 different scales, go on & change em! can be any length. be sure 2 capitalize & use the correct '♯' symbol
  { "D", "E", "G", "A", "B" },
  { "D", "E", "F♯", "A", "B"},
  { "D", "E", "D", "A", "C" },
  { "D", "E", "F♯", "G", "B"}
}

orgn.vel = function()
  return 0.8 + math.random() * 0.2 -- random logic that genrates a new velocity for each key press
end

orgn.controls = crop:new{ -- controls at the top of the grid. generated using the crops lib - gr8 place to add stuff !
  scale = value:new{ v = 1, p = { { 1, 4 }, 1 } }
}


orgn.make_keyboard = function(rows, offset) -- function for generating a keyboard, optional # of rows + row separation
  local keyboard = crop:new{} -- new crop (control container)
  
  for i = 1, rows do -- make a single line keyboard for each row
    keyboard[i] = momentaries:new{ -- momentaries essentially works like a keybaord, hence we're using it
      v = {}, -- initial value is a blank table
      p = { { 1, 16 }, 9 - i }, -- y position stars at the bottom and moves up, x goes from 1 - 16
      offset = offset * i, -- pitch offset
      event = function(self, v, l, added, removed) -- event is called whenever the control is pressed
        local key
  			local gate
  			local scale = orgn.scales[orgn.controls.scale.v] -- get current sclae based on scale control value
  			
  			if added ~= -1 then -- notes added & removed are sent back throught thier respective arguments. defautls to -1 if no activity
  				key = added
  				gate = true
  			elseif removed ~= -1 then
  				key = removed
  				gate = false
  			end
  			
  			if key ~= nil then
  			  local note = scale[((key - 1) % #scale) + 1] -- grab note name from current scale
  			  
  			  for j,v in ipairs(musicutil.NOTE_NAMES) do -- hacky way of grabbing midi note num from note name
            if v == note then
              note = j - 1
              break
            end
  			  end
  			  
  			  note = note + math.floor((key - 1) / #scale) * 12 + self.offset -- add row offset and wrap scale to next octave
          
          if gate then
  			    orgn.noteon(note)
  			  else
  			    orgn.noteoff(note)
  			  end
  			end
      end
    }
  end
  
  return keyboard -- return our keybaord
end

orgn.keyboard = orgn.make_keyboard(7, 12) -- call keybaord function w/ 8 rows & octave separation. u can change this !


--------------------------------------------
  
function orgn.g_key(g, x, y, z)
  crops:key(g, x, y, z)  -- sends keypresses to all controls auto-magically
  g:refresh()
end

function orgn.g_redraw(g)
  crops:draw(g) -- redraws all controls
  g:refresh()
end

orgn.cleanup = function()
  
  --save paramset before script close
  params:write()
end

-------------------------- globals - feel free to redefine in referenced script

g = grid.connect()

g.key = function(x, y, z)
  orgn.g_key(g, x, y, z)
end

function init()
  orgn.init()
  orgn.g_redraw(g)
end

function cleanup()
  orgn.cleanup()
end

return orgn