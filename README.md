![orgn logo](lib/doc/logo-01.png) 

<p align="center">
  <img src="https://github.com/andr-ew/orgn/blob/master/lib/doc/screen_cap.gif?raw=true" alt="orgn screen animated gif"/>
</p>
<br>

a 3-operator FM synth with fx. inspired by yamaha portasound keyboards

### [--video--]()

### requirements

- norns (210927 or later)
- grid (any size) or midi keyboard
- audio input (optional)
- midi mapping encouraged

### install

run `;install https://github.com/andr-ew/orgn` in the maiden repl, then run SYSTEM > RESTART to boot the new engine

***POSSIBLE STROBE WARINING*** on the screen graphics for this script. I'll add an option to disable the graphics as soon as I get a chance


# documentation

orgn is a 3-operator FM synthesizer followed by an FX engine which loosley emulates yamaha's ultra-cheap range of consumer keyboards from the 80's & 90's - the PortaSound series. whereas these keyboards were locked into 100 or so sometimes corny factory presets (with a catchy demo song to match), orgn gives you full control over the synthesis & fx engines. you can also process external signals through the FX via the norns inputs.

if you like reading, the documentation below provides some detailed technical explanations of most of the controls available, and provides some basic explanation of FM synthesis. if you don't like reading, I made a short [video]() that shows you what all orgn can do - that alone should be enough to get you started. synthesis is about experimentation, so don't feel like you need to know everything before diving in !

## grid
![orgn grid docs](lib/doc/orgn.png)
## screen

the norns screen has three pages of controls, which can be mapped to anything in the params menu

- **K1/K2:** page
- **E1-E3:** edit control

the default mappings, along with the controls available on the grid, are designed to get you up & running quickly with orgn without getting buried in options. once you've gotten familiar with these, you can dive into the params menu, map additional params to external [midi controllers](https://github.com/andr-ew/bleached)/OSC, or edit the screen mappings via PARAMS > EDIT > map > encoders

## key parameters

### timbre

- **amp [a/b/c]:** the amplitude or volume of the three sine waves in the synth voice

  by default, the amplitutes are:

  | a | b | c |
  | - | - | - |
  | 1.0 | 0.5 | 0.0 |

  generally for FM synthesis, any 0 (silent) wave would be considered a modulator wave while any non-zero (audible) wave would be considered a carrier wave. so by default you have two carrier waves (**a** & **b**) and one modulator wave (**c**). we'll expand more on modulator & carrier in the nest bullet point
  
  if you like, you can also use orgn as a simple addative synthesizer, just by manipulating the levels of these three sines (this gets especially tasty with the **detune** param). there are a suprising variety of organ tones and muted piano sounds to be found this way !
  
- **pm [a/b/c] -> [a/b/c]**: this flavor of param sets the level (or _index_) of modulation between two sine waves.

  on the left side of the arrow you'll normally have your modulator (silent) wave and on the right you'll have the carrier (audible) wave. increasing the **pm** level turns the plain sine wave into a progressively brighter tone, a bit like opening the filter on an oscillator.
  
  by default on the norns screen, you have access to **pm c -> b** and **pm c -> a**, which routs our single modulator wave to our two carrier waves. 
  
  in the params menu, you have access to _every_ possible routing between two waves, including feedback. however, it's often more informative & musical to focus on just one or two routings at a time - that way it's always easy to transition between bright tones and pure sine waves

### envelope

### fx

## tuning

## pattern recording

# API docs

(forthcoming)

# thanks to

- rodrigo constanzo
- ezra buchla
- @justmat + @ganders 

for various code snippets & jumping off points for the effects engine

- trent gil

for inspiration on FM & envelope parametization (w/ synth & just friends)
