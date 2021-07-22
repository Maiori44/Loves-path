local coins = {
  sprite = love.graphics.newImage("Sprites/coin.png"),
  quads = GetQuads(8, love.graphics.newImage("Sprites/coin.png")),
  hudtimer = 0;
  [0] = {x = 2, y = 2, got = false},
  [4] = {x = 13, y = 9, got = false},
  [5] = {x = 18, y = 5, got = false},
  [9] = {x = 1, y = 1, got = false},
  [10] = {x = 3, y = 5, got = false}
}

return coins