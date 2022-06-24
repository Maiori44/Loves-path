local sound = require "music"
local particles = require "particles"
local coins = require "coins"
local discord = require "discordRPC"

-- TILESET STRUCTURE
-- 01 02 03 WALLS
-- 04 05 06 WALLS
-- 07 08 09 WALLS
-- 10 11 12 FLOORS
-- 13 14 15 LOCK - KEY - RED SWTICH
-- 16 17 18 BLUE SWTICH - START - GOAL
-- 19 20 21 REDWALL ON - BLUEWALL ON - REDWALL OFF
-- 22 23 24 BLUEWALL OFF - ANIMATED FLOOR
-- 25 26 27 RIGHT PUSHER
-- 28 29 30 LEFT PUSHER
-- 31 32 33 UP PUSHER
-- 34 35 36 DOWN PUSHER
-- 37 38 39 SPIKES (ON - OFF - ALWAYS ON)
-- 40 41 42 BRIDGE - CRACKED BRIDGE - SLIME
-- 43 44 45 CHASMS - ENEMY
-- 46 47 48 CUSTOMS

TILE_EMPTY = 0
TILE_WALL1 = 1
TILE_WALL2 = 2
TILE_WALL3 = 3
TILE_WALL4 = 4
TILE_WALL5 = 5
TILE_WALL6 = 6
TILE_WALL7 = 7
TILE_WALL8 = 8
TILE_WALL9 = 9
TILE_FLOOR1 = 10
TILE_FLOOR2 = 11
TILE_FLOOR3 = 12
TILE_LOCK = 13
TILE_KEY = 14
TILE_REDSWITCH = 15
TILE_BLUESWITCH = 16
TILE_START = 17
TILE_GOAL = 18
TILE_REDWALLON = 19
TILE_BLUEWALLON = 20
TILE_REDWALLOFF = 21
TILE_BLUEWALLOFF = 22
TILE_AFLOOR1 = 23
TILE_AFLOOR2 = 24
TILE_RIGHTPUSHER1 = 25
TILE_RIGHTPUSHER2 = 26
TILE_RIGHTPUSHER3 = 27
TILE_LEFTPUSHER1 = 28
TILE_LEFTPUSHER2 = 29
TILE_LEFTPUSHER3 = 30
TILE_UPPUSHER1 = 31
TILE_UPPUSHER2 = 32
TILE_UPPUSHER3 = 33
TILE_DOWNPUSHER1 = 34
TILE_DOWNPUSHER2 = 35
TILE_DOWNPUSHER3 = 36
TILE_SPIKEON = 37
TILE_SPIKEOFF = 38
TILE_SPIKE = 39
TILE_BRIDGE = 40
TILE_CRACKEDBRIDGE = 41
TILE_SLIME = 42
TILE_CHASM1 = 43
TILE_CHASM2 = 44
TILE_ENEMY = 45
TILE_CUSTOM1 = 46
TILE_CUSTOM2 = 47
TILE_CUSTOM3 = 48
TILE_BRIDGE_ROTATED = 50
TILE_CRACKEDBRIDGE_ROTATED = 51
TILE_SUPERDARK = -1

lastmap = 1
mapspath = "Maps/"
tilemap = {}
quads = {}

for i=0,15 do
	for j=0,2 do
		local quad = love.graphics.newQuad(1+j*(32+2), 1+i*(32+2), 32, 32, 102, 544)
		table.insert(quads, quad)
	end
end
quads[TILE_SUPERDARK] = quads[TILE_FLOOR1]

function UpdateTilemap(tilesize, rotatebridges)
	if not tilesize then tilesize = math.floor(scale * GetScaleByScreen() * 32) end
	if not rotatebridges then rotatebridges = tilesets[tilesetname].rotatebridges end
	tileset:clear()
	local scale = tilesize / 32
	for i,row in ipairs(tilemap) do
		for j,tile in ipairs(row) do
			if tile ~= 0 then
				local rotation = 0
				local animationtime = tileAnimations[tile] or 1
				local animationframe = math.floor((leveltime % animationtime) / 10)
				local x = j * tilesize
				local y = i * tilesize
				if tile >= 50 then
					tile = tile - 10
					if rotatebridges ~= false then
						rotation = math.pi / 2
						x = x + tilesize
					end
				end
				if quads[tile+animationframe] then
					tileset:add(quads[tile+animationframe], x, y, rotation, scale)
					if debugmode and debugmode["Map info"] then
						love.graphics.print(tile+animationframe, GetStartX() + x, GetStartY() + y, rotation, scale)
					end
				else
					love.graphics.draw(GetImage("Sprites/error.png"), x, y, 0, scale)
					love.graphics.print(tile, x, y, 0, scale)
				end
			end
		end
	end
end

