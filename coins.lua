local sprite = love.graphics.newImage("Sprites/coin.png")

local coins = {
  sprite = sprite,
  quads = GetQuads(8, sprite),
  hudtimer = 0;
  [4] = {x = 13, y = 9, got = false},
  [5] = {x = 18, y = 5, got = false},
  [8] = {x = 1, y = 1, got = false},
  [11] = {x = 13, y = 13, got = false}
}

return coins