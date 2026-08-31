--[[ 露营之旅 — 杯子品尝 A 档（见 docs/杯子品尝-SPEC.md）]]

local C = {
  focuses = {
    { id = "nose", name = "闻香", note = "先闻再喝" },
    { id = "mouth", name = "入口", note = "关注口感" },
    { id = "after", name = "回味", note = "余韵收束" }
  },
  brewLabels = { "抬杯", "入口", "放下" }
}

C.PHASES = {
  { id = "focus", head = "关注点", kind = "choice", catalog = "focuses", store = "focusI", defaultPick = 2, assetBag = "cupFocuses",
    enterToast = "关注点 · 左右 · A", enterSfx = "ui_ok" },
  { id = "brew", head = "品尝", kind = "brew", brewSteps = 3,
    enterToast = "抬杯 · 按 A 下一步", enterSfx = "cup" }
}

local hooks = nil
local function H()
  assert(hooks, "CupSip.bind required")
  return hooks
end

function C.bind(h) hooks = h end

function C.phaseById(id)
  for i, p in ipairs(C.PHASES) do
    if p.id == id then return p, i end
  end
end

function C.catalogFor(phase)
  if not phase or not phase.catalog then return nil end
  return C[phase.catalog]
end

function C.modLine(style, kind)
  if not style then return "" end
  if kind == "tea" then return style.teaMod or "" end
  return style.coffeeMod or ""
end

