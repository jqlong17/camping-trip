-- 场景切换与流程；不负责绘制和设备输入。

local R = require("runtime")
local Story = require("scenes.story")
local Session = require("session")
local Flow = {}
local host

function Flow.bindHost(h)
  host = h
end

function Flow.syncSceneBgm()
  if R.scene == "play" then Audio.syncPlayBgm(); return end
  if R.scene == "title" or R.scene == "codex" or R.scene == "about"
      or R.scene == "homecoming" or R.scene == "diary" then
    if Audio.bgm.title then Audio.playBgm(Audio.bgm.title) end
  elseif R.scene == "prologue" or R.scene == "depart" or R.scene == "cast" or R.scene == "destination" then
    if Audio.bgm.morning then Audio.playBgm(Audio.bgm.morning) end
  end
end

function Flow.needsQuitConfirm()
  local s = R.scene
  return s == "prologue" or s == "cast" or s == "destination" or s == "depart"
      or s == "play" or s == "homecoming" or s == "diary"
end

function Flow.openQuitConfirm()
  R.quitConfirm = true
  R.quitConfirmChoice = 1
  Audio.playSfx("ui_move")
  Toast.clear()
end

function Flow.cancelQuitConfirm()
  if not R.quitConfirm then return end
  R.quitConfirm = false
  Audio.playSfx("ui_move")
end

function Flow.nudgeQuitConfirm(delta)
  if not R.quitConfirm then return end
  local next = R.quitConfirmChoice + delta
  if next < 1 then next = 2 elseif next > 2 then next = 1 end
  if next ~= R.quitConfirmChoice then
    R.quitConfirmChoice = next
    Audio.playSfx("ui_move")
  end
end

function Flow.resolveQuitConfirm()
  if not R.quitConfirm then return end
  if R.quitConfirmChoice == 2 then
    Audio.playSfx("ui_ok")
    Flow.goTitle()
    host.say("已返回标题 · 本趟未写入日记", 3)
  else
    Flow.cancelQuitConfirm()
  end
end

--- B / Esc：仪式取消 → 选杯取消 → 旅程二次确认 → 图鉴/关于直接回标题
function Flow.tryBack()
  if R.quitConfirm then
    Flow.cancelQuitConfirm()
    return true
  end
  if R.ritual then
    GearPlay.cancelRitual()
    R.brewActive = false
    return true
  end
  if R.scene == "play" and R.cupPick then
    R.cupPick, R.cupKind = false, nil
    return true
  end
  if Flow.needsQuitConfirm() then
    Flow.openQuitConfirm()
    return true
  end
  if R.scene ~= "title" then
    Flow.goTitle()
    return true
  end
  return false
end

function Flow.goTitle()
  R.quitConfirm = false
  R.scene = "title"
  Story.reset()
  State.cast.i = 1
  R.lanternOn, R.canGoHome = false, false
  Time.resetForTitle()
  Audio.stopAmb()
  Flow.syncSceneBgm()
  host.say("触摸或方向键选择 · A 确认", 3)
end

function Flow.goPrologue()
  R.scene = "prologue"
  Story.prologue.i = 1
  host.ensureStory("p1")
  Audio.stopAmb()
  Flow.syncSceneBgm()
  Toast.clear()
end

function Flow.goCast()
  R.scene = "cast"
  for i = 1, 9 do host.ensureCast(i) end
  host.say("这次谁去？选好后按 A 确认", 3)
end

function Flow.goDestination()
  R.scene = "destination"
  State.destination.i = State.destination.i or 1
  Toast.clear()
  Flow.syncSceneBgm()
end

function Flow.nudgeDestination(delta)
  local count = #State.destination.ids
  State.destination.i = ((State.destination.i - 1 + delta) % count) + 1
  Audio.playSfx("ui_move")
end

function Flow.activateDestination(id)
  local pack = Destinations.set(id)
  R.destinationId = pack.id
  State.trip.destinationId = pack.id
  State.save.data.lastDestinationId = pack.id
  Story.setDestination(pack)
  CampPreload.reset(pack.id)
  CampMap.build()
  CampMap.indexRenderData()
  CampPreload.begin("destination_selected")
  return pack
end

function Flow.confirmDestination()
  local id = State.destination.ids[State.destination.i] or "forest"
  Flow.activateDestination(id)
  Persist.write()
  Flow.goDepart()
end

function Flow.goDepart()
  R.scene = "depart"
  Story.depart.i = 1
  local firstBeat = Story.depart.beats[1]
  host.ensureStory(firstBeat and firstBeat.img or "d1")
  Toast.clear()
end

