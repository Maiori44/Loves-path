local music = require "music"

local cutscenes = {
	num = 1,
	page = 1,
	texttime = 0,
	list = {
		{"This is a test dialogue", "test test test test"},
		{"This cutscene was still not added yet\nEnjoy chapter 2!"},
		{"This cutscene was still not added yet\nEnjoy chapter 3!"},
		{"This cutscene was still not added yet\nEnjoy chapter 4!"},
		{"Hello person that wanted to check this game source code!"},
		{"I gotta warn you: most of it is bad..."}
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