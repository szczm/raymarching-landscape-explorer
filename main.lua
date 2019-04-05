gentext = require('gentext')

-- SETTINGS are up here for accessibility and quick changes
SETTINGS = {
  textureSize = 2048,    -- pixel size of one dimension of a texture (2048x2048)
  generationLevel = 10,  -- used as a number of iterations/levels for heightMap generation
  playerHeight = 0.5,    -- measuring from player's toes
  
  fovChangeSpeed = 2.0,  -- per mouse wheel scroll
  defaultFov = 90,

  moveSpeed = 1,         -- these are just some arbitrary values,
  moveAcceleration = 5,  -- I can't prove their physical accuracy.

  manualSeed = false,
  debugMode = true,
}

-- _DATA is an array with named variables. If a uniform exists in the shader
--  with a matching name, it's corresponding value will be assigned.
_DATA = {
  screenResolution = {},
  time = 0,
  fps = 0,
  fov = SETTINGS.defaultFov,
  
  worldSize = 300,
  worldHeight = 25,

  origin = { 0, 0, 0 },
  direction = { 0, 0, 0 },
  rotation = { 0, 0, 0 },
  velocity = { 0, 0, 0 },
  
  seed = 0,
  heightMapData = nil,
  heightMap = nil,
  colorMap = nil,
  skyboxMap = nil,

  vegetationMap = nil,
  vegetationColorMap = nil,
  vegetationVarianceMap = nil,

  sunPosition = { 0, 0, 0 },
  dayCycle = { 0, 0, 0 },

  waterColor = { 0, 0, 0 },
  waterHeight = 0,
  waterDensity = 0,
  waterFluorescence = 0,
  
  colorNormalVariance = 0,
  shadowRoughness = 0,
  shadowInfluence = 0,
  fogDensity = 0,
  skyExponent = 0,
}

-- DATA is a container for __DATA, which holds information about whether a member
--   of the __DATA array has been modified. Used solely for displaying debug data
DATA = setmetatable({
  __READ = {}
}, {
  __newindex = function(self, key, value)
    _DATA[key] = value
    self.__READ[key] = false
  end,
  
  __index = function(self, key)
    return _DATA[key]
  end,

  __pairs = function(self)
    local function iter(tbl, k)
      local v
      k, v = next(tbl, k)
      if v then return k, v end
    end

    return iter, _DATA, next(_DATA)
  end
})

-- Löve2D uses LuaJIT 2.1.0, which conforms to the Lua 5.1 standard. A __pairs metatable event
--   was added in Lua 5.2. Since I wrote code using __pairs (DATA doesn't contain redundant data,
--   it passed _DATA under the hood) and then found out it isn't used, here's my minimised 
--   "polyfill" that should make it work like in Lua 5.2.
local _=pairs pairs=function(a)local b=(getmetatable(a)or{}).__pairs if b then local c,d,e=b(a)e=e or next(d)local function f()local g e,g=c(d,e)if g then return e,g end end return f end return _(a)end

-- generateHeightMap generates a height map using Löve's Simplex noise
function generateHeightMap(levelLow, levelHigh, textureSize)
  local size = textureSize or SETTINGS.textureSize
  local heightMapData = love.image.newImageData(size, size, "rgba16")

  local levelBase = {}

  local lo, hi = levelLow or 0, levelHigh or SETTINGS.generationLevel

  for i = lo, hi do
    levelBase[i] = {
      x = love.math.random(10000) + love.math.random(),
      y = love.math.random(10000) + love.math.random(),
      s = 1 / 2^(i + love.math.random() - 0.5)
    }
  end

  local min = 1
  local max = 0

  heightMapData:mapPixel(function(x, y, r, g, b, a)
    local z = 0

    for i = lo, hi do
      z = z + love.math.noise(
        2^i * x / size + levelBase[i].x,
        2^i * y / size + levelBase[i].y
      ) * levelBase[i].s
    end

    min = math.min(min, z)
    max = math.max(max, z)

    return z, z, z, 1
  end)

  local smooth = (function()
    local a, b = love.math.random() * 3.0 + 0.2, love.math.random() * 3.0 + 0.2
    local scale = 1 / (max - min)

    return function(sample)
      local s = math.max(sample - min, 0) * scale
      return 1 - (1 - (s ^ a)) ^ b
    end
  end)()

  heightMapData:mapPixel(function(x, y, r, g, b, a)
    local z = smooth(r)
    return z, z, z, 1
  end)

  return heightMapData
