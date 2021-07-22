local particles = {list = {}}

--[[function particles.setMain(particlename)
  if particlename == "" or not love.filesystem.getInfo("Sprites/Particles/"..particlename, "file") then
    particles.main = nil
    return
  end
  particles.main = love.graphics.newParticleSystem(love.graphics.newImage("Sprites/Particles/"..particlename), 60)
  particles.main:setParticleLifetime(7, 10)
  particles.main:setEmissionRate(5)
  particles.main:setSizeVariation(1)
  particles.main:setLinearAcceleration(20, 20, 80, 80)
  particles.main:setSpin(1, 5)
  particles.main:setColors(1, 1, 1, 1, 1, 1, 1, 0)
end]]

local path = "Sprites/Particles/"

function particles.spawnSmoke(x, y)
  for i = 1,40 do
    if not particles.list[i] then
      particles.list[i] = {x = x, y = y}
      particles.list[i].particle = love.graphics.newParticleSystem(love.graphics.newImage(path.."smoke.png"), 10)
      particles.list[i].particle:setParticleLifetime(0.4, 0.7)
      particles.list[i].particle:setLinearAcceleration(-100, -100, 100, 100)
      particles.list[i].particle:setColors(1, 1, 1, 1, 1, 1, 1, 0)
      particles.list[i].particle:emit(10)
      break
    end
  end
end

function particles.spawnShards(x, y, mult)
  for i = 1,40 do
    if not particles.list[i] then
      particles.list[i] = {x = x, y = y}
      particles.list[i].particle = love.graphics.newParticleSystem(love.graphics.newImage(path.."shard.png"), 20*mult)
      particles.list[i].particle:setParticleLifetime(2*mult, 4*mult)
      particles.list[i].particle:setLinearAcceleration(-500*mult, -500*mult, 500*mult, 500*mult)
      particles.list[i].particle:setSpin(-15, 15)
      particles.list[i].particle:setColors(mult, mult, mult, mult, mult, 0, 0, 0)
      particles.list[i].particle:emit(20*mult)
      break
    end
  end
end

function particles.spawnWarning(x, y)
  for i = 1,40 do
    if not particles.list[i] then
      particles.list[i] = {x = x, y = y}
      particles.list[i].particle = love.graphics.newParticleSystem(love.graphics.newImage(path.."warning.png"), 1)
      particles.list[i].particle:setParticleLifetime(1)
      particles.list[i].particle:setSizes(1, 1.5)
      particles.list[i].particle:setColors(1, 1, 1, 1, 1, 1, 1, 0)
      particles.list[i].particle:emit(1)
      break
    end
  end
end

function particles.spawnStars(x, y)
  for i = 1,40 do
    if not particles.list[i] then
      particles.list[i] = {x = x, y = y}
      particles.list[i].particle = love.graphics.newParticleSystem(love.graphics.newImage(path.."star.png"), 10)
      particles.list[i].particle:setParticleLifetime(2, 3)
      particles.list[i].particle:setLinearAcceleration(-100, -100, 100, 100)
      particles.list[i].particle:setSizes(1, 0)
      particles.list[i].particle:setColors(1, 1, 1, 0.7, 1, 1, 1, 0)
      particles.list[i].particle:emit(10)
      break
    end
  end
end

function particles.update(dt)
  for k, v in pairs(particles.list) do
    if v.particle then
      v.particle:update(dt)
    end
  end
end

function particles.collectGarbage()
  for k, v in pairs(particles.list) do
    if v.particle:getCount() == 0 then
      particles.list[k] = nil
    end
  end
  collectgarbage()
end

function particles.reset()
  for k, v in pairs(particles.list) do
    v.particle:reset()
  end
  particles.collectGarbage()
end

return particles