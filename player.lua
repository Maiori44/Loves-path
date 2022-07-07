local sound = require "music"
local particles = require "particles"
local nativefs = require "nativefs"
local cutscenes = require "cutscenes"
local sound = require "music"

local rainbowSecret = {
	input = {},
	needed = {"up", "up", "down", "down", "left", "right", "left", "right", "b", "a"}
}

hidecontrols = false

local debugOptions = {
	"Game info",
	"Cancel",
	escapebutton = 1
}

local function SaveScreenshot(imagedata)
	if not love.filesystem.getInfo("Source/Screenshots", "directory") then
		nativefs.createDirectory("Screenshots")
	end
	local date = os.date("%Y%m%d%H%M%S")..".png"
	nativefs.write("Screenshots/"..date, imagedata:encode("png"))
	notification.setMessage("Sreenshot saved as:\n"..date)
end

local function GetLSMax(cmenu)
	return math.min((debugmode and 255) or lastmap, #cmenu - 1)
end

local function LSCheck(cmenu, max)
	if pointer < 1 or pointer > #cmenu or pointer > max then
		pointer = #cmenu
	end
end

local function MoveTilemap(momx, momy)
	local newmap = {}
	for y = 1, mapheight do
		newmap[y] = newmap[y] or {}
		for x = 1, mapwidth do
			local newy = y + momy
			local newline = newmap[newy]
			if not newline and newy <= mapheight and newy > 0 then
				newmap[newy] = {}
				newline = newmap[newy]
			end
			local newx = x + momx
			if newline and newx <= mapwidth and newx > 0 then
				newline[newx] = tilemap[y][x]
			end
			newmap[y][x] = newmap[y][x] or TILE_EMPTY
		end
	end
	tilemap = newmap
	UpdateTilemap()
end

local functonInputs = {
	__index = {
		f8 = function()
			love.graphics.captureScreenshot(SaveScreenshot)
		end
	}
}

local menuInputs = setmetatable({
	up = function(cmenu)
		pointer = pointer - 1
		if pointer == 0 then pointer = #cmenu end
		sound.playSound("menu_move.wav")
	end,
	down = function(cmenu)
		pointer = pointer + 1
		if pointer > #cmenu then pointer = 1 end
		sound.playSound("menu_move.wav")
	end,
	["return"] = function(cmenu)
		local selected = cmenu[pointer]
		if selected.state then
			ChangeGamestate(selected.state)
			pointer = 1
			sound.playSound("menu_select.wav")
		elseif selected.func then
			selected.func(menu[gamestate][pointer])
			sound.playSound("menu_select.wav")
		end
	end,
	escape = function(cmenu)
		local pback = cmenu[#cmenu]
		if pback.name == "back" then
			if pback.state then
				ChangeGamestate(pback.state)
				pointer = 1
			elseif pback.func then
				pback.func()
			end
			sound.playSound("menu_back.wav")
		end
	end,
	right = function(cmenu)
		local setting = cmenu[pointer]
		if not setting.value then return end
		setting.value = (setting.value + 1) % (#setting.values + 1)
		if cmenu[pointer].func then
			cmenu[pointer].func(setting)
		end
		sound.playSound("menu_move.wav")
	end,
	left = function(cmenu)
		local setting = cmenu[pointer]
		if not setting.value then return end
		setting.value = (setting.value == 0 and #setting.values) or setting.value - 1
		if cmenu[pointer].func then
			cmenu[pointer].func(setting)
		end
		sound.playSound("menu_move.wav")
	end,
	backspace = function(cmenu)
		local setting = cmenu[pointer]
		if setting.int and utf8.len(setting.int) > 0 then
			setting.int = setting.int:sub(1, utf8.len(setting.int) - 1)
		elseif setting.string and utf8.len(setting.string) > 0 then
			local byteoffset = utf8.offset(setting.string, -1)
			if byteoffset then
				setting.string = setting.string:sub(1, byteoffset - 1)
			end
		end
	end,
}, functonInputs)

local defaultInputs = {__index = menuInputs}

local cameraInputs = {
	__index = setmetatable({
		["+"] = function()
			scale = math.min(scale + 0.1, 2)
			mouse.mode = "camera"
			wheelmoved = 120
			UpdateTilemap()
		end,
		["-"] = function()
			scale = math.min(scale - 0.1, 2)
			mouse.mode = "camera"
			wheelmoved = 120
			UpdateTilemap()
		end
	}, functonInputs)
}

local inputModes = {
	cutscene = function()
		if cutscenes.texttime >= cutscenes.current[cutscenes.page]:len() then
			cutscenes.page = cutscenes.page + 1
			cutscenes.texttime = 0
			if cutscenes.page > #cutscenes.current then
				gamestate = cutscenes.nextgamestate
				sound.setMusic(cutscenes.prevmusic)
				if cutscenes.num > 1 and gamestate == "ingame" then
					lastmap = lastmap + 1
					EndLevel()
				end
			end
		else
			cutscenes.texttime = cutscenes.current[cutscenes.page]:len()
		end
	end,
	title = function(key)
		table.insert(rainbowSecret.input, key)
		if rainbowSecret.input[#rainbowSecret.input] ~= rainbowSecret.needed[#rainbowSecret.input] then
			rainbowSecret.input = {}
		end
		if #rainbowSecret.input == 10 then
			rainbowmode = not rainbowmode
			rainbowSecret.input = {}
		end
		local func = menuInputs[key]
		if func then
			func(menu.title)
		end
	end,
	ingame = setmetatable({
		r = RestartMap,
		escape = function()
			gamestate = "pause"
			pointer = 1
			sound.reset()
			sound.playSound("menu_back.wav")
		end,
		space = function()
			if not player then return end
			particles.spawnHelp(player.x, player.y)
		end,
		left = function()
			if not player then return end
			player.fmomx = -1
			player.fmomy = 0
			player.ftime = 5
		end,
		a = "left",
		right = function()
			if not player then return end
			player.fmomx = 1
			player.fmomy = 0
			player.ftime = 5
		end,
		d = "right",
		up = function()
			if not player then return end
			player.fmomx = 0
			player.fmomy = -1
			player.ftime = 5
		end,
		w = "up",
		down = function()
			if not player then return end
			player.fmomx = 0
			player.fmomy = 1
			player.ftime = 5
		end,
		s = "down",
	}, cameraInputs),
	editing = setmetatable({
		c = function()
			hidecontrols = not hidecontrols
		end,
		escape = function()
			gamestate = "map settings"
			pointer = 1
			local settings = menu["map settings"]
			settings[1].string = gamemapname
			settings[2].value = 0
			settings[3].value = 0
			settings[4].int = tostring(mapwidth)
			settings[5].int = tostring(mapheight)
			for k, v in ipairs(possibleTilesets) do
				if tilesetname == v then
					settings[2].value = k
					break
				end
			end
			for k, v in ipairs(possibleMusic) do
				if sound.musicname == v then
					settings[3].value = k
					break
				end
			end
			sound.playSound("menu_back.wav")
		end,
		tab = function()
			mouse.mode = (mouse.mode == "camera" and "editing") or "camera"
			wheelmoved = 0
		end,
		left = function()
			for y = 1, mapheight do
				if tilemap[y][1] ~= TILE_EMPTY then
					notification.setMessage("Can't move the map past the border!")
					return
				end
			end
			MoveTilemap(-1, 0)
		end,
		a = "left",
		right = function()
			for y = 1, mapheight do
				if tilemap[y][mapwidth] ~= TILE_EMPTY then
					notification.setMessage("Can't move the map past the border!")
					return
				end
			end
			MoveTilemap(1, 0)
		end,
		d = "right",
		up = function()
			local line = tilemap[1]
			for x = 1, mapwidth do
				if line[x] ~= TILE_EMPTY then
					notification.setMessage("Can't move the map past the border!")
					return
				end
			end
			MoveTilemap(0, -1)
		end,
		w = "up",
		down = function()
			local line = tilemap[mapheight]
			for x = 1, mapwidth do
				if line[x] ~= TILE_EMPTY then
					notification.setMessage("Can't move the map past the border!")
					return
				end
			end
			MoveTilemap(0, 1)
		end,
		s = "down",
	}, cameraInputs),
	["select level"] = setmetatable({
		left = function(cmenu)
			local max = GetLSMax(cmenu)
			pointer = (pointer - 1 <= max and pointer - 1) or max
			sound.playSound("menu_move.wav")
			LSCheck(cmenu, max)
		end,
		right = function(cmenu)
			local max = GetLSMax(cmenu)
			pointer = (pointer + 1 <= max and pointer + 1) or (pointer == #cmenu and 1) or #cmenu
			sound.playSound("menu_move.wav")
			LSCheck(cmenu, max)
		end,
		up = function(cmenu)
			local max = GetLSMax(cmenu)
			pointer = (pointer - 10 <= max and pointer ~= #cmenu and pointer - 10) or max
			sound.playSound("menu_move.wav")
			LSCheck(cmenu, max)
		end,
		down = function(cmenu)
			local max = GetLSMax(cmenu)
			pointer = (pointer + 10 <= max and pointer + 10) or (pointer == #cmenu and 1) or #cmenu
			sound.playSound("menu_move.wav")
			LSCheck(cmenu, max)
		end,
		["return"] = function(cmenu)
			cmenu[pointer].func()
			sound.playSound("menu_select.wav")
		end
	}, defaultInputs),
	["map settings"] = setmetatable({
		escape = function()
			gamestate = "editing"
			sound.playSound("menu_select.wav")
		end
	}, defaultInputs),
	pause = setmetatable({
		escape = function()
			gamestate = "ingame"
			sound.playSound("menu_select.wav")
		end
	}, defaultInputs),
	["sound test"] = setmetatable({
		right = function(cmenu)
			if pointer ~= 1 then return end
			repeat
				sound.soundtestpointer = sound.soundtestpointer + 1
				if sound.soundtestpointer > #sound.soundtest then sound.soundtestpointer = 1 end
			until lastmap >= (sound.soundtest[sound.soundtestpointer].require or 0)
			cmenu[1].name = "< " .. sound.soundtest[sound.soundtestpointer].name .. " >"
			sound.playSound("menu_move.wav")
		end,
		left = function(cmenu)
			if pointer ~= 1 then return end
			repeat
				sound.soundtestpointer = sound.soundtestpointer - 1
				if sound.soundtestpointer < 1 then sound.soundtestpointer = #sound.soundtest end
			until lastmap >= (sound.soundtest[sound.soundtestpointer].require or 0)
			cmenu[1].name = "< " .. sound.soundtest[sound.soundtestpointer].name .. " >"
			sound.playSound("menu_move.wav")
		end
	}, defaultInputs)
}

function love.keypressed(key)
	if debugmode and lovebug.keypressed(key) then return end
	if messagebox.show then
		messagebox.show = false
		messagebox.error = false
		return
	end
	if customEnv and customEnv.KeyPressed and gamestate == "ingame" then
		customEnv.KeyPressed(key)
	end
	local inputs = (inputModes[gamestate] or inputModes[key])
	if not inputs then
		inputModes[gamestate] = menuInputs
		inputs = menuInputs
	end
	if type(inputs) == "function" then
		inputs(key)
	else
		local func = inputs[key]
		if not func then return end
		if type(func) == "string" then
			func = inputs[func]
		end
		func(menu[gamestate])
	end
end

function love.textinput(text)
	if not menu[gamestate] then return end
	local setting = menu[gamestate][pointer]
	if not setting then return end
	if setting.int and tonumber(text) and setting.int:len() < 2 then
		setting.int = setting.int..text
	elseif setting.string and setting.string:len() < 20 then
		setting.string = setting.string..text
	end
end

mouse = {x = 0, y = 0, tile = TILE_EMPTY, camerax = 0, cameray = 0, mode = "camera", speed = 1}
function mouse.boundsCheck()
	return mouse.x <= mapwidth and mouse.y <= mapheight and mouse.x > 0 and mouse.y > 0
end

function mouse.think()
	mouse.x = math.floor((love.mouse.getX() - GetStartX()) / math.floor(32 * scale * GetScaleByScreen()))
	mouse.y = math.floor((love.mouse.getY() - GetStartY()) / math.floor(32 * scale * GetScaleByScreen()))
	if mouse.mode == "editing" and mouse.boundsCheck() then
		if love.mouse.isDown(1) then
			local tile = mouse.tile
			local x = mouse.x
			local y = mouse.y
			local oldtile = tilemap[y][x]
			local nextRow = tilemap[y + 1]
			local prevRow = tilemap[y - 1]
			if IsBridge(tile) and ((nextRow and IsBridge(nextRow[x])) or (prevRow and IsBridge(prevRow[x]))) then
				tile = tile + 10
			end
			tilemap[y][x] = tile
			if oldtile ~= tile then UpdateTilemap() end
		elseif love.mouse.isDown(2) then
			local x = mouse.x
			local y = mouse.y
			local oldtile = tilemap[y][x]
			tilemap[y][x] = TILE_EMPTY
			if oldtile ~= TILE_EMPTY then UpdateTilemap() end
		elseif love.mouse.isDown(3) then
			local possibleTile = tilemap[mouse.y][mouse.x]
			mouse.tile = ((possibleTile >= 50) and possibleTile - 10) or (possibleTile > 0 and possibleTile) or mouse.tile
		end
	end
end

function love.wheelmoved(x, y)
	if debugmode and lovebug.wheelmoved(x, y) then return end
	if gamestate == "editing" and mouse.mode == "editing" then
		wheelmoved = 120
		mouse.tile = math.min(math.max(mouse.tile+y, 1), 48)
	elseif mouse.mode == "camera" and (gamestate == "editing" or gamestate == "ingame") then
		wheelmoved = 120
		scale = math.min(math.max(scale+(0.1*(y/math.abs(y))), 0.5), 2)
		UpdateTilemap()
	end
end

local function IsMouseOnButton(mousex, mousey, button)
	local x, y, width, height = button.x, button.y, button.width, button.height
	return mousex <= width and mousey <= height and mousex > x and mousey > y
end

function love.mousemoved(x, y, dx, dy)
	if menuButtons then
		for i, button in ipairs(menuButtons) do
			if IsMouseOnButton(x, y, button) then
				if pointer ~= i then
					pointer = i
					sound.playSound("menu_move.wav")
				end
				return
			end
		end
		return
	end
	if not love.mouse.isDown(1) then return end
	if (gamestate == "ingame" or gamestate == "editing") and mouse.mode == "camera" then
		mouse.camerax = mouse.camerax+dx
		mouse.cameray = mouse.cameray+dy
	elseif gamestate == "sound test" and sound.music and x >= screenwidth/2-150 and x <= (screenwidth/2)+150 and y >= 350 and y <= 370 then
		local duration = sound.music:getDuration()
		sound.music:seek(math.min(((x-((screenwidth/2)-150))/300)*duration, duration-1))
		sound.music:pause()
	end
end

function love.mousereleased(x, y, button)
	if messagebox.show then
		messagebox.show = false
		messagebox.error = false
		return
	end
	if button ~= 1 or not menuButtons then return end
	if IsMouseOnButton(x, y, menuButtons[pointer]) then
		love.keypressed("return")
	end
end

local gamepadToKeyboard = {
	dpup = "up",
	dpdown = "down",
	dpleft = "left",
	dpright = "right",
	a = "return",
	b = "escape",
	start = "r"
}

function love.gamepadpressed(_, button)
	local key = gamepadToKeyboard[button]
	if not key then return end
	love.keypressed(key)
end