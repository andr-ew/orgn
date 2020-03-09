include 'orgn/lib/crops'
musicutil = require "musicutil"
controlspec = require 'controlspec'
voice_lib = require 'voice'

engine.name = 'R'
r = require 'r/lib/r'

orgn = {}

orgn.poly = 4
orgn.voice = voice_lib.new(orgn.poly)

ADSR = { Attack = 0, Decay = 0, Sustain = 0, Release = 0 }

function orgn.update_envelope(n, a, d, s, r)
    local adsr = { Attack = 0, Decay = 0, Sustain = 0, Release = 0 }
    local slopes = {}
    local mode = params:get("env_mode")
    local shape = params:get("env_shape")
    local size = params:get("env_size") * 1000 -- s to ms
    
    if mode == 1 then -- gate
      adsr.Sustain = 1
      slopes = { "Attack", "Release" }
    elseif mode == 2 then -- trig
      slopes = { "Attack", "Decay" }
    end
    
    if shape == 1 then -- |\
      adsr[slopes[2]] = size
    elseif shape == 2 then -- /\
      adsr[slopes[1]] = size
      adsr[slopes[2]] = size
    elseif shape == 3 then -- /|
      adsr[slopes[1]] = size
    end
    
    if a then adsr.Attack = a end
    if d then adsr.Decay = d end
    if s then adsr.Sustain = s end
    if r then adsr.Release = r end
    
    ADSR = adsr
    
    local i1 = 1
    local i2 = orgn.poly
    
    if n then
      i1 = n
      i2 = n
    end
    
    local set = ""
    for i = i1, i2 do
      for k,v in pairs(adsr) do
        set = set .. "env" .. i .. "." .. k .. " " .. v .. " "
      end
    end
    return set
  end

