local lovebug = {}
local d = lovebug

function lovebug.log(text, color)
	local l = {value = text, color = color}
	d.lines[#d.lines + 1] = l
end

d.lines = {}
lovebug.log("Debug Console")
d.history = {}
d.historyPointer = 0
d.input = ""
d.indicator = 0
d.offset = 0
d.show = false --Set back to falses
d.active = false
d.fontSize = love.graphics.getDPIScale()*16
d.spacing = 2
d.font = love.graphics.newFont(d.fontSize)
d.displayLength = 12
d.width = love.graphics.getWidth()
d.height = 16 + (1 + d.displayLength)*(d.fontSize + d.spacing)
for i=0,d.displayLength-4 do lovebug.log("") end
lovebug.log("Press 'f3' or type 'close' to close this window.")
lovebug.log("")

d.shift = {}
d.shift["1"] = "!"
d.shift["2"] = "\""
d.shift["3"] = "£"
d.shift["4"] = "$"
d.shift["5"] = "%"
d.shift["6"] = "&"
d.shift["7"] = "/"
d.shift["8"] = "("
d.shift["9"] = ")"
d.shift["0"] = "="
d.shift["["] = "{"
d.shift["]"] = "}"
d.shift["-"] = "_"
d.shift["="] = "+"
d.shift["."] = ">"
d.shift[","] = "<"
d.shift["'"] = '"'
d.shift[";"] = ':'
d.shift["\\"] = '|'

d.variables = {
	gameinfo = "debugmode.gameinfo = not debugmode.gameinfo",
	cache = "debugmode.cache = not debugmode.cache",
	camera = "debugmode.camera = not debugmode.camera",
	buttons = "debugmode.buttons = not debugmode.buttons",
	graphics = "debugmode.graphics = not debugmode.graphics",
	noclip = "debugmode.noclip = not debugmode.noclip",
	slowdown = "debugmode.slowdown = not debugmode.slowdown"
}
d.variables.msx = love.mouse.getX()
d.variables.msy = love.mouse.getY()

function lovebug.toggle()
	d.show = not d.show
	d.active = d.show
end

function lovebug.keypressed(key, scan, isTouch)
	if key == "f3" then lovebug.toggle() return true end
	if d.active then
		if key == "return" and d.input ~= "" then
			lovebug.interpret()
			return true
		end
		if key == "v" and love.keyboard.isDown("lctrl") then
			local s = love.system.getClipboardText()
			d.input = string.sub(d.input, 0, d.indicator) .. s .. string.sub(d.input, d.indicator+1, d.input.len(d.input))
			d.indicator = d.indicator + string.len(s)
			return true
		end
		if key == "right" then d.indicator = math.min(d.indicator + 1, string.len(d.input)) return true end
		if key == "left" then d.indicator = math.max(d.indicator - 1, 0) return true end
		if key == "down" and love.keyboard.isDown("lctrl") then d.displayLength = d.displayLength + 1 lovebug.updateWindow() return true end
		if key == "up" and love.keyboard.isDown("lctrl") then d.displayLength = d.displayLength - 1 lovebug.updateWindow() return true end
		if key == "down" then if d.historyPointer < #d.history then d.historyPointer = d.historyPointer + 1 d.input = d.history[d.historyPointer] else d.input = "" d.historyPointer = #d.history+1 end d.indicator = string.len(d.input) return true end
		if key == "up" then if d.historyPointer > 1 then d.historyPointer = d.historyPointer - 1 d.input = d.history[d.historyPointer] end d.indicator = string.len(d.input) return true end
		if key == "-" and love.keyboard.isDown("lctrl") then changeFontSize(d.fontSize - 1) return true end
		if key == "+" and love.keyboard.isDown("lctrl") then changeFontSize(d.fontSize + 1) return true end
		if d.active then
			if key == "rshift" or key == "lshift" then return true end
			if key == "space" then key = " " end
			if string.len(key) == 1 then
				if (love.keyboard.isDown("rshift") or love.keyboard.isDown("lshift")) then
					if d.shift[key] then
						key = d.shift[key]
					else
						key = string.upper(key)
					end
				end
				d.input = string.sub(d.input, 0, d.indicator) .. key .. string.sub(d.input, d.indicator+1, d.input.len(d.input))
				d.indicator = d.indicator + 1
				return true
			elseif key == "backspace" then
				if d.indicator == 0 then return end
				d.input = string.sub(d.input, 0, d.indicator-1) .. string.sub(d.input, d.indicator+1, d.input.len(d.input))
				d.indicator = math.max(d.indicator - 1, 0)
				return true
			end
		end
	end
	return false
end

function lovebug.interpret()
	--Save the line to the history
	d.log(d.input)
	if d.history[#d.history] ~= d.input then
		d.history[#d.history + 1] = d.input
	end
	d.historyPointer = #d.history + 1
	--Insert variables
	for name, val in pairs(d.variables) do
		if type(val) == "function" then
			d.input = string.gsub(d.input, "$"..name, val())
		elseif type(val) == "string" or type(val) == "number" then
			d.input = string.gsub(d.input, "$"..name, val)
		end
	end
	--Interpret the line
	if d.input == "clear" then d.lines = {} d.input = "" d.indicator = 0 return end
	if d.input == "close" then lovebug.toggle() d.input = "" d.indicator = 0 return end
	local ok, val = pcall(loadstring(d.input))
	if ok then
		d.lines[#d.lines].color = "green"
	else
		local ok, val = pcall(loadstring("return " .. d.input))
		if ok then
			if type(val) == "string" then
				d.log(val, "blue")
			elseif type(val) == "number" then
				d.log(val, "green")
			elseif type(val) == "boolean" then
				local m = "false"
				if val then m = "true" end
				d.log(m, "orange")
			elseif type(val) == "function" then
				d.log("function", "purple")
			elseif type(val) == "table" then
				d.log("table", "yellow")
			elseif type(val) == "nil" then
				d.log("nil", "red")
			end
		else d.log("ERROR: "..val, "red")
		end
	end
	d.input = ""
	d.indicator = 0
end

function changeFontSize(size)
	d.fontSize = love.graphics.getDPIScale()*size
	d.font = love.graphics.newFont(d.fontSize)
	lovebug.updateWindow()
	d.log("Font size set to " .. size .. ".")
end

function lovebug.updateWindow()
	d.width = love.graphics.getWidth()
	d.height = 16 + (1 + d.displayLength)*(d.fontSize + d.spacing)
end

function lovebug.draw()
	love.graphics.push()
	love.graphics.origin()
	if d.show then
		local mult = 0.7
		if d.active then mult = 1 end
		love.graphics.setColor(0.5,0.5,0.5,1)
		if d.active then love.graphics.setColor(138/255*mult,217/255*mult,230/255*mult,1) end
		love.graphics.rectangle("fill",0,0,d.width,d.height)
		love.graphics.setColor(0,0,0,1)
		love.graphics.rectangle("fill",1,1,d.width - 3,d.height - 3)
		love.graphics.setFont(d.font)
		for i = 1, d.displayLength do
			local l = #d.lines - d.displayLength + i - d.offset
			if l > 0 then
				if d.lines[l].color == "red" then love.graphics.setColor(1*mult,0,0,1)
				elseif d.lines[l].color == "green" then love.graphics.setColor(0,1*mult,0,1)
				elseif d.lines[l].color == "orange" then love.graphics.setColor(1*mult,0.6*mult,0,1)
				elseif d.lines[l].color == "purple" then love.graphics.setColor(180/255*mult,45/255*mult,212/255*mult,1)
				elseif d.lines[l].color == "yellow" then love.graphics.setColor(1*mult,1*mult,0*mult,1)
				elseif d.lines[l].color == "blue" then love.graphics.setColor(0, 0 ,1*mult,1)
				else love.graphics.setColor(0.9*mult,0.9*mult,0.9*mult,1) end
				love.graphics.print(d.lines[l].value, 10, 6 + (i-1)*(d.fontSize + d.spacing))
			end
		end
		love.graphics.setColor(1,1,1,1)
		if d.active then love.graphics.setColor(138/255*mult,217/255*mult,230/255*mult,1) end
		local inp = d.input
		if love.timer.getTime()*10%10 > 8 and d.active then
			local ofs = d.font:getWidth("> "..string.sub(d.input, 0, d.indicator))
			love.graphics.line(10+ofs, 6-2 + d.displayLength*(d.fontSize + d.spacing), 10+ofs, 4+6+d.fontSize + d.displayLength*(d.fontSize + d.spacing))
		end
		love.graphics.print("> "..d.input, 10, 6 + d.displayLength*(d.fontSize + d.spacing))
	end
	love.graphics.pop()
end

function lovebug.mousepressed(x, y, button, istouch)
	local ret = (y < d.height and d.show)
	d.active = ret
	return ret
end

function lovebug.wheelmoved(x, y)
	if not d.active then return false end
	d.offset = math.max(0, math.min(#d.lines - d.displayLength, d.offset+y))
	return true
end

return lovebug