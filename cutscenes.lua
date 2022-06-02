local music = require "music"

local cutscenes = {
	num = 1,
	page = 1,
	texttime = 0,
	list = { --SPOILERS AHEAD IF YOU HAVEN'T FINISHED THE GAME!
		{
			name = "The story begins...",
			"This is a test dialogue",
			"test test test test"
		},
		{
			name = "WIP",
			"This cutscene was still not added yet\nEnjoy chapter 2!"
		},
		{
			name = "also WIP",
			"This cutscene was still not added yet\nEnjoy chapter 3!"
		},
		{
			name = "yet another WIP",
			"This cutscene was still not added yet\nEnjoy chapter 4!"
		},
		{
			name = "This name will not appear, yet",
			"Hello person that wanted to check this game source code!"
		},
		{
			name = "This one too won't appear yet",
			"I gotta warn you: most of it is bad..."
		}
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