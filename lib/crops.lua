LO = 4;
MID = 8;
HI = 12;

crops = {
  crops = {},
  controls = {},
  metacontrols = {}
}

function crops:key(g, x, y, z)
  for k,v in pairs(self.crops) do
    v:key(g, x, y, z)
  end
end

function crops:draw(g)
  for k,v in pairs(self.crops) do
    v:draw(g)
  end
end

crop = {
  en = function(self) return true end
}

function crop:key(g, x, y, z)
  if self:en() then
    for k,v in pairs(self) do
      if type(v) == "table" and v.is_control then
        
        local pressed, args = v:key(x, y, z)
        
        if pressed then
          v:event(table.unpack(args))
          
          for i,w in ipairs(crops.metacontrols) do
            w:pass(args)
          end
        end
        
        v:draw(g)
      end
    end
  end
end

function crop:draw(g)
  if self:en() then
    for k,v in pairs(self) do
      if type(v) == "table" and v.is_control then
        v:draw(g)
      end
    end
  end
end

function crop:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    
    table.insert(crops.crops, o)
    
    return o
end

control = {
    b = { 0, HI },
    en = function(self) return true end,
    event = function(self) end,
    get = function(self) return self.v end,
    set = function(self, input)
        self.v = input
        self:event(self.v)
    end,
    draw = function(self, g) end,
    key = function() end,
    is_control = true
}

function control:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    
    table.insert(crops.controls, o)
    
    return o
end

metacontrol = control:new({
  pass = function(self) end
})

toggle = control:new()

function toggle:draw(g)
    if self:en() then
        g:led(self.p[1], self.p[2], self.b[self.v and 2 or 1])
    end
end

function toggle:key(x, y, z)
    if self:en() then
        if x == self.p[1] and y == self.p[2] then
            if z == 0 then
                local last = self.v
                self.v = not self.v
                
                return true, { self.v, last }
            end
        end
    end
end

function toggle:set(input)
    self.v = input
    self:event(self.v)
end

momentary = toggle:new()

function momentary:key(x, y, z)
    if self:en() then
        if x == self.p[1] and y == self.p[2] then
            self.v = z == 1
            
            return true, { self.v }
        end
    end
end

value = control:new({ v = 1 })

function value:draw(g)
    if self:en() then
        if type(self.p[1]) == "table" then
            for i = self.p[1][1], self.p[1][2] do
                g:led(i, self.p[2], (i - self.p[1][1] + 1 == self.v) and self.b[2] or self.b[1])
            end
        elseif type(self.p[2]) == "table" then
            for i = self.p[2][1], self.p[2][2] do
                g:led(self.p[1], i, (i - self.p[2][1] + 1 == self.v) and self.b[2] or self.b[1])
            end
        end
    end
end

function value:key(x, y, z)
    if self:en() then
        
        local is_x = (type(self.p[1]) == "table")
        local l_p = is_x and self.p[1] or self.p[2]
        local s_p = is_x and self.p[2] or self.p[1]
        local l_dim = is_x and x or y
        local s_dim = is_x and y or x
        
        if s_dim == s_p then
            for i = l_p[1], l_p[2] do
                if i == l_dim and z == 1 then
                    local last = self.v
                    self.v = i + 1 - l_p[1]

                    return true, { self.v, last }
                end
            end
        end
    end
end

toggles = control:new()

function toggles:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    
    table.insert(crops.controls, o)
    
    return o
end

function toggles:draw(g)
    if self:en() then
        
        local is_x = (type(self.p[1]) == "table")
        local l_p = is_x and self.p[1] or self.p[2]
        local s_p = is_x and self.p[2] or self.p[1]
        local l_dim = is_x and x or y
        local s_dim = is_x and y or x
        
        local mtrx = {}
        for i = 1, l_p[2] - l_p[1] do
            mtrx[i] = false
        end
        for i,v in ipairs(self.v) do
            mtrx[v] = true
        end
        
        for i = l_p[1], l_p[2] do
            if is_x then
                g:led(i, s_p, mtrx[i] and self.b[2] or self.b[1])
            else
                g:led(s_p, i, mtrx[i] and self.b[2] or self.b[1])
            end
        end
    end
end

function toggles:key(x, y, z)
     if self:en() then
        
        local is_x = (type(self.p[1]) == "table")
        local l_p = is_x and self.p[1] or self.p[2]
        local s_p = is_x and self.p[2] or self.p[1]
        local l_dim = is_x and x or y
        local s_dim = is_x and y or x
        
        if s_dim == s_p then
            for i = l_p[1], l_p[2] do
                if i == l_dim and z == 1 then
                    local last = {}
                    local thing = -1
                    for j,v in ipairs(self.v) do 
                        last[j] = v 
                        if v == i then thing = j end --?
                    end
                    local added = -1
                    local removed = -1
                    
                    if thing == -1 then
                        table.insert(self.v, i)
                        added = i
                    else
                        table.remove(self.v, thing)
                        removed = i
                    end
                    
                    return true, { self.v, last, added, removed }
                end
            end
        end
    end
end

tabutil = require 'tabutil'

momentaries = toggles:new()
    
function momentaries:key(x, y, z)
    if self:en() then
        
        local is_x = (type(self.p[1]) == "table")
        local l_p = is_x and self.p[1] or self.p[2]
        local s_p = is_x and self.p[2] or self.p[1]
        local l_dim = is_x and x or y
        local s_dim = is_x and y or x
        
        if s_dim == s_p then
            for i = l_p[1], l_p[2] do
                if i == l_dim then
                    local last = {}
                    local thing = -1
                    for j,v in ipairs(self.v) do
                        last[j] = v 
                        if v == i then thing = j end --?
                    end
                    local added = -1
                    local removed = -1
                    
                    if thing == -1 and z == 1 then
                        table.insert(self.v, i)
                        added = i
                    else
                        table.remove(self.v, thing)
                        removed = i
                    end

                    return true, { self.v, last, added, removed }
                end
            end
        end
    end
end