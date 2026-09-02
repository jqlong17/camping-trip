--[[ 露营之旅 — 装备/仪式/收获/杯子（见 docs/*模块-SPEC.md） ]]

local GearPlay = {}
local H

local FISH_NAMES = { ayu = "香鱼", trout = "溪鳟", carp = "鲤鱼" }

function GearPlay.bindHost(h)
  H = h
  local function ritualCore()
    return {
      say = H.say,
      playSfx = H.playSfx,
      getRitual = H.getRitual,
      setRitual = H.setRitual,
      clearRitual = H.clearRitual,
      ensureRitual = H.ensureRitual,
      playerXY = H.playerXY,
      onBrewMap = H.onBrewMap,
      selectCup = H.selectCup,
    }
  end
  DripBrew.bind({
    say = H.say,
    playSfx = H.playSfx,
    getRitual = H.getRitual,
    setRitual = H.setRitual,
    clearRitual = H.clearRitual,
    ensureRitual = H.ensureRitual,
    getPot = H.getCoffeePot,
    setPot = H.setCoffeePot,
    drinkCoffee = H.drinkCoffee,
    selectCup = H.selectCup,
    playerXY = H.playerXY,
    onBrewMap = H.onBrewMap,
    addTripCoffee = H.addTripCoffee,
  })
  TeaBrew.bind({
    say = H.say,
    playSfx = H.playSfx,
    getRitual = H.getRitual,
    setRitual = H.setRitual,
    clearRitual = H.clearRitual,
    ensureRitual = H.ensureRitual,
    getPot = H.getTeaPot,
    setPot = H.setTeaPot,
    drinkTea = H.drinkTea,
    selectCup = H.selectCup,
    playerXY = H.playerXY,
    onBrewMap = H.onBrewMap,
    addTripTea = H.addTripTea,
  })
  FishRod.bindHost({
    say = H.say,
    playSfx = H.playSfx,
    getRitual = H.getRitual,
    setRitual = H.setRitual,
    clearRitual = H.clearRitual,
    ensureRitual = H.ensureRitual,
    onFishSplash = H.onFishSplash,
    addFish = H.addFish,
    fishName = function(k) return FISH_NAMES[k] or k end,
  })
  TentGear.bind({
    say = H.say,
    playSfx = H.playSfx,
    getRitual = H.getRitual,
    setRitual = H.setRitual,
    clearRitual = H.clearRitual,
    ensureRitual = H.ensureRitual,
    playerXY = H.playerXY,
    walkable = H.walkable,
    getTentOpen = H.getTentOpen,
    getTentStyle = H.getTentStyle,
    setTentStyle = H.setTentStyle,
    pitchTent = function()
      return GearPlay.setTentMap(true)
    end,
    packTent = function()
      GearPlay.setTentMap(false)
    end,
  })
  CupSip.bind({
    say = H.say,
    playSfx = H.playSfx,
    getRitual = H.getRitual,
    setRitual = H.setRitual,
    clearRitual = H.clearRitual,
    ensureRitual = H.ensureRitual,
  })
  CookMeal.bind({
    say = H.say,
    playSfx = H.playSfx,
    getRitual = H.getRitual,
    setRitual = H.setRitual,
    clearRitual = H.clearRitual,
    ensureRitual = H.ensureRitual,
    addTripMeal = H.addTripMeal,
  })
end

function GearPlay.nearCreek()
  local px, py = H.playerXY()
  for _, d in ipairs({ {0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1} }) do
    local t = H.tileAt(px + d[1], py + d[2])
    if H.isWater(t) then return true end
  end
  return false
end

function GearPlay.tryHarvestFruit()
  local px, py = H.playerXY()
  local trees = H.getFruitTrees()
  for _, d in ipairs({ {0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1} }) do
    local key = tostring(px + d[1]) .. ":" .. tostring(py + d[2])
    local left = trees[key]
    if left and left > 0 then
      trees[key] = left - 1
      local haul = H.getHaul()
      haul.fruit = (haul.fruit or 0) + 1
      H.playSfx("ui_ok")
      if trees[key] <= 0 then
        H.say("摘到果子了 · 这棵没了", 2.5)
      else
        H.say("摘到果子了 · 还能再摘", 2.5)
      end
      return true
    end
  end
  return false
end

function GearPlay.setTentMap(on)
  local m = H.getMap()
  local function restoreGround(x, y, ground)
    if m[y] then m[y][x] = ground or 7 end
  end
  -- 收起：恢复搭帐前地面（不要写成草地 1，否则留下绿方块）
  local prev = H.getTentPos and H.getTentPos()
  if prev and prev.x and prev.y then
    restoreGround(prev.x, prev.y, prev.ground)
  end
  for y, row in pairs(m) do
    if type(row) == "table" then
      for x, t in pairs(row) do
        if t == 5 then row[x] = 7 end
      end
    end
  end
  if on then
    local px, py = H.playerXY()
    if not H.walkable(px, py) then return false end
    if H.canPitchTent and not H.canPitchTent(px, py) then return false end
    local ground = (m[py] and m[py][px]) or 7
    if ground == 5 then ground = 7 end
    H.setTentPos(px, py, ground)
    if m[py] then m[py][px] = 5 end
    H.setTentOpen(true)
  else
    H.setTentPos(nil, nil)
    H.setTentOpen(false)
  end
  -- 地图改了必须重建 propRows，否则帐篷不进绘制列表
  if CampMap.indexRenderData then CampMap.indexRenderData() end
  return true
end

function GearPlay.toggleTent()
  if H.getTentOpen() then
    GearPlay.setTentMap(false)
    H.playSfx("tent")
    H.say("帐篷收起来了。", 2)
    return
  end
  local px, py = H.playerXY()
  if not H.walkable(px, py) then
    H.say("这里搭不了帐篷", 2)
    return
  end
  if GearPlay.setTentMap(true) then
    H.playSfx("tent")
    H.say("帐篷搭好了。", 2.5)
  end
end

function GearPlay.tryLightLantern()
  if H.getLanternOn() then return false end
  if Time.index() < 5 then return false end
  if not H.nearFire() then return false end
  H.setLanternOn(true)
  H.setCanGoHome(true)
  H.playSfx("lantern")
  H.say("点亮了露营灯 · 夜色温柔。", 3.5)
  return true
end

function GearPlay.advanceRitual()
  local r = H.getRitual()
  if not r then return end
  if r.kind == "drip" then DripBrew.advance()
  elseif r.kind == "tea" then TeaBrew.advance()
  elseif r.kind == "rod" then FishRod.advance()
  elseif r.kind == "tent" then TentGear.advance()
  elseif r.kind == "cup_sip" then CupSip.advance()
  elseif r.kind == "cook" then CookMeal.advance() end
end

function GearPlay.nudgeRitual(dir)
  local r = H.getRitual()
  if not r then return false end
  if r.kind == "drip" then DripBrew.nudge(dir); return true
  elseif r.kind == "tea" then TeaBrew.nudge(dir); return true
  elseif r.kind == "rod" then FishRod.nudge(dir); return true
  elseif r.kind == "tent" then TentGear.nudge(dir); return true
  elseif r.kind == "cup_sip" then CupSip.nudge(dir); return true
  elseif r.kind == "cook" then CookMeal.nudge(dir); return true
  end
  return false
end

function GearPlay.cancelRitual()
  local r = H.getRitual()
  if not r then return end
  if r.kind == "tent" then TentGear.cancel(); return end
  if r.kind == "cook" then CookMeal.cancel(); return end
  if r.kind == "cup_sip" then H.clearRitual(); return end
  H.clearRitual()
  H.setBrewActive(false)
  local label = (r.kind == "tea" and "泡茶") or (r.kind == "rod" and "钓鱼") or "手冲"
  H.say("取消了" .. label, 2)
end

function GearPlay.tryUseGear()
  if GearPlay.tryHarvestFruit() then return end
  local r = H.getRitual()
  if r then
    GearPlay.advanceRitual()
    return
  end
  -- 入夜 + 靠近篝火：优先点火，不依赖选中哪件装备（DEV-052）
  if GearPlay.tryLightLantern() then return end
  local g = H.getGear()[H.getSelected()]
  if not g then return end
  if g.id == "tent" then
    TentGear.start()
  elseif g.id == "drip" then
    DripBrew.start()
  elseif g.id == "tea" then
    TeaBrew.start()
  elseif g.id == "rod" then
    if GearPlay.nearCreek() then FishRod.start()
    else H.say(Destinations.currentId() == "coast" and "去浪边再试试。" or "去小溪边再试试。", 2.5) end
  elseif g.id == "cup" then
    H.drinkFromCup()
  elseif g.id == "cook" then
    CookMeal.start()
  else
    H.say("拿起了" .. g.name, 2)
  end
end

function GearPlay.diaryTripLines()
  local h = State.trip.haul
  local lines = {}
  if (h.fruit or 0) > 0 then lines[#lines + 1] = "摘了 " .. h.fruit .. " 个野果。" end
  if (h.coffee or 0) > 0 then lines[#lines + 1] = "手冲咖啡 " .. h.coffee .. " 壶。" end
  if (h.tea or 0) > 0 then lines[#lines + 1] = "泡茶 " .. h.tea .. " 壶。" end
  if (h.meals or 0) > 0 then lines[#lines + 1] = "做了 " .. h.meals .. " 顿饭。" end
  local ft = Persist.fishTotalOf(h.fish)
  if ft > 0 then lines[#lines + 1] = "钓到鱼 " .. ft .. " 条。" end
  if DripBrew.taste then lines[#lines + 1] = "咖啡：" .. DripBrew.taste end
  if TeaBrew.taste then lines[#lines + 1] = "茶：" .. TeaBrew.taste end
  if CookMeal.taste then lines[#lines + 1] = "饭：" .. CookMeal.taste end
  if TentGear.mood then lines[#lines + 1] = "帐：" .. TentGear.mood end
  if FishRod.mood then lines[#lines + 1] = "钓：" .. FishRod.mood end
  if #lines == 0 then lines[#lines + 1] = "安静的一天。也很好。" end
  return lines
end

return GearPlay