function orgn.init()
  
  engine.trace(1)
  
  r.engine.poly_new("fg", "FreqGate", orgn.poly)
  r.engine.poly_new("glide", "Slew", orgn.poly)
  r.engine.poly_new("ptrack", "Amp", orgn.poly)
  r.engine.poly_new("osca", "SineOsc", orgn.poly)
  r.engine.poly_new("oscb", "SineOsc", orgn.poly)
  r.engine.poly_new("oscc", "SineOsc", orgn.poly)
  r.engine.poly_new("lvla", "Amp", orgn.poly)
  r.engine.poly_new("lvlb", "Amp", orgn.poly)
  r.engine.poly_new("lvlc", "Amp", orgn.poly)
  r.engine.poly_new("env", "ADSREnv", orgn.poly)
  r.engine.poly_new("amp", "Amp", orgn.poly)
  r.engine.poly_new("lvlvel", "MGain", orgn.poly)
  r.engine.poly_new("pan", "Pan", orgn.poly)
  r.engine.poly_new("lvl", "SGain", orgn.poly)
  
  engine.new("lfo1", "SineLFO")
  engine.new("lfoamp1", "Amp")
  -- engine.new("lfop", "Amp")
  -- engine.new("lfolvla", "Amp")
  -- engine.new("lfolvlb", "Amp")
  -- engine.new("lfolvlc", "Amp")
  -- engine.new("lfosr", "Amp")
  
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
  -- r.engine.poly_connect("fg/Gate", "env/Gate", orgn.poly)
  r.engine.poly_connect("glide/Out", "ptrack/In", orgn.poly)
  r.engine.poly_connect("ptrack/Out", "osca/FM", orgn.poly)
  r.engine.poly_connect("ptrack/Out", "oscb/FM", orgn.poly)
  r.engine.poly_connect("ptrack/Out", "oscc/FM", orgn.poly)
  r.engine.poly_connect("osca/Out", "lvla/In", orgn.poly)
  r.engine.poly_connect("oscb/Out", "lvlb/In", orgn.poly)
  r.engine.poly_connect("oscc/Out", "lvlc/In", orgn.poly)
  r.engine.poly_connect("oscc/Out", "osca/PM", orgn.poly)
  r.engine.poly_connect("oscc/Out", "oscb/PM", orgn.poly)
  r.engine.poly_connect("oscb/Out", "oscc/PM", orgn.poly)
  r.engine.poly_connect("lvla/Out", "amp/In", orgn.poly)
  r.engine.poly_connect("lvlb/Out", "amp/In", orgn.poly)
  r.engine.poly_connect("lvlc/Out", "amp/In", orgn.poly)
  r.engine.poly_connect("env/Out", "amp/Lin", orgn.poly)
  r.engine.poly_connect("amp/Out", "lvlvel/In", orgn.poly)
  r.engine.poly_connect("lvlvel/Out", "pan/In", orgn.poly)
  r.engine.poly_connect("pan/Left", "lvl/Left", orgn.poly)
  r.engine.poly_connect("pan/Right", "lvl/Right", orgn.poly)

  for voicenum=1, orgn.poly do
    engine.connect("lvl"..voicenum.."/Left", "decil/In")
    engine.connect("lvl"..voicenum.."/Right", "decir/In")
    engine.connect("lvl"..voicenum.."/Left", "xfade/InALeft")
    engine.connect("lvl"..voicenum.."/Right", "xfade/InARight")
    
    -- engine.connect("lvl"..voicenum.."/Left", "soundout/Left")
    -- engine.connect("lvl"..voicenum.."/Right", "soundout/Right")
    
    engine.connect("lfoamp1/Out", "ptrack"..voicenum.."/In")
  end
  
  engine.connect("lfo1/Out", "lfoamp1/In")
  
  -- engine.connect("soundin/Left", "inlvl/Left")
  -- engine.connect("soundin/Right", "inlvl/Right")
  -- engine.connect("inlvl/Left", "decil/In")
  -- engine.connect("inlvl/Right", "decir/In")
  -- engine.connect("inlvl/Left", "xfade/InALeft")
  -- engine.connect("inlvl/Right", "xfade/InARight")
  engine.connect("decil/Out", "eql/In")
  engine.connect("decir/Out", "eqr/In")
  engine.connect("eql/Out", "xfade/InBLeft")
  engine.connect("eqr/Out", "xfade/InBRight")
  engine.connect("xfade/Left", "outlvl/Left")
  engine.connect("xfade/Right", "outlvl/Right")
  engine.connect("outlvl/Left", "soundout/Left")
  engine.connect("outlvl/Right", "soundout/Right")
  
  r.engine.poly_set("osca.FM", 1, orgn.poly)
  r.engine.poly_set("oscb.FM", 1, orgn.poly)
  r.engine.poly_set("oscc.FM", 1, orgn.poly)
  r.engine.poly_set("ptrack.Level", 1, orgn.poly)
  
  engine.bulkset("xfade.TrimA 1 xfade.TrimB 1 xfade.Master 1")
  
  r.util.make_param("lvl", "SGain", "Gain", orgn.poly, { default=0.0 }, "lvl abc")
  r.util.make_param("lvla", "Amp", "Level", orgn.poly, { default=1 }, "lvl a")
  r.util.make_param("lvlb", "Amp", "Level", orgn.poly, { default=0.3 }, "lvl b")
  r.util.make_param("lvla", "Amp", "Level", orgn.poly, { default=0.3 }, "lvl c")
  r.util.make_param("osca", "SineOsc", "PM", orgn.poly, {}, "pm c -> a")
  r.util.make_param("oscb", "SineOsc", "PM", orgn.poly, {}, "pm c -> b")
  r.util.make_param("oscc", "SineOsc", "PM", orgn.poly, {}, "pm c <- b")
  r.util.make_param("glide", "Slew", "Time", orgn.poly, {}, "glide")
  params:add { type="control", id="width", name="width", controlspec=controlspec.UNIPOLAR }
  
  params:add_separator()
  
  local function send_env()
    engine.bulkset(orgn.update_envelope())
  end
  
  em = metro.init()
  
  function env_action()
    em:stop()
    em.event = send_env
    em:start( 0.1, 1)
    
    orgn.controls.shape.v = params:get("env_shape")
    orgn.controls.mode.v = params:get("env_mode") == 2
    
    orgn.g_redraw(g)
  end
  
  params:add { type="control", id="env_size", name="env size", controlspec=controlspec.new(0.001, 6, 'exp', 0, 0.5, "s"), action=env_action }
  params:add { type="option", id="env_shape", name="env shape", options={ "|\\", "/\\", "/|" }, action=env_action }
  params:add { type="option", id="env_mode", name="env mode", options={ "gate","trig" }, action=env_action }
  
  params:add_separator()
  
  r.util.make_param("lfo1", "SineLFO", "Frequency", 1, {}, "lfo freq")
  r.util.make_param("lfoamp1", "Amp", "Level", 1, { maxval = 0.5 }, "lfo depth")
  
  params:add_separator()
  
  r.util.make_param("xfade", "XFader", "Fade", 1, {}, "dry/wet")
  
  params:add { 
    type="control", id="samplerate", name="sample rate", controlspec=r.specs.Decimator.Rate,
    action=function(v)
      engine.bulkset("decil.Rate " .. v .. " decir.Rate " .. v)
    end 
  }
  params:add { 
    type="control", id="bitdepth", name="bit depth", controlspec=r.specs.Decimator.Depth,
    action=function(v)
      engine.bulkset("decil.Depth " .. v .. " decir.Depth " .. v)
    end 
  }
  params:add { 
    type="control", id="smoothing", name="smoothing", controlspec=r.specs.Decimator.Smooth,
    action=function(v)
      engine.bulkset("decil.Smooth " .. v .. " decir.Smooth " .. v)
    end
  }
  params:add {
    type="control", id="eqfreq", name="eq freq", controlspec=r.specs.EQBPFilter.Frequency,
    action=function(v) engine.bulkset("eqr.Frequency " .. v .. " eql.Frequency " .. v) end
  }
  params:add {
    type="control", id="eqwidth", name="eq width", controlspec=r.specs.EQBPFilter.Bandwidth,
    action=function(v) engine.bulkset("eqr.Bandwidth " .. v .. " eql.Bandwidth " .. v) end
  }
  
  r.util.make_param("outlvl", "SGain", "Gain", orgn.poly, { default=0.0 }, "lvl out")
  
  params:read()
  params:bang()
  
  send_env()
