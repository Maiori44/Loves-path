#!/bin/bash
7z a "Love's Path.zip" Maps Music Shaders Sounds Sprites cache.lua cdef.c coins.lua conf.lua customhandler.lua cutscenes.lua discordRPC.lua editundo.ttf main.lua maps.lua menu.lua music.lua nativefs.lua objects.lua particles.lua player.lua
filename="Love's Path $1"
mkdir "$filename"
cat Compiler/love.exe "Love's Path.zip" > "$filename/Love's Path.exe"
rm "Love's Path.zip"
cp -r Compiler/dlls/* "$filename"
7z a "$filename.zip" "$filename"
rm -r "$filename"