function C.composeSipLine(baseTaste, style, kind, sipIndex, potMax, _sipI, focusI)
  local name = style and style.name or "杯子"
  local mod = C.modLine(style, kind)
  local drink = kind == "tea" and "茶" or "咖啡"
  local foc = C.focuses[focusI or 2] or C.focuses[2]
  local parts = { name }
  if baseTaste and baseTaste ~= "" then parts[#parts + 1] = baseTaste end
  if mod ~= "" then parts[#parts + 1] = mod end
  parts[#parts + 1] = foc.name
  parts[#parts + 1] = drink .. "第" .. tostring(sipIndex) .. "口"
  return table.concat(parts, " · ")
end

local function toastEntering(phase)
  local h = H()
  if phase.enterSfx then h.playSfx(phase.enterSfx) end
  if phase.enterToast then h.say(phase.enterToast, 2.5) end
end

local function enterPhase(ritual, phaseIndex)
  local phase = C.PHASES[phaseIndex]
  ritual.phase = phase.id
  ritual.pick = phase.defaultPick or 1
  if phase.kind == "brew" then ritual.brewStep = 1 end
  toastEntering(phase)
end

local function storePick(ritual, phase)
  if phase.store then ritual[phase.store] = ritual.pick end
end

function C.start(kind, ctx)
  local h = H()
  ctx = ctx or {}
  h.ensureRitual()
  h.setRitual({
    kind = "cup_sip",
    drinkKind = kind,
    phase = "focus",
    pick = 2,
    brewStep = 1,
    focusI = 2,
    baseTaste = ctx.taste,
    style = ctx.style,
    sipIndex = ctx.sipIndex or 1
  })
  h.playSfx("cup")
  h.say("关注点 · 左右 · A", 2.5)
end

function C.advance()
  local h = H()
  local r = h.getRitual()
  if not r or r.kind ~= "cup_sip" then return end
  local phase, idx = C.phaseById(r.phase)
  if not phase then
    if r.brewStep and r.brewStep < (r.brewSteps or 2) then
      r.brewStep = r.brewStep + 1
    else
      h.clearRitual()
    end
    return
  end
  if phase.kind == "brew" then
    local max = phase.brewSteps or 3
    if r.brewStep < max then
      r.brewStep = r.brewStep + 1
      h.playSfx("ui_ok")
      h.say((C.brewLabels[r.brewStep] or "品尝") .. " · 按 A 下一步", 2)
    else
      local line = C.composeSipLine(
        r.baseTaste, r.style, r.drinkKind, r.sipIndex, nil, nil, r.focusI
      )
      h.say(line, 3.5)
      h.clearRitual()
    end
    return
  end
  if phase.kind == "choice" then storePick(r, phase) end
  local nextIdx = idx + 1
  if nextIdx > #C.PHASES then
    h.clearRitual()
    return
  end
  enterPhase(r, nextIdx)
  if C.PHASES[nextIdx] and C.PHASES[nextIdx].kind == "brew" then
    local line = C.composeSipLine(
      r.baseTaste, r.style, r.drinkKind, r.sipIndex, nil, nil, r.focusI
    )
    h.say(line, 3)
  end
end

function C.nudge(dir)
  local r = H().getRitual()
  if not r or r.kind ~= "cup_sip" then return end
  local phase = C.phaseById(r.phase)
  if not phase or phase.kind ~= "choice" then return end
  local list = C.catalogFor(phase)
  if not list then return end
  r.pick = ((r.pick - 1 + dir) % #list) + 1
  H().playSfx("ui_move")
end

function C.loadChoiceAssets(bucket, loadImage)
  local base = "assets/ritual/cup/"
  bucket.cupFocuses = {}
  bucket.cupSip = {
    loadImage(base .. "sip_1.png"),
    loadImage(base .. "sip_2.png"),
    loadImage(base .. "sip_3.png")
  }
  for _, f in ipairs(C.focuses) do
    bucket.cupFocuses[f.id] = loadImage(base .. "focus_" .. f.id .. ".png")
  end
end

function C.drawTop(ritual, assets, context)
  love.graphics.setColor(0.1, 0.1, 0.12, 1)
  love.graphics.rectangle("fill", 0, 0, context.TOP_W, context.TOP_H)
  love.graphics.setColor(1, 1, 1, 1)
  local phase = C.phaseById(ritual.phase)
  local img
  if phase and phase.kind == "brew" then
    img = assets and assets.cupSip and assets.cupSip[ritual.brewStep]
  elseif phase and phase.kind == "choice" then
    local list = C.catalogFor(phase)
    local item = list and list[ritual.pick]
    local bag = assets and phase.assetBag and assets[phase.assetBag]
    img = bag and item and bag[item.id]
  else
    img = assets and assets.cupSip and assets.cupSip[ritual.brewStep or 1]
  end
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    if phase and phase.kind == "brew" then
      -- 4:3 特写铺满后上屏真居中
      local maxW, maxH = context.TOP_W - 32, context.TOP_H - 40
      local s = math.min(maxW / iw, maxH / ih)
      love.graphics.draw(
        img,
        math.floor((context.TOP_W - iw * s) / 2),
        math.floor((context.TOP_H - ih * s) / 2),
        0, s, s
      )
    else
      -- 关注点图标：放大到约 96px 并居中
      local target = 96
      local s = math.min(target / iw, target / ih, 4)
      love.graphics.draw(
        img,
        math.floor((context.TOP_W - iw * s) / 2),
        math.floor((context.TOP_H - ih * s) / 2),
        0, s, s
      )
    end
  end
end

function C.drawBottom(ritual, assets, context)
  local phase = C.phaseById(ritual.phase)
  local BOT_W = context.BOT_W
  love.graphics.setColor(0.95, 0.92, 0.86, 1)
  love.graphics.rectangle("fill", 0, 0, BOT_W, context.BOT_H or 240)
  love.graphics.setColor(0.2, 0.16, 0.12, 1)
  if phase and phase.kind == "choice" then
    local idx = select(2, C.phaseById(ritual.phase)) or 1
    love.graphics.printf(tostring(idx) .. "·" .. #C.PHASES .. " " .. phase.head, 12, 16, BOT_W - 24, "left")
    local list = C.catalogFor(phase)
    local bag = assets and phase.assetBag and assets[phase.assetBag]
    local n = list and #list or 0
    local slot = math.floor((BOT_W - 20) / math.max(n, 1))
    for i, item in ipairs(list or {}) do
      local x = 10 + (i - 1) * slot
      local on = i == ritual.pick
      love.graphics.setColor(on and 0.95 or 0.2, on and 0.9 or 0.2, on and 0.7 or 0.2, on and 0.35 or 0.15)
      love.graphics.rectangle("fill", x, 70, slot - 6, 78, 4, 4)
      love.graphics.setColor(1, 1, 1, 1)
      local icon = bag and bag[item.id]
      if icon then
        local iw, ih = icon:getWidth(), icon:getHeight()
        local s = math.min(40 / iw, 40 / ih)
        love.graphics.draw(icon, x + (slot - 6 - iw * s) / 2, 78 + (40 - ih * s) / 2, 0, s, s)
      end
      love.graphics.setColor(0.15, 0.12, 0.1, 1)
      love.graphics.printf(item.name, x, 124, slot - 6, "center")
    end
    local cur = list and list[ritual.pick]
    if cur then
      love.graphics.setColor(0.35, 0.28, 0.2, 1)
      love.graphics.printf(cur.note or "", 12, 160, BOT_W - 24, "center")
    end
  else
    love.graphics.printf((C.brewLabels[ritual.brewStep] or "品尝") .. " · A 继续", 12, 100, BOT_W - 24, "center")
  end
end

return C
