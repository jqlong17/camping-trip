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

function Playtest.tick(dt)
  if not Playtest.on or Playtest.done then return end
  if not E then return end
  Playtest.t = Playtest.t + dt
  local s, t = Playtest.step, Playtest.t

  local function nextStep()
    Playtest.step = Playtest.step + 1
    Playtest.t = 0
  end

  if s == 0 and t > 0.35 then Playtest.shot("01_title"); nextStep()
  elseif s == 1 and t > 0.25 then E.menuIndex = 1; E.confirmMenu(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 2 and t > 0.35 then Playtest.shot("02_prologue"); nextStep()
  elseif s == 3 and t > 0.2 then E.advancePrologue(); nextStep()
  elseif s == 4 and t > 0.2 then E.advancePrologue(); nextStep()
  elseif s == 5 and t > 0.2 then E.advancePrologue(); nextStep()
  elseif s == 6 and t > 0.2 then E.advancePrologue(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 7 and t > 0.35 then Playtest.shot("03_cast"); State.cast.i = 1; nextStep()
  elseif s == 8 and t > 0.25 then E.confirmCast(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 9 and t > 0.35 then Playtest.shot("04_depart"); nextStep()
  elseif s == 10 and t > 0.2 then E.advanceDepart(); nextStep()
  elseif s == 11 and t > 0.2 then E.advanceDepart(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 12 and t > 1.15 then
    E.spawnBird(); E.spawnBird(); E.spawnBug(); E.spawnBug()
    Playtest.shot("05_camp")
    Playtest.log("wildlife birds=" .. #E.critters.birds .. " bugs=" .. #E.critters.bugs)
    nextStep()
  elseif s == 12 then
    if t > 0.35 and #E.critters.birds == 0 then E.spawnBird() end
    if t > 0.55 and #E.critters.bugs == 0 then E.spawnBug() end
  elseif s == 13 then
    if t >= 0.12 then
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
    E.player.x, E.player.y = 11, 9
    E.selected = 1
    E.tryUseGear()
    Playtest.log("tentOpen=" .. tostring(E.tentOpen))
    nextStep()
  elseif s == 15 and t > 0.35 then Playtest.shot("05b_tent_open"); nextStep()
  elseif s == 16 and t > 0.2 then
    E.selected = 2
    E.tryUseGear()
    Playtest.log("ritual=" .. tostring(E.ritual and E.ritual.kind))
    nextStep()
  elseif s == 17 and t > 0.35 then Playtest.shot("05c_drip_ritual"); nextStep()
  elseif s == 18 and t > 0.15 then E.tryUseGear(); nextStep()
  elseif s == 19 and t > 0.15 then E.tryUseGear(); nextStep()
  elseif s == 20 and t > 0.15 then
    E.tryUseGear()
    E.tryUseGear()
    Playtest.log("dripped=" .. tostring(E.drippedOnce) .. " coffeeCups=" .. tostring(E.coffeeCups))
    nextStep()
  elseif s == 21 and t > 0.2 then
    E.selected = 6
    E.tryUseGear()
    Playtest.log("fan=" .. tostring(E.ritual and E.ritual.kind))
    nextStep()
  elseif s == 22 and t > 0.5 then Playtest.shot("05d_fan"); E.tryUseGear(); nextStep()
  elseif s == 23 and t > 0.2 then
    E.player.x, E.player.y = E.creekCenterX(7), 7
    E.selected = 4
    E.tryUseGear()
    Playtest.log("rod=" .. tostring(E.ritual and E.ritual.kind))
    nextStep()
  elseif s == 24 and t > 0.5 then Playtest.shot("05e_fish"); E.tryUseGear(); nextStep()
  elseif s == 25 and t > 0.25 then
    Time.setClock(20 * 60)
    Time.unfreeze()
    E.selected = 3
    local fp = E.firepit
    E.player.x, E.player.y = fp.x - 1, fp.y
    E.tryUseGear()
    Playtest.log("lantern=" .. tostring(E.lanternOn))
    E.spawnMeteor(); E.spawnLeaf(); E.spawnLeaf(); E.spawnBug(); E.spawnBug()
    for _, u in ipairs(E.critters.bugs) do u.kind = "firefly" end
    nextStep()
  elseif s == 26 and t > 0.55 then
    Playtest.shot("06_night_lamp")
    Playtest.log("night stars=" .. #E.nightFX.stars .. " meteors=" .. #E.nightFX.meteors)
    nextStep()
  elseif s == 27 and t > 0.25 then E.goHomecoming(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 28 and t > 0.35 then Playtest.shot("07_home"); nextStep()
  elseif s == 29 and t > 0.25 then E.advanceHome(); Playtest.log("-> " .. E.scene); nextStep()
  elseif s == 30 and t > 0.35 then Playtest.shot("08_back_title"); nextStep()
  elseif s == 31 and t > 0.2 then
    E.menuIndex = 4
    E.confirmMenu()
    Playtest.log("-> " .. E.scene)
    nextStep()
  elseif s == 32 and t > 0.35 then Playtest.shot("09_codex"); nextStep()
  elseif s == 33 and t > 0.15 then E.moveCodex(1); nextStep()
  elseif s == 34 and t > 0.25 then
    Playtest.log("codex=" .. tostring(E.gear[E.codex.i] and E.gear[E.codex.i].id))
    nextStep()
  elseif s == 35 and t > 0.2 then
    E.goTitle()
    E.menuIndex = 5
    E.confirmMenu()
    Playtest.log("-> " .. E.scene)
    nextStep()
  elseif s == 36 and t > 0.35 then
    Playtest.shot("10_about")
    love.filesystem.write(Playtest.outDir .. "/result.txt", table.concat(Playtest.lines, "\n") .. "\nPASS\n")
    Playtest.done = true
    Playtest.log("PASS")
    love.event.quit()
  end
end

return Playtest
