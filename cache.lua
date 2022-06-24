local quadcache = {}

local function CacheQuad(x, y, width, height, sw, sh)
	local quadid = tostring(x).."-"..y.."-"..width.."-"..height.."-"..sw.."-"..sh
	if not quadcache[quadid] then quadcache[quadid] = love.graphics.newQuad(x, y, width, height, sw, sh) end
	return quadcache[quadid]
end

function GetDirectionalQuads(image)
	local quads = {}
	image = GetImage(image)
	local imagewidth = image:getWidth()
	local imageheight = image:getHeight()
	quads[1] = CacheQuad(1, 1, 32, 32, imagewidth, imageheight)
	quads[2] = CacheQuad(35, 1, 32, 32, imagewidth, imageheight)
	quads[3] = CacheQuad(1, 35, 32, 32, imagewidth, imageheight)
	quads[4] = CacheQuad(35, 35, 32, 32, imagewidth, imageheight)
	quads[5] = CacheQuad(1, 69, 32, 32, imagewidth, imageheight)
	quads[6] = CacheQuad(35, 69, 32, 32, imagewidth, imageheight)
	quads[7] = CacheQuad(1, 103, 32, 32, imagewidth, imageheight)
	quads[8] = CacheQuad(35, 103, 32, 32, imagewidth, imageheight)
	return quads
end

function GetQuads(neededquads, image)
	local quads = {}
	if type(image) == "string" then
		image = GetImage(image)
	end
	local imagewidth = image:getWidth()
	local imageheight = image:getHeight()
	for i = 0,neededquads-1 do
		table.insert(quads, CacheQuad(1+(34*i), 1, 32, 32, imagewidth, imageheight))
	end
	return quads
end

function GetExtraQuad(image)
	image = GetImage(image)
	return {CacheQuad(69, 1, 32, 32, image:getWidth(), image:getHeight())}
end

function CacheQuadArray(quads)
	local key = tonumber(tostring(quads):sub(7))
	quadcache[key] = quads
	return key
end

function GetQuadArray(key)
	return quadcache[key]
end

local imagecache = {}

local ffiString = require("ffi").string

function GetImage(path)
	if not imagecache[path] then
		local newImage = love.graphics.newImage(ffiString(path))
		newImage:setWrap("repeat", "repeat")
		imagecache[path] = newImage
	end
	return imagecache[path]
end

function GetCacheInfo()
	local cacheinfo = ""
	for k, _ in pairs(imagecache) do
		cacheinfo = cacheinfo .. k .. "\n"
	end
	return cacheinfo
end