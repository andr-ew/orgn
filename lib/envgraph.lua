--- Envelope graph drawing module.
-- Subclass of Graph for drawing common envelope graphs. Includes DADSR, ADSR, ASR and AR (Perc).
--
-- @module lib.EnvGraph
-- @release v1.0.1
-- @author Mark Eats

local EnvGraph = {}
EnvGraph.__index = EnvGraph

local Graph = require "graph"


------------------------------------------------------------MODS------------------------

-------- Private utility methods --------

local function graph_to_screen(self, x, y, round)
  if self._x_warp == "exp" then
    x = util.explin(self._x_min, self._x_max, self._x, self._x + self._w - 1, x)
  else
    x = util.linlin(self._x_min, self._x_max, self._x, self._x + self._w - 1, x)
  end
  if self._y_warp == "exp" then
    y = util.explin(self._y_min, self._y_max, self._y + self._h - 1, self._y, y)
  else
    y = util.linlin(self._y_min, self._y_max, self._y + self._h - 1, self._y, y)
  end
  if round then
    x, y = util.round(x), util.round(y)
  end
  return x, y
end

local function recalculate_screen_coords(self)
  self.origin_sx = util.round(util.linlin(self._x_min, self._x_max, self._x, self._x + self._w - 1, 0))
  self.origin_sy = util.round(util.linlin(self._y_min, self._y_max, self._y + self._h - 1, self._y, 0))
  for i = 1, #self._points do
    self._points[i].sx, self._points[i].sy = graph_to_screen(self, self._points[i].x, self._points[i].y, true)
  end
  self._lines_dirty = true
  self._spline_dirty = true
end

local function generate_line_from_points(self)
  
  if #self._points < 2 or (self._style ~= "line" and self._style ~= "line_and_point") then return end
  
  local line_path = {}
  local px, py, prev_px, prev_py, sx, sy, prev_sx, prev_sy
  
  px, py = self._points[1].x, self._points[1].y
  sx, sy = self._points[1].sx, self._points[1].sy
  
  table.insert(line_path, {x = sx, y = sy})
  
  for i = 2, #self._points do
    
    prev_px, prev_py = px, py
    prev_sx, prev_sy = sx, sy
    px, py = self._points[i].x, self._points[i].y
    sx, sy = self._points[i].sx, self._points[i].sy
    
    -- Exponential or curve value
    local curve = self._points[i].curve
    if curve == "exp" or ( type(curve) == "number" and math.abs(curve) > 0.01) then
      
      local sx_distance = sx - prev_sx
      
      if sx_distance <= 1 or prev_sy == sy then
        -- Draw a straight line
        table.insert(line_path, {x = sx, y = sy})
        
      else
        
        local grow, a
        if type(curve) == "number" then
          grow = math.exp(curve)
          a = 1 / (1.0 - grow)
        end
        
        for sample_x = prev_sx + 1, sx - 1 do
          local sample_x_progress = (sample_x - prev_sx) / sx_distance
          if self._x_warp == "exp" then
            local sample_graph_x = util.linexp(self._x_min, self._x_max, self._x_min, self._x_max, prev_px + (px - prev_px) * sample_x_progress)
            local prev_px_exp = util.linexp(self._x_min, self._x_max, self._x_min, self._x_max, prev_px)
            local px_exp = util.linexp(self._x_min, self._x_max, self._x_min, self._x_max, px)
            sample_x_progress = (sample_graph_x - prev_px_exp) / (px_exp - prev_px_exp)
          end
          if sample_x_progress <= 0 then sample_x_progress = 1 end
          
          local sy_section
          
          if curve == "exp" then
            -- Avoiding zero
            local prev_adj_y, cur_adj_y
            if prev_py < 0 then prev_adj_y = math.min(prev_py, -0.0001)
            else prev_adj_y = math.max(prev_py, 0.0001) end
            if py < 0 then cur_adj_y = math.min(py, -0.0001)
            else cur_adj_y = math.max(py, 0.0001) end
            
            sy_section = util.linexp(0, 1, prev_adj_y, cur_adj_y, sample_x_progress)
            
          else
            -- Curve formula from SuperCollider
            sy_section = util.linlin(0, 1, prev_py, py, a - (a * math.pow(grow, sample_x_progress)))
            
          end
          
          if self._y_warp == "exp" then
            sy_section = util.explin(self._y_min, self._y_max, self._y + self._h - 1, self._y, sy_section)
          else
            sy_section = util.linlin(self._y_min, self._y_max, self._y + self._h - 1, self._y, sy_section)
          end
          
          table.insert(line_path, {x = sample_x, y = sy_section})
        end
        table.insert(line_path, {x = sx, y = sy})
      end
      
    -- Linear
    else
      table.insert(line_path, {x = sx, y = sy})
      
    end
  end
  table.insert(self._lines, line_path)
