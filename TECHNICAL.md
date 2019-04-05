## Technical details

First, the world (all it's textures and parameters) is generated in the script part of the program ([main.lua](main.lua)). This is then passed to the shader ([shader.frag](shader.frag)), and using this shader a rectangle is drawn on the screen, which rasterizes, shades and displays the current view on the screen. Debug data and other interface elements are drawn using methods provided by LÖVE.

### World generation

A world is represented using the following parameters:
* seed - a \[0, 2^53-1\] seed is generated using `love.math.random`, which is used to represent the world and generate all other parameters
* height map - describes the height over space; a `heightmap` type (explained below)
* color map - used to color the landscape (left to right on the color map is used to color the landscape bottom to top); a `colormap` type (explained below)
* skybox map - a `colormap` used to color the skybox
* day cycle - a vector consisting of three values: day length (min: 63 seconds, max: unlimited), the sun's declination/axial tilt relative to current planet, and a random starting time
* color normal variance - varies the color map lookup based on the normal vector of a point
* water height - bottom-relative height of the water/fog's surface
* water color - a single color value indicating the (uniform) water/folg color
* water density - lower value mean water acts more like a liquid, higher values - more like a gas (a fog)
* water fluorescence - higher values make the water/fog shine
* shadow roughness
* shadow influence - higher values = darker nights
* sky exponent - single value used to shape the lookup curve for the skybox color map
* vegetation map - a `heightmap` used to add additional variance throughout the landscape, higher values mean higher probability of "vegetation" showing locally
* vegetation variance map - a less varied, more faded `heightmap` further controlling the vegetation appearance on a global level
* vegetation color map - a `colormap` sampled for coloring vegetation

#### `heightmap` type
All height maps are uniform dimensioned (default size: 2048x2048), `rgba16` type textures; when used for height, darker value indicates a lower point in world, and brighter a higher point.

#### `colormap` type
All color maps are 1D textures that are gradient colored, and values to the left are considered lower values (e.g. valleys in the land).

### Rendering

The world is rendered on the screen using the above parameters, using a ray marching algorithm called *sphere tracing* (explained e.g. [here](https://www.scratchapixel.com/lessons/advanced-rendering/rendering-distance-fields)). For each visible pixel, a ray is traced until it hits the ground, or a bounding box surrounding the landscape. The shading is then applied. As sphere tracing is used, this allows for very cheap soft shadows and other advanced effects.

#### Translating height data into world points

The height map is sampled using a very simple, brute force approach of sampling the heightmap at the current ray position from top view. This approach can easily skip a peak (or any local maxima), thus introducing rendering artifacts. The algorithm compensates for this by using under-relaxation, as in, a value received by evaluating the signed distance function is multiplied by a factor of 0,5. This increases graphical fidelity in exchange for performance.

#### Water/fog rendering

For a world point calculated by sphere tracing, a surface point on the ray is calculated analytically, and then the height map is sampled at that point to generate accurate water shading, taking into account the proper depth and shadowing at that point.

## Phrase/seed generation

A collection of 1024 nouns, 512 adjectives and 4096 was selected, and using these, a phrase can be generated in a form of `a/an (adjective) (noun) (verb)s a/an (adjective) (noun)` from a seed, for a total of 2^53 possible phrases. Due to the constricted collection and generation, this process can be reversed to transform a phrase into a seed. As language is public domain, feel free to use the [phrase generating module](gentext.lua) in your project.

## Limitations

* Currently, generated worlds are size limited. A height map is 2048x2048, which is rendered as 300 world units, which at normal speed gives 300 seconds = 5 minutes of walking edge to edge and a precision of 300/2048 ≈ 0.15 world units for a pixel. These values were chosen through experimentation and should be sufficient.
* The rendering algorithm works faster in strongly varied landscapes, and a lot slower in flat lands, due to the nature of sphere tracing.
