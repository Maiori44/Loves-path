local sound = require "music"
local particles = require "particles"
local nativefs = require "nativefs"

local rainbowSecret = {input = {}, needed = {"up", "up", "down", "down", "left", "right", "left", "right", "b", "a"}}

hidecontrols = false

function love.keypressed(key)
  if messagebox.show then
    messagebox.show = false
    messagebox.error = false
    return
  end
  if gamestate == "title" then
    table.insert(rainbowSecret.input, key)
    if rainbowSecret.input[#rainbowSecret.input] ~= rainbowSecret.needed[#rainbowSecret.input] then
      rainbowSecret.input = {}
    end
    if #rainbowSecret.input == 10 then
      rainbowmode = not rainbowmode
      rainbowSecret.input = {}
    end
  end
  if gamestate == "ingame" and customEnv and customEnv.KeyPressed then
    customEnv.KeyPressed(key)
  end
  if key == "f3" and debugmode then
    local options = {"Noclip", "Slowdown", "Map info", "Graphic info", "Game info", "Cancel", escapebutton = 1}
    local text = "Choose which option to toggle:\n"..
    "Game info = "..tostring(debugmode["Game info"] or false).."\n"..
    "Graphic info = "..tostring(debugmode["Graphic info"] or false).."\n"..
    "Map info = "..tostring(debugmode["Map info"] or false).."\n"..
    "Slowdown = "..tostring(debugmode["Slowdown"] or false).."\n"..
    "Noclip = "..tostring(debugmode["Noclip"] or false).."\n"
    local button = love.window.showMessageBox("Debug mode settings", text, options, "info")
    if button < #options then
      debugmode[options[button]] = (debugmode[options[button]] == nil and true) or (not debugmode[options[button]]) 
    end
  elseif key == "f8" then
    love.graphics.captureScreenshot(function(imagedata)
      if not love.filesystem.getInfo("Source/Screenshots", "directory") then
        nativefs.createDirectory("Screenshots")
      end
      local date = os.date("%Y%m%d%H%M%S")..".png"
      nativefs.write("Screenshots/"..date, imagedata:encode("png"))
      notification.setMessage("Sreenshot saved as:\n"..date)
    end)
  elseif key == "+" and (gamestate == "ingame" or gamestate == "editing") then
    scale = math.min(scale+0.1, 2)
    mouse.mode = "camera"
    wheelmoved = 120
  elseif key == "-" and (gamestate == "ingame" or gamestate == "editing") then
    scale = math.max(scale-0.1, 0.5)
    mouse.mode = "camera"
    wheelmoved = 120
  elseif gamestate == "editing" then
    if key == "c" then
      hidecontrols = not hidecontrols
    elseif key == "escape" then
      gamestate = "map settings"
      pointer = 1
      menu["map settings"][1].string = gamemapname
      menu["map settings"][2].value = 0
      menu["map settings"][3].value = 0
      menu["map settings"][4].int = tostring(mapwidth)
      menu["map settings"][5].int = tostring(mapheight)
      for k, v in ipairs(possibleTilesets) do
        if tilesetname == v then
          menu["map settings"][2].value = k
          break
        end
      end
      for k, v in ipairs(possibleMusic) do
        if sound.musicname == v then
          menu["map settings"][3].value = k
          break
        end
      end
    elseif key == "tab" then
      mouse.mode = (mouse.mode == "camera" and "editing") or "camera"
      wheelmoved = 0
    end
  elseif gamestate == "map settings" and key == "escape" then
    gamestate = "editing"
  elseif gamestate == "ingame" then
    if key == "r" then
      LoadMap("map"..GetMapNum(gamemap)..".map")
    elseif key == "escape" then
      gamestate = "pause"
      pointer = 1
      sound.reset()
    elseif key == "space" then
      if not player then return end
      particles.spawnHelp(player.x, player.y)
    end
    if player and player.momx == 0 and player.momy == 0 then
      if key == "left" or key == "a" then
        player.momx = -1
        particles.spawnSmoke(player.x, player.y)
      elseif key == "right" or key == "d" then
        player.momx = 1
        particles.spawnSmoke(player.x, player.y)
      elseif key == "up" or key == "w" then
        player.momy = -1
        particles.spawnSmoke(player.x, player.y)
      elseif key == "down" or key == "s" then
        player.momy = 1
        particles.spawnSmoke(player.x, player.y)
      end
    end
  elseif gamestate == "pause" and key == "escape" then
    gamestate = "ingame"
  elseif key == "escape" then
    local pback = menu[gamestate][#menu[gamestate]]
    if pback.name == "back" then pback.func() end
  elseif gamestate == "select level" then
    local max = math.min((debugmode and 255) or lastmap, #menu["select level"]-1)
    if key == "left" then
      pointer = (pointer-1 <= max and pointer-1) or max
    elseif key == "right" then
      pointer = (pointer+1 <= max and pointer+1) or (pointer == #menu["select level"] and 1) or #menu["select level"]
    elseif key == "up" then
      pointer = (pointer-10 <= max and pointer ~= #menu["select level"] and pointer-10) or max
    elseif key == "down" then
      pointer = (pointer+10 <= max and pointer+10) or (pointer == #menu["select level"] and 1) or #menu["select level"]
    elseif key == "space" or key == "return" then
      menu["select level"][pointer].func()
    end
    if pointer < 1 or pointer > #menu["select level"] or pointer > max then
      pointer = #menu["select level"]
    end
  elseif key == "backspace" then
    local setting = menu[gamestate][pointer]
    if setting.int and utf8.len(setting.int) > 0 then
      setting.int = setting.int:sub(1, utf8.len(setting.int)-1)
    elseif setting.string and utf8.len(setting.string) > 0 then
      local byteoffset = utf8.offset(setting.string, -1)
      if byteoffset then
        setting.string = setting.string:sub(1, byteoffset - 1)
      end
    end
  elseif gamestate ~= "editing" then
    if key == "up" then
      pointer = pointer-1
      if pointer == 0 then pointer = #menu[gamestate] end
    elseif key == "down" then
      pointer = pointer+1
      if pointer > #menu[gamestate] then pointer = 1 end
    elseif menu[gamestate][pointer].values then
      local setting = menu[gamestate][pointer]
      if key == "right" then
        setting.value = (setting.value + 1) % (#setting.values + 1)
        if menu[gamestate][pointer].func then 
          menu[gamestate][pointer].func(setting)
        end
      elseif key == "left" then
        setting.value = (setting.value == 0 and #setting.values) or setting.value - 1
        if menu[gamestate][pointer].func then 
          menu[gamestate][pointer].func(setting)
        end
      end
    elseif (key == "space" or key == "return") and menu[gamestate][pointer].func then
      menu[gamestate][pointer].func(menu[gamestate][pointer])
    elseif gamestate == "sound test" and pointer == 1 then
      if key == "right" then
        repeat
          sound.soundtestpointer = sound.soundtestpointer+1
          if sound.soundtestpointer > #sound.soundtest then sound.soundtestpointer = 1 end
        until lastmap >= (sound.soundtest[sound.soundtestpointer].require or 0)
        menu["sound test"][1].name = "< "..sound.soundtest[sound.soundtestpointer].name.." >"
      elseif key == "left" then
        repeat
          sound.soundtestpointer = sound.soundtestpointer-1
          if sound.soundtestpointer < 1 then sound.soundtestpointer = #sound.soundtest end
        until lastmap >= (sound.soundtest[sound.soundtestpointer].require or 0)
        menu["sound test"][1].name = "< "..sound.soundtest[sound.soundtestpointer].name.." >"
      end
    end
  end
end

function love.textinput(text)
  if not menu[gamestate] then return end
  local setting = menu[gamestate][pointer]
  if setting.int and tonumber(text) and setting.int:len() < 2 then
    setting.int = setting.int..text
  elseif setting.string and setting.string:len() < 20 then
    setting.string = setting.string..text
  end
end

mouse = {x = 0, y = 0, tile = TILE_EMPTY, camerax = 0, cameray = 0, mode = "camera"}
function mouse.boundsCheck()
  if mouse.x <= mapwidth and mouse.y <= mapheight and mouse.x > 0 and mouse.y > 0 then
    return true
  end
  return false
end

function mouse.think()
  mouse.x = math.floor((love.mouse.getX() - GetStartX()) / math.floor(32 * scale * GetScaleByScreen()))
  mouse.y = math.floor((love.mouse.getY() - GetStartY()) / math.floor(32 * scale * GetScaleByScreen()))
  if mouse.mode == "editing" and mouse.boundsCheck() then
    if love.mouse.isDown(1) then
      tilemap[mouse.y][mouse.x] = mouse.tile
    elseif love.mouse.isDown(2) then
      tilemap[mouse.y][mouse.x] = TILE_EMPTY
    elseif love.mouse.isDown(3) then
      local possibleTile = tilemap[mouse.y][mouse.x]
      mouse.tile = (possibleTile > 0 and possibleTile) or mouse.tile
    end
  end
end

function love.wheelmoved(x, y)
  if gamestate == "editing" and mouse.mode == "editing" then
    wheelmoved = 120
    mouse.tile = math.min(math.max(mouse.tile+y, 1), 48)
  elseif mouse.mode == "camera" and (gamestate == "editing" or gamestate == "ingame") then
    wheelmoved = 120
    scale = math.min(math.max(scale+(0.1*(y/math.abs(y))), 0.5), 2)
  end
end

function love.mousemoved(x, y, dx, dy)
  if not love.mouse.isDown(1) then return end
  if (gamestate == "ingame" or gamestate == "editing") and mouse.mode == "camera" then
    mouse.camerax = mouse.camerax+dx
    mouse.cameray = mouse.cameray+dy
  elseif gamestate == "sound test" and sound.music
  and x >= screenwidth/2-150 and x <= (screenwidth/2)+150 and y >= 350 and y <= 370 then
    local duration = sound.music:getDuration()
    sound.music:seek(math.min(((x-((screenwidth/2)-150))/300)*duration, duration-1))
    sound.music:pause()
  end
end