local sound = require "music"
local coins = require "coins"
local nativefs = require "nativefs"

pointer = 1
local valuesnames = {[0] = "off", [1] = "on"}
local numtobool = {[0] = false, [1] = true}
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
possibletilesets = {
  [0] = "forest.png",
  [1] = "frost.png",
  [2] = "castle.png"
}

local function ToggleValue()
  local setting = menu.settings[pointer]
  setting.value = (setting.value+1)%2
  setting.valuename = valuesnames[setting.value]
end

local function ChangeGamestate(newgamestate)
  laststate = gamestate
  gamestate = newgamestate
  statetimer = 0
end

function GetAllMaps()
  menu["select level"] = {}
  local mapn = 1
  local possiblemaps = love.filesystem.getDirectoryItems(mapspath:sub(1, -2))
  for k, mapname in ipairs(possiblemaps) do
    if mapname:sub(mapname:len()-3) == ".map" and mapname:match("%d+%d") then
      menu["select level"][mapn] = {
        name = tostring(mapn),
        func = function()
          LoadMap(mapname)
          gamemap = tonumber(mapname:match("%d+%d"))
          frames = 0
          seconds = 0
          minutes = 0
          hours = 0
        end
      }
      mapn = mapn+1
    end
  end
  if #menu["select level"] > 255 then
    love.window.showMessageBox("Loaded too many maps!", "Saving data may fail.", "warning")
  end
  table.insert(menu["select level"], {name = "back", func = function() ChangeGamestate("title") pointer = 1 end})
end


local function SaveMap(map, mapname, tilesetname, musicname, width, height, reset)
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

local function ResetData()
  menu.settings[1].value = 1
  if menu.settings[2].value == 1 then
    love.window.setMode(800, 600, {fullscreen = false})
    screenwidth = love.graphics.getWidth()
    screenheight = love.graphics.getHeight()
  end
  for i = 1,#menu.settings-2 do
    menu.settings[i].value = menu.settings[i].oldvalue
    if menu.settings[i].valuename then
      menu.settings[i].valuename = valuesnames[menu.settings[i].value]
    end
  end
  lastmap = 1
  for k, v in pairs(coins) do
    if type(k) == "number" then
      coins[k].got = false
    end
  end
  sound.setMusic("menu.ogg")
  SaveSettings()
  SaveData()
end

