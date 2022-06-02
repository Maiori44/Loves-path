local sound = require "music"
local coins = require "coins"
local nativefs = require "nativefs"
local discord = require "discordRPC"
local cutscenes = require "cutscenes"

EXTRA_THEATER = 2
EXTRA_BONUSLEVELS = 3
EXTRA_WOBBLE = 4
EXTRA_SUPERDARK = 5

pointer = 1
valuesnames = {[0] = "off", [1] = "on"}
local percentuals = {
	[0] = "0%",
	[1] = "10%",
	[2] = "20%",
	[3] = "30%",
	[4] = "40%",
	[5] = "50%",
	[6] = "60%",
	[7] = "70%",
	[8] = "80%",
	[9] = "90%",
	[10] = "100%"
}

possibleTilesets = {
	[0] = "forest.png",
	[1] = "frost.png",
	[2] = "castle.png",
	[3] = "factory.png",
}

possibleMusic = {
	[0] = "none",
	[1] = "forest 1.ogg",
	[2] = "forest 2.ogg",
	[3] = "frost 1.ogg",
	[4] = "frost 2.ogg",
	[5] = "castle 1.ogg",
	[6] = "castle 2.ogg",
	[7] = "factory 1.ogg",
	[8] = "factory 2.ogg",
	[9] = "bonus.ogg",
}

function ChangeGamestate(newgamestate)
	laststate = gamestate
	gamestate = newgamestate
	statetimer = 0
end

local function SpawnDots(x, y)
	SpawnObject("Sprites/Bonuses/pac dot.png", x, y, "pacdot")
end

local function LoadBonusMap(num)
	LoadMap("bonus0"..num..".map")
	gamemap = -num
	frames = 0
	seconds = 0
	minutes = 0
	hours = 0
	discord.updateGamePresence()
end

local function VanillaExtraCheck()
	if customEnv then
		messagebox.setMessage("This extra is locked...", "You can only unlock it by playing without mods!\n(Once unlocked it can be used with mods too)")
		return true
	end
end

local function LockedCutscene()
	messagebox.setMessage("This cutscene is locked!", "Complete more levels to unlock it!")
end

