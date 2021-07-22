local coins = {
  sprite = love.graphics.newImage("Sprites/coin.png"),
  quads = GetQuads(8, love.graphics.newImage("Sprites/coin.png")),
  hudtimer = 0;
  [0] = {x = 2, y = 2, got = false},
  [1] = {x = 2, y = 2, got = false},
  [10] = {x = 3, y = 5, got = false}
}

return coins