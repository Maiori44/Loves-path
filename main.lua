VERSION = "Version 43 ALPHA 1.2"

local SetColor = love.graphics.setColor

function love.graphics.setColor(r, g, b, a)
  if not rainbowmode then SetColor(r, g, b, a) return end
  local clock = (os.clock()*100)%510
  if clock < 85 then r = 255-(clock%256)*6 g = g*255 b = b*255
  elseif clock > 85 and clock < 170 then g = 255-(clock%256)*5 r = r*255 b = b*255
  elseif clock > 170 and clock < 255 then b = 255-(clock%256)*4 g = g*255 r = r*255
  elseif clock > 255 and clock < 340 then r = 255-(clock%256)*3 g = 255-(clock%256)*3 b = b*255
  elseif clock > 340 and clock < 425 then r = 255-(clock%256)*2 g = g*255 b = 255-(clock%256)*2
  else r = r*255 g = 255-(clock%256) b = 255-(clock%256) end
  r, g, b = love.math.colorFromBytes(r, g, b)
  SetColor(r, g, b, a)
end

function GetMapNum(mapnum)
  mapnum = tostring(mapnum)
  if tonumber(mapnum) < 10 then mapnum = "0"..mapnum end
  if mapnum:len() > 2 then mapnum = mapnum:sub(2) end
  return mapnum
end

function CheckArgument(n, funcname, arg, ctype)
  local atype = type(arg)
  if atype ~= ctype then
    error("bad argument # "..n.." to '"..funcname.."' ("..ctype.." expected, got "..atype..")")
  end
end

require "maps"
require "objects"
require "menu"
require "player"
utf8 = require "utf8"
local sound = require "music"
local particles = require "particles"

io.stdout:setvbuf("no")

local font
local titlescreen = love.graphics.newImage("Sprites/title1.png")
local titleglow = love.graphics.newImage("Sprites/title2.png")
local errortile = love.graphics.newImage("Sprites/error.png")

local function GetUnit(val)
  local tval = tostring(val)
  return tonumber(tval:sub(tval:len()))
end

function GetScale(num)
  return math.floor((19/num)*10)/10
end

local function DoTime(timetodo, timetoreset)
  if timetoreset == 60 then
    return timetodo+1, 0
  end
  return timetodo, timetoreset
end

function GetStartX()
  return ((screenwidth-(mapwidth+2)*scale*32)/2)+mouse.camerax
end

function GetStartY()
  return ((screenheight-((mapheight < 20 and mapheight) or mapheight+2)*scale*32)/2)+mouse.cameray
end

function love.load(args)
  love.window.setVSync(-1)
  if args[1] == "-debug" then
    debugmode = {["Game info"] = true}
  end
  font = love.graphics.newFont("editundo.ttf", 24, "mono")
  leveltime = 0
  frametime = 0
  seconds = 0
  minutes = 0
  hours = 0
  gamestate = "title"
  gamemap = 0
  lastmap = 1
  scale = 1
  screenwidth = love.graphics.getWidth()
  screenheight = love.graphics.getHeight()
  quads = {}
  width = 0
  height = 0
  tileset = 0
  wheelmoved = 0
  player = nil
  gamemapname = ""
  musicname = ""
  pcall(LoadData)
  --[[if menu.settings[7].value == 1 then
    local console = io.open("log "..os.date()..".txt", "w+")
    io.output(console)
    io.stdout:setvbuf("no")
  end]]
  sound.setMusic("menu.ogg")
  --particles.setMain("leaf.png")
end

function love.update(dt)
  if customEnv then customEnv.leveltime = leveltime end
  if #sound.list >= 10 then sound.collectGarbage() end
  if #particles.list >= 20 then particles.collectGarbage() end
  if gamestate == "ingame" then
    --if particles.main then particles.main:update(dt) end
    particles.update(dt)
    frametime = frametime+dt
    while frametime > 1/60 do
      leveltime = leveltime+1
      frames = frames+1
      seconds, frames = DoTime(seconds, frames)
      minutes, seconds = DoTime(minutes, seconds)
      hours, minutes = DoTime(hours, minutes)
      frametime = frametime-1/60
      if customEnv and customEnv.UpdateFrame and type(customEnv.UpdateFrame) == "function" then
        customEnv.UpdateFrame(frames, seconds, minutes, hours)
      end
      TryMove(player, 0, 0)
      if (leveltime%2) == 0 then
        for k, mo in pairs(objects) do
          if thinkers[mo.type] then thinkers[mo.type](mo) end
          if mo.momx and mo.momy and (mo.momx ~= 0 or mo.momy ~= 0) then
            local movingmom = (mo.momx ~= 0 and mo.momx) or mo.momy
            movingmom = (movingmom > 0 and math.ceil(2/movingmom)) or math.floor(2/movingmom)
            if (leveltime%movingmom == 0) then
              local momx = (mo.momx > 0 and math.ceil(mo.momx)) or math.floor(mo.momx)
              local momy = (mo.momy > 0 and math.ceil(mo.momy)) or math.floor(mo.momy)
              if not TryMove(mo, momx, momy) then
                mo.momx = 0
                mo.momy = 0
                sound.playSound("stop.wav")
              end
            end
          end
        end
      end
      if (leveltime%60) == 0 then
        CheckMap(TILE_SPIKEON, TILE_SPIKEOFF, TILE_SPIKEOFF, TILE_SPIKEON)
      end
    end
  elseif gamestate == "editing" then
    leveltime = leveltime+1
    mouse.think()
  end
