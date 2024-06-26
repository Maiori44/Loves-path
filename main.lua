VERSION = "Version b9.0.245"

if love.filesystem.isFused() then
	love.filesystem.mount(love.filesystem.getSourceBaseDirectory(), "Source")
end

local PrintFormatted = love.graphics.printf

---@diagnostic disable-next-line: duplicate-set-field
function love.graphics.printf(text, x, y, ...)
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(0, 0, 0, a)
	PrintFormatted(text, x + 1, y, ...)
	PrintFormatted(text, x - 1, y, ...)
	PrintFormatted(text, x, y + 1, ...)
	PrintFormatted(text, x, y - 1, ...)
	love.graphics.setColor(r, g, b, a)
	PrintFormatted(text, x, y, ...)
end

local Print = love.graphics.print

---@diagnostic disable-next-line: duplicate-set-field
function love.graphics.print(text, x, y, ...)
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(0, 0, 0, a)
	Print(text, x + 1, y, ...)
	Print(text, x - 1, y, ...)
	Print(text, x, y + 1, ...)
	Print(text, x, y - 1, ...)
	love.graphics.setColor(r, g, b, a)
	Print(text, x, y, ...)
end

love.graphics.setBackgroundColor(0.1, 0.1, 0.1, 1)

function GetMapNum(mapnum)
	mapnum = tostring(mapnum)
	if tonumber(mapnum) < 10 then mapnum = "0"..mapnum end
	if mapnum:len() > 2 then mapnum = mapnum:sub(2) end
	return mapnum
end

local font

messagebox = {
	title = "",
	contents = "",
	show = false,
	error = false,
	width = 0,
	height = 0,
	setMessage = function(title, contents, error)
		messagebox.show = true
		messagebox.title = title
		messagebox.contents = contents or ""
		local linewidth = 0
		for line in string.gmatch(messagebox.contents, "[^\r\n]+") do
			local clinewidth = font:getWidth(line)
			linewidth = (clinewidth > linewidth and clinewidth) or linewidth
		end
		messagebox.width = math.max(math.max(font:getWidth(messagebox.title) * 1.5, linewidth), 260)
		messagebox.height = 85
		for w in messagebox.contents:gmatch("\n") do
			messagebox.height = messagebox.height + 20
		end
		if error or (contents and type(contents) == "boolean") then
			messagebox.error = true
		end
	end
}

notification = {
	text = "",
	timer = 0,
	setMessage = function(text)
		notification.text = text
		notification.timer = 480
	end
}

local ffi = require "ffi"
ffi.cdef((love.filesystem.read("cdef.c")))

require "cache"
require "menu"
require "customhandler"
require "maps"
require "objects"
require "player"
utf8 = require "utf8"
local sound = require "music"
local particles = require "particles"
local coins = require "coins"
local discord = require "discordRPC"
local cutscenes = require "cutscenes"

startTimestamp = os.time(os.date("*t") --[[@as osdateparam]])

discord.menu = {
	state = "Menu",
	largeImageKey = "logo",
	startTimestamp = startTimestamp
}

function discord.updateGamePresence()
	local presence = {
		details = "Playing",
		largeImageKey = "logo",
		startTimestamp = startTimestamp,
		smallImageText = "Level " .. gamemap + 1 .. ": " .. gamemapname
	}
	if customEnv then
		presence.state = "Modded"
		presence.smallImageKey = "unknown"
	elseif gamemap == -99 then
		presence.state = "???"
		presence.smallImageKey = "unknown"
		presence.smallImageText = "???"
	elseif gamemap < 0 then
		presence.state = "Bonus levels"
		presence.smallImageKey = "unknown"
	else
		local chapter = math.floor(gamemap / 10) + 1
		presence.state = "Chapter " .. chapter
		presence.smallImageKey = "chapter" .. chapter
	end
	discord.updatePresence(presence)
end

io.stdout:setvbuf("no")

local titlescreen = love.graphics.newImage("Sprites/title1.png")
local titleglow = love.graphics.newImage("Sprites/title2.png")

local function GetUnit(val)
	local tval = tostring(val)
	return tonumber(tval:sub(tval:len()))
end

function GetScale(num)
	return math.floor((18/num)*10)/10
end

function GetScaleByScreen()
	return screenheight/600
end

local function DoTime(timetodo, timetoreset)
	if timetoreset == 60 then
		return timetodo+1, 0
	end
	return timetodo, timetoreset
end

function GetStartX()
	return ((screenwidth-(mapwidth+2)*(scale * GetScaleByScreen())*32)/2)+mouse.camerax
end

function GetStartY()
	return ((screenheight-((mapheight < 20 and mapheight) or mapheight+2)*(scale * GetScaleByScreen())*32)/2)+mouse.cameray
end