menu = {
	title = {
		{name = "Start Game", func = function()
			if lastmap == 1 then
				if customEnv then
					gamemap = 0
					LoadMap("map00.map")
					frames = 0
					seconds = 0
					minutes = 0
					hours = 0
				else
					ChangeGamestate("name him")
				end
			else
				ChangeGamestate("select level")
				pointer = 1
			end
		end},
		{name = "Addons", state = "addons"},
		{name = "Extras", state = "extras"},
		{name = "Settings", state = "settings"},
		{name = "Credits", state = "credits"},
		{name = "Quit", func = function() love.event.quit(0) end}
	},
	pause = {
		{name = "Resume", state = "ingame"},
		{name = "Restart", func = RestartMap},
		{name = "Return to title", func = function()
			gamestate = "title"
			sound.setMusic("menu.ogg")
			pointer = 1
			discord.updatePresence(discord.menu)
		end},
		{name = "Quit", func = function() love.event.quit(0) end}
	},
	settings = {
		{name = "Show FPS", value = 1, values = valuesnames},
		{name = "Fullscreen", value = 0, values = valuesnames, func = function(this)
				love.window.setMode(800, 600, {fullscreen = this.value == 1, resizable = true, minwidth = 800, minheight = 600})
				screenwidth = love.graphics.getWidth()
				screenheight = love.graphics.getHeight()
		end},
		{name = "Timer", value = 0, values = valuesnames},
		{name = "Music", value = 5, values = percentuals, func = function(this)
			if not sound.music then
				sound.setMusic("menu.ogg")
			end
			sound.music:setVolume(this.value / 10)
		end},
		{name = "Sounds", value = 5, values = percentuals},
		{name = "Particles", value = 3, values = {[0] = "none", [1] = "few", [2] = "most", [3] = "all"}},
		{name = "Flashing stuff", value = 1, values = valuesnames},
		{name = "Cutscenes", value = 1, values = valuesnames},
		{name = "Erase Data", func = function(this)
			if this.name == "Erase Data" then
				this.name = "Are you sure?"
				messagebox.setMessage("Are you sure?", "This option will reset the save file\nall collected coins, cleared levels and more will be lost\npress the option again to confirm")
			elseif this.name == "Are you sure?" then
				lastmap = 1
				for k, _ in pairs(coins) do
					if type(k) == "number" then
						coins[k].got = false
					end
				end
				sound.soundtest[#sound.soundtest] = {require = 0xFF}
				menu.extras[EXTRA_THEATER].name = "???????"
				menu.extras[EXTRA_BONUSLEVELS].name = "????? ??????"
				menu.extras[EXTRA_WOBBLE].name = "???????"
				menu.extras[EXTRA_WOBBLE].value = nil
				menu.extras[EXTRA_WOBBLE].values = nil
				menu.extras[EXTRA_SUPERDARK].name = "?????????"
				menu.extras[EXTRA_SUPERDARK].value = nil
				menu.extras[EXTRA_SUPERDARK].values = nil
				SaveData()
				this.name = "Erase Data"
				notification.setMessage("Data erased")
			end
		end},
		{name = "back", func = function()
			sound.setMusic("menu.ogg")
			menu.settings[#menu.settings-1].name = "Erase Data"
			SaveSettings()
			ChangeGamestate("title")
			pointer = 4
		end}
	},
	credits = {
		{name = "back", func = function() ChangeGamestate("title") pointer = #menu.title - 1 end}
	},
	["select level"] = nil,
	["level editor"] = {
		{name = "Load map: ", int = "", func = function()
			if menu["level editor"][1].int ~= "" then
				gamemap = tonumber(menu["level editor"][1].int)
				if LoadEditorMap("map"..GetMapNum(gamemap)..".map") then
					objects = {}
					voids = {}
					leveltime = 0
					frametime = 0
					gamestate = "editing"
					mouse.tile = TILE_WALL1
					mouse.camerax = 0
					mouse.cameray = 0
					scale = ((mapwidth >= 20 or mapheight >= 20) and GetScale((mapwidth >= mapheight and mapwidth) or mapheight )) or 1
					UpdateTilemap()
				else
					messagebox.setMessage("Map not found!", "If you want to create a new map\nselect the \"Create Map\" button instead")
					menu["level editor"][1].int = ""
				end
			end
		end},
		{name = "Create Map", func = function() 
			ChangeGamestate("create map")
			local mapnum = menu["create map"][1].int
			local ptilesetname = menu["create map"][3].string
			menu["create map"][1].int = (mapnum == "" and tostring(#menu["select level"]-1)) or mapnum
			menu["create map"][3].string = (ptilesetname == "" and "forest.png") or ptilesetname
			menu["create map"][7].name = "Create map"
			pointer = 1
		end},
		{name = "back", state = "addons"},
	},
	["create map"] = {
		{name = "Map num: ", int = ""},
		{name = "Map name: ", string = ""},
		{name = "Tileset: ", value = 0, values = possibleTilesets},
		{name = "Music: ", value = 0, values = possibleMusic},
		{name = "Map width: ", int = ""},
		{name = "Map height: ", int = ""},
		{name = "Create map", func = function()
			if menu["create map"][1].int == "" then
				messagebox.setMessage("Invalid map number!", "you need to set the map number to...a number")
				return
			end
			if love.filesystem.getInfo(mapspath.."map"..GetMapNum(menu["create map"][1].int)..".map", "file") then
				local mapnum = tostring(tonumber(menu["create map"][1].int))
				messagebox.setMessage("Map "..mapnum.." already exists!", "You can load it from the \"load map:\" button\nby setting the map to load to \""..mapnum.."\"")
			else
				local mapinfo = menu["create map"]
				if not SaveMap(mapspath.."/map"..GetMapNum(mapinfo[1].int)..".map", mapinfo[2].string.."\n", mapinfo[3].values[mapinfo[3].value].."\n", mapinfo[4].values[mapinfo[4].value].."\n", mapinfo[5].int.."\n", mapinfo[6].int.."\n", true) then return end
				gamemap = tonumber(mapinfo[1].int)
				LoadEditorMap("map"..GetMapNum(gamemap)..".map")
				leveltime = 0
				frametime = 0
				gamestate = "editing"
				mouse.tile = TILE_WALL1
				mouse.camerax = 0
				mouse.cameray = 0
				scale = ((mapwidth >= 20 or mapheight >= 20) and GetScale((mapwidth >= mapheight and mapwidth) or mapheight )) or 1
				UpdateTilemap()
			end
		end},
		{name = "back", func = function() ChangeGamestate("level editor") pointer = 2 end}
	},
	["map settings"] = {
		{name = "Map name: ", string = ""},
		{name = "Tileset: ", value = 0, values = possibleTilesets},
		{name = "Music: ", value = 0, values = possibleMusic},
		{name = "Map width: ", int = ""},
		{name = "Map height: ", int = ""},
		{name = "Save", func = function()
			local mapinfo = menu["map settings"]
			SaveMap(mapspath.."/map"..GetMapNum(gamemap)..".map", mapinfo[1].string.."\n", mapinfo[2].values[mapinfo[2].value].."\n", mapinfo[3].values[mapinfo[3].value].."\n", mapinfo[4].int.."\n", mapinfo[5].int.."\n")
			LoadEditorMap("map"..GetMapNum(gamemap)..".map")
			notification.setMessage("Map saved")
			UpdateTilemap()
		end},
		{name = "Resume editing", func = function() gamestate = "editing" end},
		{name = "Return to Title", func = function()
			gamestate = "title"
			sound.setMusic("menu.ogg")
			pointer = 1
			discord.updatePresence(discord.menu)
		end},
		{name = "Quit", func = function() love.event.quit(0) end}
	},
	["the end"] = {
		{name = "Return to Title", func = function() gamestate = "title" sound.setMusic("menu.ogg") pointer = 1 end},
		{name = "Quit", func = function() love.event.quit(0) end}
	},
	["sound test"] = {
		{name = "< "..sound.soundtest[sound.soundtestpointer].name.." >", soundtest = true, func = function()
			local musicname = sound.soundtest[sound.soundtestpointer].filename
			sound.setMusic((sound.musicname == musicname and "") or musicname)
		end},
		{name = "back", func = function() ChangeGamestate("extras") sound.setMusic("menu.ogg") pointer = 1 end}
	},
	addons = {
		{name = "Level Editor", func = function()
			if mapspath == "Maps/" and not debugmode then
				messagebox.setMessage("You can't edit the vanilla maps!", "You need to create a mod for that,\nif you want to create and edit your own maps\nselect the documentation button")
				return
			end
			ChangeGamestate("level editor")
			pointer = 1
			menu["level editor"][1].name = "Load map: "
			menu["level editor"][1].int = ""
		end},
		{name = "Load mod", func = function()
			menu["select mod"] = {}
			local path = (love.filesystem.isFused() and "Source/Custom") or "Custom"
			for _, filename in ipairs(love.filesystem.getDirectoryItems(path)) do
				if love.filesystem.getInfo(path.."/"..filename, "directory") then
					table.insert(menu["select mod"], {name = filename, func = function()
						if not SearchCustom(filename) then return end
						gamestate = "title"
						pointer = 1
						table.remove(menu.addons, 2)
						table.remove(menu.addons, 2)
						table.remove(menu.extras, 3)
						EXTRA_WOBBLE = 3
						EXTRA_SUPERDARK = 4
						LoadData()
						notification.setMessage("\""..filename.."\" loaded succesfully")
					end})
				end
			end
			table.insert(menu["select mod"], {name = "back", func = function() ChangeGamestate("addons") pointer = 2 end})
			ChangeGamestate("select mod")
			pointer = 1
		end},
		{name = "Create Mod: ", string = "", func = function(this)
			if this.string == "" then
				return
			elseif this.string == "save" then
				messagebox.setMessage("Invalid Mod name!", "Naming your mod \"save\" will make it override the vanilla save file\nthat's not a good idea\nchoose another name")
				return
			elseif nativefs.getInfo("Custom/"..this.string, "directory") then
				messagebox.setMessage("Mod already exists!", "A mod named \""..this.string.."\" already exists!\nif it's your mod you can load it from the addons menu")
				return
			end
			local modpath = "Custom/"..this.string
			nativefs.createDirectory(modpath)
			nativefs.createDirectory(modpath.."/Maps")
			nativefs.createDirectory(modpath.."/Tiles")
			nativefs.createDirectory(modpath.."/Enemies")
			nativefs.createDirectory(modpath.."/Music")
			nativefs.createDirectory(modpath.."/Sound")
			nativefs.write(modpath.."/custom.lua", "--Files generated automatically by the game\n--More info about them in readme.txt")
			messagebox.setMessage("Mod successfully created!", "The mod can be found at "..modpath)
		end},
		{name = "Documentation", func = function()
			if not love.system.openURL("file://"..love.filesystem.getSourceBaseDirectory().."/readme.txt") then
				messagebox.setMessage("Documentation not found!", "Could not find \"readme.txt\" in your folder\nreinstall the game to get another copy", true)
			end
		end},
		{name = "back", func = function() ChangeGamestate("title") pointer = 2 end}
	},
	extras = {
		{name = "Sound test", func = function()
			ChangeGamestate("sound test")
			pointer = 1
			sound.setMusic("")
			sound.soundtestpointer = 1
			menu["sound test"][1].name = "< Love's path >"
		end},
		{name = "???????", func = function()
			local coinsgot = coins.count()
			if coinsgot < 2 then
				messagebox.setMessage("This extra is locked...", "You need "..2 - coinsgot.." more coins to unlock this extra!")
				return
			end
			ChangeGamestate("select cutscene")
			pointer = 1
			local lastscene = lastmap / 10 + 1
			local list = {}
			for num, cutscene in ipairs(cutscenes.list) do
				if num >= lastscene then
					table.insert(list, {name = cutscene.name:gsub("[%a%p%.]", "?"), func = LockedCutscene})
				else
					table.insert(list, {name = cutscene.name, func = function()
						if gamestate == "cutscene selected" then return end
						cutscenes.setCutscene(num, "select cutscene")
						gamestate = "cutscene selected"
						menu["cutscene selected"] = list
					end})
				end
			end
			table.insert(list, {name = "back", func = function() ChangeGamestate("extras") pointer = 2 end})
			menu["select cutscene"] = list
		end},
		{name = "????? ??????", func = function()
			local coinsgot, coinstotal = coins.count()
			if coinsgot ~= coinstotal then
				messagebox.setMessage("This extra is locked...", "You need "..coinstotal - coinsgot.." more coins to unlock this extra!")
				return
			end
			ChangeGamestate("bonus levels")
			pointer = 1
		end},
		{name = "???????", func = function(this)
			if this.value then return end
			if VanillaExtraCheck() then return end
			local coinsgot, coinstotal = coins.count()
			messagebox.setMessage("This extra is locked...", "You need "..math.floor(coinstotal / 2) - coinsgot.." more coins to unlock this extra!")
		end},
		{name = "?????????", func = function(this)
			if VanillaExtraCheck() then return end
			if not this.value then
				messagebox.setMessage("This extra is locked...", "Look for a yellow button hidden somewhere in chapter 4!")
			else
				darkshader:send("light", this.value == 1 and 160 or 200)
			end
		end},
		{name = "back", func = function() ChangeGamestate("title") pointer = 3 end}
	},
	["bonus levels"] = {
		{name = "pac love", func = function()
			LoadBonusMap(1)
			IterateMap(TILE_FLOOR3, SpawnDots)
		end},
		{name = "love is you", func = function()
			LoadBonusMap(2)
			local is = "Sprites/Bonuses/is.png"
			local bridge = "Sprites/Bonuses/bridge.png"
			local slime = "Sprites/Bonuses/slime.png"
			local lock = "Sprites/Bonuses/lock.png"
			local kand = "Sprites/Bonuses/and.png"
			local sprs1 = {
				"Sprites/Bonuses/void.png",
				lock,
				bridge,
				slime
			}
			local sprs2 = {
				"Sprites/Bonuses/defeat.png",
				"Sprites/Bonuses/stop.png",
				"Sprites/Bonuses/crumble.png",
				"Sprites/Bonuses/sticky.png"
			}
			local quads = GetQuads(4, is)
			for y = 15, 18 do
				SpawnObject(sprs1[y - 14], 25, y, "dummy", quads)
				SpawnObject(is, 26, y, "dummy", quads)
				SpawnObject(sprs2[y - 14], 27, y, "dummy", quads)
			end
			SpawnObject("Sprites/Bonuses/spike.png", 23, 15, "dummy", quads)
			SpawnObject(kand, 24, 15, "dummy", quads)
			SpawnObject("Sprites/Bonuses/pipe.png", 23, 16, "dummy", quads)
			SpawnObject(kand, 24, 16, "dummy", quads)
			SpawnObject("Sprites/Bonuses/love.png", 7, 5, "biylove", quads)
			SpawnObject(is, 8, 5, "biylove", quads)
			SpawnObject("Sprites/Bonuses/you.png", 9, 5, "biylove", quads)
			SpawnObject(lock, 14, 7, "biylock", quads)
			SpawnObject(is, 25, 6, "biyword", quads)
			SpawnObject(slime, 26, 6, "biyword", quads)
			SpawnObject("Sprites/Bonuses/win.png", 13, 8, "biywin", quads)
			SpawnObject("Sprites/Bonuses/key.png", 2, 3, "biyword", quads)
			SpawnObject(is, 2, 4, "biyword", quads)
			SpawnObject(slime, 13, 17, "biyword", quads)
			SpawnObject(is, 14, 16, "biyword", quads)
			SpawnObject(bridge, 15, 17, "biybridge", quads)
		end},
		{name = "mirrored plane", func = function()
			LoadBonusMap(3)
			objects = {}
			SpawnObject("Sprites/player.png", 8, 19, "playerclone")
			SpawnObject("Sprites/player.png", player.x, player.y, "player")
			player = objects[2]
		end},
		{name = "brain messer", func = function()
			LoadBonusMap(4)
			local bfmonitor, nummonitor = "Sprites/Bonuses/brainfuck monitor.png", "Sprites/Bonuses/number monitor.png"
			for x = 5, 19 do
				SpawnObject(bfmonitor, x, 12, "bfmonitor", GetQuads(7, bfmonitor), "hp", nil, 1)
			end
			for x = 10, 14 do
				SpawnObject(nummonitor, x, 4, "dummy", GetQuads(10, nummonitor), "hp", nil, 1)
			end
		end},
		{name = "simply riddles", func = function()
			LoadBonusMap(5)
			local bimonitor = "Sprites/Bonuses/binary monitor.png"
			for x = 2, 5 do
				SpawnObject(bimonitor, x, 7, "bimonitor", GetQuads(2, bimonitor), "frame")
			end
			for x = 7, 10 do
				SpawnObject(bimonitor, x, 7, "bimonitor", GetQuads(2, bimonitor), "frame")
			end
			for x = 16, 19 do
				SpawnObject(bimonitor, x, 7, "bimonitor", GetQuads(2, bimonitor), "frame")
			end
			for x = 21, 24 do
				SpawnObject(bimonitor, x, 7, "bimonitor", GetQuads(2, bimonitor), "frame")
			end
			local numonitor = "Sprites/Bonuses/number monitor.png"
			SpawnObject(numonitor, 22, 31, "numonitor", GetQuads(10, numonitor), "frame")
			SpawnObject(numonitor, 4, 20, "numonitor", GetQuads(10, numonitor), "frame")
		end},
		{name = "wall landers", func = function()
			LoadBonusMap(6)
			SetTile(16, 2, TILE_DOWNPUSHER1)
			SetTile(17, 2, TILE_DOWNPUSHER1)
			SetTile(14, 2, TILE_DOWNPUSHER1)
			local rotcounter = "Sprites/Bonuses/number monitor.png"
			SpawnObject(rotcounter, 20, 1, "rotcounter", GetQuads(10, rotcounter), "frame").frame = 10
		end},
		{name = "back", func = function() ChangeGamestate("extras") pointer = 3 end}
	},
	["bonus level complete!"] = {
		{name = "retry", func = function() menu["bonus levels"][math.abs(gamemap)].func() end},
		{name = "return to level select", func = function()
			gamestate = "bonus levels"
			pointer = math.abs(gamemap)
			sound.setMusic("menu.ogg")
			discord.updatePresence(discord.menu)
		end}
	},
	["name him"] = {
		{name = "his name: ", string = "Brownie", func = function(self)
			local newname = self.string
			if newname:gsub("%s+", "") == "" then
				messagebox.setMessage("Invalid name!", "Nothing can't be his name.")
				return
			end
			hisname = newname:match("^%s*(.-)%s*$")
			local oldstatetimer = statetimer
			gamemap = 0
			LoadMap("map00.map")
			frames = 0
			seconds = 0
			minutes = 0
			hours = 0
			discord.updatePresence({
				details = "Playing",
				state = "Level 1: Grassy Forest",
				largeImageKey = "logo",
				startTimestamp = os.time(os.date("*t"))
			})
			if menu.settings[8].value == 0 then return end
			cutscenes.setCutscene(1)
			gamestate = "the story begins"
			statetimer = oldstatetimer
			menu["the story begins"] = {
				{name = "his name: " .. hisname},
				{name = "back"}
			}
		end},
		{name = "back", state = "title"}
	},
}

function SaveSettings()
	local file, errormsg = io.open("settings.cfg", "w+b")
	if not file then
		messagebox.setMessage("Failed to save settings!", errormsg, true)
		return
	end
	for i = 1,#menu.settings-2 do
		file:write(string.char(menu.settings[i].value))
	end
	file:close()
end

local function DataCheck(val)
	if val and type(val) == "number" then
		return val
	else
		return nil
	end
end

saver = nil

function StartSaving()
	saver = coroutine.create(SaveData)
end

local function SaverYield()
	if saver then
		coroutine.yield()
	end
end

savefile = "save.dat"

function SaveData()
	local file, errormsg = io.open(savefile, "w+b")
	if not file then
		messagebox.setMessage("Failed to save data!", errormsg, true)
		return
	end
	SaverYield()
	local l = string.char(math.min(lastmap, 255))
	file:write(l..l)
	SaverYield()
	if not customEnv then
		local extras = menu.extras
		local superdark = extras[EXTRA_SUPERDARK].value and 3 or 1
		local wobble = extras[EXTRA_WOBBLE].value and 4 or 1
		local theater = extras[EXTRA_THEATER].name ~= "???????" and 7 or 1
		SaverYield()
		file:write(hisname.."\0"..string.char(superdark * wobble * theater))
		SaverYield()
	end
	for k, coin in pairs(coins) do
		if type(k) == "number" then
			file:write(string.char(k)..string.char((coin.got and 1) or 0))
		end
		SaverYield()
	end
	file:close()
end

local function TryLoadData(savefile)
	if not customEnv then
		hisname = ""
		local char = savefile:read(1)
		while char ~= "\0" do
			hisname = hisname..char
			char = savefile:read(1)
		end
		local extras = savefile:read(1):byte()
		if (extras % 3) == 0 then
			local superdark = menu.extras[EXTRA_SUPERDARK]
			superdark.name = "superdark"
			superdark.value = 0
			superdark.values = valuesnames
		end
		if (extras % 4) == 0 then
			local wobble = menu.extras[EXTRA_WOBBLE]
			wobble.name = "wobble"
			wobble.value = 0
			wobble.values = valuesnames
		end
		if (extras % 7) == 0 then
			menu.extras[EXTRA_THEATER].name = "theater"
		end
	end
	repeat
		local mapnum = savefile:read(1):byte()
		local coingot = savefile:read(1):byte()
		if coins[mapnum] and coingot then coins[mapnum].got = (coingot == 1 and true) or false end
	until not mapnum or not coingot
end

function LoadData()
	local savefile = io.open(savefile, "rb")
	if not savefile then
		SaveData()
		return
	end
	local possibleval = savefile:read(1)
	local savecheck = savefile:read(1)
	lastmap = (possibleval and string.byte(possibleval)) or 256
	savecheck = (savecheck and string.byte(savecheck)) or 256
	local errormsg
	if lastmap > 255 then
		errormsg = 'Value "lastmap" is missing\nit will be set back to default.'
	elseif lastmap ~= savecheck then
		errormsg = 'Value "lastmap" is corrupted or was modified\nit will be set back to default.'
	end
	if errormsg then
		love.window.showMessageBox("Error while loading saved data!", errormsg, "warning")
		lastmap = 1
	end
	pcall(TryLoadData, savefile)
	if customEnv then return end
end

function LoadSettings()
	LoadData()
	local file = io.open("settings.cfg", "rb")
	if not file then
		SaveSettings()
		return
	end
	for i = 1,#menu.settings-2 do
		local oldvalue = menu.settings[i].value
		menu.settings[i].oldvalue = oldvalue
		menu.settings[i].value = DataCheck(string.byte(file:read(1) or menu.settings[i].value))
		if not menu.settings[i].value or menu.settings[i].value > ((menu.settings[i].values and #menu.settings[i].values + 1) or 1) then
			local errormsg = 'Value "'..menu.settings[i].name..'" has missing or invalid value\nIt will be set to default.'
			love.window.showMessageBox("Error while loading saved data!", errormsg, "warning")
			menu.settings[i].value = oldvalue
		end
	end
	if menu.settings[2].value == 1 then
		love.window.setMode(800, 600, {fullscreen = true, resizable = true, minwidth = 800, minheight = 600})
		screenwidth = love.graphics.getWidth()
		screenheight = love.graphics.getHeight()
	end
	file:close()
end