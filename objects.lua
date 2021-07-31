local sound = require "music"
local particles = require "particles"
local coins = require "coins"

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
collisions = {}
thinkers = {}

function SpawnObject(sprite, x, y, type, quads, quadtype, direction)
  if not collisions[type] then error('object type "'..type..'" does not exist!') end
  table.insert(objects, {
    sprite = sprite,
    quads = quads,
    quadtype = (quadtype and quadtype) or (not quads and "none") or (#quads == 1 and "single")
    or (#quads == 8 and "directions") or "default",
    x = x,
    y = y,
    momx = 0,
    momy = 0,
    direction = direction or DIR_LEFT,
    type = type,
    key = #objects+1
  })
  return objects[#objects]
end

function RemoveObject(mo)
  objects[mo.key] = nil
  if mo.type == "player" then particles.spawnShards(player.x, player.y, 1) player = nil
  else particles.spawnShards(mo.x, mo.y, 0.5) end
  sound.playSound("boom.wav")
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
  if mo.type == "player" then player = nil end
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

local function ThrustMovingObject(mo, momx, momy, thrustx, thrusty)
  if momx == 0 and momy == 0 then return end
  mo.momx = thrustx
  mo.momy = thrusty
end

local function CrackBridge(mo)
  if momx == 0 and momy == 0 then return end
  tilemap[mo.y][mo.x] = TILE_CRACKEDBRIDGE
end

local function DestroyBridge(mo, momx, momy)
  if momx == 0 and momy == 0 then return end
  tilemap[mo.y][mo.x] = TILE_EMPTY
  if tilemap[mo.y+1][mo.x] and tilemap[mo.y+1][mo.x] == TILE_CHASM2 then
    tilemap[mo.y+1][mo.x] = TILE_EMPTY
  end
  local uppertile = tilemap[mo.y-1][mo.x]
  if uppertile and uppertile ~= TILE_EMPTY and uppertile ~= TILE_BRIDGE and uppertile ~= TILE_CRACKEDBRIDGE
  and uppertile ~= TILE_ and uppertile ~= TILE_CHASM1 and uppertile ~= TILE_CHASM2 then
    tilemap[mo.y][mo.x] = TILE_CHASM1
  elseif uppertile and (uppertile == TILE_BRIDGE or uppertile == TILE_CRACKEDBRIDGE) then
    tilemap[mo.y][mo.x] = TILE_CHASM2
  end
end

function StopObject(mo, momx, momy)
  momx = momx or mo.momx
  momy = momy or mo.momy
  if momx == 0 and momy == 0 then return end
  mo.momx = 0
  mo.momy = 0
end

local function PusherCheck(mo)
  local mopos = tilemap[mo.y][mo.x]
  if mopos == TILE_EMPTY or mopos == TILE_CHASM1 or mopos == TILE_CHASM2 then
    RemoveObject(mo)
  end
end

function PushObject(_, obstmo, momx, momy)
  obstmo.lastaxis = (momx ~= 0 and "x") or "y"
  PusherCheck(obstmo)
  if not TryMove(obstmo, momx, momy) then return false end
end

function SlowPushObject(mo, obstmo, momx, momy)
  obstmo.momx = momx/1.4
  obstmo.momy = momy/1.4
  obstmo.lastaxis = (momx ~= 0 and "x") or "y"
  PusherCheck(mo)
  return false
end

function SearchObject(x, y)
  for k, mo in pairs(objects) do
    if mo.type ~= "player" and mo.x == x and mo.y == y then return mo end
  end
end

function TryMove(mo, momx, momy)
  if not mo then return end
  collisions[mo.type][TILE_CUSTOM1] = tilesets[tilesetname].collision[TILE_CUSTOM1]
  collisions[mo.type][TILE_CUSTOM2] = tilesets[tilesetname].collision[TILE_CUSTOM2]
  collisions[mo.type][TILE_CUSTOM3] = tilesets[tilesetname].collision[TILE_CUSTOM3]
  if collisions[mo.type] and tilemap[mo.y+momy] and collisions[mo.type][tilemap[mo.y+momy][mo.x+momx]] then
    local obstmo = SearchObject(mo.x+momx, mo.y+momy)
    if debugmode and debugmode["Noclip"] then obstmo = nil end
    if obstmo then
      collisions[obstmo.type][TILE_CUSTOM1] = tilesets[tilesetname].collision[TILE_CUSTOM1]
      collisions[obstmo.type][TILE_CUSTOM2] = tilesets[tilesetname].collision[TILE_CUSTOM2]
      collisions[obstmo.type][TILE_CUSTOM3] = tilesets[tilesetname].collision[TILE_CUSTOM3]
      if not collisions[mo.type][obstmo.type] then return false end
      local check
      if type(collisions[mo.type][obstmo.type]) == "function" then
        check = collisions[mo.type][obstmo.type](mo, obstmo, momx, momy)
      else
        check = true
      end
      if check ~= nil then return check end
    end
    mo.y = mo.y+momy
    mo.x = mo.x+momx
    if type(collisions[mo.type][tilemap[mo.y][mo.x]]) == "function" then
      local check = collisions[mo.type][tilemap[mo.y][mo.x]](mo, momx, momy)
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

function GetDistance(mo1, mo2)
  return mo1.x-mo2.x, mo1.y-mo2.y
end

function DashObject(mo)
  mo.momx, mo.momy = DirectionMomentum(mo.direction)
end

function FireShot(mo, sprite, quads, type)
  local bullet = SpawnObject(sprite, mo.x, mo.y, type or "bullet", quads, nil, mo.direction)
  DashObject(bullet)
  return bullet
end

function FacePlayer(mo)
  distx, disty = GetDistance(mo, player)
  local py = (disty/math.abs(disty))*-1
  local px = (distx/math.abs(distx))*-1
  if ((distx ~= 0 and distx < disty and collisions[mo.type][tilemap[mo.y][mo.x-distx]])
  or (disty == 0 or not collisions[mo.type][tilemap[mo.y+py][mo.x]])) and collisions[mo.type][tilemap[mo.y][mo.x+px]] then
    mo.direction = MomentumDirection(px, 0) or DIR_LEFT
  else
    mo.direction = MomentumDirection(0, py) or DIR_LEFT
  end
end

function AddObjectType(typename, collision, thinker)
  CheckArgument(1, "AddObjectType", typename, "string")
  if collisions[typename] then error('object type "'..typename..'" arleady exists!') end
  collisions[typename] = setmetatable(collision or {}, {
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
      [TILE_RIGHTPUSHER1] = function(mo, momx, momy) ThrustMovingObject(mo, momx, momy, 1, 0) end,
      [TILE_LEFTPUSHER1] = function(mo, momx, momy) ThrustMovingObject(mo, momx, momy, -1, 0) end,
      [TILE_UPPUSHER1] = function(mo, momx, momy) ThrustMovingObject(mo, momx, momy, 0, -1) end,
      [TILE_DOWNPUSHER1] = function(mo, momx, momy) ThrustMovingObject(mo, momx, momy, 0, 1) end,
      [TILE_SPIKEON] = RemoveObject,
      [TILE_SPIKEOFF] = true,
      [TILE_SPIKE] = RemoveObject,
      [TILE_BRIDGE] = CrackBridge, 
      [TILE_CRACKEDBRIDGE] = DestroyBridge,
      [TILE_SLIME] = StopObject,
      [TILE_CHASM1] = RemoveMovingObject,
      [TILE_CHASM2] = RemoveMovingObject,
      [TILE_ENEMY] = true,
    }
  })
  if thinker and type(thinker) == "function" then thinkers[typename] = thinker end
end

----OBJECT DEFINITIONS

---MISC

--PLAYER
AddObjectType("player", {
  [TILE_GOAL] = function()
  gamemap = gamemap+1
  lastmap = math.max(gamemap+1, lastmap)
  SaveData()
  if gamemap == #menu["select level"]-1 then
    pointer = 1
    gamestate = "the end"
    sound.setMusic("")
    return
  end
  local errorcheck = LoadMap("map"..GetMapNum(gamemap)..".map")
  if errorcheck and errorcheck == "error" then
    gamemap = gamemap-1
    local errorcheck2 = LoadMap("map"..GetMapNum(gamemap)..".map")
    if errorcheck2 and errorcheck2 == "error" then
      local finalcheck = LoadMap("map00.map")
      if finalcheck and finalcheck == "error" then
        error("Could not find a map to load\nthe Maps folder may be corrupted, reinstall the game and replace it.")
      end
    end
  end
  sound.reset()
  sound.playSound("win.wav")
  end,
  coin = function(_, obstmo)
    coins.hudtimer = 160
    coins[gamemap].got = true
    sound.playSound("coin.wav")
    particles.spawnStars(obstmo.x, obstmo.y)
    EraseObject(obstmo) end,
  key = PushObject,
  enemy = RemoveObject,
  bullet = RemoveObject,
  snowball = SlowPushObject,
  snowman = RemoveObject,
})

--COIN
AddObjectType("coin")

--KEY
AddObjectType("key", {
  [TILE_FLOOR1] = StopObject,
  [TILE_FLOOR2] = StopObject,
  [TILE_FLOOR3] = StopObject,
  [TILE_LOCK] = function(mo)
    tilemap[mo.y][mo.x] = TILE_FLOOR1
    objects[mo.key] = nil
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
AddObjectType("enemy", {key = PushObject--[[, snowball = SlowPushObject]]}, function(mo)
  if (leveltime%(61-math.floor(gamemap/2)) > 0) or not player or (mo.momx ~= 0 and mo.momy ~= 0) then return end
  FacePlayer(mo)
  DashObject(mo)
  particles.spawnSmoke(mo.x, mo.y)
end)

--BULLET
AddObjectType("bullet", {
  [TILE_EMPTY] = true,
  [TILE_RIGHTPUSHER1] = true,
  [TILE_LEFTPUSHER1] = true,
  [TILE_UPPUSHER1] = true,
  [TILE_DOWNPUSHER1] = true,
  [TILE_SPIKEON] = true,
  [TILE_SPIKE] = true,
  [TILE_SLIME] = true,
  [TILE_CHASM1] = true,
  [TILE_CHASM2] = true,
  bullet = function(mo, obstmo) RemoveObject(mo) RemoveObject(obstmo) end,
}, RemoveStandingObject)

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
  [TILE_REDWALLON] = RemoveObject,
  [TILE_BLUEWALLON] = RemoveObject,
  [TILE_RIGHTPUSHER1] = RemoveObject,
  [TILE_LEFTPUSHER1] = RemoveObject,
  [TILE_UPPUSHER1] = RemoveObject,
  [TILE_DOWNPUSHER1] = RemoveObject,
  player = PushObject,
  key = PushObject,
  enemy = RemoveCollidedObject,
  snowball = SlowPushObject,
  snowman = RemoveCollidedObject,
})

--SNOWMAN
AddObjectType("snowman", {}, function(mo)
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

