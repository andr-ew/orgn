local App = {}

local scale_focus = false

local mar = { left = 2, top = 4, right = 0, bottom = 1 }
local gap = 4
local split = { y = 64 * 3/4 }
local div = { x = { ctl = 3, gfx = 2 }, y = { ctl = 1, gfx = 2 } }
local mul = { 
    ctl = { x = (128 - mar.left - mar.right - (div.x.ctl - 1)*gap) / div.x.ctl }, 
    gfx = { 
        x = (128 - mar.left - mar.right - (gap * (div.x.gfx - 1))) / div.x.gfx,
        y = (split.y - mar.top - mar.bottom - (gap * (div.y.gfx - 1))) / div.y.gfx,
    }
}
local x = { 
    ctl = { mar.left, mar.left + mul.ctl.x, mar.left + mul.ctl.x*2, 128 - mar.right },
    gfx = { mar.left, mar.left + mul.gfx.x }
}
local y = {
    ctl = { split.y, 64 - mar.bottom },
    gfx = { mar.top, mar.top + mul.gfx.y }
}
local w = { 
    gfx = ((128 - mar.left - mar.right) / div.x.gfx) - gap*2, 
    ctl = ((128 - mar.left - mar.right) / div.x.ctl) - gap*2
}
local h = { gfx = (split.y - mar.left - mar.right) / div.y.gfx - gap*2 }

--grid ui

function App.grid(args)
    local wide = args.wide or false
    local varibright = args.varibright or true

    local hl = { 4, 15 }

    local _ratio = {
        c = to.pattern(mpat, 'ratio_c', Grid.number, function()
            return {
                x = wide and { 1, 16 } or { 1, 8 }, y = 1,
                state = of.param('ratio_c')
            }
        end),
        b = wide and to.pattern(mpat, 'ratio_b', Grid.number, function()
            return {
                x = { 1, 16 }, y = 2,
                state = of.param('ratio_b')
            }
        end),
        a = wide and to.pattern(mpat, 'ratio_a', Grid.number, function()
            return {
                x = { 1, 5 }, y = 3,
                state = of.param('ratio_a')
            }
        end)
    }
    local _oct = {
        up = to.pattern(mpat, 'oct_up', Grid.trigger, function()
            return {
                x = wide and 11 or 4, y = wide and 3 or 2, 
                action = function() params:delta('oct', 1) end,
            }
        end),
        down = to.pattern(mpat, 'oct_down', Grid.trigger, function()
            return {
                x = wide and 10 or 3, y = wide and 3 or 2, 
                action = function() params:delta('oct', -1) end
            }
        end)
    }
    local _voicing = wide and to.pattern(mpat, 'voicing', Grid.toggle, function()
        return {
            x = 12, y = 3, lvl = hl,
            state = of.param('voicing')
        }
    end)
    local _mode = to.pattern(mpat, 'mode', Grid.toggle, function()
        return {
            x = wide and 13 or 5, y = wide and 3 or 2, lvl = hl,
            state = of.param('mode'),
        }
    end)
    local _ramp = to.pattern(mpat, 'ramp', Grid.control, function()
        return {
            x = wide and { 14, 16 } or { 6, 8 }, y = wide and 3 or 2,
            state = of.param('ramp'),
            controlspec = of.controlspec('ramp')
        }
    end)
    local _keymap = to.pattern(mpat, 'keymap', Grid.momentary, function()
        --TODO: keyboard height arg
        return {
            x = wide and { 1, 15 } or { 1, 8 }, y = wide and { 4, 8 } or { 3, 8 },
            count = params:get('voicing') == 2 and 1 or 8, 
            lvl = function(_, x, y)
                return tune.is_tonic(x, y, params:get('scale_preset')) 
                    and { 4, 15 } 
                    or { 0, 15 }
            end,
            action = function(v, t, d, add, rem)
                local k = add or rem
                local id = k.x + (k.y * 16)
                local vel = math.random()*0.2 + 0.85

                local hz = 440 * tune.hz(k.x, k.y, nil, nil, params:get('scale_preset'))

                if add then orgn.noteOn(id, hz, vel)
                elseif rem then orgn.noteOff(id) end
            end
        }
    end)

    local _scale = wide and to.pattern(mpat, 'scale_preset', Grid.number, function()
        return {
            y = 3, x = { 6, 9 }, edge = 'both',
            lvl = scale_focus and { 0, 8 } or hl,
            clock = true,
            state = { params:get('scale_preset') },
            action = function(v, t, d, add, rem)
                print(add, rem)
                params:set('scale_preset', v)

                nest.grid.make_dirty()

                if add then clock.sleep(0.2) end
                scale_focus = add ~= nil

                nest.screen.make_dirty()
            end
        }
    end)

    local _scale_degrees = Tune.grid.scale_degrees{ left = 2, top = 4 }
    local _tonic = Tune.grid.tonic{ left = 2, top = 7 }

    local function Demo()
        return function()
            local g = nest.grid.device()

            if nest.grid.is_drawing() then
                demo.redraw(g) 
            end
        end
    end
    local _demo = Demo()

    local _patrec = PatternRecorder()

    return function(props)
        _ratio.c()
        if wide then
            _ratio.b()
            _ratio.a()
        end
        _oct.up()
        _oct.down()
        if wide then
            _voicing() 
            _scale()
        end
        _mode()
        _ramp()
        
        _patrec{
            x = wide and 16 or { 1, 2 }, y = wide and { 1, 8 } or 2, 
            pattern = pattern, varibright = varibright,
        }
    
        if demo.playing() then 
            _demo()
        else
            if scale_focus then
                _scale_degrees{ preset = params:get('scale_preset') }
                _tonic{ preset = params:get('scale_preset') }
            else
               _keymap()
            end
        end
    end
