local coindef = require("ffi").typeof("coindef")
local sprite = love.graphics.newImage("Sprites/coin.png")

local coins = {
	sprite = sprite,
	path = "Sprites/coin.png",
	quads = GetQuads(8, sprite),
	hudtimer = 0,
	soundtest = {name = "Lovely Bonus", subtitle = "Bonus levels", creator = "MAKYUNI", filename = "bonus.ogg"};
	[4] = coindef(13, 9, false),--{x = 13, y = 9, got = false},
	[5] = coindef(18, 5, false),--{x = 18, y = 5, got = false},
	[9] = coindef(1, 1, false),--{x = 1, y = 1, got = false},
	[11] = coindef(13, 13, false),--{x = 13, y = 13, got = false},
	[13] = coindef(18, 16, false),--{x = 18, y = 16, got = false},
	[14] = coindef(10, 13, false),--{x = 10, y = 13, got = false},
	[16] = coindef(24, 3, false),--{x = 24, y = 3, got = false},
	[21] = coindef(6, 5, false),--{x = 6, y = 5, got = false},
	[24] = coindef(6, 3, false),--{x = 6, y = 3, got = false},
	[25] = coindef(17, 9, false),--{x = 17, y = 9, got = false},
	[26] = coindef(17, 11, false),--{x = 17, y = 11, got = false}
}

function coins.count()
	local coinstotal = 0
	local coinsgot = 0
	for k, coin in pairs(coins) do
		if type(k) == "number" then
			coinstotal = coinstotal+1
			if coin.got then
				coinsgot = coinsgot+1
			end
		end
	end
	return coinsgot, coinstotal
end

function coins.reset()
	for k, v in pairs(coins) do
		if type(k) == "number" then
			coins[k] = nil
		end
	end
end

return coins