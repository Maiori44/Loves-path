local sound = require "music"
local coins = require "coins"

local path = (love.filesystem.isFused() and "Source/Custom/") or "Custom/"

local readOnlyValues = {
  VERSION = "constant",
  TILE_EMPTY = "TILE_* constant",
  TILE_WALL1 = "TILE_* constant",
  TILE_WALL2 = "TILE_* constant",
  TILE_WALL3 = "TILE_* constant",
  TILE_WALL4 = "TILE_* constant",
  TILE_WALL5 = "TILE_* constant",
  TILE_WALL6 = "TILE_* constant",
  TILE_WALL7 = "TILE_* constant",
  TILE_WALL8 = "TILE_* constant",
  TILE_WALL9 = "TILE_* constant",
  TILE_FLOOR1 = "TILE_* constant",
  TILE_FLOOR2 = "TILE_* constant",
  TILE_FLOOR3 = "TILE_* constant",
  TILE_LOCK = "TILE_* constant",
  TILE_KEY = "TILE_* constant",
  TILE_REDSWITCH = "TILE_* constant",
  TILE_BLUESWITCH = "TILE_* constant",
  TILE_START = "TILE_* constant",
  TILE_GOAL = "TILE_* constant",
  TILE_REDWALLON = "TILE_* constant",
  TILE_BLUEWALLON = "TILE_* constant",
  TILE_REDWALLOFF = "TILE_* constant",
  TILE_BLUEWALLOFF = "TILE_* constant",
  TILE_AFLOOR1 = "TILE_* constant",
  TILE_AFLOOR2 = "TILE_* constant",
  TILE_RIGHTPUSHER1 = "TILE_* constant",
  TILE_RIGHTPUSHER2 = "TILE_* constant",
  TILE_RIGHTPUSHER3 = "TILE_* constant",
  TILE_LEFTPUSHER1 = "TILE_* constant",
  TILE_LEFTPUSHER2 = "TILE_* constant",
  TILE_LEFTPUSHER3 = "TILE_* constant",
  TILE_UPPUSHER1 = "TILE_* constant",
  TILE_UPPUSHER2 = "TILE_* constant",
  TILE_UPPUSHER3 = "TILE_* constant",
  TILE_DOWNPUSHER1 = "TILE_* constant",
  TILE_DOWNPUSHER2 = "TILE_* constant",
  TILE_DOWNPUSHER3 = "TILE_* constant",
  TILE_SPIKEON = "TILE_* constant",
  TILE_SPIKEOFF = "TILE_* constant",
  TILE_SPIKE = "TILE_* constant",
  TILE_BRIDGE = "TILE_* constant",
  TILE_CRACKEDBRIDGE = "TILE_* constant",
  TILE_SLIME = "TILE_* constant",
  TILE_CHASM1 = "TILE_* constant",
  TILE_CHASM2 = "TILE_* constant",
  TILE_ENEMY = "TILE_* constant",
  TILE_CUSTOM1 = "TILE_* constant",
  TILE_CUSTOM2 = "TILE_* constant",
  TILE_CUSTOM3 = "TILE_* constant",
  DIR_LEFT = "DIR_* constant",
  DIR_RIGHT = "DIR_* constant",
  DIR_UP = "DIR_* constant",
  DIR_DOWN = "DIR_* constant",
  player = "pointer",
  tilemap = "pointer",
  leveltime = "checker",
  timer = "checker",
}

local tilesetFlagsTypes = {
  snow = "boolean",
  dark = "boolean",
  rain = "table",
  thunder = "boolean",
  glitch = "boolean",
  negative = "boolean",
  enemyquadtype = "string",
  bridgeshardcolor = "table",
  playersprite = "userdata",
  vanilla = "nil",
}

function CheckArgument(n, funcname, arg, ctype, bad)
  local atype = type(arg)
  if atype ~= ctype then
    error("bad "..(bad or "argument").." #"..n.." to '"..funcname.."' ("..ctype.." expected, got "..atype..")")
  end
end

