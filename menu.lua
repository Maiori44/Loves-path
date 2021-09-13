local sound = require "music"
local coins = require "coins"

pointer = 1
local valuesnames = {[0] = "off", [1] = "on"}
local numtobool = {[0] = false, [1] = true}

local function ToggleValue()
  local setting = menu.settings[pointer]
  setting.value = (setting.value+1)%2
  setting.valuename = valuesnames[setting.value]
end

function GetAllMaps()
  menu["select level"] = {}
  local mapn = 1
  local possiblemaps = love.filesystem.getDirectoryItems((love.filesystem.isFused() and "Source/"..mapspath) or mapspath)
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
  table.insert(menu["select level"], {name = "back", func = function() gamestate = "title" pointer = 1 end})
end


local function SaveMap(map, mapname, tilesetname, musicname, width, height, reset)
  local file = io.open(map, "w+")
  file:write(mapname)
  file:write(tilesetname)
  file:write(musicname)
  file:write((width ~= "\n") and ((tonumber(width:sub(1, width:len()-1)) > 35) and "35\n" or width) or "10\n")
  file:write((height ~= "\n") and ((tonumber(height:sub(1, height:len()-1)) > 35) and "35\n" or height) or "10\n")
  for i,row in ipairs(tilemap) do
    for j,tile in ipairs(row) do
      file:write((reset and "00") or ((tile < 10 and "0"..tile) or tostring(tile)))
    end
  end
  file:close()
  GetAllMaps()
end

local function ResetData()
  menu.settings[1].value = 1
  if menu.settings[2].value == 1 then
    love.window.setMode(800, 600, {fullscreen = false})
    screenwidth = love.graphics.getWidth()
    screenheight = love.graphics.getHeight()
  end
  menu.settings[2].value = 0
  menu.settings[3].value = 0
  menu.settings[4].value = 1
  menu.settings[5].value = 1
  menu.settings[6].value = 1
  menu.settings[7].value = 1
  menu.settings[8].value = 1
  for i = 1,#menu.settings-2 do
    menu.settings[i].valuename = valuesnames[menu.settings[i].value]
  end
  lastmap = 1
  for k, v in pairs(coins) do
    if type(k) == "number" then
      coins[k].got = false
    end
  end
  SaveSettings()
  SaveData()
end

local warned = false

