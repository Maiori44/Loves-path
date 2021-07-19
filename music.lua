local sound = {list = {}, soundtestpointer = 1}

function sound.stopMusic()
  if not sound.music then return end
  sound.musicname = nil
  sound.music:stop()
  sound.music = nil
end

function sound.setMusic(filename)
  local filepath = "Music/"..filename
  if love.filesystem.isFused() then
    love.filesystem.mount(love.filesystem.getSourceBaseDirectory(), "Source")
    filepath = "Source/Music/"..filename
  end
  if menu.settings[4].value == 0 or filename == ""
  or not pcall(love.audio.newSource, filepath, "stream") then
    sound.stopMusic()
    return
  end
  if sound.musicname == filename then return end
  sound.musicname = filename
  if sound.music then sound.music:stop() end
  sound.music = love.audio.newSource(filepath, "stream")
  sound.music:setLooping(true)
  sound.music:play()
end

function sound.playSound(filename)
  if menu.settings[5].value == 0 then return end
  for i = 1,20 do
    if not sound.list[i] then
      sound.list[i] = love.audio.newSource("Sounds/"..filename, "static")
      sound.list[i]:play()
      break
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
  {name = "Grassy Forest", subtitle = "Chapter 1 Act 1", creator = "MAKYUNI", filename = "forest1.ogg", require = 2},
  {name = "Haunted Woods", subtitle = "Chapter 1 Act 2", creator = "MAKYUNI", filename = "forest2.ogg", require = 6},
  {name = "Inside the mind", subtitle = "why did I try to make music", creator = "Felix44", filename = "mind.ogg", require = 11},
  {name = "Song 12", subtitle = "just a test", creator = "Janne", filename = "factory.ogg"},
}

return sound