function SearchCustom(modname)
  path = path..modname
  if love.filesystem.getInfo(path, "directory") then
    coins.reset()
    sound.soundtest = {{name = "Love's path", subtitle = "Main menu", creator = "MAKYUNI", filename = "menu.ogg"}}
    lastmap = 1
    mapspath = path.."/Maps/"
    GetAllMaps()
    savefile = modname..".dat"
    LoadData()
    local ok, CustomInfo = pcall(love.filesystem.load, path.."/custom.lua")
    if not CustomInfo then
      customEnv = {}
      return
    end
    if not ok then love.window.showMessageBox("Failed to load custom.lua!", CustomInfo, "error") return end
    local musics = love.filesystem.getDirectoryItems(path.."/Music")
    if musics then
      for _, musicname in ipairs(musics) do
        if musicname:sub(#musicname - 3) == ".ogg" then
          table.insert(possibleMusic, musicname)
        end
      end
    end
    customEnv = {
      --MISCELLANEOUS LIBRARY--
      VERSION = VERSION,
      print = print,
      error = error,
      type = type,
      tostring = tostring,
      tonumber = tonumber,
      ipairs = ipairs,
      pairs = pairs,
      KeyPressed = nil,
      SetMessageBox = function(title, text)
        messagebox.setMessage(tostring(title), tostring(text))
      end,
      SetNotifcation = function(text)
        notification.setMessage(tostring(text))
      end,

      --SOUND LIBRARY--
      PlaySound = sound.playSound,
      AddSoundTestEntry = function(name, subtitle, creator, filename, required)
        CheckArgument(1, "AddSoundTestEntry", name, "string")
        CheckArgument(4, "AddSoundTestEntry", filename, "string")
        table.insert(sound.soundtest,
        {name = name, subtitle = subtitle or "", creator = creator or "", filename = filename, require = tonumber(required)})
      end,
      
      --MAP LIBRARY--
      TILE_EMPTY = 0,
      TILE_WALL1 = 1,
      TILE_WALL2 = 2,
      TILE_WALL3 = 3,
      TILE_WALL4 = 4,
      TILE_WALL5 = 5,
      TILE_WALL6 = 6,
      TILE_WALL7 = 7,
      TILE_WALL8 = 8,
      TILE_WALL9 = 9,
      TILE_FLOOR1 = 10,
      TILE_FLOOR2 = 11,
      TILE_FLOOR3 = 12,
      TILE_LOCK = 13,
      TILE_KEY = 14,
      TILE_REDSWITCH = 15,
      TILE_BLUESWITCH = 16,
      TILE_START = 17,
      TILE_GOAL = 18,
      TILE_REDWALLON = 19,
      TILE_BLUEWALLON = 20,
      TILE_REDWALLOFF = 21,
      TILE_BLUEWALLOFF = 22,
      TILE_AFLOOR1 = 23,
      TILE_AFLOOR2 = 24,
      TILE_RIGHTPUSHER1 = 25,
      TILE_RIGHTPUSHER2 = 26,
      TILE_RIGHTPUSHER3 = 27,
      TILE_LEFTPUSHER1 = 28,
      TILE_LEFTPUSHER2 = 29,
      TILE_LEFTPUSHER3 = 30,
      TILE_UPPUSHER1 = 31,
      TILE_UPPUSHER2 = 32,
      TILE_UPPUSHER3 = 33,
      TILE_DOWNPUSHER1 = 34,
      TILE_DOWNPUSHER2 = 35,
      TILE_DOWNPUSHER3 = 36,
      TILE_SPIKEON = 37,
      TILE_SPIKEOFF = 38,
      TILE_SPIKE = 39,
      TILE_BRIDGE = 40,
      TILE_CRACKEDBRIDGE = 41,
      TILE_SLIME = 42,
      TILE_CHASM1 = 43,
      TILE_CHASM2 = 44,
      TILE_ENEMY = 45,
      TILE_CUSTOM1 = 46,
      TILE_CUSTOM2 = 47,
      TILE_CUSTOM3 = 48,
      tilemap = tilemap,
      leveltime = nil,
      timer = nil,
      SetTimer = function(time)
        timer = time
      end,
      CheckMap = CheckMap,
      IterateMap = IterateMap,
      AddCustomCoin = function(map, x, y)
        CheckArgument(1, "AddCustomCoin", map, "number")
        CheckArgument(2, "AddCustomCoin", x, "number")
        CheckArgument(3, "AddCustomCoin", y, "number")
        coins[map] = {x = x, y = y, got = false}
        LoadData()
      end,
      UpdateFrame = nil,
      MapLoad = nil,
      
      --SPRITES LIBRARY--
      GetImage = function(filepath)
        return GetImage(path.."/"..filepath)
      end,
      GetDirectionalQuads = GetDirectionalQuads,
      GetQuads = GetQuads,
      GetExtraQuad = GetExtraQuad,
      
      --OBJECTS LIBRARY--
      DIR_LEFT = 1,
      DIR_RIGHT = 3,
      DIR_UP = 5,
      DIR_DOWN = 7,
      player = player,
      SpawnObject = SpawnObject,
      RemoveObject = RemoveObject,
      RemoveMovingObject = RemoveMovingObject,
      RemoveStandingObject = RemoveStandingObject,
      RemoveCollidedObject = RemoveCollidedObject,
      EraseObject = EraseObject,
      DamageObject = DamageObject,
      StopObject = StopObject,
      PushObject = PushObject,
      SlowPushObject = SlowPushObject,
      SearchObject = SearchObject,
      TryMove = TryMove,
      PredictMove = PredictMove,
      DirectionMomentum = DirectionMomentum,
      MomentumDirection = MomentumDirection,
      GetDistance = GetDistance,
      DashObject = DashObject,
      FireShot = FireShot,
      FacePlayer = FacePlayer,
      EndLevel = EndLevel,
      AddObjectType = AddObjectType,
      AddObjectCollision = function(motype, collidedmotype, collision)
        CheckArgument(1, "AddObjectCollision", motype, "string")
        CheckArgument(2, "AddObjectCollision", collidedmotype, "string")
        if not collisions[motype] then error('object type "'..motype..'" does not exist!') end
        if not collisions[collidedmotype] then error('object type "'..collidedmotype..'" does not exist!') end
        if collisions[motype][collidedmotype] then
          error('object type "'..motype..'" arleady has collisions defined for "'..collidedmotype..'"!')
        end
        collisions[motype][collidedmotype] = collision
      end,
      
      --TILESET LIBRARY--
      wallDesc = "\nMost objects can't walk in this tile",
      floorDesc = "\nObjects can walk in this tile",
      spikeDesc = "\nObjects in this tile will be destroyed",
      AddCustomTileset = function(tilesetname, description, collision, tile, flags)
        CheckArgument(1, "AddCustomTileset", tilesetname, "string")
        if tilesets[tilesetname] then error('tileset "'..tilesetname..'" arleady exists!') end
        tilesets[tilesetname] = {
          description = setmetatable(description or {}, {__index = function() return "MISSING INFO!" end}),
          collision = setmetatable(collision or {}, {__index = function() return true end}),
          tile = setmetatable(tile or {}, {__index = function() return nil end})
        }
        if flags then
          local num = 0
          for k, v in pairs(flags) do
            num = num + 1
            if tilesetFlagsTypes[k] then
              CheckArgument(num, k, v, tilesetFlagsTypes[k], "tileset flag value")
              tilesets[tilesetname][k] = v
            else
              error("Unknown tileset flag \""..k.."\"")
            end
          end
        end
        table.insert(possibleTilesets, tilesetname)
      end,
    }
    setfenv(CustomInfo, setmetatable({}, {
      __index = function(t, k) if customEnv[k] then return customEnv[k] end end,
      __newindex = function(t, k, v)
        if readOnlyValues[k] then
          error('attempt to modify read-only value "'..k..'" ('..readOnlyValues[k]..')')
          return
        end
        customEnv[k] = v
      end
    }))
    local ok, errormsg2 = pcall(CustomInfo)
    if not ok then love.window.showMessageBox("Error while loading custom.lua!", errormsg2, "error") return end
  end
end

function GetTilesetPath()
  if tilesetname == "" then tilesetname = "forest.png" end
  local testpath = path
  if tilesets[tilesetname] and type(tilesets[tilesetname]) == "table" then
    testpath = (tilesets[tilesetname].vanilla and "Sprites") or path
  else
    if tilesetname == "forest.png" then
      error("the default tileset is missing.\n"..
      "If you did not alter the source code in any way, contact me!")
    end
    local errorname = "Error while loading tileset!"
    local errormsg = 'the tileset "'..tilesetname..'" was not found\n'.."the default tileset will be used instead."
    messagebox.setMessage(errorname, errormsg, true)
    tilesetname = "forest.png"
    return GetTilesetPath()
  end
  if love.filesystem.getInfo(testpath, "directory")
  and love.filesystem.getInfo(testpath.."/Tiles/"..tilesetname)
  and love.filesystem.getInfo(testpath.."/Enemies/"..tilesetname) then
    return testpath.."/"
  else
    if tilesetname == "forest.png" then
      error("The default tileset is broken.\n"..
      "Undo any modifications done to it or reinstall the .exe")
    end
    local errorname = "Error while loading tileset!"
    local errormsg = 'The tileset "'..tilesetname..'" has missing sprites\n'..
    "the default tileset will be used instead."
    messagebox.setMessage(errorname, errormsg, true)
    tilesetname = "forest.png"
    return GetTilesetPath()
  end
end