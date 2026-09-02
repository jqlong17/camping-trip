-- 桌面、3DS 按键与下屏触摸统一路由。

local R = require("runtime")
local Flow = require("scene_flow")
local Session = require("session")
local Menu = require("scenes.menu")
local Cast = require("scenes.cast")
local Codex = require("scenes.codex")
local MenuDraw = require("draw.menu")
local Input = {}
local host

function Input.bindHost(h)
  host = h
end

local function hitGear(lx, ly)
  for i, gear in ipairs(R.gear) do
    if lx >= gear.x and lx <= gear.x + 80 and ly >= gear.y and ly <= gear.y + 72 then return i end
  end
end

local function playActionHit(lx, ly)
  if lx >= 20 and lx <= 150 and ly >= 210 and ly <= 232 then return "wait" end
  if R.canGoHome and lx >= 170 and lx <= 300 and ly >= 210 and ly <= 232 then return "home" end
end

local function handleQuitConfirmKey(key)
  if not R.quitConfirm then return false end
  if key == "left" then Flow.nudgeQuitConfirm(-1)
  elseif key == "right" or key == "d" then Flow.nudgeQuitConfirm(1)
  elseif key == "return" or key == "space" or key == "a" or key == "z" then Flow.resolveQuitConfirm()
  elseif key == "b" then Flow.cancelQuitConfirm()
  end
  return true
end

local function handleQuitConfirmPad(button)
  if not R.quitConfirm then return false end
  if button == "dpleft" then Flow.nudgeQuitConfirm(-1)
  elseif button == "dpright" then Flow.nudgeQuitConfirm(1)
  elseif button == "a" then Flow.resolveQuitConfirm()
  elseif button == "b" or button == "back" then Flow.cancelQuitConfirm()
  end
  return true
end

function Input.onBottomTouch(lx, ly)
  if R.quitConfirm then
    local hit = MenuDraw.hitQuitConfirm(lx, ly)
    if hit then
      R.quitConfirmChoice = hit
      Flow.resolveQuitConfirm()
    end
    return
  end
  if R.scene == "title" then
    local i = Menu.hit(lx, ly)
    if i then
      if R.menuIndex ~= i then Audio.playSfx("ui_move") end
      R.menuIndex = i
      Flow.confirmMenu()
    end
  elseif R.scene == "codex" then
    local i = hitGear(lx, ly)
    if i then Codex.set(R, i)
    elseif lx >= 100 and lx <= 220 and ly >= 204 and ly <= 226 then Flow.goTitle() end
  elseif R.scene == "about" then
    if lx >= 100 and lx <= 220 and ly >= 204 and ly <= 226 then Flow.goTitle() end
  elseif R.scene == "diary" then
    if lx < 104 then Flow.nudgeDiary(-1)
    elseif lx > 216 then Flow.nudgeDiary(1)
    else Flow.finishDiary() end
  elseif R.scene == "prologue" or R.scene == "depart"
      or R.scene == "homecoming" then
    Flow.advancePrimary()
  elseif R.scene == "cast" then
    local i = Cast.hit(lx, ly)
    if i then Cast.set(i)
    elseif lx >= 100 and lx <= 220 and ly >= 210 and ly <= 232 then Flow.confirmCast() end
  elseif R.scene == "destination" then
    if ly >= 56 and ly <= 172 then
      State.destination.i = lx < 160 and 1 or 2
      Flow.confirmDestination()
    elseif lx >= 100 and lx <= 220 and ly >= 204 and ly <= 232 then
      Flow.confirmDestination()
    end
  elseif R.scene == "play" then
    if R.ritual then
      if lx >= 100 and lx <= 220 and ly >= 210 and ly <= 232 then Session.tryUseGear()
      elseif lx >= 230 and lx <= 300 and ly >= 210 and ly <= 232 then
        GearPlay.cancelRitual()
        R.brewActive = false
      end
      return
    end
    local action = playActionHit(lx, ly)
    if action == "wait" then Session.advanceTime()
    elseif action == "home" then Flow.goHomecoming()
    else
      local i = hitGear(lx, ly)
      if i then
        if R.selected ~= i then Audio.playSfx("ui_move") end
        R.selected = i
        host.say("选中 · " .. R.gear[i].name)
      end
    end
  end
