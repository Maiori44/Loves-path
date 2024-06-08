local sound = {list = {}, soundtestpointer = 1, sounds = {}}

function sound.stopMusic()
	if not sound.music then return end
	sound.musicname = nil
	sound.music:stop()
	sound.music = nil
end

function sound.setMusic(filename)
	local filepath = "Music/"..filename
	if menu.settings[4].value == 0 or filename == "" then
		sound.stopMusic()
		return
	end
	if not love.filesystem.getInfo(filepath, "file") then
		filepath = mapspath:sub(1, -7).."/Music/"..filename
		if not love.filesystem.getInfo(filepath, "file") then
			sound.stopMusic()
			return
		end
	end
	if sound.musicname == filename then return end
	sound.musicname = filename
	if sound.music then sound.music:stop() end
	sound.music = love.audio.newSource(filepath, "stream")
	sound.music:setLooping(true)
	sound.music:setVolume(menu.settings[4].value / 10)
	sound.music:play()
end

function sound.getSounds(dirpath, modded)
	local iter = love.filesystem.getDirectoryItems(dirpath)
	if not iter then return end
	for _, filename in ipairs(iter) do
		sound.sounds[filename] = modded
	end
end

sound.getSounds("Sounds", false)

function sound.playSound(filename)
	if menu.settings[5].value == 0 then return end
	local isFromMod = sound.sounds[filename]
	if isFromMod == nil then
		messagebox.setMessage("Sound file not found!", "Sound \""..filename.."\" does not exist.\n(Sound files are searched on mod load,\nif you added the file later restart the game!)", true)
		return
	end
	local path = isFromMod and path.."/Sounds/" or "Sounds/"
	for i = 1, 40 do
		if not sound.list[i] then
			sound.list[i] = love.audio.newSource(path..filename, "static")
			sound.list[i]:play()
			sound.list[i]:setVolume(menu.settings[5].value / 10)
			return
		end
	end
end

function sound.reset()
	for k, sound in pairs(sound.list) do
		sound:stop()
	end
end

function sound.collectGarbage()
	for k, s in pairs(sound.list) do
		if not s:isPlaying() then
			sound.list[k] = nil
		end
	end
	collectgarbage()
end

sound.soundtest = {
	{name = "Love's path", subtitle = "Main menu", creator = "MAKYUNI", filename = "menu.ogg"},
	{name = "Grassy Forest", subtitle = "Chapter 1 Act 1", creator = "MAKYUNI", filename = "forest 1.ogg", require = 2},
	{name = "Haunted Woods", subtitle = "Chapter 1 Act 2", creator = "MAKYUNI", filename = "forest 2.ogg", require = 6},
	{name = "Snowy Mountain", subtitle = "Chapter 2 Act 1", creator = "MAKYUNI", filename = "frost 1.ogg", require = 11},
	{name = "Tough Climb", subtitle = "Chapter 2 Act 2", creator = "MAKYUNI", filename = "frost 2.ogg", require = 16},
	{name = "Castle of Time", subtitle = "Chapter 3 Act 1", creator = "MAKYUNI", filename = "castle 1.ogg", require = 21},
	{name = "Growing Burden", subtitle = "Chapter 3 Act 2", creator = "MAKYUNI", filename = "castle 2.ogg", require = 26},
	{name = "Neglected Factory", subtitle = "Chapter 4 Act 1", creator = "MAKYUNI", filename = "factory 1.ogg", require = 31},
	{name = "Rusted Gears", subtitle = "Chapter 4 Act 2", creator = "MAKYUNI", filename = "factory 2.ogg", require = 36},
	{name = "Inside the mind", subtitle = "Chapter 5", creator = "Rosy.iso & MAKYUNI", filename = "mind.ogg", require = 41},
	{name = "Inside the heart", subtitle = "Vs. Beldurra", creator = "LordXernom", filename = "heart.ogg", require = 50},
	{require = 0xFF} --gets replaced by bonus.ogg when unlocked
}

return sound