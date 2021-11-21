local sound = {list = {}, soundtestpointer = 1}

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
  if not pcall(love.audio.newSource, filepath, "stream") then
    filepath = mapspath:sub(1, -7).."/Music/"..filename
    if not pcall(love.audio.newSource, filepath, "stream") then
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

function sound.playSound(filename)
  if menu.settings[5].value == 0 then return end
  for i = 1,20 do
    if not sound.list[i] then
      sound.list[i] = love.audio.newSource("Sounds/"..filename, "static")
      sound.list[i]:play()
      sound.list[i]:setVolume(menu.settings[5].value / 10)
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
  {name = "Grassy Forest", subtitle = "Chapter 1 Act 1", creator = "MAKYUNI", filename = "forest 1.ogg", require = 2},
  {name = "Haunted Woods", subtitle = "Chapter 1 Act 2", creator = "MAKYUNI", filename = "forest 2.ogg", require = 6},
  {name = "Snowy Mountain", subtitle = "Chapter 2 Act 1", creator = "MAKYUNI", filename = "frost 1.ogg", require = 11},
  {name = "Tough Climb", subtitle = "Chapter 2 Act 2", creator = "MAKYUNI", filename = "frost 2.ogg", require = 16},
  {name = "Castle of Time", subtitle = "Chapter 3 Act 1", creator = "MAKYUNI", filename = "castle 1.ogg", require = 21},
  {name = "Growing Burden", subtitle = "Chapter 3 Act 2", creator = "MAKYUNI", filename = "castle 2.ogg", require = 21}, --change the require in the future
  {name = "Neglected Factory", subtitle = "Chapter 4 Act 1", creator = "MAKYUNI (inspired by Janne Kivilahti)", filename = "factory 1.ogg", require = 21},
  {name = "Rusted Gears", subtitle = "Chapter 4 Act 2", creator = "MAKYUNI", filename = "factory 2.ogg", require = 21},
  --{name = "Inside the mind", subtitle = "Chapter 5", creator = "Felix44 & MAKYUNI", filename = "mind.ogg", require = 21}, --placeholder
  {require = 256}
}

return sound