local sound = require "music"
local particles = require "particles"
local coins = require "coins"

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

local playersprite = love.graphics.newImage("Sprites/player.png")
local keysprite = love.graphics.newImage("Sprites/key.png")
local enemysprite = love.graphics.newImage("Sprites/Enemies/forest.png")

local function GetMapData(mapname)
  return love.filesystem.read(mapspath..mapname)
end

function LoadMap(mapname)
  objects = {}
  voids = {}
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
    enemysprite = love.graphics.newImage(path.."Enemies/"..tilesetname)
    tileset = love.graphics.newImage(path.."Tiles/"..tilesetname)
  end
  local playerx, playery
  tilemap = {}
  local ReadTile = string.gmatch(ReadLine(), "..")
  for y = 1,mapheight do
    tilemap[y] = {}
    for x = 1,mapwidth do
      tile = tonumber(ReadTile() or 0)
      tilemap[y][x] = tile or TILE_EMPTY
      if tile == TILE_START then
        playerx = x
        playery = y
      elseif tile == TILE_KEY then
        SpawnObject(keysprite, x, y, "key")
        tilemap[y][x] = TILE_FLOOR1
      elseif tile == TILE_ENEMY then
        SpawnObject(enemysprite, x, y, "enemy", GetDirectionalQuads(enemysprite), tilesets[tilesetname].enemyquadtype or "directions")
        tilemap[y][x] = TILE_FLOOR1
      elseif (tile == TILE_CUSTOM1 or tile == TILE_CUSTOM2 or tile == TILE_CUSTOM3)
      and type(tilesets[tilesetname].tile[tile]) == "function" then
        tilesets[tilesetname].tile[tile](x, y)
      end
    end
  end
  local loadedmap = tonumber(mapname:match("%d+%d"))
  if coins[loadedmap] and not coins[loadedmap].got then
    SpawnObject(coins.sprite, coins[loadedmap].x, coins[loadedmap].y, "coin", coins.quads, "default")
  end
  if customEnv then customEnv.tilemap = tilemap end
  if playerx and playery then
    player = SpawnObject(playersprite, playerx, playery, "player")
    if customEnv then customEnv.player = player end
  end
  leveltime = 0
  frametime = 0
  flash = 1
  darkness = 0
  gamestate = "ingame"
  mouse.camerax = 0
  mouse.cameray = 0
  mouse.mode = "camera"
  scale = ((mapwidth >= 20 or mapheight >= 20) and GetScale((mapwidth >= mapheight and mapwidth) or mapheight )) or 1
  love.window.requestAttention()
  if customEnv and customEnv.MapLoad and type(customEnv.MapLoad) == "function" then
    customEnv.MapLoad(gamemap, tilesetname)
  end
  particles.reset()
  particles.reset(PARTICLE_HELP)
  if tilesets[tilesetname].snow and not particles.list[PARTICLE_SNOW] then
    particles.spawnSnow()
  elseif not tilesets[tilesetname].snow then
    particles.reset(PARTICLE_SNOW)
  end
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
        if tilemap[y][x] == tocheck then
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
  return replaced
end

function IterateMap(tile, func)
  for y = 1, mapheight do
    for x = 1, mapwidth do
      if tilemap[y][x] == tile then func(x, y) end
    end
  end
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
  if oldtileset ~= tilesetname then
    enemysprite = love.graphics.newImage(path.."Enemies/"..tilesetname)
    tileset = love.graphics.newImage(path.."Tiles/"..tilesetname)
  end
  wheelmoved = 0
  flash = 1
  darkness = 0
  mouse.mode = "editing"
  love.window.requestAttention()
  particles.reset()
  particles.reset(41)
  return true
end