end

local function generate_lines_from_functions(self)
  local width = self._w - 1
  
  for i = 1, #self._functions do
    local line_path = {}
    local step = 1 / self._functions[i].sample_quality
    if width % step ~= 0 then
      step = (width - 0.000001) / math.modf(width / step)
    end
    
    for sx = self._x, self._x + width, step do
      local x, y
      if self._x_warp == "exp" then
        x = util.explin(self._x, self._x + width, self._x_min, self._x_max, sx)
      else
        x = util.linlin(self._x, self._x + width, self._x_min, self._x_max, sx)
      end
      y = self._functions[i].func(x)
      if self._y_warp == "exp" then
        y = util.explin(self._y_min, self._y_max, self._y + self._h - 1, self._y, y)
      else
        y = util.linlin(self._y_min, self._y_max, self._y + self._h - 1, self._y, y)
      end
      table.insert(line_path, {x = sx, y = y})
    end
    
    table.insert(self._lines, line_path)
  end
end

local function interpolate_points(p1, p2, ratio, exp_x, exp_y)
  ratio = ratio or 0.5
  local point = {}
  if exp_x then
    point.x = util.linexp(0, 1, p1.x, p2.x, ratio)
  else
    point.x = util.linlin(0, 1, p1.x, p2.x, ratio)
  end
  if exp_y then
    point.y = util.linexp(0, 1, p1.y, p2.y, ratio)
  else
    point.y = util.linlin(0, 1, p1.y, p2.y, ratio)
  end
  return point
end

local function generate_spline_from_points(self)
  -- Draws a b-spline using beziers.
  -- Based on https://stackoverflow.com/questions/2534786/drawing-a-clamped-uniform-cubic-b-spline-using-cairo
  self._spline = {}
  local points = {table.unpack(self._points)}
  local num_points = #points
  
  if num_points < 2 then return end
  
  local exp_x = self._x_warp == "exp"
  local exp_y = self._y_warp == "exp"
  
  -- Pad ends to clamp
  local last = points[num_points]
  for i = 1, 3 do
    table.insert(points, 1, points[1])
    table.insert(points, last)
    num_points = num_points + 2
  end
  
  -- Interpolate
  local one_thirds = {}
  local two_thirds = {}
  for i = 1, num_points - 1 do
    table.insert(one_thirds, interpolate_points(points[i], points[i + 1], 0.333333, exp_x, exp_y))
    table.insert(two_thirds, interpolate_points(points[i], points[i + 1], 0.666666, exp_x, exp_y))
  end
  
  -- Create bezier coords
  for i = 1, num_points - 3 do
    table.insert(self._spline, interpolate_points(two_thirds[i], one_thirds[i+1], 0.5, exp_x, exp_y)) -- Start
    table.insert(self._spline, one_thirds[i + 1])
    table.insert(self._spline, two_thirds[i + 1])
    table.insert(self._spline, interpolate_points(two_thirds[i + 1], one_thirds[i + 2], 0.5, exp_x, exp_y))
  end
  
  -- Scale to screen space and shift 0.5 for line drawing
  for k, v in pairs(self._spline) do
    v.x, v.y = graph_to_screen(self, v.x, v.y, false)
    v.x = v.x + 0.5
    v.y = v.y + 0.5
  end