function SetTile(x, y, tile)
	tilemap[y][x] = tile
	local rotation = 0
	local animationtime = tileAnimations[tile] or 1
	local animationframe = math.floor((leveltime % animationtime) / 10)
	local tilesize = math.floor(scale * GetScaleByScreen() * 32)
	x = x * tilesize
	y = y * tilesize
	if tile >= 50 then
		tile = tile - 10
		if tilesets[tilesetname].rotatebridges ~= false then
			rotation = math.pi / 2
			x = x + tilesize
		end
	end
	tileset:add(quads[tile+animationframe], x, y, rotation, tilesize / 32)
end

local enemysprite = "Sprites/Enemies/forest.png"

function RestartMap()
	local oldscale = scale
	if gamemap < 0 then
		if gamemap == -99 then
			LoadMap("superdark.map")
			frames = 0
			seconds = 0
			minutes = 0
			hours = 0
			tilesets["factory.png"].tile[TILE_CUSTOM2](21, 12)
		else
			menu["bonus levels"][math.abs(gamemap)].func()
		end
		scale = oldscale
		UpdateTilemap()
	else
		LoadMap("map"..GetMapNum(gamemap)..".map", oldscale)
	end
end

menu.pause[2].func = RestartMap --blame file load order

local function GetMapData(mapname)
	return love.filesystem.read(mapspath..mapname)
end

function LoadMap(mapname, oldscale)
	timer = 0
	voids = {}
	for k, _ in pairs(objects) do objects[k] = nil end
	objects = {}
	local mapdata = GetMapData(mapname)
	if not mapdata then
		messagebox.setMessage("Failed to load "..mapname.."!", "Map not found.", true)
		return "error"
	end
	local oldtileset = tilesetname
	local ReadLine = string.gmatch(mapdata, "[^\r\n]+")
	gamemapname = ReadLine()
	tilesetname = ReadLine()
	local path = GetTilesetPath()
	local musicname = ReadLine()
	sound.setMusic(musicname)
	mapwidth = tonumber(ReadLine())
	mapheight = tonumber(ReadLine())
	if not mapwidth or not mapheight or tilesetname == "" then
		messagebox.setMessage("Failed to load "..mapname.."!", "The map is corrupted.", true)
		return "error"
	end
	if oldtileset ~= tilesetname then
		enemysprite = path.."Enemies/"..tilesetname
		tileset:setTexture(GetImage(path.."Tiles/"..tilesetname))
	end
	local playerx, playery
	tilemap = {}
	local ReadTile = string.gmatch(ReadLine(), "..")
	local flags = tilesets[tilesetname]
	for y = 1,mapheight do
		tilemap[y] = {}
		for x = 1,mapwidth do
			local tile = tonumber(ReadTile() or 0)
			tilemap[y][x] = tile or TILE_EMPTY
			if tile == TILE_START then
				tilemap[y][x] = TILE_FLOOR1
				playerx = x
				playery = y
			elseif tile == TILE_KEY then
				SpawnObject(flags.keysprite and flags.keysprite or "Sprites/key.png", x, y, "key")
				tilemap[y][x] = TILE_FLOOR1
			elseif tile == TILE_ENEMY then
				SpawnObject(enemysprite, x, y, "enemy", GetDirectionalQuads(enemysprite), flags.enemyquadtype or "directions")
				tilemap[y][x] = TILE_FLOOR1
			elseif (tile == TILE_CUSTOM1 or tile == TILE_CUSTOM2 or tile == TILE_CUSTOM3) and type(flags.tile[tile]) == "function" then
				flags.tile[tile](x, y)
			end
		end
	end
	local loadedmap = tonumber(mapname:match("%d+%d"))
	local coindata = coins[loadedmap]
	if coindata and not mapname:match("bonus") then
		local shadow = coindata.got
		SpawnObject(shadow and coins.shadowpath or coins.path, coindata.x, coindata.y, shadow and "shadowcoin" or "coin", coins.quads, "default")
	end
	if customEnv then customEnv.tilemap = tilemap end
	if playerx and playery then
		player = SpawnObject(flags.playersprite or "Sprites/player.png", playerx, playery, "player")
		player.fmomx = 0
		player.fmomy = 0
		player.ftime = 0
		if customEnv then customEnv.player = player end
	end
	statetimer = 1
	leveltime = 0
	frametime = 0
	flash = 1
	darkness = 0
	rotation = 0
	gamestate = "ingame"
	mouse.camerax = 0
	mouse.cameray = 0
	mouse.mode = "camera"
	local longside = math.max(mapwidth, mapheight)
	scale = oldscale or ((mapwidth >= 20 or mapheight >= 20) and GetScale(longside)) or 1
	love.window.requestAttention()
	if customEnv and customEnv.MapLoad and type(customEnv.MapLoad) == "function" then
		customEnv.MapLoad(gamemap, tilesetname)
	end
	particles.reset()
	particles.reset(PARTICLE_HELP)
	if flags.snow then
		particles.spawnSnow()
	else
		particles.reset(PARTICLE_SNOW)
	end
	if flags.rain then
		particles.spawnRain()
	else
		particles.reset(PARTICLE_RAIN)
	end
	UpdateTilemap(nil, flags.rotatebridges)
