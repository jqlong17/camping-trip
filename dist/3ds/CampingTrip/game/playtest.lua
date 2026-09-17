--[[ 露营之旅 — 桌面/CI playtest（见 docs/代码架构-SPEC.md） ]]

local Playtest = {
  on = false,
  t = 0,
  step = 0,
  done = false,
  lines = {},
  outDir = "playtest",
  _walk = 0,
  _tentShotPhase = 0,
  _teaPreviewShots = {},
}

local E
local StoryDraw = require("draw.story")
local Flow = require("scene_flow")
local R = require("runtime")
local TEST_DESTINATION = os.getenv("LINJIAN_PLAYTEST_DESTINATION") == "forest" and "forest" or "coast"
Playtest.outDir = "playtest-" .. TEST_DESTINATION

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
  elseif s == 9 and t > 0.35 then
    State.destination.i = TEST_DESTINATION == "coast" and 2 or 1
    Playtest.shot("04_destination_" .. TEST_DESTINATION)
    Playtest.log("destinationChoice=" .. TEST_DESTINATION)
    nextStep()
  elseif s == 10 and t > 0.2 then E.confirmDestination(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 11 and t > 0.2 then
    if not Playtest._arrivalReady then
      E.advanceDepart()
      Playtest._arrivalReady = true
      Playtest.t = 0
      return
    end
    if not Playtest._arrivalGo then
      Playtest.shot("04b_" .. TEST_DESTINATION .. "_arrive")
      E.advanceDepart()
      Playtest._arrivalGo = true
      Playtest.t = 0
    end
    if E.scene ~= "play" then
      if Playtest.t > 20 then
        Playtest.fail("arrival timeout scene=" .. tostring(E.scene))
      end
      return
    end
    Playtest.log("-> " .. E.scene .. " destination=" .. Destinations.currentId())
    nextStep()
  elseif s == 12 and t > 1.15 then
    E.spawnBird(); E.spawnBird(); E.spawnBug(); E.spawnBug()
    Playtest.shot(TEST_DESTINATION == "coast" and "05_coast_sunrise_camp" or "05_forest_camp_day")
    Playtest.log("wildlife birds=" .. #E.critters.birds .. " bugs=" .. #E.critters.bugs)
    nextStep()
  elseif s == 12 then
    -- let birds leave the branch before the camp shot
    if t > 0.35 and #E.critters.birds == 0 then E.spawnBird() end
    if t > 0.55 and #E.critters.bugs == 0 then E.spawnBug() end
  elseif s == 13 then
    if t >= 0.12 then
      if Playtest._walk == 0 then
        if TEST_DESTINATION == "coast" then
          E.player.x, E.player.y = 10, 4
          if not Playtest.require(
            not CampMap.walkable(10, 3) and CampMap.walkable(10, 4),
            "coast_water_boundary_changed"
          ) then return end
        else
          E.player.x, E.player.y = E.creekCenterX(7) - 1, 7
          if not Playtest.require(
            CampMap.isWater(CampMap.tileAt(E.player.x, E.player.y))
              and CampMap.walkable(E.player.x, E.player.y),
            "creek_water_collision_changed"
          ) then return end
        end
      end
      local dirs = { {1,0}, {0,1}, {-1,0}, {0,-1} }
      local d = dirs[(Playtest._walk % 4) + 1]
      E.tryMove(d[1], d[2])
      Playtest.t = 0
      Playtest._walk = Playtest._walk + 1
      if Playtest._walk >= 4 then
        Playtest._walk = 0
        if TEST_DESTINATION == "forest" and not Playtest.require(#E.splashFX.drops > 0, "creek_splash_missing") then return end
        local steps, piers = 0, 0
        for _, decal in ipairs(CampMap.getDecals()) do
          if decal.kind == "step" then steps = steps + 1 end
          if decal.kind == "pier" then piers = piers + 1 end
        end
        if TEST_DESTINATION == "forest" and not Playtest.require(steps == 3 and piers == 1, "creek_landmarks_changed") then return end
        Playtest.log("walk_dirs_ok splash=" .. tostring(#E.splashFX.drops))
        Playtest.log(TEST_DESTINATION == "coast"
          and "coastCollision=sea_blocked wet_sand_walkable"
          or "creekCollision=walkable landmarks=3_steps+1_pier")
        nextStep()
      end
    end
  elseif s == 14 and t > 0.25 then
    local spawn = Destinations.current().spawn
    E.player.x, E.player.y = spawn.x, spawn.y
    E.selected = 1
    E.tryUseGear() -- 单款帐篷：A 直接展开
    Playtest.log("tentOpen=" .. tostring(E.tentOpen) .. " at=" .. tostring(E.tentPos and E.tentPos.x) .. "," .. tostring(E.tentPos and E.tentPos.y) .. " mood=" .. tostring(TentGear.mood))
    Playtest.log("tentGround=" .. tostring(E.tentPos and E.tentPos.ground))
    local tentImage = Assets.get().tentOpen
    if not Playtest.require(
      tentImage and tentImage:getWidth() == 96 and tentImage:getHeight() == 72,
      "tent_hd_asset_not_loaded"
    ) then return end
    Playtest.log("tentAsset=96x72 display=48x36 bboxDisplay=46x34")
    if not Playtest.require(E.tentOpen == true, "tent_not_open") then return end
    if not Playtest.require(E.ritual == nil, "tent_should_open_without_ritual") then return end
    if not Playtest.require(TentGear.mood ~= nil, "tent_mood_missing") then return end
    if not Playtest.require(E.tentPos and E.tentPos.ground == 7, "tent_ground_not_dirt") then return end
    local tentX, tentY = E.tentPos.x, E.tentPos.y
    if not Playtest.require(
      CampMap.tentOccupies(tentX - 1, tentY) and CampMap.tentOccupies(tentX, tentY)
        and CampMap.tentOccupies(tentX + 1, tentY),
      "tent_footprint_not_three_tiles"
    ) then return end
    if not Playtest.require(
      not CampMap.walkable(tentX - 1, tentY) and not CampMap.walkable(tentX, tentY)
        and not CampMap.walkable(tentX + 1, tentY),
      "tent_footprint_walkable"
    ) then return end
    Playtest.log("tentFootprint=" .. tostring(tentX - 1) .. ".." .. tostring(tentX + 1) .. "@" .. tostring(tentY) .. " blocked=true")
    -- 遮挡截图只保留帐篷与人物，避免蝴蝶/小鸟飞过主体干扰视觉验收。
    E.critters.birds, E.critters.bugs = {}, {}
    nextStep()
  elseif s == 15 then
    if Playtest._tentShotPhase == 0 and t > 0.25 then
      E.player.x, E.player.y = 10, 8
      Playtest.shot("05b_tent_player_behind")
      Playtest._tentShotPhase = 1
    elseif Playtest._tentShotPhase == 1 and t > 0.65 then
      E.player.x, E.player.y = 10, 10
      Playtest.shot("05b2_tent_player_front")
      Playtest._tentShotPhase = 2
    elseif Playtest._tentShotPhase == 2 then
      Playtest.log("tentYSort=behind_occluded front_visible")
      nextStep()
    end
  elseif s == 16 and t > 0.2 then
    E.selected = 2
    local started, startErr = pcall(E.tryUseGear)
    if not started then
      Playtest.fail("drip_start_error " .. tostring(startErr))
      return
    end
    Playtest.log("ritual=" .. tostring(E.ritual and E.ritual.kind) .. " phase=" .. tostring(E.ritual and E.ritual.phase))
    local bag = Assets.get().ritual
    local dripOnly = bag and bag.readyKinds and bag.readyKinds.drip == true and bag.readyKinds.tea ~= true
    Playtest.log("dripOnly=" .. tostring(dripOnly))
    if not Playtest.require(dripOnly, "drip_must_not_preload_tea") then return end
    nextStep()
  elseif s == 17 and t > 0.25 then
    if not Playtest._dripPreviewShot then
      Playtest.shot("05c0_drip_top_preview")
      Playtest._dripPreviewShot = true
      return
    end
    if E.ritual and E.ritual.phase == "bean" then
      E.ritual.pick = 2 -- 秘鲁
      E.tryUseGear()
      return
    elseif E.ritual and E.ritual.phase == "grind" then
      E.tryUseGear()
      return
    elseif E.ritual and E.ritual.phase == "dripper" then
      E.ritual.pick = 1 -- V60
      if not Playtest._dripDripperShot then
        Playtest.shot("05c0a_drip_phase003_dripper")
        Playtest._dripDripperShot = true
      else
        E.tryUseGear()
      end
      return
    elseif E.ritual and E.ritual.phase == "paper" then
      if not Playtest._dripPaperShot then
        Playtest.shot("05c0b_drip_phase004_paper")
        Playtest._dripPaperShot = true
      else
        E.tryUseGear()
      end
      return
    elseif E.ritual and E.ritual.phase == "temp" then
      E.ritual.pick = 1 -- 92
      E.tryUseGear()
      return
    elseif E.ritual and E.ritual.phase == "pours" then
      E.ritual.pick = 3 -- 4次，验证最多轨迹节点的预览
      if not Playtest._dripPoursShot then
        Playtest.shot("05c0c_drip_phase006_pours4")
        Playtest._dripPoursShot = true
        return
      end
    end
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
    if not Playtest._cupPreviewReady then
      E.drinkFromCup()
      if E.cupPick and not E.ritual then E.drinkFromCup() end
      Playtest._cupPreviewReady = true
      return
    elseif not Playtest._cupPreviewShot and E.ritual and E.ritual.kind == "cup_sip" then
      Playtest.shot("05c1_cup_top_preview")
      Playtest._cupPreviewShot = true
      return
    end
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
    if not Playtest._teaPreviewReady then
      TeaBrew.start()
      Playtest._teaPreviewReady = true
      Playtest.log("teaRitual=" .. tostring(E.ritual and E.ritual.kind) .. " phase=" .. tostring(E.ritual and E.ritual.phase))
      return
    end
    if E.ritual and E.ritual.kind == "tea" then
      if E.ritual.phase == "leaf" then E.ritual.pick = 1 end
      if E.ritual.phase == "temp" then E.ritual.pick = 2 end
      local shotKey = E.ritual.phase
      if shotKey == "brew" then shotKey = "brew" .. tostring(E.ritual.brewStep) end
      local shotNames = {
        leaf = "05c0_tea_leaf_preview",
        ware = "05c1_tea_ware_preview",
        rinse = "05c2_tea_rinse_preview",
        temp = "05c3_tea_temp_preview",
        brew3 = "05c4_tea_brew_preview"
      }
      if shotNames[shotKey] and not Playtest._teaPreviewShots[shotKey] then
        Playtest.shot(shotNames[shotKey])
        Playtest._teaPreviewShots[shotKey] = true
        return
      end
      TeaBrew.advance()
      return
    end
    Playtest.log("teaTaste=" .. tostring(TeaBrew.taste) .. " teaCups=" .. tostring(E.teaCups))
    nextStep()
  elseif s == 21 and t > 0.2 then
    E.selected = 6 -- cook
    if not Playtest._cookPreviewReady then
      E.tryUseGear()
      Playtest._cookPreviewReady = true
      return
    elseif not Playtest._cookPreviewShot then
      Playtest.shot("05d0_cook_top_preview")
      Playtest._cookPreviewShot = true
      return
    end
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
    if TEST_DESTINATION == "forest" then
      E.player.x, E.player.y = 3, 8
      E.tryUseGear()
    end
    Playtest.log("fruit=" .. tostring(State.trip.haul.fruit))
    nextStep()
  elseif s == 24 and t > 0.35 then Playtest.shot("05d2_fruit"); nextStep()
  elseif s == 25 and t > 0.2 then
    E.player.x, E.player.y = TEST_DESTINATION == "coast" and 10 or E.creekCenterX(7), TEST_DESTINATION == "coast" and 4 or 7
    E.selected = 4 -- rod
    love.math.setRandomSeed(7)
    if not Playtest._fishPreviewReady then
      E.tryUseGear()
      Playtest._fishPreviewReady = true
      return
    elseif not Playtest._fishPreviewShot then
      Playtest.shot("05e0_fish_top_preview")
      Playtest._fishPreviewShot = true
      return
    end
    Playtest.log("rodStart=" .. tostring(E.ritual and E.ritual.phase))
    if not Playtest.require(E.ritual and E.ritual.kind == "rod", "rod_not_available_at_destination_water") then return end
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
    if TEST_DESTINATION == "coast" then
      Time.setClock(18 * 60)
      Playtest.shot("05f_coast_sunset")
    end
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
    Playtest.shot("06_" .. TEST_DESTINATION .. "_night_lamp")
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
    Playtest.shot("07b_diary_page1")
    local audit = StoryDraw.diaryAudit()
    for i, page in ipairs(audit.pages) do
      Playtest.log("diaryPage" .. i .. "=" .. page.title .. " | " .. page.body)
    end
    for _, iss in ipairs(audit.issues) do
      Playtest.log("diaryIssue=" .. iss)
    end
    if not Playtest.require(audit.ok, "diary_display:" .. table.concat(audit.issues, ",")) then return end
    if not Playtest.require(audit.characterOverlay == false, "diary_character_overlay_present") then return end
    Playtest.log("diaryCharacterOverlay=none")
    Playtest.log("diaryAudit=ok pages=" .. #audit.pages)
    nextStep()
  elseif s == 35 and t > 0.25 then
    Flow.nudgeDiary(1)
    if not Playtest.require(R.diaryPage == 2, "diary_page2_navigation") then return end
    nextStep()
  elseif s == 36 and t > 0.35 then
    Playtest.shot("07c_diary_page2")
    nextStep()
  elseif s == 37 and t > 0.2 then
    Flow.nudgeDiary(1)
    if not Playtest.require(R.diaryPage == 3, "diary_page3_navigation") then return end
    nextStep()
  elseif s == 38 and t > 0.35 then
    Playtest.shot("07d_diary_page3")
    nextStep()
  elseif s == 39 and t > 0.25 then
    E.finishDiary()
    Playtest.log("save trips=" .. tostring(State.save.data.trips) .. " fruit=" .. tostring(State.save.data.totals.fruit) .. " fish=" .. tostring(State.save.data.totals.fishTotal))
    Playtest.log("-> " .. E.scene)
    nextStep()
  elseif s == 40 and t > 0.35 then Playtest.shot("08_back_title"); nextStep()
  elseif s == 41 and t > 0.2 then
    if not Playtest._titleContinue then
      E.menuIndex = 2
      E.confirmMenu()
      Playtest._titleContinue = true
      Playtest.t = 0
      return
    end
    if E.scene == "depart" then
      Playtest.fail("title continue jumped to depart")
      return
    end
    if E.scene ~= "play" then
      if Playtest.t > 20 then Playtest.fail("title continue timeout scene=" .. tostring(E.scene)) end
      return
    end
    Playtest.log("titleContinue -> play")
    E.goTitle()
    nextStep()
  elseif s == 42 and t > 0.2 then
    E.menuIndex = 4 -- 装备图鉴
    E.confirmMenu()
    Playtest.log("-> " .. E.scene)
    nextStep()
  elseif s == 43 and t > 0.35 then Playtest.shot("09_codex"); nextStep()
  elseif s == 44 and t > 0.15 then E.moveCodex(1); nextStep()
  elseif s == 45 and t > 0.25 then
    Playtest.log("codex=" .. tostring(E.gear[E.codex.i] and E.gear[E.codex.i].id))
    nextStep()
  elseif s == 46 and t > 0.2 then
    E.goTitle()
    E.menuIndex = 5 -- 关于
    E.confirmMenu()
    Playtest.log("-> " .. E.scene)
    nextStep()
  elseif s == 47 and t > 0.35 then
    Playtest.shot("10_about")
    Playtest.log("steps=" .. tostring(Playtest.step + 1))
    love.filesystem.write(Playtest.outDir .. "/result.txt", table.concat(Playtest.lines, "\n") .. "\nPASS\n")
    Playtest.done = true
    Playtest.log("PASS")
    love.event.quit()
  end

end

return Playtest