end



-------- Private drawing methods --------

local function draw_axes(self)
  if self._show_x_axis then
    screen.level(3)
    screen.move(self._x, self.origin_sy + 0.5)
    screen.line(self._x + self._w, self.origin_sy + 0.5)
    screen.stroke()
  end
  if self._show_y_axis then
    screen.level(1) -- This looks the same as the x line at level 3 for some reason
    screen.move(self.origin_sx + 0.5, self._y)
    screen.line(self.origin_sx + 0.5, self._y + self._h)
    screen.stroke()
  end
end

local function draw_points(self)
  
  if (self._style ~= "point" and self._style ~= "line_and_point" and self._style ~= "spline_and_point") then return end
  
  for i = 1, #self._points do
    local sx, sy = self._points[i].sx, self._points[i].sy
    
    screen.rect(sx - 1, sy - 1, 3, 3)
    if self._active then screen.level(15) else screen.level(5) end
    screen.fill()
    
    if self._points[i].highlight then
      screen.rect(sx - 2.5, sy - 2.5, 6, 6)
      screen.stroke()
    end
  end
end

local function draw_bars(self)
  
  if self._style ~= "bar" then return end
  
  for i = 1, #self._points do
    local sx, sy = self._points[i].sx, self._points[i].sy
    
    if self._points[i].highlight then
      if sy < self.origin_sy then
        screen.rect(sx - 1, sy, 3, math.max(1, self.origin_sy - sy + 1))
      else
        screen.rect(sx - 1, self.origin_sy, 3, math.max(1, sy - self.origin_sy + 1))
      end
      if self._active then screen.level(15) else screen.level(3) end
      screen.fill()
      
    else
      screen.level(3)
      if math.abs(sy - self.origin_sy) < 1 then
        screen.rect(sx - 1, sy, 3, 1)
        screen.fill()
      elseif sy < self.origin_sy then
        screen.rect(sx - 0.5, sy + 0.5, 2, math.max(0, self.origin_sy - sy))
        screen.stroke()
      else
        screen.rect(sx - 0.5, self.origin_sy + 0.5, 2, math.max(0, sy - self.origin_sy))
        screen.stroke()
      end
    end
    
  end
end

local function draw_lines(self, lvl)
  
  if (self._style ~= "line" and self._style ~= "line_and_point") and #self._functions == 0 then return end
  
  if self._lines_dirty then
    self._lines = {}
    generate_line_from_points(self)
    generate_lines_from_functions(self)
    self._lines_dirty = false
  end
  
  screen.line_join("round")
  if self._active then screen.level(lvl) else screen.level(lvl) end
  for l = 1, #self._lines do
    screen.move(self._lines[l][1].x + 0.5, self._lines[l][1].y + 0.5)
    for i = 2, #self._lines[l] do
      screen.line(self._lines[l][i].x + 0.5, self._lines[l][i].y + 0.5)
    end
    screen.stroke()
  end
  screen.line_join("miter")
end

local function draw_spline(self, lvl)
  if (self._style ~= "spline" and self._style ~= "spline_and_point") then return end
  
  if self._spline_dirty then
    generate_spline_from_points(self)
    self._spline_dirty = false
  end
  
  if self._active then screen.level(lvl) else screen.level(lvl) end
  for i = 1, #self._spline - 4, 4 do
    screen.move(self._spline[i].x, self._spline[i].y)
    screen.curve(self._spline[i + 1].x, self._spline[i + 1].y, self._spline[i + 2].x, self._spline[i + 2].y, self._spline[i + 3].x, self._spline[i + 3].y)
  end
  screen.stroke()
end



-------- Redraw --------

--- Redraw the graph.
-- Call whenever graph data or settings have been changed.
function Graph:redraw(lvl)
  
  screen.line_width(1)
  
  -- draw_axes(self)
  draw_lines(self, lvl)
  draw_spline(self, lvl)
  --draw_points(self)
  -- draw_bars(self)
