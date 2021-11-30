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

# documentation

orgn is a 3-operator FM synthesizer followed by an FX engine which loosley emulates yamaha's ultra-cheap range of consumer keyboards from the 80's & 90's - the PortaSound series. whereas these keyboards were locked into 100 or so sometimes corny factory presets (with a catchy demo song to match), orgn gives you full control over the synthesis & fx engines. you can also process external signals through the FX via the norns inputs.

## grid
![orgn grid docs](lib/doc/orgn.png)
## screen

the norns screen has three pages of controls, which can be mapped to anything in the params menu

- **K1/K2:** page
- **E1-E3:** edit control

the default mappings, along with the controls available on the grid, are designed to get you up & running quickly with orgn without getting buried in options. once you've gotten familiar with these, you can dive into the params menu, map additional params to external [midi controllers](https://github.com/andr-ew/bleached)/OSC, or edit the screen mappings via PARAMS > EDIT > map > encoders

## key parameters

### timbre

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