end

-- generateColorMap generates a simple colormap using sin for color components
function generateColorMap()
  local colorMapData = love.image.newImageData(SETTINGS.textureSize, 1)

  local ar, ag, ab = love.math.random(), love.math.random(), love.math.random()
  local dr, dg, db = love.math.random(), love.math.random(), love.math.random()
  local br, bg, bb = love.math.random(), love.math.random(), love.math.random()

  colorMapData:mapPixel(function(x, y, r, g, b, a)
    local xx = x / SETTINGS.textureSize
    local pi2 = math.pi * 2

    local r = math.sin((xx + dr) * ar * pi2 * 1.5)
    local g = math.sin((xx + dg) * ag * pi2 * 1.5)
    local b = math.sin((xx + db) * ab * pi2 * 1.5)
    return br + r * (1 - br), bg + g * (1 - bg), bb + b * (1 - bb)
  end)

  return love.graphics.newImage(colorMapData)
end

-- generateWorld generates all textures and parameters for a world
function generateWorld()
  local newSeed

  if SETTINGS.manualSeed then
    newSeed = gentext.phraseToSeed(io.read())
    SETTINGS.manualSeed = false
  else
    newSeed = love.math.random(2^53) - 1
  end

  love.math.setRandomSeed(newSeed)

  local heightMapData = generateHeightMap(1)

  local heightMap = love.graphics.newImage(heightMapData)
  heightMap:setWrap('repeat', 'repeat')
  heightMap:setFilter('linear', 'linear', 16)

  local colorMap = generateColorMap()
  local skyboxMap = generateColorMap()

  local dayLength = love.math.random() * 0.1 -- najkrócej 63 sekundy doba
  local sunDeclination = (love.math.random() - 0.5) * math.pi * 0.9 -- żeby nie było 90 stopni deklinacji
  local dayPhase = love.math.random() * math.pi * 2

  local colorNormalVariance = love.math.random() * 0.3

  local waterHeight = -0.5 + love.math.random() * 5.0
  local waterColor = { love.math.random(), love.math.random(), love.math.random() }
  local waterDensity = 0.5 + love.math.random() * 9.5
  local waterFluorescence = love.math.random()^2

  local shadowRoughness = 1.0 + love.math.random() * 2.0
  local shadowInfluence = 0.5 + love.math.random() * 0.3

  local fogDensity = love.math.random() * DATA.worldSize * 2.0

  local skyExponent = 1.0 + love.math.random() * 2.0

  local vegetationMap = love.graphics.newImage(generateHeightMap(6, 12, SETTINGS.textureSize / 2))
  vegetationMap:setWrap('repeat', 'repeat')
  vegetationMap:setFilter('linear', 'linear', 16)

  local vegetationVarianceMap = love.graphics.newImage(generateHeightMap(1, 5, SETTINGS.textureSize / 8))
  vegetationVarianceMap:setWrap('repeat', 'repeat')
  vegetationVarianceMap:setFilter('linear', 'linear', 16)

  local vegetationColorMap = generateColorMap()

  DATA.seed = gentext.seedToPhrase(newSeed)
  DATA.heightMapData = heightMapData
  DATA.heightMap = heightMap
  DATA.colorMap = colorMap
  DATA.skyboxMap = skyboxMap
  DATA.origin = { 0, 0, 0 }
  DATA.dayCycle = { dayLength, sunDeclination, dayPhase }
  DATA.colorNormalVariance = colorNormalVariance
  DATA.waterHeight = waterHeight
  DATA.waterColor = waterColor
  DATA.waterDensity = waterDensity
  DATA.waterFluorescence = waterFluorescence
  DATA.shadowRoughness = shadowRoughness
  DATA.shadowInfluence = shadowInfluence
  DATA.fogDensity = fogDensity
  DATA.skyExponent = skyExponent
  DATA.vegetationMap = vegetationMap
  DATA.vegetationVarianceMap = vegetationVarianceMap
  DATA.vegetationColorMap = vegetationColorMap
end