end

function CheckMap(...)
	local args = {...}
	local dosmoke = false
	if args[#args] == true then
		dosmoke = true
		args[#args] = nil
	end
	local replaced = false
	for y = 1, mapheight do
		for x = 1, mapwidth do
			for i = 1, #args, 2 do
				local tocheck = args[i]
				local change = args[i+1]
				if not tocheck or not args then break end
				if tilemap[y] and tilemap[y][x] == tocheck then
					tilemap[y][x] = change
					replaced = true
					if dosmoke then
						particles.spawnSmoke(x, y)
					end
					break
				end
			end
		end
	end
	UpdateTilemap()
	return replaced
end

function IterateMap(tile, func)
	for y = 1, mapheight do
		for x = 1, mapwidth do
			if tilemap[y] and tilemap[y][x] == tile then
				local check = func(x, y)
				if check then return end
			end
		end
	end
	UpdateTilemap()
end

function LoadEditorMap(mapname)
	local mapdata = GetMapData(mapname)
	if not mapdata then return false end
	local oldtileset = tilesetname
	local ReadLine = string.gmatch(mapdata, "[^\r\n]+")
	gamemapname = ReadLine()
	tilesetname = ReadLine()
	local path = GetTilesetPath()
	local musicname = ReadLine()
	sound.setMusic(musicname)
	mapwidth = tonumber(ReadLine())
	mapheight = tonumber(ReadLine())
	if not mapwidth or not mapheight or tilesetname == "" then
		messagebox.setMessage("Failed to load "..mapname.."!", "The map is corrupted.", true)
		love.event.quit(0)
		return false
	end
	tilemap = {}
	local ReadTile = string.gmatch(ReadLine(), "..")
	for y = 1,mapheight do
		tilemap[y] = {}
		for x = 1,mapwidth do
			tile = tonumber(ReadTile() or 0)
			tilemap[y][x] = tile or TILE_EMPTY
		end
	end
	objects = {}
	voids = {}
	player = nil
	if oldtileset ~= tilesetname then
		enemysprite = path.."Enemies/"..tilesetname
		tileset = love.graphics.newSpriteBatch(GetImage(path.."Tiles/"..tilesetname), 1225, "static")
	end
	wheelmoved = 0
	statetimer = 1
	flash = 1
	darkness = 0
	rotation = 0
	mouse.mode = "editing"
	love.window.requestAttention()
	particles.reset()
	particles.reset(PARTICLE_SNOW)
	particles.reset(PARTICLE_RAIN)
	discord.updatePresence({
		details = "Editing level",
		state = gamemapname,
		startTimestamp = startTimestamp,
		largeImageKey = "logo"
	})
	return true
end

function GetAllMaps()
	menu["select level"] = {}
	local mapn = 1
	local possiblemaps = love.filesystem.getDirectoryItems(mapspath:sub(1, -2))
	for k, mapname in ipairs(possiblemaps) do
		if mapname:match("map%d%d%.map") == mapname then
			menu["select level"][mapn] = {
				name = tostring(mapn),
				func = function()
					LoadMap(mapname)
					gamemap = tonumber(mapname:match("%d%d"))
					frames = 0
					seconds = 0
					minutes = 0
					hours = 0
					discord.updateGamePresence()
				end
			}
			mapn = mapn + 1
		end
	end
	if #menu["select level"] > 255 then
		love.window.showMessageBox("Loaded too many maps!", "Saving data may fail.", "warning")
	end
	table.insert(menu["select level"], {name = "back", func = function() ChangeGamestate("title") pointer = 1 end})
end


function SaveMap(map, mapname, tilesetname, musicname, width, height, reset)
	if map:sub(1, 7) == "Source/" then
		map = map:sub(8)
	end
	local file = io.open(map, "w+")
	if not file then
		messagebox.setMessage("Failed to save map!", "Check if the Map folder exists in your mod folder", true)
		return false
	end
	file:write((#mapname == 1 and "unnamed\n") or mapname)
	file:write((#tilesetname == 1 and "forest.png\n") or tilesetname)
	file:write((#musicname == 1 and "none\n") or musicname)
	local awidth = (width ~= "\n") and (width ~= "0\n") and ((tonumber(width:sub(1, width:len()-1)) > 35) and "35\n" or width) or "10\n"
	file:write(awidth)
	local aheight = (height ~= "\n") and (height ~= "0\n") and ((tonumber(height:sub(1, height:len()-1)) > 35) and "35\n" or height) or "10\n"
	file:write(aheight)
	for y = 1, tonumber(aheight) do
		for x = 1, tonumber(awidth) do
			local tile = (tilemap[y] and tilemap[y][x]) or 0
			file:write((reset and "00") or ((tile < 10 and "0"..tile) or tostring(tile)))
		end
	end
	file:close()
	GetAllMaps()
	return true
end