local function WarnPlayer()
  if warned then return false end
  if mapspath == "Maps" and not debugmode then
    local button = love.window.showMessageBox("Notice!", "Modifying the vanilla maps (especially if you didn't finish the story) is probably not a good idea\nI recommend reading the documentation to create a custom map pack first\nwill you still proceed to the level editor?", {"Continue", "Go back"})
    if button == 1 then warned = true return false end
    return true
  end
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
        gamestate = "select level" 
        pointer = 1
      end
    end},
    {name = "Level Editor", func = function()
      gamestate = "level editor"
      pointer = 1
      menu["level editor"][1].name = "Load map: "
      menu["level editor"][1].int = ""
    end},
    {name = "Sound test", func = function()
      gamestate = "sound test"
      pointer = 1
      sound.setMusic("")
      sound.soundtestpointer = 1
      menu["sound test"][1].name = "< Love's path >"
    end},
    {name = "Settings", func = function() gamestate = "settings" pointer = 1 end},
    {name = "Credits", func = function() gamestate = "credits" pointer = 1 end},
    {name = "Quit", func = function() love.event.quit(0) end}
  },
  pause = {
    {name = "Resume", func = function() gamestate = "ingame" end},
    {name = "Restart", func = function() LoadMap("map"..gamemap..".map") end},
    {name = "Return to title", func = function() gamestate = "title" sound.setMusic("menu.ogg") pointer = 1 end},
    {name = "Quit", func = function() love.event.quit(0) end}
  },
  settings = {
    {name = "Show FPS", value = 1, valuename = "on", func = ToggleValue},
    {name = "Fullscreen", value = 0, valuename = "off", func = function()
        ToggleValue()
        love.window.setMode(800, 600, {fullscreen = numtobool[menu.settings[pointer].value]})
        screenwidth = love.graphics.getWidth()
        screenheight = love.graphics.getHeight()
    end},
    {name = "Timer", value = 0, valuename = "off", func = ToggleValue},
    {name = "Music", value = 1, valuename = "on", func = function()
      ToggleValue()
      sound.setMusic("menu.ogg")
    end},
    {name = "Sounds", value = 1, valuename = "on", func = ToggleValue},
    {name = "Particles", value = 1, valuename = "on", func = ToggleValue},
    {name = "Flashing stuff", value = 1, valuename = "on", func = ToggleValue},
    {name = "Cutscenes", value = 1, valuename = "on", func = ToggleValue},
    {name = "Erase Data", func = function()
      if menu.settings[#menu.settings-1].name == "Erase Data" then
        menu.settings[#menu.settings-1].name = "Are you sure?"
      elseif menu.settings[#menu.settings-1].name == "Are you sure?" then
        ResetData()
        menu.settings[#menu.settings-1].name = "Data erased"
      end
    end},
    {name = "Back", func = function()
      menu.settings[#menu.settings-1].name = "Erase Data"
      SaveSettings()
      gamestate = "title"
      pointer = 1
    end}
  },
  credits = {
    {name = "Back", func = function() gamestate = "title" pointer = 1 end}
  },
  ["select level"] = {},
  ["level editor"] = {
    {name = "Load map: ", int = "", func = function()
      if menu["level editor"][1].name:sub(1, 8) == "Load map" and menu["level editor"][1].int:len() > 0 and WarnPlayer() then return end
      if menu["level editor"][1].int ~= "" then
        gamemap = tonumber(menu["level editor"][1].int)
      end
      if menu["level editor"][1].name:sub(1, 8) == "Load map" and menu["level editor"][1].int:len() > 0
      and not LoadEditorMap("map"..GetMapNum(menu["level editor"][1].int)..".map") then
        menu["level editor"][1].name = "Map not found!"
        menu["level editor"][1].int = ""
      elseif menu["level editor"][1].name == "Map not found!" then
        menu["level editor"][1].name = "Load map: "
      elseif menu["level editor"][1].int ~= "" and mapwidth and mapheight and tilesetname ~= "" then
        objects = {}
        voids = {}
        leveltime = 0
        frametime = 0
        gamestate = "editing"
        mouse.tile = TILE_WALL1
        mouse.camerax = 0
        mouse.cameray = 0
        scale = ((mapwidth >= 20 or mapheight >= 20) and GetScale((mapwidth >= mapheight and mapwidth) or mapheight )) or 1
      end
    end},
    {name = "Create Map", func = function() 
      if WarnPlayer() then return end
      gamestate = "create map"
      local mapnum = menu["create map"][1].int
      local ptilesetname = menu["create map"][3].string
      menu["create map"][1].int = (mapnum == "" and tostring(#menu["select level"]-1)) or mapnum
      menu["create map"][3].string = (ptilesetname == "" and "forest.png") or ptilesetname
      menu["create map"][7].name = "Create map"
      pointer = 1
    end},
    {name = "Documentation", func = function()
      if not love.system.openURL("file://"..love.filesystem.getSourceBaseDirectory().."/readme.txt") then
        love.window.showMessageBox("Error while opening file!", "Could not find \"readme.txt\" in your folder\nreinstall the game to get another copy", "error")
      end
    end},
    {name = "Back", func = function() gamestate = "title" pointer = 1 end},
  },
  ["create map"] = {
    {name = "Map num: ", int = ""},
    {name = "Map name: ", string = ""},
    {name = "Tileset: ", string = ""},
    {name = "Music name: ", string = ""},
    {name = "Map width: ", int = ""},
    {name = "Map height: ", int = ""},
    {name = "Create map", func = function()
      if menu["create map"][1].int == "" then
        menu["create map"][7].name = "Invalid Map num!"
        return
      end
      local check = io.open(mapspath.."/map"..GetMapNum(menu["create map"][1].int)..".map")
      if check then
        check:close()
        menu["create map"][7].name = "Map "..tostring(tonumber(menu["create map"][1].int)).." arleady exists!"
      else
        local mapinfo = menu["create map"]
        SaveMap(mapspath.."/map"..GetMapNum(mapinfo[1].int)..".map", mapinfo[2].string.."\n", mapinfo[3].string.."\n", mapinfo[4].string.."\n", mapinfo[5].int.."\n", mapinfo[6].int.."\n", true)
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
    {name = "Back", func = function() gamestate = "level editor" pointer = 1 end}
  },
  ["map settings"] = {
    {name = "Map name: ", string = ""},
    {name = "Tileset: ", string = ""},
    {name = "Music name: ", string = ""},
    {name = "Map width: ", int = ""},
    {name = "Map height: ", int = ""},
    {name = "Save", func = function()
      local mapinfo = menu["map settings"]
      SaveMap(mapspath.."/map"..GetMapNum(gamemap)..".map", mapinfo[1].string.."\n", mapinfo[2].string.."\n", mapinfo[3].string.."\n", mapinfo[4].int.."\n", mapinfo[5].int.."\n")
      LoadEditorMap("map"..GetMapNum(gamemap)..".map")
      menu["map settings"][6].name = "Map saved!"
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
    {name = "Back", func = function() gamestate = "title" sound.setMusic("menu.ogg") pointer = 1 end}
  },
}

GetAllMaps()

function SaveSettings()
  local file = io.open("settings.cfg", "w+b")
  file:write(string.char((warned and 1) or 0))
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
  warned = numtobool[string.byte(file:read(1))] or false
  for i = 1,#menu.settings-2 do
    local oldvalue = menu.settings[i].value
    menu.settings[i].value = DataCheck(string.byte(file:read(1) or menu.settings[i].value))
    menu.settings[i].valuename = valuesnames[menu.settings[i].value]
    if not menu.settings[i].value or menu.settings[i].value > 1 then
      local options = {"No", "Yes"}
      local errormsg = 'Value "'..menu.settings[i].name..'" has missing or invalid value\nIt will be set to default.'
      love.window.showMessageBox("Error while loading saved data!", errormsg, "warning")
      menu.settings[i].value = oldvalue
      menu.settings[i].valuename = valuesnames[menu.settings[i].value]
    end
  end
  if menu.settings[2].value == 1 then
    love.window.setMode(800, 600, {fullscreen = numtobool[menu.settings[2].value]})
    screenwidth = love.graphics.getWidth()
    screenheight = love.graphics.getHeight()
  end
  file:close()
end