end


------------------------------------------------------------/MODS-----------------------


-------- Private utility methods --------

local function new_env_graph(x_min, x_max, y_min, y_max)
  local graph = Graph.new(x_min, x_max, "lin", y_min, y_max, "lin", "line_and_point", false, false)
  setmetatable(EnvGraph, {__index = Graph})
  setmetatable(graph, EnvGraph)
  return graph
end

local function set_env_values(self, delay, attack, decay, sustain, release, level, curve)
  if not self._env then self._env = {} end
  if delay then self._env.delay = math.max(0, delay) end
  if attack then self._env.attack = math.max(0, attack) end
  if decay then self._env.decay = math.max(0, decay) end
  if sustain then self._env.sustain = util.clamp(sustain, 0, 1) end
  if release then self._env.release = math.max(0, release) end
  if level then self._env.level = util.clamp(level, self._y_min, self._y_max) end
  if curve then self._env.curve = curve end
end


-------- Public methods --------

--- Create a new DADSR EnvGraph object.
-- All arguments optional.
-- @tparam number x_min Minimum value for x axis, defaults to 0.
-- @tparam number x_max Maximum value for x axis, defaults to 1.
-- @tparam number y_min Minimum value for y axis, defaults to 0.
-- @tparam number y_max Maximum value for y axis, defaults to 1.
-- @tparam number delay Delay value, defaults to 0.1
-- @tparam number attack Attack value, defaults to 0.05.
-- @tparam number decay Decay value, defaults to 0.2.
-- @tparam number sustain Sustain value, accepts 0-1, defaults to 0.5.
-- @tparam number release Release value, defaults to 0.3.
-- @tparam number level Level value, accepts y_min to y_max, defaults to 1.
-- @tparam string|number curve Curve of envelope, accepts "lin", "exp" or a number where 0 is linear and positive and negative numbers curve the envelope up and down, defaults to -4.
-- @treturn EnvGraph Instance of EnvGraph.
function EnvGraph.new_dadsr(x_min, x_max, y_min, y_max, delay, attack, decay, sustain, release, level, curve)
  local graph = new_env_graph(x_min, x_max, y_min, y_max)
  set_env_values(graph, delay or 0.1, attack or 0.05, decay or 0.2, sustain or 0.5, release or 0.3, level or 1, curve or -4)
  
  graph:add_point(0, 0)
  graph:add_point(graph._env.delay, 0)
  graph:add_point(graph._env.delay + graph._env.attack, graph._env.level, graph._env.curve)
  graph:add_point(graph._env.delay + graph._env.attack + graph._env.decay, graph._env.level * graph._env.sustain, graph._env.curve)
  graph:add_point(graph._x_max - graph._env.release, graph._env.level * graph._env.sustain, graph._env.curve)
  graph:add_point(graph._x_max, 0, graph._env.curve)
  return graph
end

--- Edit a DADSR EnvGraph object.
-- All arguments optional.
-- @tparam number delay Delay value.
-- @tparam number attack Attack value.
-- @tparam number decay Decay value.
-- @tparam number sustain Sustain value, accepts 0-1.
-- @tparam number release Release value.
-- @tparam number level Level value, accepts y_min to y_max.
-- @tparam string|number curve Curve of envelope, accepts "lin", "exp" or a number where 0 is linear and positive and negative numbers curve the envelope up and down, defaults to -4.
function EnvGraph:edit_dadsr(delay, attack, decay, sustain, release, level, curve)
  if #self._points ~= 6 then return end
  set_env_values(self, delay, attack, decay, sustain, release, level, curve)
  
  self:edit_point(2, self._env.delay)
  self:edit_point(3, self._env.delay + self._env.attack, self._env.level, self._env.curve)
  self:edit_point(4, self._env.delay + self._env.attack + self._env.decay, self._env.level * self._env.sustain, self._env.curve)
  self:edit_point(5, self._x_max - self._env.release, self._env.level * self._env.sustain, self._env.curve)
  self:edit_point(6, nil, nil, self._env.curve)
