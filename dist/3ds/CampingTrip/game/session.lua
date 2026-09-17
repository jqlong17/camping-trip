-- 营地会话行为：玩家移动、杯壶、短仪式及 GearPlay 宿主。

local R = require("runtime")
local AP = require("asset_paths")
local Session = {}
local host

local CUP_COLS = 3

function Session.bindHost(h)
  host = h
  GearPlay.bindHost({
    say = h.say,
    playSfx = Audio.playSfx,
    getRitual = function() return R.ritual end,
    setRitual = function(v) R.ritual = v end,
    clearRitual = Session.clearRitual,
    ensureRitual = h.ensureRitual,
    playerXY = function() return R.player.x, R.player.y end,
    tileAt = CampMap.tileAt,
    isWater = CampMap.isWater,
    walkable = CampMap.walkable,
    canPitchTent = CampMap.canPitchTent,
    getMap = CampMap.getMap,
    getFruitTrees = function() return State.trip.fruitTrees end,
    getHaul = function() return State.trip.haul end,
    getGear = function() return R.gear end,
    getSelected = function() return R.selected end,
    getTentOpen = function() return R.tentOpen end,
    setTentOpen = function(v) R.tentOpen = v end,
    getTentPos = function() return R.tentPos end,
    setTentPos = function(x, y, ground)
      if x == nil or y == nil then R.tentPos = nil
      else R.tentPos = { x = x, y = y, ground = ground or 7 } end
    end,
    getTentStyle = function() return R.tentColorI or 1, R.tentStyleI or 1, R.tentDoorI or 1 end,
    setTentStyle = function(c, s, d)
      R.tentColorI, R.tentStyleI, R.tentDoorI = c or 1, s or 1, d or 1
    end,
    getLanternOn = function() return R.lanternOn end,
    setLanternOn = function(v) R.lanternOn = v end,
    setCanGoHome = function(v) R.canGoHome = v end,
    nearFire = function()
      local firepit = CampMap.getFirepit()
      return math.abs(R.player.x - firepit.x) + math.abs(R.player.y - firepit.y) <= 2
    end,
    getCoffeePot = function() return R.drippedOnce, R.coffeeCups end,
    setCoffeePot = function(ready, cups)
      R.drippedOnce, R.coffeeCups = ready, cups
      if ready then Session.selectCupGear() end
    end,
    getTeaPot = function() return R.teaReady, R.teaCups end,
    setTeaPot = function(ready, cups)
      R.teaReady, R.teaCups = ready, cups
      if ready then Session.selectCupGear() end
    end,
    drinkCoffee = Session.drinkCoffee,
    drinkTea = Session.drinkTea,
    drinkFromCup = Session.drinkFromCup,
    selectCup = Session.selectCupGear,
    onBrewMap = Session.onBrewMap,
    addTripCoffee = function(n) State.trip.haul.coffee = (State.trip.haul.coffee or 0) + (n or 1) end,
    addTripTea = function(n) State.trip.haul.tea = (State.trip.haul.tea or 0) + (n or 1) end,
    addTripMeal = function(n) State.trip.haul.meals = (State.trip.haul.meals or 0) + (n or 1) end,
    addFish = function(kind)
      local fish = State.trip.haul.fish
      fish[kind] = (fish[kind] or 0) + 1
    end,
    onFishSplash = function() CampWorld.getFishFX().timer = 0.05 end,
    setBrewActive = function(v) R.brewActive = v end,
  })
end

function Session.cupSlotRect(i)
  local col, row = (i - 1) % CUP_COLS, math.floor((i - 1) / CUP_COLS)
  return 16 + col * 96, 44 + row * 58, 92, 54
end

function Session.applyCupIcon()
  local icon = Assets.ensureCupIcon(R.cupStyle)
  if not icon then return end
  for _, gear in ipairs(R.gear) do
    if gear.id == "cup" then gear.icon = icon end
  end
end

