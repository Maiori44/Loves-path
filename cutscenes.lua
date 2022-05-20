local music = require "music"

local cutscenes = {
	num = 1,
	page = 1,
	texttime = 0,
	list = {
		{"This is a test dialogue", "test test test test"}
	}
}

function cutscenes.setCutscene(num)
	cutscenes.current = cutscenes.list[num]
	cutscenes.num = num
	cutscenes.page = 1
	cutscenes.texttime = 0
	cutscenes.prevmusic = music.musicname
	music.setMusic("none")
	flash = 0
end

return cutscenes