end

--- Create a new ADSR EnvGraph object.
-- All arguments optional.
-- @tparam number x_min Minimum value for x axis, defaults to 0.
-- @tparam number x_max Maximum value for x axis, defaults to 1.
-- @tparam number y_min Minimum value for y axis, defaults to 0.
-- @tparam number y_max Maximum value for y axis, defaults to 1.
-- @tparam number attack Attack value, defaults to 0.05.
-- @tparam number decay Decay value, defaults to 0.2.
-- @tparam number sustain Sustain value, accepts 0-1, defaults to 0.5.
-- @tparam number release Release value, defaults to 0.3.
-- @tparam number level Level value, accepts y_min to y_max, defaults to 1.
-- @tparam string|number curve Curve of envelope, accepts "lin", "exp" or a number where 0 is linear and positive and negative numbers curve the envelope up and down, defaults to -4.
-- @treturn EnvGraph Instance of EnvGraph.
function EnvGraph.new_adsr(x_min, x_max, y_min, y_max, attack, decay, sustain, release, level, curve)
  local graph = new_env_graph(x_min, x_max, y_min, y_max)
  set_env_values(graph, nil, attack or 0.05, decay or 0.2, sustain or 0.5, release or 0.3, level or 1, curve or -4)
  
  graph:add_point(0, 0)
  graph:add_point(graph._env.attack, graph._env.level, graph._env.curve)
  graph:add_point(graph._env.attack + graph._env.decay, graph._env.level * graph._env.sustain, graph._env.curve)
  graph:add_point(graph._x_max - graph._env.release, graph._env.level * graph._env.sustain, graph._env.curve)
  graph:add_point(graph._x_max, 0, graph._env.curve)
  return graph
end

--- Edit an ADSR EnvGraph object.
-- All arguments optional.
-- @tparam number attack Attack value.
-- @tparam number decay Decay value.
-- @tparam number sustain Sustain value, accepts 0-1.
-- @tparam number release Release value.
-- @tparam number level Level value, accepts y_min to y_max.
-- @tparam string|number curve Curve of envelope, accepts "lin", "exp" or a number where 0 is linear and positive and negative numbers curve the envelope up and down, defaults to -4.
function EnvGraph:edit_adsr(attack, decay, sustain, release, level, curve)
  if #self._points ~= 5 then return end
  set_env_values(self, nil, attack, decay, sustain, release, level, curve)
  
  self:edit_point(2, self._env.attack, self._env.level, self._env.curve)
  self:edit_point(3, self._env.attack + self._env.decay, self._env.level * self._env.sustain, self._env.curve)
  self:edit_point(4, self._x_max - self._env.release, self._env.level * self._env.sustain, self._env.curve)
  self:edit_point(5, nil, nil, self._env.curve)
end


--- Create a new ASR EnvGraph object.
-- All arguments optional.
-- @tparam number x_min Minimum value for x axis, defaults to 0.
-- @tparam number x_max Maximum value for x axis, defaults to 1.
-- @tparam number y_min Minimum value for y axis, defaults to 0.
-- @tparam number y_max Maximum value for y axis, defaults to 1.
-- @tparam number attack Attack value, defaults to 0.05.
-- @tparam number release Release value, defaults to 0.3.
-- @tparam number level Level value, accepts y_min to y_max, defaults to 1.
-- @tparam string|number curve Curve of envelope, accepts "lin", "exp" or a number where 0 is linear and positive and negative numbers curve the envelope up and down, defaults to -4.
-- @treturn EnvGraph Instance of EnvGraph.
function EnvGraph.new_asr(x_min, x_max, y_min, y_max, attack, release, level, curve)
  local graph = new_env_graph(x_min, x_max, y_min, y_max)
  set_env_values(graph, nil, attack or 0.05, nil, nil, release or 0.3, level or 1, curve or -4)
  
  graph:add_point(0, 0)
  graph:add_point(graph._env.attack, graph._env.level, graph._env.curve)
  graph:add_point(graph._x_max - graph._env.release, graph._env.level, graph._env.curve)
  graph:add_point(graph._x_max, 0, graph._env.curve)
  return graph