end

function Input.onKey(key)
  if key == "escape" then
    if R.quitConfirm then Flow.cancelQuitConfirm(); return end
    if R.scene == "title" then love.event.quit(); return end
    Flow.tryBack()
    return
  end
  if handleQuitConfirmKey(key) then return end

  if R.scene == "title" then
    if key == "up" or key == "w" then Menu.move(R, -1)
    elseif key == "down" or key == "s" then Menu.move(R, 1)
    elseif key == "return" or key == "space" or key == "a" then Flow.confirmMenu() end
  elseif R.scene == "codex" then
    if key == "left" then Codex.move(R, -1)
    elseif key == "right" then Codex.move(R, 1)
    elseif key == "up" or key == "w" then Codex.move(R, -3)
    elseif key == "down" or key == "s" then Codex.move(R, 3)
    elseif key == "return" or key == "space" or key == "a" or key == "b" then Flow.goTitle() end
  elseif R.scene == "about" then
    if key == "return" or key == "space" or key == "a" or key == "b" then Flow.goTitle() end
  elseif R.scene == "diary" then
    if key == "b" then Flow.tryBack()
    elseif key == "left" then Flow.nudgeDiary(-1)
    elseif key == "right" or key == "d" then Flow.nudgeDiary(1)
    elseif key == "return" or key == "space" or key == "a" then Flow.finishDiary() end
  elseif R.scene == "prologue" or R.scene == "depart"
      or R.scene == "homecoming" then
    if key == "b" then Flow.tryBack()
    elseif key == "return" or key == "space" or key == "a" then Flow.advancePrimary() end
  elseif R.scene == "cast" then
    if key == "b" then Flow.tryBack()
    elseif key == "left" then Cast.move("left")
    elseif key == "right" then Cast.move("right")
    elseif key == "up" then Cast.move("up")
    elseif key == "down" then Cast.move("down")
    elseif key == "return" or key == "space" or key == "a" then Flow.confirmCast() end
  elseif R.scene == "destination" then
    if key == "b" then Flow.tryBack()
    elseif key == "left" or key == "up" then Flow.nudgeDestination(-1)
    elseif key == "right" or key == "down" or key == "d" then Flow.nudgeDestination(1)
    elseif key == "return" or key == "space" or key == "a" then Flow.confirmDestination() end
  elseif R.scene == "play" then
    if R.cupPick then
      if R.cupKind and R.drippedOnce and R.teaReady
          and R.coffeeCups < DripBrew.CUPS_PER_POT and R.teaCups < TeaBrew.CUPS_PER_POT then
        if key == "left" or key == "a" then R.cupKind = "coffee"; Audio.playSfx("ui_move")
        elseif key == "right" or key == "d" then R.cupKind = "tea"; Audio.playSfx("ui_move") end
      end
      if key == "left" or key == "a" then Session.nudgeCupStyle(-1, 0)
      elseif key == "right" or key == "d" then Session.nudgeCupStyle(1, 0)
      elseif key == "up" or key == "w" then Session.nudgeCupStyle(0, -1)
      elseif key == "down" or key == "s" then Session.nudgeCupStyle(0, 1)
      elseif key == "return" or key == "space" or key == "z" then Session.drinkFromCup()
      elseif key == "b" then Flow.tryBack() end
      return
    end
    if R.ritual then
      if key == "left" then GearPlay.nudgeRitual(-1)
      elseif key == "right" or key == "d" then GearPlay.nudgeRitual(1) end
    end
    if key == "up" or key == "w" then Session.tryMove(0, -1)
    elseif key == "down" or key == "s" then Session.tryMove(0, 1)
    elseif key == "left" then Session.tryMove(-1, 0)
    elseif key == "right" or key == "d" then Session.tryMove(1, 0)
    elseif key == "a" then Session.tryMove(-1, 0)
    elseif key == "return" or key == "space" or key == "z" then Session.tryUseGear()
    elseif key == "x" then Session.advanceTime()
    elseif key == "r" then Time.fastForward(); Audio.syncPlayBgm()
    elseif key == "h" and R.canGoHome then Flow.goHomecoming()
    elseif key == "b" then Flow.tryBack() end
  end
