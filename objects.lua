local sound = require "music"
local particles = require "particles"
local coins = require "coins"
local ffi = require "ffi"
local discord = require "discordRPC"

-- DIRECTIONAL OBJECT SPRITE STRUCTURE
-- 1 2 LEFT
-- 3 4 RIGHT
-- 5 6 UP
-- 7 8 DOWN

DIR_LEFT = 1
DIR_RIGHT = 3
DIR_UP = 5
DIR_DOWN = 7

objects = {}
voids = {}
local collisions = {}
thinkers = {}

local MakeObject = ffi.typeof("gameobject")
local MakePlayerObject = ffi.typeof("playerobject")

function SpawnObject(sprite, x, y, type, quads, quadtype, direction, hp)
	if not collisions[type] then error('object type "'..type..'" does not exist!') end
	quadtype = (quadtype and quadtype) or (not quads and "none") or (hp and "hp") or (#quads == 1 and "single") or (#quads == 8 and "directions") or "default"
	local key = (#voids > 0 and table.remove(voids) or #objects + 1)
	local newobject = (type == "player" and MakePlayerObject or MakeObject)(quads and CacheQuadArray(quads) or 0, key, sprite, quadtype, type, hp or 1, x, y, direction or DIR_LEFT, 0, 1, false, false, 0, 0)
	objects[key] = newobject
	return newobject
end

function RemoveObject(mo, soundname)
	objects[mo.key] = nil
	table.insert(voids, mo.key)
	soundname = (type(soundname) == "string" and soundname) or nil
	soundname = (not soundname and ((mo == player and "heartbreak"..love.math.random(1, 2)..".wav") or "boom.wav")) or soundname
	if mo == player then particles.spawnShards(player.x, player.y, 1) darkness = 0 player = nil
	else particles.spawnShards(mo.x, mo.y, 0.5) end
	sound.playSound(soundname)
end

function RemoveMovingObject(mo, momx, momy)
	momx = momx or mo.momx
	momy = momy or mo.momy
	if momx and momy and momx == 0 and momy == 0 then return end
	RemoveObject(mo)
end

function RemoveStandingObject(mo, momx, momy)
	momx = momx or mo.momx
	momy = momy or mo.momy
	if momx == 0 and momy == 0 then RemoveObject(mo) end
end

function RemoveCollidedObject(_, obstmo)
	RemoveObject(obstmo)
end

function EraseObject(mo)
	objects[mo.key] = nil
	table.insert(voids, mo.key)
	if mo.type == "player" then player = nil end
end

function DamageObject(mo, amount)
	mo.hp = mo.hp - (amount or 1)
	if mo.hp <= 0 then
		RemoveObject(mo)
		return true
	end
	return false
end

local function RedSwitch(mo, momx, momy)
	if momx == 0 and momy == 0 then return end
	CheckMap(TILE_REDSWITCH, TILE_BLUESWITCH, TILE_REDWALLON, TILE_REDWALLOFF, TILE_BLUEWALLOFF, TILE_BLUEWALLON)
	sound.playSound("door.wav")
end

local function BlueSwitch(mo, momx, momy)
	if momx == 0 and momy == 0 then return end
	CheckMap(TILE_BLUESWITCH, TILE_REDSWITCH, TILE_BLUEWALLON, TILE_BLUEWALLOFF, TILE_REDWALLOFF, TILE_REDWALLON)
	sound.playSound("door.wav")
end

local function CrackBridge(mo)
	local x = mo.x
	local y = mo.y
	SetTile(x, y, tilemap[y][x] == TILE_BRIDGE_ROTATED and TILE_CRACKEDBRIDGE_ROTATED or TILE_CRACKEDBRIDGE)
end

function IsBridge(tile)
	return tile == TILE_BRIDGE or tile == TILE_CRACKEDBRIDGE or tile == TILE_BRIDGE_ROTATED or tile == TILE_CRACKEDBRIDGE_ROTATED
end

local function DestroyBridge(mo, momx, momy)
	if momx == 0 and momy == 0 then return end
	local x = mo.x
	local y = mo.y
	tilemap[y][x] = TILE_EMPTY
	if tilemap[y + 1][x] then
		if tilemap[y + 1][x] == TILE_CHASM2 then
			tilemap[y + 1][x] = TILE_EMPTY
			particles.spawnBridgeShards(mo.x, mo.y, 6)
			particles.spawnBridgeShards(mo.x, mo.y + 1, 6, 0.2)
		else
			particles.spawnBridgeShards(mo.x, mo.y, 12)
		end
	end
	local uppertile = tilemap[mo.y - 1][mo.x]
	local isBridge = IsBridge(uppertile)
	if uppertile and uppertile ~= TILE_EMPTY and (not isBridge) and uppertile ~= TILE_CHASM1 and uppertile ~= TILE_CHASM2 then
		tilemap[y][x] = TILE_CHASM1
	elseif uppertile and isBridge then
		tilemap[y][x] = TILE_CHASM2
	end
	UpdateTilemap()
end

function StopObject(mo, momx, momy)
	momx = momx or mo.momx
	momy = momy or mo.momy
	if momx == 0 and momy == 0 then return end
	mo.momx = 0
	mo.momy = 0
end

function PusherCheck(mo)
	local mopos = tilemap[mo.y][mo.x]
	if mopos == TILE_EMPTY or mopos == TILE_CHASM1 or mopos == TILE_CHASM2 then
		RemoveObject(mo)
	end
	return false
end

function PushObject(_, obstmo, momx, momy)
	obstmo.lastaxis = (momx ~= 0 and true) or false
	PusherCheck(obstmo)
	if not TryMove(obstmo, momx, momy) then return false end
end

function SlowPushObject(mo, obstmo, momx, momy)
	obstmo.momx = momx/1.4
	obstmo.momy = momy/1.4
	obstmo.lastaxis = (momx ~= 0 and true) or false
	PusherCheck(mo)
	return false
end

function SearchObject(x, y, notmo)
	for _, mo in pairs(objects) do
		if mo.x == x and mo.y == y and mo ~= notmo then return mo end
	end
end

local predicting = false

function TryMove(mo, momx, momy)
	if not mo then return end
	momx = GetTrueMomentum(momx)
	momy = GetTrueMomentum(momy)
	local moCollisions = collisions[ffi.string(mo.type)]
	local tilesetCollisions = tilesets[tilesetname].collision
	moCollisions[TILE_CUSTOM1] = tilesetCollisions[TILE_CUSTOM1]
	moCollisions[TILE_CUSTOM2] = tilesetCollisions[TILE_CUSTOM2]
	moCollisions[TILE_CUSTOM3] = tilesetCollisions[TILE_CUSTOM3]
	local sgamemap = gamemap
	if tilemap[mo.y+momy] and moCollisions[tilemap[mo.y+momy][mo.x+momx]] then
		local obstmo = SearchObject(mo.x+momx, mo.y+momy, mo)
		if (debugmode and debugmode["Noclip"]) or predicting then obstmo = nil end
		if obstmo then
			local obstmoType = ffi.string(obstmo.type)
			local obstmoCollisions = collisions[obstmoType]
			obstmoCollisions[TILE_CUSTOM1] = tilesetCollisions[TILE_CUSTOM1]
			obstmoCollisions[TILE_CUSTOM2] = tilesetCollisions[TILE_CUSTOM2]
			obstmoCollisions[TILE_CUSTOM3] = tilesetCollisions[TILE_CUSTOM3]
			local collision = moCollisions[obstmoType]
			if not collision then return false end
			local check
			if type(collision) == "function" then
				check = collision(mo, obstmo, momx, momy)
			else
				check = collision == nil and true or collision
			end
			if check == true then
				mo.y = mo.y+momy
				mo.x = mo.x+momx
				return true
			end
			if check ~= nil then return check end
		end
		if sgamemap ~= gamemap then return false end
		mo.y = mo.y+momy
		mo.x = mo.x+momx
		local tile = tilemap[mo.y][mo.x]
		if tile >= 50 then tile = tile - 10 end
		if type(moCollisions[tile]) == "function" and not predicting then
			local check = moCollisions[tile](mo, momx, momy)
			if check == false and mo then
				mo.y = mo.y-momy
				mo.x = mo.x-momx
				return false
			end
		end
		return true
	end
	return false
end

function PredictMove(mo, momx, momy)
	if predicting then return false end
	predicting = true
	local oldx = mo.x
	local oldy = mo.y
	local check = TryMove(mo, momx, momy)
	mo.x = oldx
	mo.y = oldy
	predicting = false
	return check
end

local function ThrustObject(mo, thrustx, thrusty)
	if not PredictMove(mo, thrustx, thrusty) then StopObject(mo) return end
	local obstmo = SearchObject(mo.x + GetTrueMomentum(thrustx), mo.y + GetTrueMomentum(thrusty))
	if obstmo then
		local collision = collisions[ffi.string(mo.type)][ffi.string(obstmo.type)]
		if not collision then StopObject(mo) return end
		local check = collision(mo, obstmo, thrustx, thrusty)
		if not check then StopObject(mo) return end
	end
	mo.momx = thrustx
	mo.momy = thrusty
	mo.lastaxis = (thrustx ~= 0 and true) or false
end

local directionToMomentum = {
	[DIR_RIGHT] = {momx = 1, momy = 0},
	[DIR_DOWN] = {momx = 0, momy = 1},
	[DIR_LEFT] = {momx = -1, momy = 0},
	[DIR_UP] = {momx = 0, momy = -1}
}

function DirectionMomentum(direction)
	return directionToMomentum[direction].momx, directionToMomentum[direction].momy
end

function MomentumDirection(checkx, checky)
	for k,v in pairs(directionToMomentum) do
		if v.momx == checkx and v.momy == checky then
			return k
		end
	end
end

function GetTrueMomentum(mom)
	return (mom > 0 and math.ceil(mom)) or math.floor(mom)
end

function GetDistance(mo1, mo2)
	return mo1.x-mo2.x, mo1.y-mo2.y
end

function DashObject(mo)
	mo.momx, mo.momy = DirectionMomentum(mo.direction)
end

function FireShot(mo, sprite, quads, type)
	local bullet = SpawnObject(sprite, mo.x, mo.y, type or "bullet", quads, nil, mo.direction)
	DashObject(bullet)
	sound.playSound("bullet.wav")
	return bullet
end

function FacePlayer(mo)
	local distx, disty = GetDistance(mo, player)
	local py = (disty/math.abs(disty))*-1
	local px = (distx/math.abs(distx))*-1
	local moCollisions = collisions[ffi.string(mo.type)]
	if ((distx ~= 0 and distx < disty and moCollisions[tilemap[mo.y][mo.x-distx]])
	or (disty == 0 or not moCollisions[tilemap[mo.y+py][mo.x]])) and moCollisions[tilemap[mo.y][mo.x+px]] then
		mo.direction = MomentumDirection(px, 0) or DIR_LEFT
	else
		mo.direction = MomentumDirection(0, py) or DIR_LEFT
	end
end

function EndLevel()
	gamemap = gamemap + 1
	if gamemap == lastmap then
		local unlocks = "Unlocked music:"
		for k, entry in ipairs(sound.soundtest) do
			if entry.require == gamemap + 1 then
				unlocks = unlocks.."\n"..entry.name
			end
		end
		if unlocks ~= "Unlocked music:" then
			notification.setMessage(unlocks)
		end
	end
	local prevlastmap = lastmap
	lastmap = math.max(gamemap + 1, lastmap)
	if lastmap > prevlastmap then StartSaving() end
	if gamemap == #menu["select level"] - 1 then
		pointer = 1
		gamestate = "the end"
		sound.reset()
		sound.setMusic("")
		discord.updatePresence(discord.menu)
		return
	end
	local errorcheck = LoadMap("map"..GetMapNum(gamemap)..".map")
	if errorcheck and errorcheck == "error" then
		gamemap = gamemap-1
		messagebox.setMessage("Failed to load next map!", "The current map was reloaded instead", true)
		local errorcheck2 = LoadMap("map"..GetMapNum(gamemap)..".map")
		if errorcheck2 and errorcheck2 == "error" then
			local finalcheck = LoadMap("map00.map")
			messagebox.setMessage("Failed to load next or current map!", "as a last ditch effor map00.map was loaded\nsomething must really be broken...", true)
			if finalcheck and finalcheck == "error" then
				error("Could not find a map to load\nthe Maps folder may be corrupted, reinstall the game and replace it.")
			end
		end
	end
	sound.reset()
	sound.playSound("win.wav")
	discord.updateGamePresence()
end

local defaultCollisions = {
	__index = {
		[TILE_EMPTY] = RemoveMovingObject,
		[TILE_FLOOR1] = true,
		[TILE_FLOOR2] = true,
		[TILE_FLOOR3] = true,
		[TILE_KEY] = true,
		[TILE_REDSWITCH] = RedSwitch,
		[TILE_BLUESWITCH] = BlueSwitch,
		[TILE_START] = true,
		[TILE_GOAL] = true,
		[TILE_REDWALLOFF] = true,
		[TILE_BLUEWALLOFF] = true,
		[TILE_AFLOOR1] = true,
		[TILE_AFLOOR2] = true,
		[TILE_RIGHTPUSHER1] = function(mo) ThrustObject(mo, 1, 0) return true end,
		[TILE_LEFTPUSHER1] = function(mo) ThrustObject(mo, -1, 0) return true end,
		[TILE_UPPUSHER1] = function(mo) ThrustObject(mo, 0, -1) return true end,
		[TILE_DOWNPUSHER1] = function(mo) ThrustObject(mo, 0, 1) return true end,
		[TILE_SPIKEON] = RemoveObject,
		[TILE_SPIKEOFF] = true,
		[TILE_SPIKE] = RemoveObject,
		[TILE_BRIDGE] = CrackBridge, 
		[TILE_CRACKEDBRIDGE] = DestroyBridge,
		[TILE_SLIME] = StopObject,
		[TILE_CHASM1] = RemoveMovingObject,
		[TILE_CHASM2] = RemoveMovingObject,
		[TILE_ENEMY] = true,
		[TILE_BRIDGE_ROTATED] = CrackBridge, 
		[TILE_CRACKEDBRIDGE_ROTATED] = DestroyBridge
	}
}

function AddObjectType(typename, collision, thinker)
	CheckArgument(1, "AddObjectType", typename, "string")
	if collisions[typename] then error('object type "'..typename..'" already exists!') end
	collisions[typename] = setmetatable(collision or {}, defaultCollisions)
	if type(thinker) == "function" then thinkers[typename] = thinker end
end

----OBJECT DEFINITIONS

---MISC

--PLAYER
local function ResetButtons(x, y)
	local button = SearchObject(x, y)
	button.frame = 1
end

AddObjectType("player", {
	[TILE_GOAL] = EndLevel,
	[TILE_SUPERDARK] = function()
		gamemap = -99
		RestartMap()
		discord.updateGamePresence()
	end,
	coin = function(_, obstmo)
		coins.hudtimer = 160
		coins[gamemap].got = true
		sound.playSound("coin.wav")
		particles.spawnStars(obstmo.x, obstmo.y)
		EraseObject(obstmo)
		if not customEnv then
			local coinsgot, coinstotal = coins.count()
			if coinsgot == math.floor(coinstotal / 2) then
				local wobble = menu.extras[EXTRA_WOBBLE]
				wobble.name = "wobble"
				wobble.value = 0
				wobble.values = valuesnames
				messagebox.setMessage("wobble mode unlocked!", [[
When enabled wobble mode will rotate the map up and down
Making movement much harder!
NOTE: May cause a bit of nausea
Good luck!
(wobble mode can be enabled in the extras menu)]])
			elseif coinsgot == coinstotal then
				sound.soundtest[#sound.soundtest] = coins.soundtest
				menu.extras[EXTRA_BONUSLEVELS].name = "Bonus levels"
				notification.setMessage("Unlocked music:\nLovely Bonus")
				messagebox.setMessage("Bonus levels unlocked!", [[
Each bonus level has a special unique gimmick!
They are ordered by difficulty, but can be cleared in any order
Good luck!
(The bonus levels can be accessed from the extras menu)]])
			end
		end
		StartSaving()
	end,
	shadowcoin = function(_, obstmo)
		sound.playSound("coin.wav")
		particles.spawnStars(obstmo.x, obstmo.y)
		EraseObject(obstmo)
	end,
	key = PushObject,
	box = function(_, obstmo, momx, momy)
		local check = PushObject(nil, obstmo, momx, momy)
		if check == false then
			return DamageObject(obstmo)
		elseif tilemap[obstmo.y][obstmo.x] == TILE_CUSTOM3 then
			obstmo.var2 = true
		end
		return check
	end,
	enemy = RemoveObject,
	bullet = RemoveObject,
	snowball = SlowPushObject,
	snowman = RemoveObject,
	masterbutton = function(mo, obstmo, momx, momy)
		local frame = obstmo.frame
		if (mo.momx == 0 and mo.momy == 0) or (momx == 0 and momy == 0) or frame == 3 then return end
		sound.playSound("button.wav")
		if frame == 2 then
			sound.playSound("button_off.wav")
			IterateMap(TILE_CUSTOM1, ResetButtons)
		elseif frame == 1 then
			obstmo.frame = 2
			local check = true
			local buttons = {}
			IterateMap(TILE_CUSTOM1, function(x, y)
				local button = SearchObject(x, y)
				if button.frame == 1 then
					check = false
					return true
				end
				table.insert(buttons, button)
			end)
			if check then
				CheckMap(TILE_LOCK, TILE_FLOOR2)
				for _, button in ipairs(buttons) do button.frame = 3 end
				sound.playSound("lock.wav")
			end
		end
	end,
	metalbox = PushObject,
	miniman = RemoveObject,
	bfmonitor = function(_, obstmo, momx, momy)
		if momx == 0 and momy == 0 then return true end
		obstmo.hp = math.max((obstmo.hp + 1) % 8, 1)
		return true
	end,
	biylove = function(mo, obstmo, momx, momy)
		PushObject(nil, obstmo, momx, momy)
		player = nil
		mo.momx = 0
		mo.momy = 0
	end,
	biylock = function(_, obstmo, momx, momy)
		PushObject(nil, obstmo, momx, momy)
		if obstmo.x == 24 and obstmo.y == 6 then
			CheckMap(TILE_LOCK, TILE_SLIME)
			sound.playSound("box.wav")
		end
	end,
	biyword = PushObject,
	biywin = function(_, obstmo, momx, momy)
		local check = PushObject(nil, obstmo, momx, momy)
		local key = objects[1]
		if obstmo.x == 2 and obstmo.y == 5 and key then
			EraseObject(key)
			SetTile(17, 12, TILE_CUSTOM2)
			sound.playSound("box.wav")
		end
		return check
	end,
	biybridge = PushObject,
	pacdot = function (_, obstmo)
		RemoveObject(obstmo, "menu_move.wav")
		local gotAll = true;
		IterateMap(TILE_FLOOR3, function(x, y)
			local mo = SearchObject(x, y)
			if mo and mo.type == "pacdot" then
				gotAll = false
				return true
			end
		end)
		if gotAll then
			SetTile(11, 10, TILE_CUSTOM2)
			sound.playSound("box.wav")
		end
	end,
	bimonitor = function(_, obstmo, momx, momy)
		if momx == 0 and momy == 0 then return true end
		obstmo.frame = (obstmo.frame % 2) + 1
		return true
	end,
	numonitor = function(_, obstmo, momx, momy)
		if momx == 0 and momy == 0 then return true end
		obstmo.frame = math.max((obstmo.frame + 1) % 11, 1)
		return true
	end,
}, function(mo)
	if mo.momx == 0 and mo.momy == 0 and (mo.fmomx ~= 0 or mo.fmomy ~= 0) and mo.ftime > 0 then
		mo.momx = mo.fmomx
		mo.momy = mo.fmomy
		mo.ftime = 0
		particles.spawnSmoke(mo.x, mo.y)
		return
	end
	mo.ftime = math.max(mo.ftime - 1, 0)
end)

--COIN
AddObjectType("coin")

--SHADOW COIN
AddObjectType("shadowcoin")

--KEY
AddObjectType("key", {
	[TILE_FLOOR1] = StopObject,
	[TILE_FLOOR2] = StopObject,
	[TILE_FLOOR3] = StopObject,
	[TILE_LOCK] = function(mo)
		SetTile(mo.x, mo.y, TILE_FLOOR1)
		EraseObject(mo)
		sound.playSound("lock.wav")
	end,
	[TILE_KEY] = StopObject,
	[TILE_START] = StopObject,
	[TILE_GOAL] = StopObject,
	[TILE_REDWALLOFF] = StopObject,
	[TILE_BLUEWALLOFF] = StopObject,
	[TILE_AFLOOR1] = StopObject,
	[TILE_AFLOOR2] = StopObject,
	[TILE_SPIKEOFF] = StopObject,
	[TILE_ENEMY] = StopObject
})

--ENEMY
AddObjectType("enemy", {player = RemoveCollidedObject, key = PushObject, box = PusherCheck, pacdot = true}, function(mo)
	if not player or (mo.momx ~= 0 and mo.momy ~= 0) then return end
	local time = leveltime % 100
	if time == 40 then
		FacePlayer(mo)
		local tx, ty = DirectionMomentum(mo.direction)
		particles.spawnWarning(mo.x + tx, mo.y + ty)
	elseif time == 0 then
		DashObject(mo)
		particles.spawnSmoke(mo.x, mo.y)
	end
end)

--BULLET
AddObjectType("bullet", {
	[TILE_EMPTY] = true,
	[TILE_REDSWITCH] = true,
	[TILE_BLUESWITCH] = true,
	[TILE_RIGHTPUSHER1] = true,
	[TILE_LEFTPUSHER1] = true,
	[TILE_UPPUSHER1] = true,
	[TILE_DOWNPUSHER1] = true,
	[TILE_SPIKEON] = true,
	[TILE_SPIKE] = true,
	[TILE_SLIME] = true,
	[TILE_CHASM1] = true,
	[TILE_CHASM2] = true,
	player = RemoveCollidedObject,
	bullet = function(mo, obstmo) RemoveObject(mo) RemoveObject(obstmo) end,
	masterbutton = true,
	metalbox = RemoveObject
}, RemoveStandingObject)

--DUMMY
AddObjectType("dummy")

---CHAPTER 2

--SNOWBALL
AddObjectType("snowball", {
	[TILE_WALL1] = RemoveObject,
	[TILE_WALL2] = RemoveObject,
	[TILE_WALL3] = RemoveObject,
	[TILE_WALL4] = RemoveObject,
	[TILE_WALL5] = RemoveObject,
	[TILE_WALL6] = RemoveObject,
	[TILE_WALL7] = RemoveObject,
	[TILE_WALL8] = RemoveObject,
	[TILE_WALL9] = RemoveObject,
	[TILE_LOCK] = RemoveObject,
	[TILE_REDWALLON] = RemoveObject,
	[TILE_BLUEWALLON] = RemoveObject,
	[TILE_RIGHTPUSHER1] = function(mo) ThrustObject(mo, 0.95, 0) return true end,
	[TILE_LEFTPUSHER1] = function(mo) ThrustObject(mo, -0.95, 0) return true end,
	[TILE_UPPUSHER1] = function(mo) ThrustObject(mo, 0, -0.95) return true end,
	[TILE_DOWNPUSHER1] = function(mo) ThrustObject(mo, 0, 0.95) return true end,
	player = PushObject,
	coin = true,
	shadowcoin = true,
	key = PushObject,
	enemy = RemoveCollidedObject,
	snowball = SlowPushObject,
	snowman = RemoveCollidedObject,
})

--SNOWMAN
AddObjectType("snowman", nil, function(mo)
	if not player then return end
	local time = leveltime%180
	if time == 0 then
		FireShot(mo, mo.sprite, GetExtraQuad(mo.sprite))
	elseif time == 110 then
		FacePlayer(mo)
		local tx, ty = DirectionMomentum(mo.direction)
		particles.spawnWarning(mo.x+tx, mo.y+ty)
	end
end)

---CHAPTER 3

--BOX
AddObjectType("box", {
	[TILE_FLOOR1] = StopObject,
	[TILE_FLOOR2] = StopObject,
	[TILE_FLOOR3] = StopObject,
	[TILE_KEY] = StopObject,
	[TILE_START] = StopObject,
	[TILE_GOAL] = StopObject,
	[TILE_REDWALLOFF] = StopObject,
	[TILE_BLUEWALLOFF] = StopObject,
	[TILE_AFLOOR1] = StopObject,
	[TILE_AFLOOR2] = StopObject,
	[TILE_SPIKEON] = false,
	[TILE_SPIKEOFF] = StopObject,
	[TILE_SPIKE] = false,
	[TILE_ENEMY] = StopObject,
}, function(mo)
	if leveltime % 10 > 0 then return end
	local tile = tilemap[mo.y][mo.x]
	if tile == TILE_SPIKEON or tile == TILE_SPIKE then
		DamageObject(mo)
	end
end)

---CHAPTER 4

--MASTER BUTTON
AddObjectType("masterbutton")

--METAL BOX
local function DestroySpikes(mo)
	SetTile(mo.x, mo.y, TILE_FLOOR2)
	sound.playSound("boom.wav")
	particles.spawnShards(mo.x, mo.y, 0.5)
end

AddObjectType("metalbox", {
	[TILE_FLOOR1] = StopObject,
	[TILE_FLOOR2] = StopObject,
	[TILE_FLOOR3] = StopObject,
	[TILE_KEY] = StopObject,
	[TILE_START] = StopObject,
	[TILE_GOAL] = StopObject,
	[TILE_REDWALLOFF] = StopObject,
	[TILE_BLUEWALLOFF] = StopObject,
	[TILE_AFLOOR1] = StopObject,
	[TILE_AFLOOR2] = StopObject,
	[TILE_SPIKEON] = DestroySpikes,
	[TILE_SPIKEOFF] = StopObject,
	[TILE_SPIKE] = DestroySpikes,
	[TILE_ENEMY] = StopObject,
	enemy = RemoveCollidedObject,
	bullet = RemoveCollidedObject,
	miniman = function(mo, obstmo)
		RemoveObject(obstmo)
		local pmo = SearchObject(obstmo.x, obstmo.y)
		if pmo and pmo ~= mo then RemoveObject(pmo) end
	end
})

--MINIMAN
AddObjectType("miniman", {metalbox = false}, function(mo)
	if not player or (leveltime % 8) ~= 0 then return end
	FacePlayer(mo)
	if ((mo.direction == DIR_DOWN or mo.direction == DIR_UP) and mo.x == player.x
	or (mo.direction == DIR_LEFT or mo.direction == DIR_RIGHT) and mo.y == player.y)
	and PredictMove(mo, DirectionMomentum(mo.direction)) then
		FireShot(mo, mo.sprite, GetExtraQuad(mo.sprite))
	end
end)

---BONUS LEVELS

--BRAINFUCK MONITOR
AddObjectType("bfmonitor")

--BRAINFUCK READER
local function EndBrainfuck(mo, posmo)
	EraseObject(posmo)
	EraseObject(mo)
	player.momy = -1
	if SearchObject(10, 4).hp == 1 and SearchObject(11, 4).hp == 8 and SearchObject(12, 4).hp == 8 and SearchObject(13, 4).hp == 8 and SearchObject(14, 4).hp == 8 then
		if tilemap[16][20] == TILE_LOCK then
			SetTile(20, 16, TILE_FLOOR1)
			sound.playSound("lock.wav")
		end
	end
end

local brainfuckOptions = {
	function() end,
	function(pos)
		local monitor = SearchObject(10 + pos, 4)
		monitor.hp = math.max((monitor.hp + 1) % 11, 1)
	end,
	function(pos)
		local monitor = SearchObject(10 + pos, 4)
		monitor.hp = monitor.hp == 1 and 10 or monitor.hp - 1
	end,
	function(pos, mo, posmo)
		mo.hp = (pos - 1) % 5
		posmo.x = 10 + mo.hp
	end,
	function(pos, mo, posmo)
		mo.hp = (pos + 1) % 5
		posmo.x = 10 + mo.hp
	end,
	function(pos, mo, posmo)
		if SearchObject(10 + pos, 4).hp == 1 then
			local scope = 0
			while mo.x < 18 do
				mo.x = mo.x + 1
				local symbol = SearchObject(mo.x, mo.y).hp
				if symbol == 7 then
					scope = scope - 1
					if scope == -1 then return end
				elseif symbol == 6 then scope = scope + 1 end
			end
			EndBrainfuck(mo, posmo)
		end
	end,
	function(pos, mo, posmo)
		if SearchObject(10 + pos, 4).hp ~= 1 then
			local scope = 0
			while mo.x > 5 do
				mo.x = mo.x - 1
				local symbol = SearchObject(mo.x, mo.y).hp
				if symbol == 6 then
					scope = scope - 1
					if scope == -1 then return end
				elseif symbol == 7 then scope = scope + 1 end
			end
			EndBrainfuck(mo, posmo)
		end
	end,
}

AddObjectType("bfreader", nil, function(mo)
	if not player then return end
	player.momx = 0
	player.momy = 0
	player.x = 3
	player.y = 6
	if leveltime % 10 > 0 then return end
	mo.x = mo.x + 1
	local posmo = objects[mo.var1]
	if mo.x == 20 then
		EndBrainfuck(mo, posmo)
		return
	end
	brainfuckOptions[SearchObject(mo.x, mo.y).hp](mo.hp, mo, posmo)
end)

--PLAYER CLONE
local function RemoveMovingObjectAndPlayer(mo, momx, momy)
	local key = mo.key
	RemoveMovingObject(mo, momx, momy)
	if not objects[key] and player then RemoveObject(player) end
end

local function RemoveObjectAndPlayer(mo)
	RemoveObject(mo)
	if player then RemoveObject(player) end
end

AddObjectType("playerclone", {
	[TILE_EMPTY] = RemoveMovingObjectAndPlayer,
	[TILE_SPIKEON] = RemoveObjectAndPlayer,
	[TILE_SPIKEOFF] = true,
	[TILE_SPIKE] = RemoveObjectAndPlayer,
	[TILE_BRIDGE] = CrackBridge, 
	[TILE_CRACKEDBRIDGE] = DestroyBridge,
	[TILE_SLIME] = StopObject,
	[TILE_CHASM1] = RemoveMovingObjectAndPlayer,
	[TILE_CHASM2] = RemoveMovingObjectAndPlayer,
	[TILE_ENEMY] = true,
}, function(mo)
	if not player then RemoveObject(mo) return end
	if mo.var2 and player.ftime > 0 and (player.fmomx ~= 0 or player.fmomy ~= 0) and mo.momx == 0 and mo.momy == 0 then
		mo.momx, mo.momy = player.fmomx * -1, player.fmomy
		particles.spawnSmoke(mo.x, mo.y)
	end
	mo.var2 = (player.momx == 0 and player.momy == 0)
end)

--BIY STUFF
local BIYCollision = {
	[TILE_EMPTY] = StopObject,
	[TILE_FLOOR1] = StopObject,
	[TILE_FLOOR2] = StopObject,
	[TILE_FLOOR3] = StopObject,
	[TILE_KEY] = StopObject,
	[TILE_START] = StopObject,
	[TILE_GOAL] = StopObject,
	[TILE_REDWALLOFF] = StopObject,
	[TILE_BLUEWALLOFF] = StopObject,
	[TILE_AFLOOR1] = StopObject,
	[TILE_AFLOOR2] = StopObject,
	[TILE_SPIKEON] = StopObject,
	[TILE_SPIKEOFF] = StopObject,
	[TILE_SPIKE] = StopObject,
	[TILE_ENEMY] = StopObject,
	[TILE_CHASM1] = StopObject,
	[TILE_CHASM2] = StopObject,
	biyword = PushObject,
	biybridge = PushObject,
	biylove = function(_, obstmo, momx, momy)
		PushObject(nil, obstmo, momx, momy)
		if not player then return end
		player = nil
		sound.playSound("box.wav")
	end,
}

AddObjectType("biylove", BIYCollision)
AddObjectType("biylock", BIYCollision)
AddObjectType("biyword", BIYCollision)
AddObjectType("biywin", BIYCollision)

AddObjectType("biybridge", BIYCollision, function(mo)
	if mo.var2 or not player then return end
	local is = objects[29]
	if not is or is.x ~= 14 or is.y ~= 16 then return end
	local slime = objects[28]
	if not slime then return end
	if mo.x == 13 and mo.y == 16 and slime.x == 15 and slime.y == 16 then
		tilemap[11][4] = TILE_SLIME
		tilemap[11][5] = TILE_SLIME
		tilemap[12][4] = TILE_SLIME
		tilemap[12][5] = TILE_SLIME
		tilemap[13][4] = TILE_CHASM1
		tilemap[13][5] = TILE_CHASM1
		UpdateTilemap()
		sound.playSound("box.wav")
		mo.var2 = true
	elseif slime.x == 13 and slime.y == 16 and mo.x == 15 and mo.y == 16 then
		CheckMap(TILE_SLIME, TILE_CRACKEDBRIDGE)
		sound.playSound("box.wav")
		mo.var2 = true
	end
end)

--PAC DOT
AddObjectType("pacdot", {
	player = function (mo)
		RemoveObject(mo, "menu_move.wav")
		local gotAll = true;
		IterateMap(TILE_FLOOR3, function(x, y)
			local mo = SearchObject(x, y)
			if mo and mo.type == "pacdot" then
				gotAll = false
				return true
			end
		end)
		if gotAll then
			SetTile(11, 10, TILE_CUSTOM2)
			sound.playSound("box.wav")
		end
	end
})

--RIDDLE MONITORS
AddObjectType("bimonitor")
AddObjectType("numonitor")

--ROTATIONS COUNTER
local function RotateMap()
	local newtilemap = {}
	for k, row in pairs(tilemap) do
		for y = 1, mapheight do
			if not newtilemap[y] then newtilemap[y] = {} end
			newtilemap[y][mapheight - k + 1] = row[y]
		end
	end
	tilemap = newtilemap
	for _, mo in pairs(objects) do
		mo.x, mo.y = mapwidth - mo.y + 1, mo.x
	end
end

AddObjectType("rotcounter", nil, function(mo)
	CheckMap(TILE_FLOOR1, TILE_DOWNPUSHER1)
	if not player then return end
	if player.fmomx ~= 0 then
		for _, mo in pairs(objects) do
			if tilemap[mo.y + 1] and tilemap[mo.y + 1][mo.x] == TILE_DOWNPUSHER1
			and not SearchObject(mo.x, mo.y + 1) then return end
		end
		RotateMap()
		rotation = -math.pi / 2
		if player.fmomx < 0 then
			RotateMap()
			RotateMap()
			rotation = -rotation
		end
		UpdateTilemap()
		player.fmomx = 0
		if mo.frame == 1 then RemoveObject(player)
		else mo.frame = mo.frame - 1 end
	end
end)