end

--- Edit an ASR EnvGraph object.
-- All arguments optional.
-- @tparam number attack Attack value.
-- @tparam number release Release value.
-- @tparam number level Level value, accepts y_min to y_max.
-- @tparam string|number curve Curve of envelope, accepts "lin", "exp" or a number where 0 is linear and positive and negative numbers curve the envelope up and down, defaults to -4.
function EnvGraph:edit_asr(attack, release, level, curve)
  if #self._points ~= 4 then return end
  set_env_values(self, nil, attack, nil, nil, release, level, curve)
  
  self:edit_point(2, self._env.attack, self._env.level, self._env.curve)
  self:edit_point(3, self._x_max - self._env.release, self._env.level, self._env.curve)
  self:edit_point(4, nil, nil, self._env.curve)
end

--- Create a new AR (Perc) EnvGraph object.
-- All arguments optional.
-- @tparam number x_min Minimum value for x axis, defaults to 0.
-- @tparam number x_max Maximum value for x axis, defaults to 1.
-- @tparam number y_min Minimum value for y axis, defaults to 0.
-- @tparam number y_max Maximum value for y axis, defaults to 1.
-- @tparam number attack Attack value, defaults to 0.05.
-- @tparam number release Release value, defaults to 0.3.
-- @tparam number level Level value, accepts y_min to y_max, defaults to 1.
-- @tparam string|number curve Curve of envelope, accepts "lin", "exp" or a number where 0 is linear and positive and negative numbers curve the envelope up and down, defaults to -4.
-- @treturn EnvGraph Instance of EnvGraph.
function EnvGraph.new_ar(x_min, x_max, y_min, y_max, attack, release, level, curve)
  local graph = new_env_graph(x_min, x_max, y_min, y_max)
  set_env_values(graph, nil, attack or 0.1, nil, nil, release or 0.9, level or 1, curve or -4)
  
  graph:add_point(0, 0)
  graph:add_point(graph._env.attack, graph._env.level, graph._env.curve)
  graph:add_point(graph._env.attack + graph._env.release, 0, graph._env.curve)
  return graph
end

--- Edit an AR (Perc) EnvGraph object.
-- All arguments optional.
-- @tparam number attack Attack value.
-- @tparam number release Release value.
-- @tparam number level Level value, accepts y_min to y_max.
-- @tparam string|number curve Curve of envelope, accepts "lin", "exp" or a number where 0 is linear and positive and negative numbers curve the envelope up and down, defaults to -4.
function EnvGraph:edit_ar(attack, release, level, curve)
  if #self._points ~= 3 then return end
  set_env_values(self, nil, attack, nil, nil, release, level, curve)
  
  self:edit_point(2, self._env.attack, self._env.level, self._env.curve)
  self:edit_point(3, self._env.attack + self._env.release, nil, self._env.curve)
end


-- Getters

--- Get delay value.
-- @treturn number Delay value.
function EnvGraph:get_delay() return self._env.delay end

--- Get attack value.
-- @treturn number Attack value.
function EnvGraph:get_attack() return self._env.attack end

--- Get decay value.
-- @treturn number Decay value.
function EnvGraph:get_decay() return self._env.decay end

--- Get sustain value.
-- @treturn number Sustain value.
function EnvGraph:get_sustain() return self._env.sustain end

--- Get release value.
-- @treturn number Release value.
function EnvGraph:get_release() return self._env.release end

--- Get level value.
-- @treturn number Level value.
function EnvGraph:get_level() return self._env.level end

--- Get curve value.
-- @treturn string|number Curve value.
function EnvGraph:get_curve() return self._env.curve end


return EnvGraph