end

--screen ui

function App.norns(args)
    local function Page(args)
        local i = args.idx
                
        local xx = { x.gfx[1], x.gfx[1], x.gfx[2] }
        local yy = { y.gfx[2] + gap, y.ctl[1], y.ctl[1] }
        
        local _controls = {}
        for ii = 1,3 do
            _controls[ii] = to.pattern(mpat, 'control_'..i..'_'..ii, Text.enc.control, function() 
                local id = map.id[params:get(map.option_id[i][ii])]

                return {
                    n = ii, x = xx[ii], y = yy[ii], flow = 'y', step = 0.001,
                    label = map.name[params:get(map.option_id[i][ii])],
                    state = of.param(id), controlspec = of.controlspec(id),
                }
            end)
        end

        return function()
            for _,_control in ipairs(_controls) do _control() end
        end
    end
    local _pages = {}
    for i = 1,pages do _pages[i] = Page{ idx = i } end


    local function Gfx()
        orgn_gfx.env:init(x.gfx[2], y.gfx[2], mul.gfx.x, mul.gfx.y, 'asr')
        orgn_gfx.osc:init(
            { x = x.ctl[1], y = y.gfx[1], w = w.ctl, h = h.gfx }, 
            { x = x.ctl[2], y = y.gfx[1], w = w.ctl, h = h.gfx }, 
            { x = x.ctl[3], y = y.gfx[1], w = w.ctl, h = h.gfx }
        )
        orgn_gfx.samples:init(x.ctl[2] - gap, y.gfx[2] + gap, h.gfx)

        return function()
            if nest.screen.is_drawing() then
                orgn_gfx:draw()
                nest.screen.make_dirty() --redraw every frame while graphics are shown
            end
        end
    end
    local _gfx = Gfx()

    local tab = 1
    local _tab = Text.key.option()

    return function(props)
        _gfx()

        _tab{
            n = { 2, 3 }, x = { { 118 }, { 122 }, { 126 } }, y = 52,
            align = { 'right', 'bottom' },
            font_size = 16, margin = 3,
            options = { '.', '.', '.' },
            state = { tab, function(v) tab = v end }
        }

        _pages[tab]()
    end
end

return App
