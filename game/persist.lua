--[[
  露营之旅 — 存档（见 docs/代码架构-SPEC.md）
]]

local State = require("state")

local Persist = {}

function Persist.emptyFishCounts()
  return { ayu = 0, trout = 0, carp = 0 }
end

function Persist.resetTripHaul()
  State.resetTripHaul(Persist.emptyFishCounts)
end

function Persist.fishTotalOf(tbl)
  local n = 0
  for _, v in pairs(tbl or {}) do n = n + (v or 0) end
  return n
end

function Persist.refreshMenu()
  for _, item in ipairs(State.menu.items) do
    if item.id == "continue" then
      item.enabled = State.save.data.castChosen or (State.save.data.trips or 0) > 0
    end
  end
end

function Persist.encode(data)
  local hist = {}
  for i, h in ipairs(data.history or {}) do
    local hf = h.fish or {}
    hist[#hist + 1] = string.format(
      '{"fruit":%d,"coffee":%d,"fish":{"ayu":%d,"trout":%d,"carp":%d}}',
      h.fruit or 0, h.coffee or 0, hf.ayu or 0, hf.trout or 0, hf.carp or 0
    )
    if i >= 12 then break end
  end
  local last = data.lastTrip
  local lastJson = "null"
  if last then
    local lf = last.fish or {}
    lastJson = string.format(
      '{"fruit":%d,"coffee":%d,"fish":{"ayu":%d,"trout":%d,"carp":%d}}',
      last.fruit or 0, last.coffee or 0, lf.ayu or 0, lf.trout or 0, lf.carp or 0
    )
  end
  return string.format(
    '{"castId":%d,"castChosen":%s,"trips":%d,"totals":{"coffee":%d,"fruit":%d,"fishTotal":%d,"fish":{"ayu":%d,"trout":%d,"carp":%d}},"lastTrip":%s,"history":[%s]}',
    data.castId or 1,
    data.castChosen and "true" or "false",
    data.trips or 0,
    data.totals.coffee or 0,
    data.totals.fruit or 0,
    data.totals.fishTotal or 0,
    (data.totals.fish and data.totals.fish.ayu) or 0,
    (data.totals.fish and data.totals.fish.trout) or 0,
    (data.totals.fish and data.totals.fish.carp) or 0,
    lastJson,
    table.concat(hist, ",")
  )
end

function Persist.load()
  local saveData = State.save.data
  saveData.castId = 1
  saveData.castChosen = false
  saveData.trips = 0
  saveData.totals = { coffee = 0, fruit = 0, fish = Persist.emptyFishCounts(), fishTotal = 0 }
  saveData.lastTrip = nil
  saveData.history = {}
  if not (love.filesystem.getInfo and love.filesystem.getInfo(State.save.file)) then
    Persist.refreshMenu()
    return
  end
  local raw = love.filesystem.read(State.save.file)
  if not raw or raw == "" then Persist.refreshMenu(); return end
  local castId = tonumber(raw:match('"castId"%s*:%s*(%d+)')) or 1
  local trips = tonumber(raw:match('"trips"%s*:%s*(%d+)')) or 0
  local chosen = raw:match('"castChosen"%s*:%s*true') ~= nil
  local coffee = tonumber(raw:match('"coffee"%s*:%s*(%d+)')) or 0
  local fruit = tonumber(raw:match('"fruit"%s*:%s*(%d+)')) or 0
  local fishTotal = tonumber(raw:match('"fishTotal"%s*:%s*(%d+)')) or 0
  local ayu = tonumber(raw:match('"ayu"%s*:%s*(%d+)')) or 0
  local trout = tonumber(raw:match('"trout"%s*:%s*(%d+)')) or 0
  local carp = tonumber(raw:match('"carp"%s*:%s*(%d+)')) or 0
  saveData.castId = math.max(1, math.min(9, castId))
  saveData.castChosen = chosen
  saveData.trips = trips
  saveData.totals = {
    coffee = coffee,
    fruit = fruit,
    fish = { ayu = ayu, trout = trout, carp = carp },
    fishTotal = fishTotal,
  }
  State.cast.i = saveData.castId
  Persist.refreshMenu()
end

function Persist.write()
  pcall(function()
    love.filesystem.write(State.save.file, Persist.encode(State.save.data))
  end)
  Persist.refreshMenu()
end

function Persist.commitTrip()
  local haul = State.trip.haul
  local fish = {
    ayu = haul.fish.ayu or 0,
    trout = haul.fish.trout or 0,
    carp = haul.fish.carp or 0,
  }
  local snap = {
    fruit = haul.fruit or 0,
    coffee = haul.coffee or 0,
    tea = haul.tea or 0,
    meals = haul.meals or 0,
    fish = fish,
  }
  local saveData = State.save.data
  saveData.trips = (saveData.trips or 0) + 1
  saveData.totals.fruit = (saveData.totals.fruit or 0) + snap.fruit
  saveData.totals.coffee = (saveData.totals.coffee or 0) + snap.coffee
  saveData.totals.tea = (saveData.totals.tea or 0) + (snap.tea or 0)
  saveData.totals.meals = (saveData.totals.meals or 0) + (snap.meals or 0)
  saveData.totals.fish = saveData.totals.fish or Persist.emptyFishCounts()
  for k, v in pairs(fish) do
    saveData.totals.fish[k] = (saveData.totals.fish[k] or 0) + v
  end
  saveData.totals.fishTotal = Persist.fishTotalOf(saveData.totals.fish)
  saveData.lastTrip = snap
  saveData.history = saveData.history or {}
  saveData.history[#saveData.history + 1] = snap
  while #saveData.history > 12 do table.remove(saveData.history, 1) end
  Persist.write()
end

return Persist
