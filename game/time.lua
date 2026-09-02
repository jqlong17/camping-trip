--[[
  露营之旅 — 游戏内时钟（见 docs/代码架构-SPEC.md）
]]

local Time = {}

local host

local SLOTS = { "清晨", "上午", "午后", "黄昏", "入夜", "深夜", "黎明" }

local TINT = {
  { 0.75, 0.85, 1.00, 0.18 },
  { 1.00, 1.00, 0.95, 0.05 },
  { 1.00, 0.95, 0.80, 0.08 },
  { 1.00, 0.70, 0.45, 0.22 },
  { 0.35, 0.40, 0.70, 0.40 },
  { 0.15, 0.18, 0.35, 0.55 },
  { 0.80, 0.85, 1.00, 0.20 },
}

local STEP_MIN = 5
local TICK_SEC = 3.5
local WAIT_JUMP_MIN = 60

local t = {
  index = 3,
  dayIndex = 1,
  clockMin = 14 * 60,
  frozen = false,
  autoT = 0,
}

local function indexFromClock(m)
  local h = math.floor((m % (24 * 60)) / 60)
  if h >= 5 and h < 8 then return 1 end
  if h >= 8 and h < 12 then return 2 end
  if h >= 12 and h < 17 then return 3 end
  if h >= 17 and h < 19 then return 4 end
  if h >= 19 and h < 22 then return 5 end
  if h >= 22 or h < 4 then return 6 end
  return 7
end

local function applySideEffects(prevIndex)
  local newIndex = indexFromClock(t.clockMin)
  t.index = newIndex
  if not host then return end
  if newIndex ~= prevIndex then
    if (SLOTS[newIndex] == "入夜" or SLOTS[newIndex] == "深夜") and prevIndex < 5 then
      if host.onEnterNight then host.onEnterNight() end
      host.say("入夜了 · " .. Time.label() .. " · 靠近篝火按 A 点火。", 3.5)
    elseif SLOTS[newIndex] == "黎明" then
      if host.setCanGoHome then host.setCanGoHome(true) end
      t.frozen = true
      host.say("天亮了 · " .. Time.label() .. " · 可以收拾回家（下屏按钮）", 3.5)
    elseif SLOTS[newIndex] == "黄昏" then
      host.say("黄昏了 · " .. Time.label(), 2.2)
    end
    if host.syncPlayBgm then host.syncPlayBgm() end
  elseif newIndex == 7 then
    if host.setCanGoHome then host.setCanGoHome(true) end
    t.frozen = true
  end
end

function Time.bindHost(h)
  host = h
end

function Time.slots()
  return SLOTS
end

function Time.slotName(i)
  return SLOTS[i or t.index]
end

function Time.index()
  return t.index
end

function Time.dayIndex()
  return t.dayIndex
end

function Time.clockMin()
  return t.clockMin
end

function Time.isFrozen()
  return t.frozen
end

function Time.label()
  local m = t.clockMin % (24 * 60)
  local h = math.floor(m / 60)
  local mm = m % 60
  return string.format("D%d %02d:%02d", t.dayIndex, h, mm)
end

function Time.tintRow(i)
  local index = i or t.index
  local profiles = Destinations.current().timeProfiles or {}
  if index == 1 and profiles.sunrise and profiles.sunrise.tint then return profiles.sunrise.tint end
  if (index == 2 or index == 3) and profiles.day and profiles.day.tint then return profiles.day.tint end
  if index == 4 and profiles.sunset and profiles.sunset.tint then return profiles.sunset.tint end
  if (index == 5 or index == 6) and profiles.night and profiles.night.tint then return profiles.night.tint end
  return TINT[index] or TINT[3]
end

function Time.isNight()
  return t.index >= 5 and t.index <= 6
end

function Time.starAlpha()
  if Time.isNight() then return 1 end
  if t.index == 4 then return 0.35 end
  if t.index == 7 then return 0.25 end
  return 0