menu = {
  title = {
    {name = "Start Game", func = function()
      if lastmap == 1 then
        gamemap = 0
        LoadMap("map00.map")
        frames = 0
        seconds = 0
        minutes = 0
        hours = 0
      else
        ChangeGamestate("select level")
        pointer = 1
      end
    end},
    {name = "Addons", func = function()
      ChangeGamestate("addons")
      pointer = 1
    end},
    {name = "Extras", func = function()
      ChangeGamestate("extras")
      pointer = 1
    end},
    {name = "Settings", func = function() ChangeGamestate("settings") pointer = 1 end},
    {name = "Credits", func = function() ChangeGamestate("credits") pointer = 1 end},
    {name = "Quit", func = function() love.event.quit(0) end}
  },
  pause = {
    {name = "Resume", func = function() ChangeGamestate("ingame") end},
    {name = "Restart", func = function() LoadMap("map"..gamemap..".map") end},
    {name = "Return to title", func = function() gamestate = "title" sound.setMusic("menu.ogg") pointer = 1 end},
    {name = "Quit", func = function() love.event.quit(0) end}
  },
  settings = {
    {name = "Show FPS", value = 1, valuename = "on", func = ToggleValue},
    {name = "Fullscreen", value = 0, valuename = "off", func = function(this)
        ToggleValue()
        love.window.setMode(800, 600, {fullscreen = numtobool[this.value], resizable = true})
        screenwidth = love.graphics.getWidth()
        screenheight = love.graphics.getHeight()
    end},
    {name = "Timer", value = 0, valuename = "off", func = ToggleValue},
    {name = "Music", value = 5, values = percentuals, func = function(this)
      if not sound.music then
        sound.setMusic("menu.ogg")
      end
      sound.music:setVolume(this.value / 10)
    end},
    {name = "Sounds", value = 5, values = percentuals},
    {name = "Particles", value = 1, valuename = "on", func = ToggleValue},
    {name = "Flashing stuff", value = 1, valuename = "on", func = ToggleValue},
    {name = "Cutscenes", value = 1, valuename = "on", func = ToggleValue},
    {name = "Erase Data", func = function(this)
      if this.name == "Erase Data" then
        this.name = "Are you sure?"
        messagebox.setMessage("Are you sure?", "This button will erase the save file and settings file\nyou will lose all your progress\nif you're sure you want to do this, select the button again")
      elseif this.name == "Are you sure?" then
        ResetData()
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
    {name = "back", func = function() ChangeGamestate("addons") pointer = 1 end},
  },
  ["create map"] = {
    {name = "Map num: ", int = ""},
    {name = "Map name: ", string = ""},
    {name = "Tileset: ", value = 0, values = possibletilesets},
    {name = "Music name: ", string = ""},
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
        if not SaveMap(mapspath.."/map"..GetMapNum(mapinfo[1].int)..".map", mapinfo[2].string.."\n", mapinfo[3].values[mapinfo[3].value].."\n", mapinfo[4].string.."\n", mapinfo[5].int.."\n", mapinfo[6].int.."\n", true) then return end
        gamemap = tonumber(mapinfo[1].int)
        LoadEditorMap("map"..GetMapNum(gamemap)..".map")
        leveltime = 0
        frametime = 0
        gamestate = "editing"
        mouse.tile = TILE_WALL1
        mouse.camerax = 0
        mouse.cameray = 0
        scale = ((mapwidth >= 20 or mapheight >= 20) and GetScale((mapwidth >= mapheight and mapwidth) or mapheight )) or 1
      end
    end},
    {name = "back", func = function() ChangeGamestate("level editor") pointer = 2 end}
  },
  ["map settings"] = {
    {name = "Map name: ", string = ""},
    {name = "Tileset: ", value = 0, values = possibletilesets},
    {name = "Music name: ", string = ""},
    {name = "Map width: ", int = ""},
    {name = "Map height: ", int = ""},
    {name = "Save", func = function()
      local mapinfo = menu["map settings"]
      SaveMap(mapspath.."/map"..GetMapNum(gamemap)..".map", mapinfo[1].string.."\n", mapinfo[2].values[mapinfo[2].value].."\n", mapinfo[3].string.."\n", mapinfo[4].int.."\n", mapinfo[5].int.."\n")
      LoadEditorMap("map"..GetMapNum(gamemap)..".map")
      notification.setMessage("Map saved")
    end},
    {name = "Resume editing", func = function() gamestate = "editing" end},
    {name = "Return to Title", func = function() gamestate = "title" sound.setMusic("menu.ogg") pointer = 1 end},
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
      for k, filename in ipairs(love.filesystem.getDirectoryItems(path)) do
        if love.filesystem.getInfo(path.."/"..filename, "directory") then
          table.insert(menu["select mod"], {name = filename, func = function()
            SearchCustom(filename)
            gamestate = "title"
            pointer = 1
            table.remove(menu.addons, 2)
            table.remove(menu.addons, 2)
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
    {name = "Theater", func = function()
      messagebox.setMessage("Coming Soon!", ":)")
    end},
    {name = "???", func = function()
      messagebox.setMessage("Coming Soon!", ":)")
    end},
    {name = "back", func = function() ChangeGamestate("title") pointer = 3 end}
  }
}

GetAllMaps()

function SaveSettings()
  local file = io.open("settings.cfg", "w+b")
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

savefile = "save.dat"

function SaveData()
  local file = io.open(savefile, "w+b")
  file:write(string.char(math.min(lastmap, 255)))
  file:write(string.char(math.min(lastmap, 255)))
  for k, coin in pairs(coins) do
    if type(k) == "number" then
      file:write(string.char(k))
      file:write(string.char((coin.got and 1) or 0))
    end
  end
  file:close()
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
  pcall(function()
    repeat
      local mapnum = savefile:read(1):byte()
      local coingot = savefile:read(1):byte()
      if coins[mapnum] and coingot then coins[mapnum].got = (coingot == 1 and true) or false end
    until not mapnum or not coingot
  end)
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
    if menu.settings[i].valuename then
      menu.settings[i].valuename = valuesnames[menu.settings[i].value]
    end
    if not menu.settings[i].value or menu.settings[i].value > ((menu.settings[i].values and #menu.settings[i].values + 1) or 1) then
      local errormsg = 'Value "'..menu.settings[i].name..'" has missing or invalid value\nIt will be set to default.'
      love.window.showMessageBox("Error while loading saved data!", errormsg, "warning")
      menu.settings[i].value = oldvalue
      if menu.settings[i].valuename then
        menu.settings[i].valuename = valuesnames[menu.settings[i].value]
      end
    end
  end
  if menu.settings[2].value == 1 then
    love.window.setMode(800, 600, {fullscreen = numtobool[menu.settings[2].value], resizable = true})
    screenwidth = love.graphics.getWidth()
    screenheight = love.graphics.getHeight()
  end
  file:close()
end