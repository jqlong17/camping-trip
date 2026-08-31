--[[ 露营之旅 — 桌面/CI playtest（见 docs/代码架构-SPEC.md） ]]

local Playtest = {
  on = false,
  t = 0,
  step = 0,
  done = false,
  lines = {},
  outDir = "playtest",
  _walk = 0,
}

local E
local StoryDraw = require("draw.story")
local Flow = require("scene_flow")
local R = require("runtime")

function Playtest.bindHost(h)
  E = h
end

function Playtest.wanted()
  if arg then
    for _, a in ipairs(arg) do
      if a == "--playtest" then return true end
    end
  end
  return os.getenv("LINJIAN_PLAYTEST") == "1"
end

function Playtest.log(msg)
  Playtest.lines[#Playtest.lines + 1] = msg
  print("[playtest] " .. msg)
end

function Playtest.shot(name)
  love.filesystem.createDirectory(Playtest.outDir)
  love.graphics.captureScreenshot(Playtest.outDir .. "/" .. name .. ".png")
  Playtest.log("shot " .. name)
end

function Playtest.fail(msg)
  Playtest.log("FAIL " .. msg)
  love.filesystem.createDirectory(Playtest.outDir)
  love.filesystem.write(
    Playtest.outDir .. "/result.txt",
    table.concat(Playtest.lines, "\n") .. "\nFAIL\n" .. msg .. "\n"
  )
  Playtest.done = true
  love.event.quit()
end

function Playtest.require(cond, msg)
  if cond then return true end
  Playtest.fail(msg)
  return false
end

function Playtest.tick(dt)
  if not Playtest.on or Playtest.done then return end
  if not E then return end
  Playtest.t = Playtest.t + dt
  local s, t = Playtest.step, Playtest.t

  local function nextStep()
    Playtest.step = Playtest.step + 1
    Playtest.t = 0
  end

  if s == 0 and t > 0.35 then
    -- Playtest 必须与用户已有存档无关，完整覆盖序章与首次选角。
    State.save.data.castChosen = false
    Playtest.shot("01_title")
    nextStep()
  elseif s == 1 and t > 0.25 then E.menuIndex = 1; E.confirmMenu(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 2 and t > 0.35 then Playtest.shot("02_prologue"); nextStep()
  elseif s == 3 and t > 0.2 then E.advancePrologue(); nextStep()
  elseif s == 4 and t > 0.2 then E.advancePrologue(); nextStep()
  elseif s == 5 and t > 0.2 then E.advancePrologue(); nextStep()
  elseif s == 6 and t > 0.2 then E.advancePrologue(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 7 and t > 0.35 then Playtest.shot("03_cast"); State.cast.i = 2; nextStep()
  elseif s == 8 and t > 0.25 then
    E.confirmCast()
    Playtest.log("castId=" .. tostring(E.player.castId) .. " gender=" .. tostring(State.cast.genders[E.player.castId]))
    Playtest.log("-> " .. E.scene)
    nextStep()
  elseif s == 9 and t > 0.35 then Playtest.shot("04_depart"); Playtest.log("departCast=" .. tostring(E.player.castId)); nextStep()
  elseif s == 10 and t > 0.2 then E.advanceDepart(); nextStep()
  elseif s == 11 and t > 0.2 then E.advanceDepart(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 12 and t > 1.15 then
    E.spawnBird(); E.spawnBird(); E.spawnBug(); E.spawnBug()
    Playtest.shot("05_camp")
    Playtest.log("wildlife birds=" .. #E.critters.birds .. " bugs=" .. #E.critters.bugs)
    nextStep()
  elseif s == 12 then
    -- let birds leave the branch before the camp shot
    if t > 0.35 and #E.critters.birds == 0 then E.spawnBird() end
    if t > 0.55 and #E.critters.bugs == 0 then E.spawnBug() end
  elseif s == 13 then
    if t >= 0.12 then
      if Playtest._walk == 0 then E.player.x, E.player.y = E.creekCenterX(7) - 1, 7 end
      local dirs = { {1,0}, {0,1}, {-1,0}, {0,-1} }
      local d = dirs[(Playtest._walk % 4) + 1]
      E.tryMove(d[1], d[2])
      Playtest.t = 0
      Playtest._walk = Playtest._walk + 1
      if Playtest._walk >= 4 then
        Playtest._walk = 0
        Playtest.log("walk_dirs_ok splash=" .. tostring(#E.splashFX.drops))
        nextStep()
      end
    end
  elseif s == 14 and t > 0.25 then
    E.player.x, E.player.y = 10, 9
    E.selected = 1
    E.tryUseGear() -- 单款帐篷：A 直接展开
    Playtest.log("tentOpen=" .. tostring(E.tentOpen) .. " at=" .. tostring(E.tentPos and E.tentPos.x) .. "," .. tostring(E.tentPos and E.tentPos.y) .. " mood=" .. tostring(TentGear.mood))
    Playtest.log("tentGround=" .. tostring(E.tentPos and E.tentPos.ground))
    if not Playtest.require(E.tentOpen == true, "tent_not_open") then return end
    if not Playtest.require(E.ritual == nil, "tent_should_open_without_ritual") then return end
    if not Playtest.require(TentGear.mood ~= nil, "tent_mood_missing") then return end
    if not Playtest.require(E.tentPos and E.tentPos.ground == 7, "tent_ground_not_dirt") then return end
    nextStep()
  elseif s == 15 and t > 0.35 then Playtest.shot("05b_tent_open"); nextStep()
  elseif s == 16 and t > 0.2 then
    E.selected = 2
    E.tryUseGear() -- start drip wizard
    Playtest.log("ritual=" .. tostring(E.ritual and E.ritual.kind) .. " phase=" .. tostring(E.ritual and E.ritual.phase))
    nextStep()
  elseif s == 17 and t > 0.25 then
    -- 走完选豆→研磨→滤杯→滤纸→水温→冲次→三步冲煮
    for _ = 1, 24 do
      if not E.ritual or E.ritual.kind ~= "drip" then break end
      if E.ritual.phase == "bean" then E.ritual.pick = 2 end -- 秘鲁
      if E.ritual.phase == "dripper" then E.ritual.pick = 1 end -- V60
      if E.ritual.phase == "temp" then E.ritual.pick = 1 end -- 92
      if E.ritual.phase == "pours" then E.ritual.pick = 2 end -- 3次
      E.tryUseGear()
    end
    Playtest.shot("05c_drip_ritual")
    Playtest.log("brewTaste=" .. tostring(DripBrew.taste) .. " dripped=" .. tostring(E.drippedOnce))
    nextStep()
  elseif s == 18 and t > 0.15 then
    E.selected = 5
    for _ = 1, 40 do
      if E.coffeeCups >= 3 and not E.ritual then break end
      if E.ritual and E.ritual.kind == "cup_sip" then
        if E.ritual.phase == "focus" then E.ritual.pick = 3 end
        E.tryUseGear()
      elseif E.cupPick then
        E.cupStyle = (E.cupStyle % E.cupStylesCount) + 1
        E.applyCupIcon()
        E.drinkFromCup()
      else
        E.drinkFromCup()
      end
    end
    Playtest.log("dripped=" .. tostring(E.drippedOnce) .. " coffeeCups=" .. tostring(E.coffeeCups) .. " cap=" .. tostring(E.coffeeCups == DripBrew.CUPS_PER_POT) .. " cupStyle=" .. tostring(E.cupStyle))
    nextStep()
  elseif s == 19 and t > 0.15 then
    -- 喝空后再冲一壶
    E.selected = 2
    E.tryUseGear()
    Playtest.log("rebrewStart=" .. tostring(E.ritual and E.ritual.phase))
    for _ = 1, 24 do
      if not E.ritual or E.ritual.kind ~= "drip" then break end
      E.tryUseGear()
    end
    Playtest.log("rebrew=" .. tostring(E.drippedOnce) .. " coffeeCups=" .. tostring(E.coffeeCups) .. " taste=" .. tostring(DripBrew.taste ~= nil))
    nextStep()
  elseif s == 20 and t > 0.15 then
    E.selected = 3 -- tea
    TeaBrew.start()
    Playtest.log("teaRitual=" .. tostring(E.ritual and E.ritual.kind) .. " phase=" .. tostring(E.ritual and E.ritual.phase))
    for _ = 1, 28 do
      if not E.ritual or E.ritual.kind ~= "tea" then break end
      if E.ritual.phase == "leaf" then E.ritual.pick = 1 end
      if E.ritual.phase == "temp" then E.ritual.pick = 2 end
      TeaBrew.advance()
    end
    Playtest.log("teaTaste=" .. tostring(TeaBrew.taste) .. " teaCups=" .. tostring(E.teaCups))
    nextStep()
  elseif s == 21 and t > 0.2 then
    E.selected = 6 -- cook
    E.tryUseGear()
    Playtest.log("cook=" .. tostring(E.ritual and E.ritual.kind) .. " phase=" .. tostring(E.ritual and E.ritual.phase))
    for _ = 1, 20 do
      if not E.ritual or E.ritual.kind ~= "cook" then break end
      if E.ritual.phase == "cuisine" then E.ritual.pick = 2 end -- sushi
      if E.ritual.phase == "heat" then E.ritual.pick = 2 end
      if E.ritual.phase == "season" then E.ritual.pick = 3 end -- citrus
      E.tryUseGear()
    end
    Playtest.log("cookTaste=" .. tostring(CookMeal.taste) .. " meals=" .. tostring(State.trip.haul.meals))
    nextStep()
  elseif s == 22 and t > 0.5 then Playtest.shot("05d_cook"); nextStep()
  elseif s == 23 and t > 0.2 then
    -- 摘果：走到挂果树旁
    E.player.x, E.player.y = 3, 8
    E.tryUseGear()
    Playtest.log("fruit=" .. tostring(State.trip.haul.fruit))
    nextStep()
  elseif s == 24 and t > 0.35 then Playtest.shot("05d2_fruit"); nextStep()
  elseif s == 25 and t > 0.2 then
    E.player.x, E.player.y = E.creekCenterX(7), 7
    E.selected = 4 -- rod
    love.math.setRandomSeed(7)
    E.tryUseGear()
    Playtest.log("rodStart=" .. tostring(E.ritual and E.ritual.phase))
    for _ = 1, 24 do
      if not E.ritual or E.ritual.kind ~= "rod" then break end
      if E.ritual.phase == "spot" then E.ritual.pick = 1 end -- 浅滩
      if E.ritual.phase == "bait" then E.ritual.pick = 4 end -- 昆虫
      if E.ritual.phase == "style" then E.ritual.pick = 2 end -- 轻抽
      FishRod.advance()
    end
    Playtest.log("rodMood=" .. tostring(FishRod.mood) .. " fish=" .. tostring(State.trip.haul.fish.ayu))
    nextStep()
  elseif s == 26 and t > 0.5 then
    Playtest.shot("05e_fish")
    Playtest.log("fishHaul=" .. tostring(Persist.fishTotalOf(State.trip.haul.fish)) .. " fruit=" .. tostring(State.trip.haul.fruit))
    nextStep()
  elseif s == 27 and t > 0.2 then
    -- 返回二次确认：弹窗 → 取消 → 仍留在营地
    Flow.openQuitConfirm()
    if not Playtest.require(R.quitConfirm == true, "quit_confirm_not_open") then return end
    Playtest.shot("05f_quit_confirm")
    Flow.cancelQuitConfirm()
    if not Playtest.require(R.quitConfirm == false, "quit_confirm_stuck") then return end
    if not Playtest.require(E.scene == "play", "quit_confirm_left_play") then return end
    Playtest.log("quitConfirm=cancelled scene=" .. E.scene)
    nextStep()
  elseif s == 28 and t > 0.25 then
    Time.setClock(20 * 60)
    Time.unfreeze()
    E.selected = 3
    E.player.x, E.player.y = E.firepit.x - 1, E.firepit.y
    E.tryUseGear()
    Playtest.log("lantern=" .. tostring(E.lanternOn))
    E.spawnMeteor(); E.spawnLeaf(); E.spawnLeaf(); E.spawnBug(); E.spawnBug()
    for _, u in ipairs(E.critters.bugs) do u.kind = "firefly" end
    nextStep()
  elseif s == 29 and t > 0.55 then
    Playtest.shot("06_night_lamp")
    Playtest.log("night stars=" .. #E.nightFX.stars .. " meteors=" .. #E.nightFX.meteors)
    nextStep()
  elseif s == 30 and t > 0.25 then
    Time.setClock(4 * 60 + 10) -- 04:10 黎明可回家
    Playtest.log("dawn day=" .. Time.dayIndex() .. " time=" .. Time.label())
    E.canGoHome = true
    nextStep()
  elseif s == 31 and t > 0.25 then E.goHomecoming(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 32 and t > 0.35 then Playtest.shot("07_home"); nextStep()
  elseif s == 33 and t > 0.25 then E.advanceHome(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 34 and t > 0.4 then
    if not Playtest.require(E.scene == "diary", "not_in_diary") then return end
    Playtest.shot("07b_diary")
    local audit = StoryDraw.diaryAudit()
    Playtest.log("diaryLines=" .. table.concat(audit.lines, " | "))
    Playtest.log("diaryBottom=" .. tostring(audit.bottomHaul))
    Playtest.log("diaryInkW=" .. tostring(audit.inkW))
    for _, iss in ipairs(audit.issues) do
      Playtest.log("diaryIssue=" .. iss)
    end
    if not Playtest.require(audit.ok, "diary_display:" .. table.concat(audit.issues, ",")) then return end
    Playtest.log("diaryAudit=ok count=" .. #audit.lines)
    nextStep()
  elseif s == 35 and t > 0.25 then
    E.finishDiary()
    Playtest.log("save trips=" .. tostring(State.save.data.trips) .. " fruit=" .. tostring(State.save.data.totals.fruit) .. " fish=" .. tostring(State.save.data.totals.fishTotal))
    Playtest.log("-> " .. E.scene)
    nextStep()
  elseif s == 36 and t > 0.35 then Playtest.shot("08_back_title"); nextStep()
  elseif s == 37 and t > 0.2 then
    E.menuIndex = 4 -- 装备图鉴
    E.confirmMenu()
    Playtest.log("-> " .. E.scene)
    nextStep()
  elseif s == 38 and t > 0.35 then Playtest.shot("09_codex"); nextStep()
  elseif s == 39 and t > 0.15 then E.moveCodex(1); nextStep()
  elseif s == 40 and t > 0.25 then
    Playtest.log("codex=" .. tostring(E.gear[E.codex.i] and E.gear[E.codex.i].id))
    nextStep()
  elseif s == 41 and t > 0.2 then
    E.goTitle()
    E.menuIndex = 5 -- 关于
    E.confirmMenu()
    Playtest.log("-> " .. E.scene)
    nextStep()
  elseif s == 42 and t > 0.35 then
    Playtest.shot("10_about")
    Playtest.log("steps=" .. tostring(Playtest.step + 1))
    love.filesystem.write(Playtest.outDir .. "/result.txt", table.concat(Playtest.lines, "\n") .. "\nPASS\n")
    Playtest.done = true
    Playtest.log("PASS")
    love.event.quit()
  end

end

return Playtest
