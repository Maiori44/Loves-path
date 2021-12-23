PARTICLE_SNOW = 41
PARTICLE_HELP = 42
PARTICLE_RAIN = 43

local particles = {list = {}}

local path = "Sprites/Particles/"

function particles.spawnSmoke(x, y)
	if menu.settings[6].value == 0 then return end
	for i = 1,40 do
		if not particles.list[i] then
			particles.list[i] = {x = x, y = y}
			particles.list[i].particle = love.graphics.newParticleSystem(GetImage(path.."smoke.png"), 10)
			local particle = particles.list[i].particle
			particle:setParticleLifetime(0.4, 0.7)
			particle:setLinearAcceleration(-100, -100, 100, 100)
			particle:setColors(1, 1, 1, 1, 1, 1, 1, 0)
			particle:emit(10)
			break
		end
	end
end

function particles.spawnShards(x, y, mult)
	if menu.settings[6].value == 0 then return end
	for i = 1,40 do
		if not particles.list[i] then
			particles.list[i] = {x = x, y = y}
			particles.list[i].particle = love.graphics.newParticleSystem(GetImage(path.."shard.png"), 20*mult)
			local particle = particles.list[i].particle
			particle:setParticleLifetime(2*mult, 4*mult)
			particle:setLinearAcceleration(-500*mult, -500*mult, 500*mult, 500*mult)
			particle:setSpin(-15, 15)
			particle:setColors(mult, mult, mult, mult, mult, 0, 0, 0)
			particle:emit(20*mult)
			break
		end
	end
end

function particles.spawnWarning(x, y, speed)
	if menu.settings[6].value == 0 then return end
	for i = 1,40 do
		if not particles.list[i] then
			particles.list[i] = {x = x, y = y}
			particles.list[i].particle = love.graphics.newParticleSystem(GetImage(path.."warning.png"), 1)
			local particle = particles.list[i].particle
			particle:setParticleLifetime(speed or 1)
			particle:setSizes(1, 1.5)
			particle:setColors(1, 1, 1, 1, 1, 1, 1, 0)
			particle:emit(1)
			break
		end
	end
end

function particles.spawnStars(x, y)
	if menu.settings[6].value == 0 then return end
	for i = 1,40 do
		if not particles.list[i] then
			particles.list[i] = {x = x, y = y}
			particles.list[i].particle = love.graphics.newParticleSystem(GetImage(path.."star.png"), 10)
			local particle = particles.list[i].particle
			particle:setParticleLifetime(2, 3)
			particle:setLinearAcceleration(-100, -100, 100, 100)
			particle:setSizes(1, 0)
			particle:setColors(1, 1, 1, 0.7, 1, 1, 1, 0)
			particle:emit(10)
			break
		end
	end
end

function particles.spawnBridgeShards(x, y, amount, alpha)
	if menu.settings[6].value == 0 then return end
	for i = 1,40 do
		if not particles.list[i] then
			particles.list[i] = {x = x, y = y}
			particles.list[i].particle = love.graphics.newParticleSystem(GetImage(path.."bridge.png"), amount)
			local particle = particles.list[i].particle
			particle:setParticleLifetime(0.5, (tilemap[y + 1][x] ~= TILE_EMPTY and 0.5) or 1.3)
			particle:setLinearAcceleration(0, 30, 0, 40)
			particle:setSpin(-3, 3)
			if tilesets[tilesetname].bridgeshardcolor then
				tilesets[tilesetname].bridgeshardcolor[4] = alpha
				particle:setColors(tilesets[tilesetname].bridgeshardcolor, {0, 0, 0, 0})
			else
				particle:setColors(1, 1, 1, alpha or 1, 0, 0, 0, 0)
			end
			particle:setEmissionArea("normal", 4, 4)
			particle:setSizes(0.5)
			particle:emit(amount)
			break
		end
	end
end

function particles.spawnSnow()
	if menu.settings[6].value == 0 then return end
	particles.list[PARTICLE_SNOW] = {}
	particles.list[PARTICLE_SNOW].particle = love.graphics.newParticleSystem(GetImage("Sprites/Particles/snow.png"), 100)
	local particle = particles.list[PARTICLE_SNOW].particle
	particle:setParticleLifetime(15, 25)
	particle:setEmissionArea("normal", screenwidth+20, 0)
	particle:setEmissionRate(5)
	particle:setSizeVariation(1, 0.5)
	particle:setLinearAcceleration(-30, 0, 30, 30)
	particle:emit(1)
end

function particles.spawnHelp(x, y)
	if menu.settings[6].value == 0 then return end
	particles.list[PARTICLE_HELP] = {x = x, y = y}
	particles.list[PARTICLE_HELP].particle = love.graphics.newParticleSystem(GetImage(path.."circle.png"), 1)
	local particle = particles.list[PARTICLE_HELP].particle
	particle:setParticleLifetime(1.5)
	particle:setSizes(0.1, 5)
	particle:setColors(1, 1, 1, 1, 1, 1, 1, 0)
	particle:emit(1)
end

function particles.spawnRain()
	if menu.settings[6].value == 0 then return end
	particles.list[PARTICLE_RAIN] = {}
	particles.list[PARTICLE_RAIN].particle = love.graphics.newParticleSystem(GetImage("Sprites/Particles/rain.png"), 500)
	local particle = particles.list[PARTICLE_RAIN].particle
	particle:setParticleLifetime(10)
	particle:setEmissionArea("normal", screenwidth+20, 0)
	particle:setEmissionRate(50)
	particle:setSizes(1.7)
	particle:setLinearAcceleration(0, 120, 0, 60)
	particle:setColors(tilesets[tilesetname].rain)
	particle:emit(1)
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
end

function particles.reset(num)
	if not num then
		for key = 1,40 do
			local particle = particles.list[key]
			if particle then particle.particle:reset() end
		end
	else
		local particle = particles.list[num]
		if particle then particle.particle:reset() end
	end
	particles.collectGarbage()
end

return particles