end

local tileAnimations = {
  [TILE_AFLOOR1] = 20,
  [TILE_RIGHTPUSHER1] = 30,
  [TILE_LEFTPUSHER1] = 30,
  [TILE_UPPUSHER1] = 30,
  [TILE_DOWNPUSHER1] = 30
}

local quadDrawingMethods = {
  none = function(mo, x, y)
    love.graphics.draw(mo.sprite, x, y, 0, scale)
  end,
  single = function(mo, x, y)
    love.graphics.draw(mo.sprite, mo.quads[1], x, y, 0, scale)
  end,
  directions = function(mo, x, y)
    love.graphics.draw(mo.sprite, mo.quads[math.floor((leveltime%20)/10)+mo.direction], x, y, 0, scale)
  end,
  movement = function(mo, x, y)
    local movingaxis = mo[mo.lastaxis or "x"]
      love.graphics.draw(mo.sprite, mo.quads[(movingaxis%#mo.quads)+1], x, y, 0, scale)
  end,
  default = function(mo, x, y)
    love.graphics.draw(mo.sprite, mo.quads[math.floor((leveltime%(#mo.quads*10))/10)+1], x, y, 0, scale)
  end
}

local function DrawTilemap()
  local centerx = GetStartX()
  local centery = GetStartY()
  --love.graphics.setColor(0, 1, 1, 1)
  for i,row in ipairs(tilemap) do
    for j,tile in ipairs(row) do
      if tile ~= 0 then
        local animationtime = tileAnimations[tile] or 1
        local animationframe = math.floor((leveltime%animationtime)/10)
        local x = centerx+j*math.floor(width*scale)
        local y = centery+i*math.floor(height*scale)
        if quads[tile+animationframe] then
          if debugmode and debugmode["Map info"] then
            love.graphics.print(tile+animationframe, x, y, 0, scale)
          else
            love.graphics.draw(tileset, quads[tile+animationframe], x, y, 0, scale)
          end
        else
          love.graphics.draw(errortile, x, y, 0, scale)
          love.graphics.print(tile, x, y, 0, scale)
        end
      end 
    end
  end
  for k, particle in pairs(particles.list) do
    local x = (centerx+particle.x*math.floor(width*scale))+(16*scale)
    local y = (centery+particle.y*math.floor(height*scale))+(16*scale)
    love.graphics.draw(particle.particle, x, y, 0, scale)
  end
  for k, mo in pairs(objects) do
    local x = centerx+mo.x*math.floor(width*scale)
    local y = centery+mo.y*math.floor(height*scale)
    if not quadDrawingMethods[mo.quadtype] then error('object "'..mo.type..'"('..k..') has an invalid quad type!') end
    quadDrawingMethods[mo.quadtype](mo, x, y)
  end
  if gamestate ~= "pause" and gamestate ~= "map settings" then
    love.graphics.setColor(1, 1, 1, (180%(math.min(math.max(leveltime, 120), 180))/60))
  else
    love.graphics.setColor(1, 1, 1, 0)
  end
  love.graphics.printf(gamemapname, 0, 50, screenwidth/2, "center", 0, 2, 2)
  love.graphics.setColor(1, 1, 1, 1)
  if wheelmoved > 0 and mouse.mode == "camera" then
    love.graphics.setColor(1, 1, 1, ((math.min(math.max(wheelmoved, 0), 60)%120)/60))
    love.graphics.printf("scale: "..scale, 0, screenheight-20, screenwidth, "center")
    wheelmoved = wheelmoved-1
    love.graphics.setColor(1, 1, 1, 1)
  end
end

local function DrawMenu()
  if gamestate == "title" then
    love.graphics.draw(titlescreen, (screenwidth/2)-150, 50)
    love.graphics.setColor(1, 1, 1, math.abs(math.sin(os.clock())))
    love.graphics.draw(titleglow, (screenwidth/2)-150, 50)
    love.graphics.setColor(1, 1, 1, 1)
  else
    love.graphics.printf(gamestate, 0, 50, screenwidth/2, "center", 0, 2, 2)
  end
  local ly = 140
  local x = (screenwidth/2)-225
  for i = 1,#menu[gamestate] do
    love.graphics.setColor(1, 1, 1, 1)
    if i == pointer then love.graphics.setColor(1, 1, 0, 1)
    elseif gamestate == "select level" and i > lastmap and tonumber(menu[gamestate][i].name) then 
      love.graphics.setColor(1, 1, 1, 0.5)
    elseif gamestate == "settings" and i == #menu.settings-1 then
      love.graphics.setColor(1, 0, 0, 1)
    end
    local rectangle = screenwidth
    local y = (((#menu[gamestate] > 7 or (gamestate == "sound test" and i == 1)) and 200) or 290)+(30*(i-1))
    if #menu[gamestate] == 1 or (gamestate == "sound test" and i == 2) then
      y = 480
    end
    if menu[gamestate][i].value and menu[gamestate][i].valuename then 
      rectangle = screenwidth-screenwidth/8
      love.graphics.printf(menu[gamestate][i].valuename, 0, y, screenwidth+screenwidth/8, "center")
    end
    if gamestate ~= "select level" then
      local name = menu[gamestate][i].name
      if (menu[gamestate][i].string or menu[gamestate][i].int) and menu[gamestate][i].name ~= "Map not found!" then
        name = name..(menu[gamestate][i].string or menu[gamestate][i].int)
      end
      if i == pointer and ((menu[gamestate][i].string and menu[gamestate][i].string:len() < 20)
      or (menu[gamestate][i].int and menu[gamestate][i].int:len() < 2))
      and menu[gamestate][i].name ~= "Map not found!" then
        name = name.."_"
      end
      love.graphics.printf(name, 0, y, rectangle, "center")
    else
      local unit = GetUnit(i)-1
      local offset = (unit >= 0 and unit) or 9
      local x = x+(50*offset)
      if i > 10 and GetUnit(i) == 1 then
        ly = ly+50
        x = ((love.window.getFullscreen() and 458) or 175)
      end
      if menu[gamestate][i].name == "back" then
        love.graphics.printf("back", 0, 470, screenwidth, "center")
      else
        love.graphics.print(menu[gamestate][i].name, x, ly)
      end
    end
  end
end

function GetDirectionalQuads(image)
  local quads = {}
  local imagewidth = image:getWidth()
  local imageheight = image:getHeight()
  quads[1] = love.graphics.newQuad(1, 1, 32, 32, imagewidth, imageheight)
  quads[2] = love.graphics.newQuad(35, 1, 32, 32, imagewidth, imageheight)
  quads[3] = love.graphics.newQuad(1, 35, 32, 32, imagewidth, imageheight)
  quads[4] = love.graphics.newQuad(35, 35, 32, 32, imagewidth, imageheight)
  quads[5] = love.graphics.newQuad(1, 69, 32, 32, imagewidth, imageheight)
  quads[6] = love.graphics.newQuad(35, 69, 32, 32, imagewidth, imageheight)
  quads[7] = love.graphics.newQuad(1, 103, 32, 32, imagewidth, imageheight)
  quads[8] = love.graphics.newQuad(35, 103, 32, 32, imagewidth, imageheight)
  return quads
end

function GetQuads(neededquads, image)
  local quads = {}
  local imagewidth = image:getWidth()
  local imageheight = image:getHeight()
  for i = 0,neededquads-1 do
    table.insert(quads, love.graphics.newQuad(1+(34*i), 1, 32, 32, imagewidth, imageheight))
  end
  return quads
end

function GetExtraQuad(image)
  return {love.graphics.newQuad(69, 1, 32, 32, image:getWidth(), image:getHeight())}
end

local snowsprite = love.graphics.newImage("Sprites/Chapter 2/snowball.png")
local snowmansprite = love.graphics.newImage("Sprites/Chapter 2/snowman.png")

local wallDesc = "\nMost objects can't walk in this tile"
local floorDesc = "\nObjects can walk in this tile"
local pushDesc = "\nObjects in this tile will be pushed to the "
local falsepushDesc = "\nThis tile will do nothing, use the first frame of the pusher"
local spikeDesc = "\nObjects in this tile will be destroyed"

tilesets = {
  ["forest.png"] = { --CHAPTER 1
    vanilla = true,
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
    vanilla = true,
    description = {
      [TILE_CUSTOM1] = "SNOWBALL".."\nA Snowball will spawn in this tile", 
      [TILE_CUSTOM2] = "STICKS WALL"..wallDesc.."\nIf a Snowball rams this wall it will collapse",
      [TILE_CUSTOM3] = "SNOWMAN".."\nA Snowman will spawn in this tile"
    },
    collision = {
      [TILE_CUSTOM1] = true,
      [TILE_CUSTOM2] = function(mo)
        if mo.type == "snowball" then
          tilemap[mo.y][mo.x] = TILE_FLOOR3
          RemoveObject(mo)
        else return false end
      end,
      [TILE_CUSTOM3] = true
    },
    tile = {
      [TILE_CUSTOM1] = function(x, y)
        SpawnObject(snowsprite, x, y, "snowball", GetQuads(4, snowsprite), "movement")
        tilemap[y][x] = TILE_FLOOR3
      end,
      [TILE_CUSTOM2] = nil,
      [TILE_CUSTOM3] = function(x, y)
        SpawnObject(snowmansprite, x, y, "snowman", GetDirectionalQuads(snowmansprite))
        tilemap[y][x] = TILE_FLOOR3
      end,
    }
  },
}
require "customhandler"
SearchCustom()

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

local drawModes = {
  ingame = function()
    DrawTilemap()
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
      love.graphics.printf("Press [R] to retry", 0, 20, screenwidth, "center")
    end
  end,
  title = DrawMenu,
  pause = function()
    love.graphics.setColor(1, 1, 1, 0.5)
    DrawTilemap()
    love.graphics.setColor(1, 1, 1, 1)
    DrawMenu()
  end,
  settings = DrawMenu,
  credits = function()
    local n = "\n"
    local credits =
    "-Coding-"..n..
    "Felix44"..n..n..
    "-Sprites-"..n..
    "Shadow|Pazzo"..n..
    "MAKYUNI"..n..n..
    "-Music-"..n..
    "MAKYUNI"..n..n..
    "-Maps-"..n..
    "Felix44"..n..
    "Fele88"
    love.graphics.printf(credits, 0, 120, screenwidth, "center")
    DrawMenu()
  end,
  ["select level"] = DrawMenu,
  ["select map"] = DrawMenu,
  editing = function()
    DrawTilemap()
    local centerx = GetStartX()
    local centery = GetStartY()
    local x = centerx+32*scale
    local y = centery+32*scale
    local xlen = math.floor((mapwidth*32*scale)/mapwidth)*mapwidth
    local ylen = math.floor((mapheight*32*scale)/mapheight)*mapheight
    love.graphics.rectangle("line", x, y, xlen, ylen)
    love.graphics.print(mouse.mode, 10, screenheight-20)
    if wheelmoved > 0 and mouse.mode == "editing" then
      love.graphics.setColor(1, 1, 1, ((math.min(math.max(wheelmoved, 0), 60)%120)/60))
      local tilesetx = screenwidth/15
      local tilesety = screenheight/15
      love.graphics.draw(tileset, tilesetx, tilesety)
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
      local x = centerx+mouse.x*math.floor(width*scale)
      local y = centery+mouse.y*math.floor(height*scale)
      love.graphics.draw(tileset, quads[mouse.tile], x, y, 0, scale)
    end
  end,
  ["map settings"] = function()
    love.graphics.setColor(1, 1, 1, 0.5)
    DrawTilemap()
    local x = GetStartX()+32*scale
    local y = GetStartY()+32*scale
    local xlen = math.floor((mapwidth*32*scale)/mapwidth)*mapwidth
    local ylen = math.floor((mapheight*32*scale)/mapheight)*mapheight
    love.graphics.rectangle("line", x, y, xlen, ylen)
    love.graphics.setColor(1, 1, 1, 1)
    DrawMenu()
  end,
  ["create map"] = DrawMenu,
  ["the end"] = function()
    local n = "\n"
    local msg =
    "This is the end of the Alpha"..n..
    "Thanks for playing!"..n..n..
    "Looking for something else to do?"..n..
    "Try the level editor!"..n..n..
    "see you next update!"
    love.graphics.printf(msg, 0, 120, screenwidth, "center")
    DrawMenu()
  end,
  ["sound test"] = function()
    love.graphics.printf(sound.soundtest[sound.soundtestpointer].subtitle, 0, 230, screenwidth, "center")
    love.graphics.printf("By: "..sound.soundtest[sound.soundtestpointer].creator, 0, 260, screenwidth, "center")
    if sound.musicname == sound.soundtest[sound.soundtestpointer].filename then love.graphics.setColor(1, 1, 0, 1) end
    love.graphics.line((screenwidth/2)-150, 360, (screenwidth/2)+150, 360)
    if sound.music then
      love.graphics.circle("line", ((screenwidth/2)-150)+(sound.music:tell()/sound.music:getDuration())*300, 360, 5)
    end
    love.graphics.setColor(1, 1, 1, 1)
    DrawMenu()
  end,
}

function debug.collectInfo()
  local count = collectgarbage("count")
  local debuginfo = "FPS: "..tostring(love.timer.getFPS()).."\nMemory: "..count.."\n"..
  "Gamemap: "..gamemap.."\n".."Lastmap: "..lastmap.."\n".."Gamestate: "..gamestate.."\n\n"
  debuginfo = debuginfo.."Mouse:\n"
  debuginfo = debuginfo.."tile: "..tostring(mouse.tile).."\n"
  debuginfo = debuginfo.."mode: "..tostring(mouse.mode).."\n"
  debuginfo = debuginfo.."scale: "..tostring(scale).."\n"
  debuginfo = debuginfo.."x: "..tostring(mouse.x).."\n"
  debuginfo = debuginfo.."y: "..tostring(mouse.y).."\n"
  debuginfo = debuginfo.."camerax: "..tostring(mouse.camerax).."\n"
  debuginfo = debuginfo.."cameray: "..tostring(mouse.cameray).."\n"
  if gamestate == "ingame" or gamestate == "pause" then
    debuginfo = debuginfo.."\nLeveltime: "..leveltime.."\nFrametime: "..frametime.."\nMap width: "..mapwidth.."\n"..
    "Map height: "..mapheight.."\n".."Tileset: "..tilesetname.."\n"
    if #objects > 0 then
      debuginfo = debuginfo.."\nObjects:".."\n"
      for k, mo in pairs(objects) do
        debuginfo = debuginfo..mo.type.." x:"..mo.x.."("..mo.momx..") y:"..mo.y.."("..mo.momy..") d:"..mo.direction.."("..mo.quadtype..") k:"..mo.key.."("..k..")\n"
      end
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
  if i > 38 then scale = 0.5 end
  return debuginfo, count, scale
end

function love.draw()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(font)
  font:setFilter("nearest", "nearest", 1)
  if drawModes[gamestate] then
    drawModes[gamestate]()
  else
    error("invalid gamestate!")
  end
  love.graphics.setColor(1, 1, 1, 1)
  if not debugmode and menu.settings[1].value == 1 then
    love.graphics.print("FPS: "..tostring(love.timer.getFPS()), 10, 10)
  elseif debugmode and debugmode["Game info"] then
    local debuginfo, count, scale = debug.collectInfo()
    if love.timer.getFPS() < 10 or count > 900 then
      love.graphics.setColor(1, 0, 0, 1)
    else
      love.graphics.setColor(1, 1, 0, 1)
    end
    love.graphics.print(debuginfo, 10, 10, 0, scale)
    love.graphics.setColor(1, 1, 1, 1)
  end
  if debugmode and debugmode["Graphic info"] then
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
  love.graphics.printf(VERSION, 0, screenheight-20, screenwidth, "right")
end

function love.quit()
  if dontquit then return false end
  SaveData()
  SaveLastmap()
end

--[[function love.errorhandler(msg)
  local stack = debug.traceback():gsub("\t", "")
  local errormsg = "An error accoured that forced the game to close\n\n"..msg.."\n\n"..stack
  love.window.showMessageBox("An error accoured!", errormsg, "error")
  local errorfile = io.open("Crash log "..os.date():gsub("/", "-"):gsub(":", "-")..".txt", "w+")
  errorfile:write("Crash log\nAccoured on: "..os.date().."\nGame version: "..VERSION.."\n\n"..msg.."\n\n"..stack.."\n\n"..
  (debug.collectInfo() and debug.collectInfo()) or "")
  errorfile:close()
end]]
--[[function love.load()
	local img = love.graphics.newImage("Sprites/Particles/leaf.png")

	psystem = love.graphics.newParticleSystem(img, 60)
	psystem:setParticleLifetime(7, 10)
	psystem:setEmissionRate(5)
	psystem:setSizeVariation(1)
	psystem:setLinearAcceleration(20, 20, 80, 80)
  psystem:setSpin(1, 5)
	psystem:setColors(1, 1, 1, 1, 1, 1, 1, 0)
end

function love.draw()
	love.graphics.draw(psystem, -20, -20)
end

function love.update(dt)
	psystem:update(dt)
end]]