end

nm = {}

for i = 1, orgn.poly do
  nm[i] = metro.init()
end


orgn.noteon = function(note)
  local slot = orgn.voice:get()
  orgn.voice:push(note, slot)
  
  engine.set("env"..slot.id..".Gate", -1)
  
  local function on()
    print("on", slot.id)
    
    engine.bulkset("env"..slot.id..".Gate 1 fg"..slot.id..".Frequency "..musicutil.note_num_to_freq(note))
  end
  
  if ADSR.Attack > 1000 then
    nm[slot.id]:stop()
    nm[slot.id].event = on
    nm[slot.id]:start( 0.1, 1)
  else
    on()
  end
end

function k()
  for i = 1, orgn.poly do
    engine.bulkset("env"..i..".Gate -1")
  end
end

rm = {}

for i = 1, orgn.poly do
  rm[i] = metro.init()
end

gm = {}

for i = 1, orgn.poly do
  gm[i] = metro.init()
end

orgn.noteoff = function(note)
  local slot = orgn.voice:pop(note)
  
  if slot then
    if ADSR.Attack > 1000 then
      gm[slot.id]:stop()
      gm[slot.id].event = function() 
        engine.bulkset("env"..slot.id..".Gate 0") 
      end
      gm[slot.id]:start(0.1, 1)
    else
      engine.bulkset("env"..slot.id..".Gate 0")
    end
    
    local function off()
    print("off", slot.id)
      orgn.voice:release(slot)
    end
    
    -- orgn.voice:release(slot)
    if ADSR.Release > 1000 then
      rm[slot.id]:stop()
      rm[slot.id].event = off
      rm[slot.id]:start(ADSR.Release / 1000, 1)
    else
      off()
    end
  end
end

--[[

TODO

[] random pan
[] random velocity

mappings:
[x] scale
[x glide time 0 0.1s 0.3s 1s
[] osc c oct 0 1 2 3 7
[x] envelope shape |\  / \  /|

]]--

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
  scale = value:new{ v = 1, p = { { 1, 4 }, 1 } },
  shape = value:new{ v = 2, p = { { 5, 7 }, 1 }, 
    event = function(self, v)
      params:set("env_shape", v)
  end },
  mode = toggle:new{ v = false, p = { 8, 1 }, 
    event = function(self, v)
      params:set("env_mode", v and 2 or 1)
  end },
  glide = value:new{ v = 1, p = { { 1, 3 }, 2 }, 
    event = function(self, v)
      if v == 1 then
        params:set("glide_time", 0)
      elseif v == 2 then
        params:set("glide_time", 0.3)
      elseif v == 3 then
        params:set("glide_time", 1)
      end
  end },
  oct = value:new{ v = 2, p = { { 4, 8 }, 2 }, 
    event = function(self, v)
    
  end },
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

orgn.keyboard = orgn.make_keyboard(6, 12) -- call keybaord function w/ 8 rows & octave separation. u can change this !


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