function Session.nudgeCupStyle(dx, dy)
  local count = #AP.CUP_STYLES
  if dx ~= 0 then
    R.cupStyle = ((R.cupStyle - 1 + dx) % count) + 1
  elseif dy ~= 0 then
    local nextIndex = R.cupStyle + dy * CUP_COLS
    if nextIndex < 1 then nextIndex = nextIndex + count
    elseif nextIndex > count then nextIndex = nextIndex - count end
    R.cupStyle = nextIndex
  end
  Session.applyCupIcon()
  Audio.playSfx("ui_move")
end

function Session.applyCast(id)
  R.player.castId = id
  host.ensureCast(id)
  host.ensureWalk(id)
  Assets.get().player = Assets.get().cast[id] or Assets.get().player
end

function Session.clearRitual()
  R.ritual = nil
end

function Session.updateTimedRitual(_dt)
end

function Session.onBrewMap(x, y, timer)
  if x and y then
    R.brewActive, R.brewX, R.brewY = true, x, y
    R.brewTimer = timer or 12
  else
    R.brewTimer = timer or 8
  end
end

function Session.selectCupGear()
  for i, gear in ipairs(R.gear) do
    if gear.id == "cup" then R.selected = i; return end
  end
end

function Session.drinkCoffee()
  if not R.drippedOnce or R.coffeeCups >= DripBrew.CUPS_PER_POT then
    host.say("咖啡壶空了 · 先手冲吧。", 2.5)
    return
  end
  R.coffeeCups = R.coffeeCups + 1
  R.cupPick, R.cupKind = false, nil
  CupSip.start("coffee", {
    taste = DripBrew.taste,
    style = AP.CUP_STYLES[R.cupStyle],
    sipIndex = R.coffeeCups
  })
end

function Session.drinkTea()
  if not R.teaReady or R.teaCups >= TeaBrew.CUPS_PER_POT then
    host.say("茶壶空了 · 先泡茶吧。", 2.5)
    return
  end
  R.teaCups = R.teaCups + 1
  R.cupPick, R.cupKind = false, nil
  CupSip.start("tea", {
    taste = TeaBrew.taste,
    style = AP.CUP_STYLES[R.cupStyle],
    sipIndex = R.teaCups
  })
end

function Session.drinkFromCup()
  local coffeeLeft = R.drippedOnce and R.coffeeCups < DripBrew.CUPS_PER_POT
  local teaLeft = R.teaReady and R.teaCups < TeaBrew.CUPS_PER_POT
  if coffeeLeft and teaLeft then
    if not R.cupPick then
      R.cupPick, R.cupKind = true, "coffee"
      host.say("咖啡还是茶？ · 左右选 · A 喝", 2.8)
    elseif R.cupKind == "tea" then Session.drinkTea()
    else Session.drinkCoffee() end
  elseif teaLeft then
    if not R.cupPick then R.cupPick, R.cupKind = true, "tea"; host.say("选杯子 · 方向键 · A 喝一口茶", 2.8)
    else Session.drinkTea() end
  elseif coffeeLeft then
    if not R.cupPick then R.cupPick, R.cupKind = true, "coffee"; host.say("选杯子 · 方向键 · A 喝一口咖啡", 2.8)
    else Session.drinkCoffee() end
  else
    host.say("杯子还是空的 · 先冲咖啡或泡茶吧。", 2.5)
  end
end

function Session.tryUseGear()
  GearPlay.tryUseGear()
end

function Session.tryMove(dx, dy)
  if R.ritual then return end
  local nx, ny = R.player.x + dx, R.player.y + dy
  if CampMap.walkable(nx, ny) then
    R.player.x, R.player.y = nx, ny
    R.player.walkFrame = R.player.walkFrame == 1 and 2 or 1
    R.player.idleT = 0.28
    Audio.playSfx("step")
    if CampMap.isWater(CampMap.tileAt(nx, ny)) and host and host.spawnSplash then
      host.spawnSplash(nx, ny)
    end
  end
  if dx ~= 0 or dy ~= 0 then
    if math.abs(dx) > math.abs(dy) then R.player.facing = dx > 0 and 2 or 1
    else R.player.facing = dy > 0 and 0 or 3 end
  end
end

function Session.advanceTime()
  Time.advance("wait")
  Audio.syncPlayBgm()
end

return Session
