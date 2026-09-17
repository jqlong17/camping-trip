-- 露营之旅 — LovePotion / LÖVE 引擎壳。

AP = require("asset_paths")
Destinations = require("destination_registry")
State = require("state")
Persist = require("persist")
Time = require("time")
Toast = require("ui_toast")
Playtest = require("playtest")
DripBrew = require("drip_brew")
TeaBrew = require("tea_brew")
FishRod = require("fish_rod")
TentGear = require("tent_gear")
CupSip = require("cup_sip")
CookMeal = require("cook_meal")
Audio = require("audio")
Assets = require("assets")
CampMap = require("camp_map")
CampPreload = require("camp_preload")
CampWorld = require("camp_world")
CampTiles = require("draw.camp_tiles")
CampRender = require("camp_render")
GearPlay = require("gear_play")

local R = require("runtime")
local Session = require("session")
local Flow = require("scene_flow")
local Input = require("input")
local Draw = require("draw")
local Bindings = require("bindings")

Bindings.bind()

function love.load()
  if R.isConsole or Playtest.wanted() then
    pcall(function() love.filesystem.write("load_report.txt", "boot build=" .. R.buildId .. "\n") end)
  end
  pcall(love.graphics.setDefaultFilter, "nearest", "nearest")
  pcall(Assets.detectRoot)
  Persist.load()
  Assets.writeProbe()
  CampMap.build()
  CampMap.indexRenderData()
  Assets.loadBoot()
  if not R.isConsole then
    Audio.loadBgm()
    Audio.loadSfx()
  end
  R.uiFont = Assets.newFont(14)
  R.titleFont = Assets.newFont(26) or R.uiFont
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  CampWorld.seedStars()
  if not R.isConsole then
    R.desktopBottom = love.graphics.newCanvas(R.BOT_W, R.BOT_H)
    love.window.setMode(R.TOP_W, R.TOP_H + R.BOT_H, {
      vsync = Playtest.wanted() and 0 or 1,
    })
  end
  if R.isConsole then Audio.ensureConsoleLoaded() end
  Flow.syncSceneBgm()
  Toast.say("触摸或方向键选择 · A 确认", 4)
  if Playtest.wanted() and not R.isConsole then
    Playtest.on = true
    Playtest.log("begin " .. love.filesystem.getSaveDirectory())
  end
end

function love.update(dt)
  R.perfWindow = R.perfWindow + dt
  R.perfFrames = R.perfFrames + 1
  if dt > 0.05 then R.perfSlowFrames = R.perfSlowFrames + 1 end
  if dt > R.perfMaxDt then R.perfMaxDt = dt end
  if R.perfWindow >= 5 then
    Bindings.appendLoadLog(string.format(
      "perf scene=%s destination=%s frames=%d slow=%d maxDtMs=%.1f mode=%s audio=%s",
      R.scene, Destinations.currentId(), R.perfFrames, R.perfSlowFrames, R.perfMaxDt * 1000,
      R.perfMode .. "/" .. Audio.consoleMode(), Audio.debugState()
    ))
    R.perfWindow, R.perfFrames, R.perfSlowFrames, R.perfMaxDt = 0, 0, 0, 0
  end
  Audio.ensureConsoleLoaded()
  if CampPreload.active() then CampPreload.runSlice(1) end
  Flow.pumpDepartArrival()
  R.titlePulse = R.titlePulse + dt
  R.waterPhase = R.waterPhase + dt * 2.2
  Toast.update(dt)
  if R.brewTimer > 0 then
    R.brewTimer = R.brewTimer - dt
    if R.brewTimer <= 0 and not R.ritual then R.brewActive = false end
  end
  if R.potSimmer > 0 then R.potSimmer = R.potSimmer - dt end
  if R.scene == "play" then
    if R.player.idleT > 0 then
      R.player.idleT = R.player.idleT - dt
      if R.player.idleT <= 0 then R.player.walkFrame = 0 end
    end
    if R.critterFx then
      if Destinations.current().ecology.fish then CampWorld.updateFish(dt) end
      CampWorld.updateCritters(dt)
    end
    if not R.staticPlayFx then
      CampWorld.updateNight(dt)
    end
    Audio.tick(dt, R.titlePulse)
    Session.updateTimedRitual(dt)
    Time.tickAuto(dt)
  end
  Playtest.tick(dt)
end

function love.keypressed(key)
  Input.onKey(key)
end

function love.gamepadpressed(_, button)
  Input.onGamepad(button)
end

function love.touchpressed(_, x, y)
  Input.onTouch(x, y)
end

function love.mousepressed(x, y, button)
  Input.onMouse(x, y, button)
end

function love.draw(screen)
  Draw.frame(screen)
end