function love.load(args)
	if args[1] == "-debug" then
		debugmode = {}
		table.insert(possibleTilesets, "bonus.png")
		table.insert(possibleMusic, "mind.ogg")
		table.insert(menu["level editor"], 4, {name = "Load file: ", string = "", func = function()
			mouse.tile = TILE_WALL1
			gamestate = LoadEditorMap(menu["level editor"][3].string) and "editing" or "level editor"
		end})
		table.insert(menu["map settings"], 6, {name = "Save to file: ", string = "", func = function(this)
			local mapinfo = menu["map settings"]
			SaveMap("Maps/"..this.string, mapinfo[1].string.."\n", mapinfo[2].values[mapinfo[2].value].."\n", mapinfo[3].values[mapinfo[3].value].."\n", mapinfo[4].int.."\n", mapinfo[5].int.."\n")
			LoadEditorMap(this.string)
			notification.setMessage("Map saved")
		end})
		lovebug = require "lovebug"
		love.mousepressed = lovebug.mousepressed
	end
	love.graphics.setDefaultFilter("nearest", "nearest")
	font = love.graphics.newFont("editundo.ttf", 24, "mono")
	love.graphics.setFont(font)
	love.keyboard.setKeyRepeat(true)
	hisname = ""
	leveltime = 0
	frametime = 0
	seconds = 0
	minutes = 0
	hours = 0
	gamestate = "title"
	laststate = "title"
	statetimer = 1
	gamemap = 0
	lastmap = 1
	scale = 1
	timer = 0
	flash = 0
	darkness = 0
	rotation = 0
	screenwidth = love.graphics.getWidth()
	screenheight = love.graphics.getHeight()
	wheelmoved = 0
	---@type nil | ffi.cdata*
	player = nil
	gamemapname = "forest.png"
	musicname = ""
	menuButtons = nil
	pcall(LoadSettings)
	GetAllMaps()
	local tilesetimage = GetImage("Sprites/Tiles/" .. (possibleTilesets[math.ceil(lastmap / 10) - 1] or "forest.png"))
	tileset = love.graphics.newSpriteBatch(tilesetimage, 1225, "dynamic")
	sound.setMusic("menu.ogg")
	local coinsgot, coinstotal = coins.count()
	if coinsgot == coinstotal then
		sound.soundtest[#sound.soundtest] = coins.soundtest
		menu.extras[EXTRA_BONUSLEVELS].name = "Bonus levels"
	end
	if not discord.loaded then
		messagebox.setMessage("Could not load DiscordRPC!", "The game can still be played\nbut Discord won't update your status", true)
		return
	end
	discord.initialize("974379262792581231", true)
	discord.updatePresence(discord.menu)
end

local glitchshader = love.graphics.newShader("Shaders/glitch.glsl")
local deathshader = love.graphics.newShader("Shaders/death.glsl")
darkshader = love.graphics.newShader("Shaders/dark.glsl")
darkshader:send("light", 200)

local function SpikesWarn(x, y) particles.spawnWarning(x, y, 0.4) end

--bumps structure:
--[1] -> on the top of the map?
--[2] -> of the left of the map?
--[3] -> on the bottom of the map?
--[4] -> on the right of the map?
--[5] -> momx
--[6] -> momy
local bumps =  {
	["truetruefalsefalse0-1"] = math.pi / 16,
	["truetruefalsefalse-10"] = -math.pi / 16,
	["truefalsefalsetrue10"] = math.pi / 16,
	["truefalsefalsetrue0-1"] = -math.pi / 16,
	["falsetruetruefalse-10"] = math.pi / 16,
	["falsetruetruefalse01"] = -math.pi / 16,
	["falsefalsetruetrue01"] = math.pi / 16,
	["falsefalsetruetrue10"] = -math.pi / 16
}

local function FlashCutscene()
	flash = flash + 0.02
	if flash > 1.7 then
		gamestate = "cutscene"
		sound.setMusic("cutscene "..cutscenes.num..".ogg")
	end
end

function AlternateSpikes()
	if CheckMap(TILE_SPIKEON, TILE_SPIKEOFF, TILE_SPIKEOFF, TILE_SPIKEON) then
		sound.playSound("spikes.wav")
	end
end

local updateModes = {
	ingame = function()
		if not player then darkness = math.min(darkness + 0.2, 70) end
		leveltime = leveltime + 1
		local wobble = menu.extras[EXTRA_WOBBLE].value
		rotation = (wobble and wobble > 0)
			and rotation + (math.cos(leveltime / 100) / 5) / math.max(mapheight, mapwidth)
			or rotation / 2
		frames = frames + 1
		seconds, frames = DoTime(seconds, frames)
		minutes, seconds = DoTime(minutes, seconds)
		hours, minutes = DoTime(hours, minutes)
		if debugmode and debugmode.slowdown and leveltime % 60 ~= 0 then return end
		flash = math.max(flash-0.02, 0)
		if customEnv then
			customEnv.leveltime = leveltime
			customEnv.timer = timer
			if customEnv.UpdateFrame then
				customEnv.UpdateFrame(frames, seconds, minutes, hours)
			end
		end
		if (leveltime%2) == 0 then
			local sgamemap = gamemap
			for _, mo in pairs(objects) do
				local thinker = thinkers[ffi.string(mo.type)]
				if thinker then thinker(mo) end
				TryMove(mo, 0, 0)
				if mo.momx and mo.momy and (mo.momx ~= 0 or mo.momy ~= 0) then
					local movingmom = (mo.momx ~= 0 and mo.momx) or mo.momy
					movingmom = (movingmom > 0 and math.ceil(2/movingmom)) or math.floor(2/movingmom)
					if (leveltime%movingmom == 0) then
						local momx = GetTrueMomentum(mo.momx)
						local momy = GetTrueMomentum(mo.momy)
						local check = TryMove(mo, momx, momy)
						if gamemap ~= sgamemap then return end
						if not check then
							if mo.type == "player" then
								local angley = math.max(mapheight / 100 * 20, 2)
								local anglex = math.max(mapwidth / 100 * 20, 2)
								local bump = bumps[tostring(mo.y <= angley) .. tostring(mo.x <= anglex) .. tostring(mo.y > mapheight - angley) .. tostring(mo.x > mapwidth - anglex) .. mo.momx .. mo.momy]
								if bump then rotation = rotation + bump / math.max(mapheight, mapwidth) end
							end
							mo.momx = 0
							mo.momy = 0
							sound.playSound("stop.wav")
						end
					end
				end
			end
		end
		local spikeinterval = math.ceil(600 / AssistControl(2))
		if ((leveltime + 40) % spikeinterval) == 0 then
			IterateMap(TILE_SPIKEOFF, SpikesWarn)
		elseif (leveltime % spikeinterval) == 0 then
			AlternateSpikes()
		elseif (leveltime % 620) == 0 and tilesets[tilesetname].thunder and menu.settings[7].value == 1 and flash == 0 then
			flash = 0.7
			sound.playSound("thunder.wav")
		end
		if (leveltime % 60) == 0 then
			if timer > 0 and player then
				timer = timer - 1
				if timer <= 0 then
					RemoveObject(player)
				end
			end
		end
	end,
	editing = function()
		leveltime = leveltime + 1
		mouse.think()
	end,
	["sound test"] = function()
		if sound.music and not love.mouse.isDown(1) and not sound.music:isPlaying() then sound.music:play() end
	end,
	["the story begins"] = FlashCutscene,
	chaptercomplete = FlashCutscene,
	["cutscene selected"] = FlashCutscene
}

function love.update(dt)
	if saver then
		coroutine.resume(saver)
		if coroutine.status(saver) == "dead" then saver = nil end
	end
	frametime = frametime + math.min(dt, 1/15)
	while frametime > 1/60 do
		frametime = frametime-1/60
		if statetimer < 1 then
			statetimer = statetimer + (1 - statetimer) / 10
		end
		coins.hudtimer = math.max(coins.hudtimer-1, 0)
		if #sound.list >= 10 then sound.collectGarbage() end
		if #particles.list >= 20 then particles.collectGarbage() end
		if updateModes[gamestate] then updateModes[gamestate]() end
	end
end

tileAnimations = {
	[TILE_AFLOOR1] = 20,
	[TILE_RIGHTPUSHER1] = 30,
	[TILE_LEFTPUSHER1] = 30,
	[TILE_UPPUSHER1] = 30,
	[TILE_DOWNPUSHER1] = 30
}

local quadDrawingMethods = {
	none = function(_, x, y, sprite)
		love.graphics.draw(sprite, x, y, 0, scale)
	end,
	single = function(_, x, y, sprite, quads)
		love.graphics.draw(sprite, quads[1], x, y, 0, scale)
	end,
	directions = function(mo, x, y, sprite, quads)
		love.graphics.draw(sprite, quads[math.floor((leveltime%20)/10)+mo.direction], x, y, 0, scale)
	end,
	movement = function(mo, x, y, sprite, quads)
		love.graphics.draw(sprite, quads[mo.direction+(((mo.momx == 0 and mo.momy == 0) and 0) or 1)], x, y, 0, scale)
	end,
	position = function(mo, x, y, sprite, quads)
		local movingaxis = mo.lastaxis and mo.x or mo.y
		love.graphics.draw(sprite, quads[(movingaxis%#quads)+1], x, y, 0, scale)
	end,
	hp = function(mo, x, y, sprite, quads)
		love.graphics.draw(sprite, quads[mo.hp], x, y, 0, scale)
	end,
	frame = function(mo, x, y, sprite, quads)
		love.graphics.draw(sprite, quads[mo.frame], x, y, 0, scale)
	end,
	default = function(_, x, y, sprite, quads)
		love.graphics.draw(sprite, quads[math.floor((leveltime%(#quads*10))/10)+1], x, y, 0, scale)
	end
}

local function AnimatedPrint(text, x, y, speed)
	speed = speed or 4
	for p, c in utf8.codes(text) do
		local char = utf8.char(c)
		local o = math.sin((p + love.timer.getTime() * 20) / 2.5) * speed
		o = math.floor(o - o / 2 + .5)
		love.graphics.print(char, x, y + o)
		x = x + font:getWidth(char)
	end
end

local function DrawTilemap()
	local shaders = {}
	local flags = tilesets[tilesetname]
	local centerx = GetStartX()
	local centery = GetStartY()
	scale = scale * GetScaleByScreen()
	local tilesize = math.floor(32*scale)
	local superdark = menu.extras[EXTRA_SUPERDARK].value == 1
	love.graphics.push()
	love.graphics.translate(screenwidth / 2, screenheight / 2)
	love.graphics.rotate(rotation)
	love.graphics.translate(-screenwidth / 2, -screenheight / 2)
	if player then
		mouse.speed = math.max(mouse.speed - 1, 1)
		local playerx = centerx + player.x * tilesize + tilesize / 2
		local playery = centery + player.y * tilesize + tilesize / 2
		playerx, playery = love.graphics.transformPoint(playerx, playery)
		if not love.mouse.isDown(1) then
			if playerx > screenwidth - 100 then
				mouse.camerax = mouse.camerax - 2 * mouse.speed
				mouse.speed = mouse.speed + 2
			elseif playerx < 100 then
				mouse.camerax = mouse.camerax + 2 * mouse.speed
				mouse.speed = mouse.speed + 2
			end
			if playery > screenheight - 100 then
				mouse.cameray = mouse.cameray - 2 * mouse.speed
				mouse.speed = mouse.speed + 2
			elseif playery < 100 then
				mouse.cameray = mouse.cameray + 2 * mouse.speed
				mouse.speed = mouse.speed + 2
			end
		end
		if flags.dark or superdark then
			darkshader:send("pos", {playerx, playery})
			darkshader:send("scale", scale)
			table.insert(shaders, darkshader)
		end
	elseif gamestate == "ingame" or gamestate == "pause" or gamestate == "assist mode" then
		if flags.dark or superdark then
			local radius = scale - (darkness * scale / 2)
			darkshader:send("scale", radius)
			if radius > -6.3 * scale or superdark then
				table.insert(shaders, darkshader)
			end
		end
		deathshader:send("darkness", darkness)
		table.insert(shaders, deathshader)
	end
	if flags.glitch and (gamestate == "ingame" or gamestate == "pause") and menu.settings[7].value == 1 then
		local lt = leveltime / 100
		glitchshader:send("leveltime", lt)
		glitchshader:send("intensity", math.abs(math.sin(leveltime / 700)))
		table.insert(shaders, glitchshader)
	end
	if #shaders > 0 then
		love.graphics.setShader(unpack(shaders))
	end
	if leveltime % 10 == 0 then
		UpdateTilemap(tilesize, flags.rotatebridges)
	end
	love.graphics.draw(tileset, centerx, centery)
	for k = 1,40 do
		local particle = particles.list[k]
		if particle then
			local x = (centerx+particle.x*tilesize)+(16*scale)
			local y = (centery+particle.y*tilesize)+(16*scale)
			love.graphics.draw(particle.particle, x, y, 0, scale)
		end
	end
	for k, mo in pairs(objects) do
		local x = centerx+mo.x*tilesize
		local y = centery+mo.y*tilesize
		local drawingMethod = quadDrawingMethods[ffi.string(mo.quadtype)]
		if not drawingMethod then error('object "'..ffi.string(mo.type)..'"('..k..') has an invalid quad type!') end
		drawingMethod(mo, x, y, GetImage(ffi.string(mo.sprite)), GetQuadArray(mo.quads))
	end
	local snow = particles.list[PARTICLE_SNOW]
	if snow then
		love.graphics.draw(snow.particle, -10, -10)
	end
	local rain = particles.list[PARTICLE_RAIN]
	if rain then
		love.graphics.draw(rain.particle, -10, -10)
	end
	local help = particles.list[PARTICLE_HELP]
	if help then
		local x = (centerx+help.x*tilesize)+(16*scale)
		local y = (centery+help.y*tilesize)+(16*scale)
		love.graphics.draw(help.particle, x, y, 0, scale)
	end
	love.graphics.pop()
	if debugmode and debugmode.camera and player then
		local playerx = centerx + player.x * tilesize
		local playery = centery + player.y * tilesize
		love.graphics.setColor(1, 0, 0, 1)
		love.graphics.rectangle("line", playerx, playery, tilesize, tilesize)
		love.graphics.rectangle("fill", playerx + tilesize / 2, playery + tilesize / 2, 1, 1)
		love.graphics.line(100, 0, 100, screenheight)
		love.graphics.line(screenwidth - 100, 0, screenwidth - 100, screenheight)
		love.graphics.line(0, 100, screenwidth, 100)
		love.graphics.line(0, screenheight - 100, screenwidth, screenheight - 100)
		love.graphics.setColor(1, 1, 1, 1)
	end
	scale = scale / GetScaleByScreen()
	if gamestate ~= "pause" and gamestate ~= "map settings" and gamestate ~= "assist mode" then
		love.graphics.setColor(1, 1, 1, (360%(math.min(math.max(leveltime, 240), 360))/120))
	else
		love.graphics.setColor(1, 1, 1, 0)
	end
	love.graphics.setShader()
	love.graphics.printf(gamemapname, 0, 50, screenwidth/2, "center", 0, 2, 2)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader()
	if wheelmoved > 0 and mouse.mode == "camera" then
		love.graphics.setColor(1, 1, 1, ((math.min(math.max(wheelmoved, 0), 60)%120)/60))
		love.graphics.printf("scale: "..scale, 0, screenheight-20, screenwidth, "center")
		wheelmoved = wheelmoved-1
		love.graphics.setColor(1, 1, 1, 1)
	end
end

local hudcoin = love.graphics.newImage("Sprites/hudcoin.png")
local hudcoinquads = {
	notgot = love.graphics.newQuad(1, 1, 8, 8, 40, 10),
	got = love.graphics.newQuad(11, 1, 8, 8, 40, 10),
	brightnotgot = love.graphics.newQuad(21, 1, 8, 8, 40, 10),
	brightgot = love.graphics.newQuad(31, 1, 8, 8, 40, 10),
}
local icons = love.graphics.newImage("Sprites/icons.png")
local iconsquads = GetQuads(4, icons)
local brownie = love.graphics.newImage("Sprites/brownie.png")
local girl = love.graphics.newImage("Sprites/girl.png")

local function DrawMenu(gs, prev)
	if not prev then
		menuButtons = {}
	end
	local gamestate = gs or gamestate
	if gamestate ~= laststate and statetimer < 0.999 then
		love.graphics.translate(0, screenwidth - ((1 -statetimer) * screenwidth))
		DrawMenu(laststate, true)
		love.graphics.origin()
		love.graphics.translate(0, (1 - statetimer) * screenwidth)
	end
	local wave
	if gamestate == "title" or gamestate == "select level" then
		wave = math.abs(math.sin(love.timer.getTime()))
	end
	if gamestate == "title" then
		love.graphics.draw(titlescreen, (screenwidth / 2) - 150, 50)
		love.graphics.setColor(1, 1, 1, wave)
		love.graphics.draw(titleglow, (screenwidth / 2) - 150, 50)
		love.graphics.setColor(1, 1, 1, 1)
	else
		love.graphics.printf(gamestate, 0, 50, screenwidth/2, "center", 0, 2, 2)
	end
	local ly = 140
	local x = (screenwidth/2)-225
	for i = 1,#menu[gamestate] do
		love.graphics.setColor(1, 1, 1, 1)
		if i == pointer then love.graphics.setColor(1, 1, 0, 1)
		elseif (gamestate == "select level" and i > lastmap and tonumber(menu[gamestate][i].name))
		or (gamestate == "assist mode" and menu[gamestate][1].value == 0 and i > 1 and i < #menu[gamestate]) then 
			love.graphics.setColor(1, 1, 1, 0.5)
		elseif gamestate == "settings" and i == #menu.settings-1 then
			love.graphics.setColor(1, 0, 0, 1)
		end
		local rectangle = screenwidth
		local y = (((#menu[gamestate] > 7 or (gamestate == "sound test" and i == 1)) and 200) or 290)+(30*(i-1))
		if #menu[gamestate] == 1 or (gamestate == "sound test" and i == 2) then
			y = 480
		end
		local value = menu[gamestate][i].value
		if value then
			rectangle = screenwidth-screenwidth/8
			local text = (i == pointer and "< "..menu[gamestate][i].values[value].." >") or menu[gamestate][i].values[value]
			love.graphics.printf(text, 0, y, screenwidth+screenwidth/5, "center")
		end
		if gamestate ~= "select level" then
			local name = menu[gamestate][i].name
			if (menu[gamestate][i].string or menu[gamestate][i].int) then
				name = name..(menu[gamestate][i].string or menu[gamestate][i].int)
			end
			if i == pointer and ((menu[gamestate][i].string and menu[gamestate][i].string:len() < 20)
			or (menu[gamestate][i].int and menu[gamestate][i].int:len() < 2)) then
				name = name.."_"
			end
			local width = font:getWidth(name);
			local x = rectangle / 2 - width / 2
			if not prev then
				menuButtons[i] = {x = x, y = y, width = x + width, height = y + font:getHeight()}
				if debugmode and debugmode.buttons then
					love.graphics.rectangle("line", x, y, width, font:getHeight())
				end
			end
			(i == pointer and AnimatedPrint or love.graphics.print)(name, x, y)
		else
			local unit = GetUnit(i)-1
			local offset = (unit >= 0 and unit) or 9
			local x = x+(50*offset)
			if i > 10 and GetUnit(i) == 1 then
				ly = ly + 50
				x = (screenwidth / 2) - 225
			end
			if menu[gamestate][i].name == "back" then
				local x = screenwidth / 2 - 24
				(i == pointer and AnimatedPrint or love.graphics.print)("back", x, 470)
				if not prev then
					menuButtons[i] = {x = x, y = 470, width = x + 48, height = 470 + font:getHeight()}
					if debugmode and debugmode.buttons then
						love.graphics.rectangle("line", x, 470, 48, font:getHeight())
					end
				end
			else
				local n = menu[gamestate][i].name
				love.graphics.print(n, x, ly)
				if not prev then
					local width = font:getWidth(n)
					menuButtons[i] = {x = x, y = ly, width = x + width, height = ly + font:getHeight()}
					if debugmode and debugmode.buttons then
						love.graphics.rectangle("line", x, ly, width, font:getHeight())
					end
				end
				local coin = coins[i-1]
				if coin then
					local quad = (coin.got and "got") or "notgot"
					local x = x + font:getWidth(n)
					love.graphics.draw(hudcoin, hudcoinquads[quad], x, ly)
					love.graphics.setColor(1, 1, 1, 1 - wave)
					love.graphics.draw(hudcoin, hudcoinquads["bright" .. quad], x, ly)
					love.graphics.setColor(1, 1, 1, 1)
				end
			end
		end
	end
	love.graphics.setColor(1, 1, 1, 1)
end

local function DrawMenuWithBG()
	local scale = math.max(screenwidth, screenheight) / 800
	local x = screenwidth / (scale * 4) - 200
	local y = screenheight / scale - 600
	love.graphics.draw(girl, x, y, 0, scale)
	love.graphics.draw(brownie, x + screenwidth / 2, y, 0, scale)
	DrawMenu()
end

local function DrawCoinHud(time)
	local coinsgot, coinstotal = coins.count()
	if coinstotal == 0 then return end
	love.graphics.draw(coins.sprite, coins.quads[math.floor((time%(#coins.quads*10))/10)+1], 10, screenheight-50)
	love.graphics.print(coinsgot.."/"..coinstotal, 50, screenheight-40)
end

local function DrawFlash()
	if menu.settings[7].value == 1 and flash > 0 then
		love.graphics.setColor(1, 1, 1, flash)
		love.graphics.rectangle("fill", 0, 0, screenwidth, screenheight)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

local wallDesc = "\nMost objects can't walk in this tile"
local floorDesc = "\nObjects can walk in this tile"
local pushDesc = "\nObjects in this tile will be pushed to the "
local falsepushDesc = "\nThis tile will do nothing, use the first frame of the pusher"
local spikeDesc = "\nObjects in this tile will be destroyed"

local function MirrorUpdate(x, y)
	if SearchObject(x, y) == player then
		sound.playSound("box.wav")
		if y == 15 then
			tilemap[15][30] = TILE_FLOOR1
			tilemap[6][2] = TILE_FLOOR1
			tilemap[6][30] = TILE_CUSTOM3
			tilemap[15][14] = TILE_CUSTOM3
			tilemap[15][2] = TILE_FLOOR1
			tilemap[15][18] = TILE_BLUESWITCH
			tilemap[6][18] = TILE_RIGHTPUSHER1
			tilemap[11][5] = TILE_SPIKEOFF
			tilemap[11][11] = TILE_SPIKEOFF
			tilemap[11][21] = TILE_SPIKEOFF
			tilemap[11][27] = TILE_SPIKEOFF
			tilemap[6][14] = TILE_SLIME
			tilemap[7][30] = TILE_UPPUSHER1
			CheckMap(TILE_REDWALLON, TILE_REDWALLOFF, TILE_BLUEWALLOFF, TILE_BLUEWALLON)
			UpdateTilemap()
		elseif y == 6 then
			tilemap[6][30] = TILE_FLOOR1
			tilemap[15][14] = TILE_FLOOR1
			tilemap[15][18] = TILE_FLOOR1
			tilemap[6][18] = TILE_FLOOR1
			tilemap[7][8] = TILE_SLIME
			tilemap[6][14] = TILE_FLOOR1
			tilemap[7][30] = TILE_FLOOR1
			tilemap[7][14] = TILE_LEFTPUSHER1
			tilemap[13][24] = TILE_CUSTOM3
			tilemap[14][8] = TILE_CUSTOM3
			UpdateTilemap()
		elseif y == 13 then
			tilemap[7][8] = TILE_FLOOR1
			tilemap[7][14] = TILE_FLOOR1
			tilemap[13][24] = TILE_FLOOR1
			tilemap[14][8] = TILE_FLOOR1
			tilemap[5][24] = TILE_FLOOR1
			tilemap[5][8] = TILE_FLOOR1
			UpdateTilemap()
			sound.playSound("lock.wav")
		end
		return true
	end
end

tilesets = {
	["bonus.png"] = { --BONUS LEVELS
		enemyquadtype = "none",
		rotatebridges = false,
		description = {
			[TILE_CUSTOM1] = "BUTTON\nyou aren't supposed to use this tileset btw",
			[TILE_CUSTOM2] = "CUSTOM GOAL\nif you just like the tiles I suggest you copy\nthe .png file from the .exe",
			[TILE_CUSTOM3] = "BUTTON?\nbut you're probably reading this from the source code, aren't you?"
		},
		collision = {
			[TILE_CUSTOM1] = function(mo, momx, momy)
				if momx == 0 and momy == 0 then return end
				if gamemap == -4 then
					for x = 10, 14 do
						SearchObject(x, 4).hp = 1
					end
					local readersprite = "Sprites/Bonuses/reader.png"
					local posmo = SpawnObject(readersprite, 10, 4, "dummy")
					SpawnObject(readersprite, 4, 12, "bfreader", nil, nil, nil, 0).var1 = posmo.key
				elseif gamemap == -5 then
					if mo.x == 13 and mo.y == 5 then
						local correct = {2, 2, 1, 2, 2, 2, 1, 2, 1, 1, 1, 2, 2, 1, 2, 1}
						for _, mmo in ipairs(objects) do
							if ffi.string(mmo.type) == "bimonitor" then
								local t = table.remove(correct)
								if mmo.frame ~= t then
									notification.setMessage("Wrong combination...")
									return
								end
							end
						end
						SetTile(13, 4, TILE_FLOOR1)
						sound.playSound("lock.wav")
					elseif mo.x == 4 and mo.y == 21 then
						local monitor = SearchObject(4, 20)
						if monitor.frame == 7 then
							RemoveObject(monitor)
							SetTile(4, 21, TILE_FLOOR1)
							messagebox.setMessage("Main riddle hint #1", "The first number is just half of this line's words.\nFor the second number just add 2 to this monitor.")
						else
							notification.setMessage("Wrong number...")
						end
					elseif mo.x == 22 and mo.y == 32 then
						local monitor = SearchObject(22, 31)
						if monitor.frame == 9 then
							RemoveObject(monitor)
							SetTile(22, 32, TILE_FLOOR1)
							messagebox.setMessage("Main riddle hint #2", "The last 2 numbers are both B.")
						else
							notification.setMessage("Wrong number...")
						end
					end
				elseif gamemap == -6 and mo == player then
					objects[4].frame = 10
					sound.playSound("box.wav")
				end
			end,
			[TILE_CUSTOM2] = function()
				gamestate = "bonus level complete!"
				pointer = 1
				sound.playSound("win.wav")
			end,
			[TILE_CUSTOM3] = function(mo)
				if gamemap == -1 then
					mo.x = math.abs(mo.x - 22) + mo.momx
					sound.playSound("box.wav")
				elseif gamemap == -3 then
					if mo == player or (mo.momx == 0 and mo.momy == 0) then return end
					IterateMap(TILE_CUSTOM3, MirrorUpdate)
				elseif gamemap == -5 then
					if mo.x == 22 and mo.y == 20 then
						messagebox.setMessage("Left riddle hint", "It blinks and doesn't stop\nSurely you have counted\nHow many times it's here?")
					elseif mo.x == 4 and mo.y == 31 then
						messagebox.setMessage("Right riddle hint", "It fades away every time\nbut only now changed shape\nyou'll have to run!")
						gamemapname = "8"
					end
				elseif gamemap == -6 then
					local line = tilemap[5]
					line[9] = TILE_DOWNPUSHER1
					line[10] = TILE_DOWNPUSHER1
					line[11] = TILE_DOWNPUSHER1
					line[12] = TILE_DOWNPUSHER1
					line[13] = TILE_DOWNPUSHER1
					line[14] = TILE_DOWNPUSHER1
					tilemap[18][7] = TILE_DOWNPUSHER1
					objects[4].frame = 10
					UpdateTilemap()
					sound.playSound("lock.wav")
				end
			end,
		},
		tile = {
			[TILE_CUSTOM1] = nil,
			[TILE_CUSTOM2] = nil,
			[TILE_CUSTOM3] = nil
		}
	},
	["forest.png"] = { --CHAPTER 1
		bridgeshardcolor = {0.7, 0.4, 0.1},
		description = {
			[TILE_CUSTOM1] = "UNUSED"..floorDesc,
			[TILE_CUSTOM2] = "UNUSED"..floorDesc,
			[TILE_CUSTOM3] = "UNUSED"..floorDesc
		},
		collision = {
			[TILE_CUSTOM1] = true,
			[TILE_CUSTOM2] = true,
			[TILE_CUSTOM3] = true
		},
		tile = {
			[TILE_CUSTOM1] = nil,
			[TILE_CUSTOM2] = nil,
			[TILE_CUSTOM3] = nil
		}
	},
	["frost.png"] = { --CHAPTER 2
		snow = true,
		enemyquadtype = "movement",
		keysprite = "Sprites/Chapter 2/key.png",
		bridgeshardcolor = {0.7, 0.7, 0.7},
		description = {
			[TILE_CUSTOM1] = "SNOWBALL".."\nA Snowball will spawn in this tile",
			[TILE_CUSTOM2] = "STICKS WALL"..wallDesc.."\nIf a Snowball rams this wall it will collapse",
			[TILE_CUSTOM3] = "SNOWMAN".."\nA Snowman will spawn in this tile"
		},
		collision = {
			[TILE_CUSTOM1] = true,
			[TILE_CUSTOM2] = function(mo)
				if mo.type == "snowball" then
					SetTile(mo.x, mo.y, TILE_FLOOR3)
					RemoveObject(mo)
				else return false end
			end,
			[TILE_CUSTOM3] = true
		},
		tile = {
			[TILE_CUSTOM1] = function(x, y)
				local snowsprite = "Sprites/Chapter 2/snowball.png"
				SpawnObject(snowsprite, x, y, "snowball", GetQuads(4, snowsprite), "position")
				SetTile(x, y, TILE_FLOOR3)
			end,
			[TILE_CUSTOM2] = nil,
			[TILE_CUSTOM3] = function(x, y)
				local snowmansprite = "Sprites/Chapter 2/snowman.png"
				SpawnObject(snowmansprite, x, y, "snowman", GetDirectionalQuads(snowmansprite))
				SetTile(x, y, TILE_FLOOR3)
			end,
		}
	},
	["castle.png"] = { --CHAPTER 3
		thunder = true,
		rain = {0.3, 0.5, 0.54, 1},
		enemyquadtype = "movement",
		keysprite = "Sprites/Chapter 3/key.png",
		description = {
			[TILE_CUSTOM1] = "+15\nAdds 15 seconds to the timer",
			[TILE_CUSTOM2] = "BOX\nWill spawn a pushable box in this tile",
			[TILE_CUSTOM3] = "BOX CONTAINER\nIf all of these tiles are covered by boxes the level will be completed"
		},
		collision = {
			[TILE_CUSTOM1] = true,
			[TILE_CUSTOM2] = true,
			[TILE_CUSTOM3] = function(mo)
				if mo.type == "box" and mo.var2 then
					mo.var2 = false
					sound.playSound("box.wav")
					local all = true
					IterateMap(TILE_CUSTOM3, function(x, y)
						local mo = SearchObject(x, y)
						if not mo or mo.type ~= "box" then all = false end
					end)
					if all then EndLevel() end
				end
			end
		},
		tile = {
			[TILE_CUSTOM1] = function(x, y)
				timer = timer + 15
				SetTile(x, y, TILE_FLOOR1)
			end,
			[TILE_CUSTOM2] = function(x, y)
				local boxsprite = "Sprites/Chapter 3/box.png"
				SpawnObject(boxsprite, x, y, "box", GetQuads(5, boxsprite), "hp", nil, 5)
				SetTile(x, y, TILE_FLOOR2)
			end,
			[TILE_CUSTOM3] = nil
		}
	},
	["factory.png"] = { --CHAPTER 4
		dark = true,
		bridgeshardcolor = {0.6, 0.6, 0.6},
		keysprite = "Sprites/Chapter 4/key.png",
		description = {
			[TILE_CUSTOM1] = "MASTER BUTTON\nPressing all of the red ones will open all locks\npressing a blue one will reset them all",
			[TILE_CUSTOM2] = "METAL BOX\nCan be pushed by the player and will break any miniman or spikes it finds.",
			[TILE_CUSTOM3] = "MINIMAN\nSpawns a miniman which will constantly fire when the player is in range"
		},
		collision = {
			[TILE_CUSTOM1] = true,
			[TILE_CUSTOM2] = true,
			[TILE_CUSTOM3] = true
		},
		tile = {
			[TILE_CUSTOM1] = function(x, y)
				local masterbuttonsprite = "Sprites/Chapter 4/master button.png"
				SpawnObject(masterbuttonsprite, x, y, "masterbutton", GetQuads(3, masterbuttonsprite), "frame")
			end,
			[TILE_CUSTOM2] = function(x, y)
				SpawnObject("Sprites/Chapter 4/metal box.png", x, y, "metalbox")
				SetTile(x, y, TILE_FLOOR2)
			end,
			[TILE_CUSTOM3] = function(x, y)
				local minimansprite = "Sprites/Chapter 4/miniman.png"
				SpawnObject(minimansprite, x, y, "miniman", GetDirectionalQuads(minimansprite))
				SetTile(x, y, TILE_FLOOR1)
			end
		}
	},
	["superdark.png"] = { --SUPERDARK SECRET ROOM
		dark = true,
		description = {
			[TILE_CUSTOM1] = "You should not use this tileset.",
			[TILE_CUSTOM2] = "Just use factory.png",
			[TILE_CUSTOM3] = "But you're probably reading this from the source code though, right?"
		},
		collision = {
			[TILE_CUSTOM1] = true,
			[TILE_CUSTOM2] = true,
			[TILE_CUSTOM3] = function(mo)
				local superdark = menu.extras[EXTRA_SUPERDARK]
				superdark.name = "superdark"
				superdark.value = 0
				superdark.values = valuesnames
				tilemap[mo.y][mo.x] = TILE_CUSTOM2
				sound.playSound("lock.wav")
				messagebox.setMessage("SuperDark mode unlocked!", [[
When enabled superdark mode will make all levels much darker
It will be impossible to see far away
Good luck!
(SuperDark mode can be enabled in the extras menu)]])
			end
		},
		tile = {
			[TILE_CUSTOM1] = function(x, y)
				local masterbuttonsprite = "Sprites/Chapter 4/master button.png"
				SpawnObject(masterbuttonsprite, x, y, "masterbutton", GetQuads(3, masterbuttonsprite), "frame")
			end,
			[TILE_CUSTOM2] = nil,
			[TILE_CUSTOM3] = function(x, y)
				if menu.extras[EXTRA_SUPERDARK].name == "superdark" then
					SetTile(x, y, TILE_CUSTOM2)
				end
			end
		}
	}
}

local tileDescriptions = {
	[TILE_WALL1] = "WALL 1"..wallDesc,
	[TILE_WALL2] = "WALL 2"..wallDesc,
	[TILE_WALL3] = "WALL 3"..wallDesc,
	[TILE_WALL4] = "WALL 4"..wallDesc,
	[TILE_WALL5] = "WALL 5"..wallDesc,
	[TILE_WALL6] = "WALL 6"..wallDesc,
	[TILE_WALL7] = "WALL 7"..wallDesc,
	[TILE_WALL8] = "WALL 8"..wallDesc,
	[TILE_WALL9] = "WALL 9"..wallDesc,
	[TILE_FLOOR1] = "FLOOR 1"..floorDesc,
	[TILE_FLOOR2] = "FLOOR 2"..floorDesc,
	[TILE_FLOOR3] = "FLOOR 3"..floorDesc,
	[TILE_LOCK] = "LOCK"..floorDesc.." if the lock is open\nA key is needed to open the lock",
	[TILE_KEY] = "KEY\nA key will spawn in this tile"..floorDesc,
	[TILE_REDSWITCH] = "RED SWITCH"..floorDesc.."\nIf pressed will turn on the blue tiles and turn off the red ones",
	[TILE_BLUESWITCH] = "BLUE SWITCH"..floorDesc.."\nIf pressed will turn on the red tiles and turn off the blue ones",
	[TILE_START] = "START"..floorDesc..", The player will spawn in this tile\nevery map should have 1 start tile",
	[TILE_GOAL] = "GOAL\nIf the player reaches this tile the level will be completed"..floorDesc,
	[TILE_REDWALLON] = "RED WALL (on)"..wallDesc.."\nwalking on a red switch will set this tile to off",
	[TILE_BLUEWALLON] = "BLUE WALL (on)"..wallDesc.."\nwalking on a blue switch will set this tile to off",
	[TILE_REDWALLOFF] = "RED WALL (off)"..floorDesc.."\nwalking on a blue switch will set this tile to on",
	[TILE_BLUEWALLOFF] = "BLUE WALL (off)"..floorDesc.."\nwalking on a red switch will set this tile to on",
	[TILE_AFLOOR1] = "ANIMATED FLOOR\nThis tile will alternate between itself and the next tile"..floorDesc,
	[TILE_AFLOOR2] = "ANIMATED FLOOR\nThe animation will only work with the previous tile"..floorDesc,
	[TILE_RIGHTPUSHER1] = "RIGHT PUSHER"..pushDesc.."right",
	[TILE_RIGHTPUSHER2] = "RIGHT PUSHER"..falsepushDesc,
	[TILE_RIGHTPUSHER3] = "RIGHT PUSHER"..falsepushDesc,
	[TILE_LEFTPUSHER1] = "LEFT PUSHER"..pushDesc.."left",
	[TILE_LEFTPUSHER2] = "LEFT PUSHER"..falsepushDesc,
	[TILE_LEFTPUSHER3] = "LEFT PUSHER"..falsepushDesc,
	[TILE_UPPUSHER1] = "UP PUSHER"..pushDesc.."up",
	[TILE_UPPUSHER2] = "UP PUSHER"..falsepushDesc,
	[TILE_UPPUSHER3] = "UP PUSHER"..falsepushDesc,
	[TILE_DOWNPUSHER1] = "DOWN PUSHER"..pushDesc.."down",
	[TILE_DOWNPUSHER2] = "DOWN PUSHER"..falsepushDesc,
	[TILE_DOWNPUSHER3] = "DOWN PUSHER"..falsepushDesc,
	[TILE_SPIKEON] = "MOVING SPIKES (on)"..spikeDesc.."\nthis tile will alternate between on and off",
	[TILE_SPIKEOFF] = "MOVING SPIKES (off)"..spikeDesc.."\nthis tile will alternate between off and on",
	[TILE_SPIKE] = "SPIKES"..spikeDesc,
	[TILE_BRIDGE] = "BRIDGE\nIf an object walks on a bridge it will crack",
	[TILE_CRACKEDBRIDGE] = "CRACKED BRIDGE\nIf an object walks on a cracked bridge it will collapse",
	[TILE_SLIME] = "SLIME\nObjects that walk on this tile will halt",
	[TILE_CHASM1] = "CHASM 1"..spikeDesc,
	[TILE_CHASM2] = "CHASM 2"..spikeDesc,
	[TILE_ENEMY] = "ENEMY\nAn enemy will spawn in this tile",
	[TILE_CUSTOM1] = "You're not supposed to see this message",
	[TILE_CUSTOM2] = "You're not supposed to see this message",
	[TILE_CUSTOM3] = "You're not supposed to see this message"
}

local function DrawPage(page)
	local width, height = page:getDimensions()
	local scale = GetScaleByScreen()
	love.graphics.draw(page, screenwidth / 2 - (width * scale) / 2, screenheight / 2 - (height * scale) / 2, nil, scale)
end

local function DrawMenuAboveTilemap()
	love.graphics.setColor(1, 1, 1, 0.5)
	DrawTilemap()
	love.graphics.setColor(1, 1, 1, 1)
	DrawMenu()
end

local drawModes = {
	ingame = function()
		particles.update(love.timer.getDelta())
		DrawTilemap()
		if not customEnv and gamemap == 0 then
			love.graphics.print("CONTROLS:\nWASD/ARROWS: Move\nR: Reset map\nLEFT CLICK+DRAG: Move camera\nMOUSE WHEEL: Zoom in/out\nESC: Pause", math.min((leveltime*1.5)-100, 10), 100)
		end
		if menu.settings[3].value == 1 then
			local tseconds = (seconds < 10 and "0"..seconds) or tostring(seconds)
			local tminutes = (minutes < 10 and "0"..minutes) or tostring(minutes)
			local tframes = (frames < 10 and "0"..frames) or tostring(frames)
			local time = hours..":"..tminutes.."."..tseconds
			love.graphics.print(time, 10, screenheight-20)
			love.graphics.print(tframes, font:getWidth(time)+12, screenheight-16, 0, 0.8)
		end
		if particles.main then love.graphics.draw(particles.main, -20, -20) end
		if not player then
			AnimatedPrint("Press [R] to retry", screenwidth / 2 - 105, 20, 8)
		end
		if timer > 0 and player then
			love.graphics.printf("Hurry!\n"..timer, 0, screenheight - 60, screenwidth, "center")
		end
		if coins.hudtimer > 0 then
			love.graphics.setColor(1, 1, 1, ((math.min(math.max(coins.hudtimer, 0), 60)%160)/60))
			DrawCoinHud(leveltime)
			love.graphics.setColor(1, 1, 1, 1)
		end
		DrawFlash()
	end,
	title = DrawMenuWithBG,
	pause = DrawMenuAboveTilemap,
	settings = DrawMenuWithBG,
	credits = function()
		local fifteentens = screenwidth / 1.5
		local third = screenwidth / 3
		DrawMenuWithBG()
		local a = math.sin(love.timer.getTime() * 2) / 2
		love.graphics.setColor(1, a, a)
		love.graphics.printf([[
-Rosy.iso-
Coder
Mapper
Story writer]], 0, 175, fifteentens, "center")
		love.graphics.setColor(a, 1, a)
		love.graphics.printf([[
-MAKYUNI-
Music composer
Spriter]], screenwidth - fifteentens, 175, fifteentens, "center") 
		love.graphics.setColor(0.8, a, 0.8)
		love.graphics.printf([[
-Fele88-
Beta tester
Mapper]], screenwidth - third, 355, third, "center")
		love.graphics.setColor(a, 0.7, 1)
		love.graphics.printf([[
-Dusty-
Characters designer
Artist]], 0, 355, screenwidth, "center")
		love.graphics.setColor(a, 0.7, a)
		love.graphics.printf([[
-Ciaccy-
Beta tester]], 0, 355, third, "center")
	end,
	["select level"] = function()
		DrawMenuWithBG()
		if not customEnv then
			for i = 1, 4 do
				if lastmap > (i - 1) * 10 then
					love.graphics.draw(icons, iconsquads[i], (screenwidth / 2) - 275, 135 + 50 * (i - 1))
				end
			end
		end
		love.graphics.origin()
		DrawCoinHud(love.timer.getTime() * 50)
	end,
	["level editor"] = DrawMenuWithBG,
	editing = function()
		DrawTilemap()
		if not hidecontrols then
			local controls = "CONTROLS:"
			if mouse.mode == "editing" then
				controls = controls.."\nLEFT CLICK: Place tile\nRIGHT CLICK: Delete tile\nMIDDLE CLICK: Select tile\nMOUSE WHEEL: Change tile\nWASD/ARROWS: Move map\nTAB: Change mode\nC: Hide controls\nESC: Map settings"
			else
				controls = controls.."\nLEFT CLICK+DRAG: Move camera\nMOUSE WHEEL: Zoom in/out\nTAB: Change mode\nC: Hide controls\nESC: Map settings"
			end
			love.graphics.print(controls, screenwidth-math.min(leveltime*2, 300 + ((mouse.mode == "editing" and 0) or 50)), 10)
		end
		local centerx = GetStartX()
		local centery = GetStartY()
		scale =  scale * GetScaleByScreen()
		local x = centerx+32*scale
		local y = centery+32*scale
		local xlen = (math.floor((mapwidth*32*scale)/mapwidth) * mapwidth)
		local ylen = (math.floor((mapheight*32*scale)/mapheight) * mapheight)
		love.graphics.rectangle("line", x, y, xlen, ylen)
		scale = scale / GetScaleByScreen()
		love.graphics.print(mouse.mode..((mouse.mode == "editing" and " x:"..mouse.x.." y:"..mouse.y) or ""), 10, screenheight-20)
		local tilesetsprite = GetImage(GetTilesetPath().."Tiles/"..tilesetname)
		if wheelmoved > 0 and mouse.mode == "editing" then
			love.graphics.setColor(1, 1, 1, ((math.min(math.max(wheelmoved, 0), 60)%120)/60))
			local tilesetx = screenwidth/15
			local tilesety = screenheight/15
			love.graphics.draw(tilesetsprite, tilesetx, tilesety)
			local x = (tilesetx-34)+34*(((mouse.tile%3) > 0 and mouse.tile%3) or 3)
			local y = tilesety+34*(math.floor(mouse.tile/3.01))
			love.graphics.rectangle("line", x, y, 34, 34)
			if mouse.tile >= TILE_CUSTOM1 then
				tileDescriptions[TILE_CUSTOM1] = tilesets[tilesetname].description[TILE_CUSTOM1]
				tileDescriptions[TILE_CUSTOM2] = tilesets[tilesetname].description[TILE_CUSTOM2]
				tileDescriptions[TILE_CUSTOM3] = tilesets[tilesetname].description[TILE_CUSTOM3]
			end
			love.graphics.printf(tileDescriptions[mouse.tile], 0, screenheight-(tilesety*2), screenwidth, "center")
			wheelmoved = wheelmoved-1
			love.graphics.setColor(1, 1, 1, 1)
		end
		if mouse.mode == "editing" and mouse.boundsCheck() then
			love.graphics.setColor(1, 1, 1, 0.5)
			scale = scale * GetScaleByScreen()
			local x = centerx+mouse.x*math.floor(32*scale)
			local y = centery+mouse.y*math.floor(32*scale)
			love.graphics.draw(tilesetsprite, quads[mouse.tile], x, y, 0, scale)
			scale = scale / GetScaleByScreen()
		end
	end,
	["map settings"] = function()
		love.graphics.setColor(1, 1, 1, 0.5)
		DrawTilemap()
		local centerx = GetStartX()
		local centery = GetStartY()
		scale = scale * GetScaleByScreen()
		local x = centerx + 32 * scale
		local y = centery + 32 * scale
		local xlen = math.floor((mapwidth*32*scale)/mapwidth)*mapwidth
		local ylen = math.floor((mapheight*32*scale)/mapheight)*mapheight
		love.graphics.rectangle("line", x, y, xlen, ylen)
		scale = scale / GetScaleByScreen()
		love.graphics.setColor(1, 1, 1, 1)
		DrawMenu()
	end,
	["create map"] = DrawMenuWithBG,
	["swap maps"] = DrawMenuWithBG,
	["the end"] = function()
		local n = "\n"
		local msg =
		"This is the end of the Beta"..n..
		"Thanks for playing!"..n..n..
		"Looking for something else to do?"..n..
		"Try the level editor!"..n..n..
		"see you next update!"
		love.graphics.printf(msg, 0, 120, screenwidth, "center")
		DrawMenuWithBG()
	end,
	["sound test"] = function()
		DrawMenuWithBG()
		love.graphics.printf(sound.soundtest[sound.soundtestpointer].subtitle, 0, 230, screenwidth, "center")
		love.graphics.printf("By: "..sound.soundtest[sound.soundtestpointer].creator, 0, 260, screenwidth, "center")
		if sound.musicname == sound.soundtest[sound.soundtestpointer].filename then love.graphics.setColor(1, 1, 0, 1) end
		love.graphics.line((screenwidth/2)-150, 360, (screenwidth/2)+150, 360)
		if sound.music then
			love.graphics.circle("line", ((screenwidth/2)-150)+(sound.music:tell()/sound.music:getDuration())*300, 360, 5)
		end
		love.graphics.setColor(1, 1, 1, 1)
		local gotmusic = 0
		local totmusic = 0
		for k, music in ipairs(sound.soundtest) do
			totmusic = totmusic + 1
			gotmusic = (lastmap >= (music.require or 0) and gotmusic + 1) or gotmusic
		end
		love.graphics.origin()
		love.graphics.print("Unlocked music: "..gotmusic.."/"..totmusic, 10, screenheight - 20)
	end,
	["select mod"] = function()
		DrawMenuWithBG()
		local mods = #menu["select mod"] - 1
		if mods == 0 then
			love.graphics.setColor(1, 0, 0, 1)
		else
			love.graphics.setColor(1, 1, 0, 1)
		end
		love.graphics.printf(mods.." mods found", 0, 90, screenwidth, "center")
	end,
	addons = DrawMenuWithBG,
	extras = function()
		DrawMenuWithBG()
		love.graphics.origin()
		DrawCoinHud(love.timer.getTime() * 50)
	end,
	["bonus levels"] = DrawMenuWithBG,
	["bonus level complete!"] = function()
		love.graphics.setColor(1, 1, 1, 0.5)
		DrawTilemap()
		love.graphics.setColor(1, 1, 1, 1)
		DrawMenu()
		local tseconds = (seconds < 10 and "0"..seconds) or tostring(seconds)
		local tminutes = (minutes < 10 and "0"..minutes) or tostring(minutes)
		love.graphics.printf("Completed in "..hours..":"..tminutes.."."..tseconds, 0, 90, screenwidth, "center")
	end,
	["name him"] = DrawMenuWithBG,
	["the story begins"] = function()
		DrawMenuWithBG()
		love.graphics.origin()
		DrawFlash()
	end,
	cutscene = function()
		cutscenes.texttime = cutscenes.texttime + 1
		if cutscenes.num == 1 then
			love.graphics.setColor(1, 1, 1, cutscenes.texttime / 10)
		end
		DrawPage(GetImage("Sprites/Cutscenes/" .. cutscenes.num .. "/" .. cutscenes.page .. ".png"))
		local text = cutscenes.current[cutscenes.page]:sub(0, cutscenes.texttime)
		local lines = 1
		for _ in text:gmatch("\n") do
			lines = lines + 0.5
		end
		love.graphics.printf(text, 0, screenheight - 40 * lines, screenwidth, "center")
	end,
	["select cutscene"] = function()
		if pointer < #menu["select cutscene"] then
			DrawPage(GetImage("Sprites/Cutscenes/" .. pointer .. "/1.png"))
		end
		DrawMenu()
	end,
	["cutscene selected"] = function()
		DrawPage(GetImage("Sprites/Cutscenes/" .. pointer .. "/1.png"))
		DrawMenu()
		love.graphics.origin()
		DrawFlash()
	end,
	["assist mode"] = DrawMenuAboveTilemap,
}
drawModes.chaptercomplete = drawModes.ingame

function debug.collectInfo()
	local count = collectgarbage("count")
	local debuginfo = "FPS: "..tostring(love.timer.getFPS()).."\nMemory: "..count.."\nhis name: "..hisname..
	"\nGamemap: "..gamemap.."\nLastmap: "..lastmap.."\nGamestate: "..gamestate.."\nLaststate: "..laststate.."\nModded: "..(customEnv and "true" or "false").."\n"
	debuginfo = debuginfo.."\ntile: "..tostring(mouse.tile).."\n"..
	"mode: "..tostring(mouse.mode).."\n"..
	"scale: "..tostring(scale).."\n"..
	"fullscreen scale: "..tostring(GetScaleByScreen()).."\n"..
	"X: "..tostring(mouse.x).."\n"..
	"Y: "..tostring(mouse.y).."\n"..
	"camera X: "..tostring(mouse.camerax).."\n"..
	"camera Y: "..tostring(mouse.cameray)..
	"\nScreen X: "..tostring(love.mouse.getX())..
	"\nScreen Y: "..tostring(love.mouse.getY())..
	"\nScreen width: "..tostring(screenwidth)..
	"\nScreen height: "..tostring(screenheight).."\n"
	if gamestate == "ingame" or gamestate == "pause" or gamestate == "editing" then
		debuginfo = debuginfo.."\nMap:\nLeveltime: "..leveltime..
		"\nFrametime: "..frametime..
		"\nTimer: "..timer..
		"\nFlash: "..flash..
		"\nDarkness: "..darkness..
		"\nMap width: "..mapwidth..
		"\nMap height: "..mapheight..
		"\nTileset: "..tilesetname..
		"\nStart X: "..GetStartX()..
		"\nStart Y: "..GetStartY().."\n"
		local objectsinfo = "\nObjects:\n"
		for k, mo in pairs(objects) do
			objectsinfo = objectsinfo..ffi.string(mo.type).." hp: "..mo.hp.." x:"..mo.x.."("..mo.momx..") y:"..mo.y.."("..mo.momy..") d:"..mo.direction.."("..ffi.string(mo.quadtype)..") k:"..mo.key.."("..k..")\n"
		end
		if objectsinfo == "\nObjects:\n" then objectsinfo = "" end
		debuginfo = debuginfo..objectsinfo
		if #voids > 0 then
			debuginfo = debuginfo.."Empty keys: "
			for k, v in ipairs(voids) do
				debuginfo = debuginfo..v.." "
			end
			debuginfo = debuginfo.."\n"
		end
	end
	if #sound.list > 0 then
		local sounds = ""
		for k, sound in pairs(sound.list) do
			if sound:isPlaying() then
				sounds = sounds..k.." "
			end
		end
		if sounds ~= "" then
			debuginfo = debuginfo.."\nSounds:".."\n"..sounds.."\n"
		end
		if sounds == "1 2 3 4 5 6 7 8 9 10" then
			debuginfo = debuginfo.."\nFull!\n"
		end
	end
	if #particles.list > 0 then
		local particlelist = ""
		for k, particle in pairs(particles.list) do
			if particle.particle:getCount() > 0 then
				particlelist = particlelist..k.." "
			end
		end
		if particlelist ~= "" then
			debuginfo = debuginfo.."\nParticles:".."\n"..particlelist.."\n"
		end
		if particlelist == "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20" then
			debuginfo = debuginfo.."\nFull!\n"
		end
	end
	if sound.music and sound.music:isPlaying() then
		debuginfo = debuginfo.."\nMusic:".."\n"..
		sound.musicname.."\n"..
		sound.music:tell().."/"..sound.music:getDuration().."\n"
	end
	local scale = 0.7
	local i = 0
	for w in debuginfo:gmatch("\n") do
		i = i+1
	end
	if i > 38 and not love.window.getFullscreen() then scale = 0.5 end
	return debuginfo, count, scale
end

function love.draw()
	menuButtons = nil
	love.graphics.setColor(1, 1, 1, 1);
	(assert(drawModes[gamestate], "invalid gamestate!"))()
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1, 1)
	if not debugmode and menu.settings[1].value == 1 then
		love.graphics.print("FPS: "..tostring(math.min(love.timer.getFPS(), 60)), 10, 10)
	elseif debugmode and debugmode.gameinfo then
		local debuginfo, count, scale = debug.collectInfo()
		if love.timer.getFPS() < 10 or count > 1499 then
			love.graphics.setColor(1, 0, 0, 1)
		else
			love.graphics.setColor(1, 1, 0, 1)
		end
		love.graphics.print(debuginfo, 10, 10, 0, scale)
		love.graphics.setColor(1, 1, 1, 1)
	end
	if debugmode then
		if debugmode.graphics then
			local graphicinfo = ""
			local rendererInfo = {love.graphics.getRendererInfo()}
			for k, v in ipairs(rendererInfo) do
				graphicinfo = graphicinfo..v.."\n"
			end
			graphicinfo = graphicinfo.."\n"
			for k, v in pairs(love.graphics.getStats()) do
				if k ~= "canvases" and k ~= "canvasswitches" then
					graphicinfo = graphicinfo..k..": "..v.."\n"
				end
			end
			love.graphics.setColor(1, 1, 0, 1)
			love.graphics.printf(graphicinfo, 0, 10, screenwidth, "right")
			love.graphics.setColor(1, 1, 1, 1)
		end
		if debugmode.cache then
			love.graphics.setColor(1, 1, 0, 1)
			local cacheinfo, scale = GetCacheInfo()
			love.graphics.print(cacheinfo, 10, 10, 0, scale)
			love.graphics.setColor(1, 1, 1, 1)
		end
	end
	love.graphics.printf(VERSION, 0, screenheight-20, screenwidth, "right")
	if saver then
		love.graphics.printf("Saving...", 0, screenheight-40, screenwidth, "right")
	elseif debugmode then
		love.graphics.setColor(1, 1, 0, 1)
		love.graphics.printf("debug mode", 0, screenheight-40, screenwidth, "right")
		love.graphics.setColor(1, 1, 1, 1)
	end
	if notification.timer > 0 then
		love.graphics.setColor(1, 1, 1, ((math.min(math.max(notification.timer, 0), 60) % 120) / 60))
		love.graphics.print(notification.text, 10, 45)
		love.graphics.setColor(1, 1, 1, 1)
		notification.timer = notification.timer - 1
	end
	if messagebox.show then
		love.graphics.setColor(0, 0, 0, 0.5)
		love.graphics.rectangle("fill", 0, 0, screenwidth, screenheight)
		local increase = math.abs(math.sin(love.timer.getTime()) / 5)
		local width = ((screenwidth / 2) - (messagebox.width / 2)) - 10
		local height = (screenheight / 2) - (messagebox.height / 2)
		love.graphics.setColor(0.7 + increase, 0, (messagebox.error and 0) or (0.5 + increase), 1)
		love.graphics.rectangle("fill", width, height, messagebox.width + 20, messagebox.height + 20)
		love.graphics.setColor(0.9 + increase, 0, (messagebox.error and 0) or (0.7 + increase), 1)
		love.graphics.rectangle("line", width, height, messagebox.width + 20, messagebox.height + 20)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.printf(messagebox.title, 0, height + 10, screenwidth / 1.5, "center", 0, 1.5)
		love.graphics.printf(messagebox.contents, 0, height + 50, screenwidth, "center")
		love.graphics.printf("(press any button to close this)", 0, height + messagebox.height, screenwidth / 0.7, "center", 0, 0.7)
	end
	if debugmode then
		lovebug.draw()
		love.graphics.setFont(font)
	end
end

function love.resize(width, height)
	screenwidth = width
	screenheight = height
	if #tilemap > 0 then
		UpdateTilemap()
	end
	if debugmode then
		lovebug.updateWindow()
	end
end

function love.quit()
	SaveSettings()
	SaveData()
	if discord.loaded then
		discord.shutdown()
	end
end