function love.load()
  love.window.setMode(-1, -1, { fullscreen = true, borderless = true })
  --love.window.setMode(400, 400, { fullscreen = false, borderless = true })
  love.mouse.setRelativeMode(true)

  DATA.screenResolution = { love.graphics.getDimensions() }

  generateWorld()

  shader = love.graphics.newShader("shader.frag")
end

function love.mousemoved(x, y, dx, dy, istouch)
  local rotation_scale = DATA.fov / SETTINGS.defaultFov

  DATA.rotation[3] = DATA.rotation[3] + rotation_scale * dx / 200.0;
  DATA.rotation[2] = DATA.rotation[2] - rotation_scale * dy / 200.0;

  DATA.rotation[2] = math.min( math.pi / 2, DATA.rotation[2])
  DATA.rotation[2] = math.max(-math.pi / 2, DATA.rotation[2])

  DATA.rotation = DATA.rotation
end

function love.mousepressed(x, y, button, istouch, presses)
  if button == 3 then
    DATA.fov = SETTINGS.defaultFov
  end
end

function love.wheelmoved(x, y)
  DATA.fov = DATA.fov - y * SETTINGS.fovChangeSpeed
  DATA.fov = math.min(160.0, math.max(DATA.fov, 1.0))
end

function love.update(dt)
  if love.keyboard.isDown(",") then
    DATA.time = DATA.time - 10.0 * dt
  elseif love.keyboard.isDown(".") then
    DATA.time = DATA.time + 10.0 * dt
  else
    DATA.time = DATA.time + dt
  end

  DATA.fps = love.timer.getFPS()

  local dir = {
    math.cos(DATA.rotation[2]) * math.sin(DATA.rotation[3]),
    math.sin(DATA.rotation[2]),
    math.cos(DATA.rotation[2]) * math.cos(DATA.rotation[3])
  }

  DATA.direction = dir;

  dir = {
    math.sin(DATA.rotation[3]),
    math.cos(DATA.rotation[3])
  }

  local velocity = DATA.velocity;
  local step = SETTINGS.moveAcceleration * dt

  if love.keyboard.isDown('w', 'a', 's', 'd', 'lctrl', 'space') then
    local leap = {0, 0, 0} -- I named it leap because step was already taken, look at me
  
    if love.keyboard.isDown('w') then
      leap[1] = leap[1] + dir[1]
      leap[3] = leap[3] + dir[2]
    end
    
    if love.keyboard.isDown('s') then
      leap[1] = leap[1] - dir[1]
      leap[3] = leap[3] - dir[2]
    end

    if love.keyboard.isDown('a') then
      leap[1] = leap[1] - dir[2]
      leap[3] = leap[3] + dir[1]
    end
    
    if love.keyboard.isDown('d') then
      leap[1] = leap[1] + dir[2]
      leap[3] = leap[3] - dir[1]
    end

    velocity[1] = velocity[1] + leap[1] * step
    velocity[3] = velocity[3] + leap[3] * step

    local velocityMagnitude = (velocity[1]^2 + velocity[2]^2 + velocity[3]^2)^0.5

    if velocityMagnitude > SETTINGS.moveSpeed then
      local ratio = SETTINGS.moveSpeed / velocityMagnitude

      velocity[1] = velocity[1] * ratio
      velocity[2] = velocity[2] * ratio
      velocity[3] = velocity[3] * ratio
    end
  else
    local velocityMagnitude = (velocity[1]^2 + velocity[2]^2 + velocity[3]^2)^0.5
    local speed = math.max(0, velocityMagnitude - step)

    if speed > 0 then
      local ratio = speed / velocityMagnitude
      
      velocity[1] = velocity[1] * ratio
      velocity[2] = velocity[2] * ratio
      velocity[3] = velocity[3] * ratio
    else
      velocity = {0, 0, 0}
    end
  end

  local origin = DATA.origin

  local boost = 1
  
  if love.keyboard.isDown('lshift') and SETTINGS.debugMode then
    boost = 50
  end
  
  origin[1] = origin[1] + velocity[1] * dt * boost
  origin[3] = origin[3] + velocity[3] * dt * boost

  origin[1] = math.max(-DATA.worldSize / 2 + 1, math.min(DATA.worldSize / 2 - 1, origin[1]))
  origin[3] = math.max(-DATA.worldSize / 2 + 1, math.min(DATA.worldSize / 2 - 1, origin[3]))

  local x = (origin[1] + DATA.worldSize / 2) / (DATA.worldSize / SETTINGS.textureSize)
  local z = (origin[3] + DATA.worldSize / 2) / (DATA.worldSize / SETTINGS.textureSize)

  -- 
  local xi, zi = math.floor(x), math.floor(z)
  local xf, zf = x - xi, z - zi
  xi, zi = xi - 1, zi - 1

  local h00 = DATA.heightMapData:getPixel(xi,     zi)
  local h10 = DATA.heightMapData:getPixel(xi + 1, zi)
  local h01 = DATA.heightMapData:getPixel(xi,     zi + 1)
  local h11 = DATA.heightMapData:getPixel(xi + 1, zi + 1)

  local h = h00 * (1 - xf) * (1 - zf)
          + h10 *      xf  * (1 - zf)
          + h01 * (1 - xf) *      zf
          + h11 *      xf  *      zf

  h = (h * (DATA.worldHeight)) + SETTINGS.playerHeight

  DATA.origin[2] = h
  DATA.origin = origin -- trick to mark origin as modified

  local dayCycle = DATA.dayCycle
  local phase = dayCycle[1] * DATA.time + dayCycle[3]

  local sunPosition = {
    math.cos(phase) * math.sin(dayCycle[2]),
    math.cos(phase) * math.cos(dayCycle[2]),
    math.sin(phase),
  }

  DATA.sunPosition = sunPosition
