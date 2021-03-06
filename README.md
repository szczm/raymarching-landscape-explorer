# 3D procedural raymarching landscape explorer
> developed by [@szczm_](https://twitter.com/szczm_)

![collage](https://raw.githubusercontent.com/szczm/raymarching-landscape-explorer/master/screenshots/collage_compressed.jpg)

A small, fully procedural 3D landscape explorer that I developed in few spare days in 2018. It uses raymarching (sphere tracing) to render the environment. Various parameters and textures are generated, which are then used to create a possible total of **2^53 = 9007199254740992** (over nine quadrillion) painterly shaded, unique landscapes. The generated parameters are only weakly restricted as to focus more on the artistic, rather than realistic, outcomes. The size of this repository (including screenshots) is less than 0.5 MB.

**CAUTION:** This is an experimental, work in progress tool that I'm working on from time to time. Also, it's focused more on exploring the realm of possibilities, so don't expect beautiful, photorealistic landscapes or consistent results. *You have been warned*.

## Screenshots

![screenshot](https://raw.githubusercontent.com/szczm/raymarching-landscape-explorer/master/screenshots/a_bright_surfboard_records_a_cooked_summerhouse.jpg)
Seed: `a bright surfboard records a cooked summerhouse`

![screenshot](https://raw.githubusercontent.com/szczm/raymarching-landscape-explorer/master/screenshots/a_distant_workaholic_severs_a_distant_dolt.jpg)
Seed: `a distant workaholic severs a distant dolt`

![screenshot](https://raw.githubusercontent.com/szczm/raymarching-landscape-explorer/master/screenshots/a_mediocre_table_introduces_a_misty_gnat.jpg)
Seed: `a mediocre table introduces a misty gnat`

**YOUR SCREENSHOT HERE** - share an interesting world/screenshot with me (see [**Contributing**](https://github.com/szczm/raymarching-landscape-explorer#contributing), and I might feature it here!

## Features

* 2^53 (meaning: a lot) procedurally generated, explorable landscapes,
* varied landscapes, including fluorescent fog night worlds, flat lands with red valleys, rainbow coloured hills, waterworlds and so on,
* easily share your world using a simple-to-remember phrase,
* day and night cycle, accurate soft shadows, water depth and more advanced graphical features

## Prerequisites

To run this tool, you just need a working graphics card and (probably) up to date drivers.

**Linux**: You need to have LÖVE installed, which is very easy (www.love2d.org).

This application was tested with LÖVE 11.2 on Ubuntu 18.04 and Windows 10.

Your GPU should be capable of rendering a fullscreen 3D image realtime - although older cards, while not as performant, are still able to run this tool.

## How to install/run

No installation is required, simply download the right version for your computer below:

**WARNING:** After running/generating a new world, **the application may hang up for a few seconds while calculating the required data.**

### Windows

Download [32-bit version here](https://github.com/szczm/raymarching-landscape-explorer/raw/master/raymarching-landscape-generator-win32.zip) or [64-bit version here](https://github.com/szczm/raymarching-landscape-explorer/raw/master/raymarching-landscape-generator-win64.zip), unpack and run `raymarching-landscape-generator-win32.exe` (or `win64`).

To input seed phrases, you need to launch the application from a command prompt.

### Linux

Download [.love package](https://github.com/szczm/raymarching-landscape-explorer/raw/master/raymarching-landscape-generator.love) and (provided you have [installed LÖVE](https://github.com/szczm/raymarching-landscape-explorer#prerequisites)) run the package using:
```
love raymarching-landscape-generator.love
```

### macOS / alternative method

Download [.love package](https://github.com/szczm/raymarching-landscape-explorer/raw/master/raymarching-landscape-generator.love) (or clone this repository) and using a file explorer, drag the package/directory containing the source code into the `love` application bundle (provided with the LÖVE download), the `love.exe` executable file or it's shortcut.

For more information on running LÖVE based applications, refer to [this guide](https://love2d.org/wiki/Getting_Started).

**IMPORTANT:** This application is GPU-extensive and may slow down older computers.

## How to use

* **WASD + mouse** - movement and look around
* **mouse wheel** - change FOV (field of view)
* **,** (comma key) **and .** (dot key) - change time of day
* **F1** - generate a new, random world
* **F2** - generate a new world from a provided seed
* **F3** - toggle debug mode (explained below)
* **F4** - set time of day to noon
* **F5** - toggle help

#### Debug mode

Debug mode displays all data and textures used to render the world and move the camera.

When debug mode is enabled, additional functions are available:
* **left shift key** - boost (multiplies movement speed by a factor of 50)

#### Manual seed

On the bottom of displayed debug data a seed is printed in a mnemonic phrase form, e.g. `a leafy supply provides a dishonest pineapple`. Using this phrase, you can come back later to a chosen world or share it with others running this tool.

When running the tool from a prompt, to input a mnemonic phrase, press the F2 button, then insert the phrase into the prompt and press Enter.

## Implemenentation/Technical details

For technical details, [go here (TECHNICAL.md)](TECHNICAL.md).

## Built With

* [LÖVE](https://www.love2d.org) - Used for everything: window, input processing, shader compilation etc.
* GLSL - Rendering the world

## Contributing

This is very much a work in progress and any contributions are welcome. If you find a bug, want to suggest/submit a feature, or want to help in another way, [submit an issue](https://github.com/szczm/raymarching-landscape-explorer/issues/new), a pull request or contact me directly.

Also, feel free to send me any interesting worlds you discovered! You're also very welcome to include the seed phrase (you can find it in the debug mode) using the contact information included below.

### To-do
* Input - an interface for inputing phrases (or any text input) is required, to replace current prompt typing.
* Optimization - both for data generation and shading. The current approach for sampling the height map texture during sphere tracing is a brute force and is inefficent. Generation is single threaded and slow. Also, height maps are used as gray scale, while technically taking up 4 times as much needed memory (`rgba16`).
* Fix artifacts - some small artifacts are rendered, especially on boundaries, and extreme hills/valleys can be often rendered improperly. Also, the height map sometimes gets clipped, generating a see through hole in the ground.
* Improve shading - the shading is experimental (as in, artistically), especially the lighting during noon/midnight is very uniform and shadows sometimes are low quality. Some things can also be added, such as water reflections and post processing.
* Code quality/readability - it could be improved. About 95% of code was written with no thought of ever sharing it.
* World variance - right now many worlds are quite similar. A simple method, which would restrict a world slightly (while not affecting all possible worlds globally), could be implemented (such as a factor that would lower the possible range of colours for a given world). Also, more parameters can be randomized, thus further differentiating the worlds, and more elements could be added, such as stars and other planets in the sky.
    - Vegetation - this is a work in progress and is currently just a colour change, but could be made more three-dimensional and more varied.

## Authors

* **Matthias Scherba** - [@szczm_](https://twitter.com/szczm_), matthias.scherba@gmail.com

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Acknowledgments

* LÖVE and Lua for being amazing!
* Thanks to [Hello Games](http://www.hellogames.org/) for No Man's Sky, [Vladimir Romanyuk](https://twitter.com/SpaceEngineSim) for [Space Engine](http://spaceengine.org/) and [/r/proceduralgeneration](https://www.reddit.com/r/proceduralgeneration) on Reddit for inspiring this project
* [Inigo Quilez](http://www.iquilezles.org/) and the demoscene for being a true inspiration

