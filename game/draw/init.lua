local R = require("runtime")
local Story = require("scenes.story")
local StoryDraw = require("draw.story")
local MenuDraw = require("draw.menu")
local PlayDraw = require("draw.play")
local Draw = {}

function Draw.top()
  if R.scene == "title" then MenuDraw.titleTop()
  elseif R.scene == "codex" then MenuDraw.codexTop()
  elseif R.scene == "about" then MenuDraw.aboutTop()
  elseif R.scene == "prologue" then
    local beat = Story.prologue.beats[Story.prologue.i]
    StoryDraw.storyTop(beat.img, beat.line)
  elseif R.scene == "cast" then StoryDraw.castTop()
  elseif R.scene == "depart" then
    local beat = Story.depart.beats[Story.depart.i]
    StoryDraw.storyTop(beat.img, beat.line)
  elseif R.scene == "homecoming" then
    local beat = Story.homecoming.beats[Story.homecoming.i]
    StoryDraw.storyTop(beat.img, beat.line)
  elseif R.scene == "diary" then StoryDraw.diaryTop()
  else CampRender.drawPlayTop() end
  MenuDraw.quitConfirmTop()
end

function Draw.bottom()
  if R.scene == "title" then MenuDraw.titleBottom()
  elseif R.scene == "codex" then MenuDraw.codexBottom()
  elseif R.scene == "about" then MenuDraw.aboutBottom()
  elseif R.scene == "prologue" then StoryDraw.storyBottom("按 A 继续故事")
  elseif R.scene == "cast" then StoryDraw.castBottom()
  elseif R.scene == "depart" then StoryDraw.storyBottom("按 A 前往营地")
  elseif R.scene == "homecoming" then StoryDraw.storyBottom("按 A 前往日记")
  elseif R.scene == "diary" then StoryDraw.diaryBottom()
  else PlayDraw.bottom() end
  MenuDraw.quitConfirmBottom()
end

function Draw.frame(screen)
  if screen == "bottom" then Draw.bottom(); return end
  if screen == "top" or screen == "left" or screen == "right" then Draw.top(); return end
  Draw.top()
  if R.desktopBottom then
    love.graphics.setCanvas(R.desktopBottom)
    love.graphics.clear(0.85, 0.75, 0.55)
    Draw.bottom()
    love.graphics.setCanvas()
    love.graphics.setColor(0.15, 0.15, 0.17)
    love.graphics.rectangle("fill", 0, R.TOP_H, 40, R.BOT_H)
    love.graphics.rectangle("fill", 360, R.TOP_H, 40, R.BOT_H)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(R.desktopBottom, 40, R.TOP_H)
  end
end

return Draw