end

function love.keypressed(key, scancode, isrepeat)
  if isrepeat then return end
  
  if key == "f1" then
    generateWorld()
  elseif key == "f2" then
    SETTINGS.manualSeed = true
    generateWorld()
  elseif key == "f3" then
    SETTINGS.debugMode = not SETTINGS.debugMode
  elseif key == "f4" then
    DATA.time = -DATA.dayCycle[3] / DATA.dayCycle[1] -- calculate top sun position
  end
end

function love.draw()
  love.graphics.clear(0, 0, 0)

  for key, value in pairs(DATA) do
    if shader:hasUniform(key) and not DATA.__READ[key] then
      shader:send(key, value)
    end
  end
  
  love.graphics.setColor(1, 1, 1)
  love.graphics.setShader(shader)

  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  if SETTINGS.debugMode then
    love.graphics.setShader()
    y = 85

    love.graphics.push()

    local texture_scale = love.graphics.getWidth() / SETTINGS.textureSize

    love.graphics.scale(texture_scale, 25)
    love.graphics.draw(DATA.colorMap)
    love.graphics.draw(DATA.skyboxMap, 0, 1)
    love.graphics.draw(DATA.vegetationColorMap, 0, 2)
  
    love.graphics.reset()

    love.graphics.translate(love.graphics.getWidth(), 3 * 25)
    love.graphics.scale(-0.2 * texture_scale, 0.2 * texture_scale)
    love.graphics.draw(DATA.heightMap)
    
    local world_scale = SETTINGS.textureSize / DATA.worldSize
    love.graphics.setColor(1, 0, 1)
    love.graphics.scale(world_scale, world_scale)
    love.graphics.translate(DATA.worldSize / 2, DATA.worldSize / 2)
    love.graphics.setPointSize(3)

    love.graphics.translate(DATA.origin[1], DATA.origin[3])
    love.graphics.rotate(-DATA.rotation[3])
    love.graphics.scale(10, 10)
    love.graphics.polygon('fill', -0.5, 0, 0.5, 0, 0, 1)

    love.graphics.pop()
  
    local firstArrayValue = false
    
    for key, value in pairs(DATA) do
      if shader:hasUniform(key) then
        if not DATA.__READ[key] then
          love.graphics.setColor(0, 1, 0)
        else
          love.graphics.setColor(0, 0, 1)
        end
      else
        love.graphics.setColor(1, 0, 0)
      end

      str = key .. ": "

      if type(value) == "table" then
        firstArrayValue = true
      
        for i, val in pairs(value) do
          if not firstArrayValue then str = str .. ", " end
          str = str .. val
          firstArrayValue = false
        end
      elseif type(value) == "userdata" then
        str = str .. "userdata"
      else
        str = str .. value
      end
      
      love.graphics.print(str, 10, y)
      y = y + 20
    end
  end

  for key, value in pairs(DATA) do DATA.__READ[key] = true end
end