end

function Input.onGamepad(button)
  if button == "start" then love.event.quit(); return end
  if button == "back" or button == "b" then
    Flow.tryBack()
    return
  end
  if handleQuitConfirmPad(button) then return end
  if R.scene == "title" then
    if button == "dpup" then Menu.move(R, -1)
    elseif button == "dpdown" then Menu.move(R, 1)
    elseif button == "a" then Flow.confirmMenu() end
  elseif R.scene == "codex" then
    if button == "dpleft" then Codex.move(R, -1)
    elseif button == "dpright" then Codex.move(R, 1)
    elseif button == "dpup" then Codex.move(R, -3)
    elseif button == "dpdown" then Codex.move(R, 3)
    elseif button == "a" then Flow.goTitle() end
  elseif R.scene == "about" then
    if button == "a" then Flow.goTitle() end
  elseif R.scene == "diary" then
    if button == "dpleft" then Flow.nudgeDiary(-1)
    elseif button == "dpright" then Flow.nudgeDiary(1)
    elseif button == "a" then Flow.finishDiary() end
  elseif R.scene == "prologue" or R.scene == "depart"
      or R.scene == "homecoming" then
    if button == "a" then Flow.advancePrimary() end
  elseif R.scene == "cast" then
    if button == "dpleft" then Cast.move("left")
    elseif button == "dpright" then Cast.move("right")
    elseif button == "dpup" then Cast.move("up")
    elseif button == "dpdown" then Cast.move("down")
    elseif button == "a" then Flow.confirmCast() end
  elseif R.scene == "destination" then
    if button == "dpleft" or button == "dpup" then Flow.nudgeDestination(-1)
    elseif button == "dpright" or button == "dpdown" then Flow.nudgeDestination(1)
    elseif button == "a" then Flow.confirmDestination() end
  elseif R.scene == "play" then
    if R.cupPick then
      if button == "dpleft" then Session.nudgeCupStyle(-1, 0)
      elseif button == "dpright" then Session.nudgeCupStyle(1, 0)
      elseif button == "dpup" then Session.nudgeCupStyle(0, -1)
      elseif button == "dpdown" then Session.nudgeCupStyle(0, 1)
      elseif button == "a" then Session.drinkFromCup()
      end
      return
    end
    if R.ritual then
      if button == "dpleft" then GearPlay.nudgeRitual(-1)
      elseif button == "dpright" then GearPlay.nudgeRitual(1) end
    end
    if button == "dpup" then Session.tryMove(0, -1)
    elseif button == "dpdown" then Session.tryMove(0, 1)
    elseif button == "dpleft" then Session.tryMove(-1, 0)
    elseif button == "dpright" then Session.tryMove(1, 0)
    elseif button == "a" then Session.tryUseGear()
    elseif button == "x" then Session.advanceTime()
    elseif button == "y" and R.canGoHome then Flow.goHomecoming() end
  end
end

function Input.onTouch(x, y)
  if R.isConsole then Input.onBottomTouch(x, y) end
end

function Input.onMouse(x, y, button)
  if button ~= 1 or R.isConsole then return end
  if y >= R.TOP_H and x >= 40 and x < 40 + R.BOT_W then
    Input.onBottomTouch(x - 40, y - R.TOP_H)
  end
end

return Input