function Flow.goPlay()
  R.scene = "play"
  CampPreload.ensure()
  host.ensureWalk(R.player.castId or 1)
  local spawn = Destinations.current().spawn
  R.player.x, R.player.y = spawn.x, spawn.y
  R.player.facing, R.player.walkFrame, R.player.walkTimer = 0, 0, 0
  R.selected = 1
  Time.resetForCamp()
  R.lanternOn, R.canGoHome = false, false
  R.tentOpen, R.brewActive, R.brewTimer, R.potSimmer = false, false, 0, 0
  R.tentPos = nil
  R.tentColorI, R.tentStyleI, R.tentDoorI = 1, 1, 1
  R.drippedOnce, R.coffeeCups = false, 0
  R.teaReady, R.teaCups = false, 0
  R.cupStyle, R.cupPick, R.cupKind = 1, false, nil
  R.ritual = nil
  DripBrew.resetTrip()
  TeaBrew.resetTrip()
  FishRod.resetTrip()
  CookMeal.resetTrip()
  TentGear.mood = nil
  Persist.resetTripHaul()
  CampWorld.resetCritters()
  local critters = CampWorld.getCritters()
  critters.birdT, critters.bugT = 0.4, 0.6
  Audio.stopBgm()
  Audio.syncPlayBgm()
  if Destinations.currentId() == "coast" then
    host.say("到了 · 清晨的海面正亮起来", 3.5)
  else
    host.say("到了 · 林间有小溪，可以趟过去", 3.5)
  end
end

function Flow.goDiary()
  R.scene = "diary"
  R.diaryPage = 1
  host.ensureStory("diary_desk")
  host.ensureStory("diary_tn")
  host.ensureStory("diary")
  Audio.stopAmb()
  Flow.syncSceneBgm()
  Toast.clear()
end

function Flow.nudgeDiary(delta)
  if R.scene ~= "diary" then return end
  local count = 3
  local next = math.max(1, math.min(count, (R.diaryPage or 1) + delta))
  if next ~= R.diaryPage then
    R.diaryPage = next
    Audio.playSfx("ui_move")
  end
end

function Flow.finishDiary()
  Persist.commitTrip()
  Flow.goTitle()
  host.say("存档好了 · 下周见", 3)
end

function Flow.goHomecoming()
  R.scene = "homecoming"
  Story.homecoming.i = 1
  host.ensureStory("h1")
  R.ritual = nil
  Audio.stopAmb()
  Flow.syncSceneBgm()
  Toast.clear()
end

function Flow.advancePrologue()
  if Story.advance("prologue") then return end
  if State.save.data.castChosen then
    Session.applyCast(State.save.data.castId or 1)
    Flow.goDestination()
  else
    Flow.goCast()
  end
end

function Flow.advanceDepart()
  if not Story.advance("depart") then Flow.goPlay() end
end

function Flow.advanceHome()
  if not Story.advance("homecoming") then Flow.goDiary() end
end

function Flow.confirmCast()
  Audio.playSfx("ui_ok")
  Session.applyCast(State.cast.i)
  State.save.data.castId = State.cast.i
  State.save.data.castChosen = true
  Persist.write()
  if State.castMode == "title" then
    State.castMode = "journey"
    Flow.goTitle()
  else
    Flow.goDestination()
  end
end

function Flow.startJourney()
  Flow.goPrologue()
end

function Flow.confirmMenu()
  local item = State.menu.items[R.menuIndex]
  if not item or not item.enabled then
    if item and item.id == "continue" then host.say("还没有存档", 2) end
    return
  end
  Audio.playSfx("ui_ok")
  if item.id == "start" then Flow.startJourney()
  elseif item.id == "continue" then
    if State.save.data.castChosen or (State.save.data.trips or 0) > 0 then
      Session.applyCast(State.save.data.castId or 1)
      Flow.activateDestination(State.save.data.lastDestinationId or "forest")
      Flow.goPlay()
    else host.say("还没有存档", 2) end
  elseif item.id == "cast" then State.castMode = "title"; Flow.goCast()
  elseif item.id == "codex" then
    R.scene, R.codex.i = "codex", 1
    CampPreload.ensure()
    Toast.clear()
    Flow.syncSceneBgm()
  elseif item.id == "about" then
    R.scene = "about"
    Toast.clear()
    Flow.syncSceneBgm()
  end
end

function Flow.advancePrimary()
  if R.scene == "title" then Flow.confirmMenu()
  elseif R.scene == "prologue" then Audio.playSfx("ui_ok"); Flow.advancePrologue()
  elseif R.scene == "cast" then Flow.confirmCast()
  elseif R.scene == "destination" then Flow.confirmDestination()
  elseif R.scene == "depart" then Audio.playSfx("ui_ok"); Flow.advanceDepart()
  elseif R.scene == "play" then Session.tryUseGear()
  elseif R.scene == "homecoming" then Audio.playSfx("ui_ok"); Flow.advanceHome()
  elseif R.scene == "diary" then Audio.playSfx("ui_ok"); Flow.finishDiary() end
end

return Flow