end

function Time.setClock(minOfDay, day)
  t.clockMin = ((minOfDay % (24 * 60)) + 24 * 60) % (24 * 60)
  if day then t.dayIndex = day end
  t.index = indexFromClock(t.clockMin)
  t.frozen = (t.index == 7)
  if t.frozen and host and host.setCanGoHome then host.setCanGoHome(true) end
  t.autoT = 0
end

function Time.resetForTitle()
  t.index = 3
  t.clockMin = 14 * 60
  t.frozen = false
  t.autoT = 0
end

function Time.resetForCamp()
  t.dayIndex = 1
  t.clockMin = Destinations.currentId() == "coast" and (6 * 60 + 20) or (9 * 60)
  t.index = indexFromClock(t.clockMin)
  t.frozen = false
  t.autoT = 0
end

function Time.advance(reason)
  if t.frozen then
    if host then
      if host.setCanGoHome then host.setCanGoHome(true) end
      host.say("天亮了 · " .. Time.label() .. " · 可以回家", 2.5)
      if host.appendLoadLog then
        host.appendLoadLog("time_advance reason=" .. tostring(reason or "manual") .. " frozen label=" .. Time.label())
      end
    end
    return
  end
  local prev = t.index
  local jump = STEP_MIN
  if reason == "wait" or reason == nil or reason == "manual" then
    jump = WAIT_JUMP_MIN
  end
  t.clockMin = (t.clockMin + jump) % (24 * 60)
  t.autoT = 0
  applySideEffects(prev)
  if host then
    if not t.frozen and t.index == prev then
      host.say(Time.label(), 1.6)
    elseif not t.frozen and t.index ~= prev
        and SLOTS[t.index] ~= "入夜" and SLOTS[t.index] ~= "深夜"
        and SLOTS[t.index] ~= "黎明" and SLOTS[t.index] ~= "黄昏" then
      host.say("时间到了 · " .. Time.label(), 2.2)
    end
    if host.appendLoadLog then
      host.appendLoadLog("time_advance reason=" .. tostring(reason or "manual") .. " label=" .. Time.label())
    end
  end
end

function Time.fastForward()
  if t.frozen then
    if host then
      if host.setCanGoHome then host.setCanGoHome(true) end
      host.say("天亮了 · " .. Time.label() .. " · 可以回家", 2.5)
      if host.appendLoadLog then
        host.appendLoadLog("time_fast_forward frozen label=" .. Time.label())
      end
    end
    return
  end
  local prev = t.index
  local prevMin = t.clockMin
  local newMin = (t.clockMin + STEP_MIN * 2) % (24 * 60)
  if prevMin >= 4 * 60 and prevMin < 5 * 60 and newMin >= 5 * 60 then
    newMin = 4 * 60
  end
  t.clockMin = newMin
  t.autoT = 0
  applySideEffects(prev)
  if host then
    if not t.frozen and t.index == prev then
      host.say(Time.label(), 1.6)
    elseif not t.frozen and t.index ~= prev
        and SLOTS[t.index] ~= "入夜" and SLOTS[t.index] ~= "深夜"
        and SLOTS[t.index] ~= "黎明" and SLOTS[t.index] ~= "黄昏" then
      host.say("时间到了 · " .. Time.label(), 2.2)
    end
    if host.appendLoadLog then
      host.appendLoadLog("time_fast_forward label=" .. Time.label())
    end
  end
end

function Time.tickAuto(dt)
  if t.frozen then return end
  t.autoT = t.autoT + dt
  while t.autoT >= TICK_SEC do
    t.autoT = t.autoT - TICK_SEC
    local prev = t.index
    t.clockMin = (t.clockMin + STEP_MIN) % (24 * 60)
    applySideEffects(prev)
    if t.frozen then break end
  end
end

function Time.unfreeze()
  t.frozen = false
end

return Time
