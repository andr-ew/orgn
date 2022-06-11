--  ===== ===== ===== =   =
--  =   = =   = =     ==  =
--  =   = ====  =  == = = =
--  =   = =  =  =   = =  ==
--  ===== =   = ===== =   =
--
-- a 3-operator FM synth with 
-- fx. inspired by yamaha 
-- portasound keyboards
--
-- version 1.1 @andrew
-- https://norns.community/
-- authors/andrew/orgn
--
-- K1-K2: page focus
-- E1-E3: various
--
-- required: midi keyboard
-- or grid
--
-- grid documentation available
-- on norns.community

--global variables

pages = 3 --you can add more pages here for the norns encoders

--adjust these variables for midigrid / nonvari grids
g = grid.connect()
grid_width = (g and g.device and g.device.cols >= 16) and 16 or 8
varibright = (g and g.device and g.device.cols >= 16) and true or false

--external libs

tab = require 'tabutil'
cs = require 'controlspec'
mu = require 'musicutil'
pattern_time = require 'pattern_time'

--git submodule libs

nest = include 'lib/nest/core'
Key, Enc = include 'lib/nest/norns'
Text = include 'lib/nest/text'
Grid = include 'lib/nest/grid'

multipattern = include 'lib/nest/util/pattern-tools/multipattern'
of = include 'lib/nest/util/of'
to = include 'lib/nest/util/to'
PatternRecorder = include 'lib/nest/examples/grid/pattern_recorder'

tune, Tune = include 'orgn/lib/tune/tune' 
tune.setup { presets = 8, scales = include 'orgn/lib/tune/scales' }

--script lib files

orgn, orgn_gfx = include 'orgn/lib/orgn'      --engine params & graphics
demo = include 'orgn/lib/demo'                --egg
Orgn = include 'orgn/lib/ui'                  --nest UI components (norns screen / grid)
map = include 'orgn/lib/params'               --create script params
m = include 'orgn/lib/midi'                   --midi keyboard input

engine.name = "Orgn"

--set up global patterns

function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

pattern, mpat = {}, {}
for i = 1,5 do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

--set up nest v2 UI

local _app = {
    grid = Orgn.grid{ wide = grid_width > 8, varibright = varibright },
    norns = Orgn.norns(),
}

nest.connect_grid(_app.grid, grid.connect(), 60)
nest.connect_enc(_app.norns)
nest.connect_key(_app.norns)
nest.connect_screen(_app.norns, 24)

--init/cleanup

function init()
    orgn.init()
    --params:read()
    params:set('demo start/stop', 0)
    --TODO: reset crinkle (or whatever it is that crashes shit) (?)
    params:bang()
end

function cleanup() 
    params:write()
end
