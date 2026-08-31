--[[
  露营之旅 — 钓鱼模块（见 docs/钓鱼模块-SPEC.md）
  require("fish_rod")；main 调用 FishRod.bind{...}。
]]

local F = {
  mood = nil,
  last = nil,
  spots = {
    { id = "shoal", name = "浅滩", note = "清澈", ayu = 3, trout = 1, carp = 1, catch = 0.05 },
    { id = "pool", name = "深潭", note = "安静", ayu = 1, trout = 3, carp = 2, catch = 0.08 },
    { id = "pier", name = "桥墩", note = "阴影", ayu = 1, trout = 1, carp = 3, catch = 0.06 },
    { id = "weed", name = "水草边", note = "藏鱼", ayu = 1, trout = 2, carp = 3, catch = 0.04 },
    { id = "rapids", name = "急流旁", note = "凉快", ayu = 2, trout = 3, carp = 1, catch = 0.02 }
  },
  baits = {
    { id = "worm", name = "蚯蚓", note = "万能", ayu = 2, trout = 2, carp = 2, catch = 0.10 },
    { id = "dough", name = "面团", note = "鲤爱", ayu = 0, trout = 1, carp = 3, catch = 0.06 },
    { id = "lure", name = "假饵", note = "掠食", ayu = 1, trout = 3, carp = 0, catch = 0.04 },
    { id = "bug", name = "昆虫", note = "香鱼", ayu = 3, trout = 2, carp = 0, catch = 0.08 },
    { id = "corn", name = "玉米", note = "甜香", ayu = 0, trout = 1, carp = 3, catch = 0.05 }
  },
  sinkers = {
    { id = "light", name = "轻坠", note = "表层", catch = 0.02 },
    { id = "mid", name = "中坠", note = "稳", catch = 0.06 },
    { id = "heavy", name = "重坠", note = "沉底", catch = 0.04 }
  },
  styles = {
    { id = "wait", name = "死等", note = "耐心", ayu = 1, trout = 1, carp = 2, catch = 0.04 },
    { id = "twitch", name = "轻抽", note = "诱口", ayu = 2, trout = 2, carp = 1, catch = 0.08 },
    { id = "dance", name = "逗引", note = "活跃", ayu = 1, trout = 3, carp = 1, catch = 0.06 }
  },
  brewLabels = { "抛线入水", "盯着浮漂", "咬钩了！", "起竿" }
}

F.PHASES = {
  { id = "spot", head = "选钓点", kind = "choice", catalog = "spots", store = "spotI", defaultPick = 1, assetBag = "spots",
    enterToast = "选钓点 · 左右切换 · A 确认", enterSfx = "ui_ok" },
  { id = "bait", head = "选鱼饵", kind = "choice", catalog = "baits", store = "baitI", defaultPick = 1, assetBag = "baits",
    enterSfx = "ui_ok" },
  { id = "sinker", head = "选铅坠", kind = "choice", catalog = "sinkers", store = "sinkerI", defaultPick = 2, assetBag = "sinkers",
    enterSfx = "ui_ok" },
  { id = "cast", head = "抛竿", kind = "confirm",
    enterToast = "站稳 · 按 A 抛竿", enterSfx = "ui_ok" },
  { id = "style", head = "竿法", kind = "choice", catalog = "styles", store = "styleI", defaultPick = 2, assetBag = "styles",
    enterSfx = "ui_ok" },
  { id = "brew", head = "起鱼", kind = "brew", brewSteps = 4,
    enterToast = "抛线入水 · 按 A 下一步", enterSfx = "ui_ok" }
}

local hooks = nil
local function H()
  assert(hooks, "FishRod.bind required")
  return hooks
end

function F.bind(h) hooks = h end
function F.resetTrip() F.mood, F.last = nil, nil end

function F.phaseById(id)
  for i, p in ipairs(F.PHASES) do
    if p.id == id then return p, i end
  end
end

function F.catalogFor(phase)
  if not phase or not phase.catalog then return nil end
  return F[phase.catalog]
end

function F.choiceLabel(phase, item)
  return (item and item.name) or "?"
end

function F.choiceNote(phase, item)
  return (item and item.note) or ""
end

function F.choiceIcon(phase, item, assets)
  if not assets or not phase.assetBag or not item then return nil end
  local bag = assets[phase.assetBag]
  return bag and item.id and bag[item.id]
end

function F.pickCount(ritual)
  ritual = ritual or (hooks and hooks.getRitual and hooks.getRitual())
  if not ritual or ritual.kind ~= "rod" then return 0 end
  local phase = F.phaseById(ritual.phase)
  if not phase or phase.kind ~= "choice" then return 0 end
  local list = F.catalogFor(phase)
  return list and #list or 0
end

function F.nudge(dir)
  local ritual = H().getRitual()
  if not ritual or ritual.kind ~= "rod" then return end
  local n = F.pickCount(ritual)
  if n <= 0 then return end
  ritual.pick = ritual.pick + dir
  if ritual.pick < 1 then ritual.pick = n end
  if ritual.pick > n then ritual.pick = 1 end
  H().playSfx("ui_move")
end

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

function F.resolveCatch(r)
  local spot = F.spots[r.spotI] or F.spots[1]
  local bait = F.baits[r.baitI] or F.baits[1]
  local sinker = F.sinkers[r.sinkerI] or F.sinkers[2]
  local style = F.styles[r.styleI] or F.styles[2]
  local p = 0.42 + (spot.catch or 0) + (bait.catch or 0) + (sinker.catch or 0) + (style.catch or 0)
  p = clamp(p, 0.25, 0.92)
  local caught = love.math.random() < p
  if not caught then
    return false, nil, spot.name .. " · " .. bait.name .. " · 空竿"
  end
  local w = {
    ayu = (spot.ayu or 0) + (bait.ayu or 0) + (style.ayu or 0),
    trout = (spot.trout or 0) + (bait.trout or 0) + (style.trout or 0),
    carp = (spot.carp or 0) + (bait.carp or 0) + (style.carp or 0)
  }
  local total = math.max(1, w.ayu + w.trout + w.carp)
  local roll = love.math.random(1, total)
  local kind = "ayu"
  if roll <= w.ayu then
    kind = "ayu"
  elseif roll <= w.ayu + w.trout then
    kind = "trout"
  else
    kind = "carp"
  end
  local mood = spot.name .. " · " .. bait.name .. " · " .. style.name
  return true, kind, mood
end

function F.computeMood(r, caught, kind)
  local spot = F.spots[r.spotI]
  local bait = F.baits[r.baitI]
  local style = F.styles[r.styleI]
  if not caught then
    return (spot and spot.name or "?") .. " · 浮漂轻轻一顿，又空了"
  end
  local nm = H().fishName(kind)
  local bits = {
    ayu = "水花清亮",
    trout = "线绷得紧",
    carp = "沉甸甸的"
  }
  return (spot and spot.name or "?") .. " · " .. (bait and bait.name or "?")
    .. " · " .. (style and style.name or "?") .. " → " .. nm .. "，" .. (bits[kind] or "上岸了")
end

local function toastEntering(phase)
  local h = H()
  if phase.enterSfx then h.playSfx(phase.enterSfx) end
  if phase.enterToast then h.say(phase.enterToast, 3); return end
  if phase.kind == "choice" then
    local list = F.catalogFor(phase)
    local item = list and list[phase.defaultPick or 1]
    h.say(phase.head .. " · " .. F.choiceLabel(phase, item) .. " · A 确认", 2.5)
  end
end

local function enterPhase(ritual, phaseIndex)
  local phase = F.PHASES[phaseIndex]
  ritual.phase = phase.id
  ritual.pick = phase.defaultPick or 1
  if phase.kind == "brew" then
    ritual.brewStep = 1
    ritual.step = 1
    ritual.max = phase.brewSteps or 4
    ritual.frameDur = nil -- A 推进，不用自动短片
    local caught, kind, _ = F.resolveCatch(ritual)
    ritual.caught = caught
    ritual.fishKind = kind
    ritual.scored = false
  end
  toastEntering(phase)
end

local function storePick(ritual, phase)
  ritual[phase.store] = ritual.pick
end

function F.finish()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "rod" then return end
  if not ritual.scored then
    if ritual.caught and ritual.fishKind then
      h.addFish(ritual.fishKind)
      ritual.scored = true
    else
      ritual.scored = true
    end
  end
  local mood = F.computeMood(ritual, ritual.caught, ritual.fishKind)
  F.mood = mood
  F.last = {
    spot = F.spots[ritual.spotI] and F.spots[ritual.spotI].name,
    bait = F.baits[ritual.baitI] and F.baits[ritual.baitI].name,
    sinker = F.sinkers[ritual.sinkerI] and F.sinkers[ritual.sinkerI].name,
    style = F.styles[ritual.styleI] and F.styles[ritual.styleI].name,
    caught = ritual.caught,
    fishKind = ritual.fishKind,
    mood = mood
  }
  h.clearRitual()
  if ritual.caught and ritual.fishKind then
    h.playSfx("ui_ok")
    h.say(mood, 3.2)
  else
    h.say(mood .. "。今天先这样。", 2.8)
  end
end

function F.start()
  local h = H()
  h.ensureRitual()
  h.setRitual({
    kind = "rod",
    phase = "spot",
    pick = 1,
    brewStep = 1,
    spotI = 1, baitI = 1, sinkerI = 2, styleI = 2,
    caught = false, fishKind = nil, scored = false
  })
  h.playSfx("ui_ok")
  h.say("选钓点 · 左右切换 · A 确认", 3)
end

function F.advance()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "rod" then return end
  local phase, idx = F.phaseById(ritual.phase)
  if not phase then return end
  if phase.kind == "brew" then
    local max = phase.brewSteps or 4
    if ritual.brewStep < max then
      ritual.brewStep = ritual.brewStep + 1
      ritual.step = ritual.brewStep
      if ritual.brewStep == 3 then
        h.onFishSplash()
        h.playSfx("ui_ok")
      elseif ritual.brewStep == 4 then
        h.onFishSplash()
        if ritual.caught and ritual.fishKind and not ritual.scored then
          h.addFish(ritual.fishKind)
          ritual.scored = true
          local nm = h.fishName(ritual.fishKind)
          h.say("钓到了" .. nm .. "！", 2.5)
        elseif not ritual.caught and not ritual.scored then
          ritual.scored = true
          h.say("浮漂动了一下……又空了。", 2.5)
        end
      end
      h.say((F.brewLabels[ritual.brewStep] or "起鱼") .. " · 按 A 下一步", 2.2)
    else
      F.finish()
    end
    return
  end
  if phase.kind == "choice" then storePick(ritual, phase) end
  local nextIdx = idx + 1
  if nextIdx > #F.PHASES then F.finish(); return end
  enterPhase(ritual, nextIdx)
end

function F.loadChoiceAssets(bucket, loadImage)
  local base = "assets/ritual/fish/"
  bucket.spots, bucket.baits, bucket.sinkers, bucket.styles = {}, {}, {}, {}
  bucket.fishAnim = {}
  for _, s in ipairs(F.spots) do
    bucket.spots[s.id] = loadImage(base .. "spot_" .. s.id .. ".png")
  end
  for _, b in ipairs(F.baits) do
    bucket.baits[b.id] = loadImage(base .. "bait_" .. b.id .. ".png")
  end
  for _, s in ipairs(F.sinkers) do
    bucket.sinkers[s.id] = loadImage(base .. "sinker_" .. s.id .. ".png")
  end
  for _, s in ipairs(F.styles) do
    bucket.styles[s.id] = loadImage(base .. "style_" .. s.id .. ".png")
  end
  for i = 1, 4 do
    bucket.fishAnim[i] = loadImage(base .. "fish_" .. i .. ".png")
  end
  bucket.fishMiss = loadImage(base .. "fish_4_miss.png")
end

function F.topView(ritual, assets)
  local phase = F.phaseById(ritual.phase or "brew")
  local title, img, mode = "钓鱼", nil, "icon"
  if not phase then return title, nil, mode end
  if phase.kind == "brew" then
    title = "钓鱼 · " .. (F.brewLabels[ritual.brewStep] or tostring(ritual.brewStep))
    if ritual.brewStep == 4 and not ritual.caught and assets and assets.fishMiss then
      img = assets.fishMiss
    else
      img = assets and assets.fishAnim and assets.fishAnim[ritual.brewStep]
    end
    if ritual.brewStep == 4 and ritual.caught and ritual.fishKind then
      title = "钓到 · " .. H().fishName(ritual.fishKind)
    end
    mode = "brew"
  elseif phase.kind == "confirm" then
    title = "抛竿"
    img = assets and assets.fishAnim and assets.fishAnim[1]
    mode = "brew"
  elseif phase.kind == "choice" then
    local list = F.catalogFor(phase)
    local item = list and list[ritual.pick]
    title = phase.head .. " · " .. F.choiceLabel(phase, item)
    img = F.choiceIcon(phase, item, assets)
  end
  return title, img, mode
end

function F.drawTop(ritual, assets, ctx)
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, ctx.TOP_W, ctx.TOP_H)
  local title, img, mode = F.topView(ritual, assets)
  if img then
    love.graphics.setColor(1, 1, 1, 1)
    if mode == "brew" then
      local srcW, srcH = 160, 120
      local iw, ih = img:getWidth(), img:getHeight()
      if iw < srcW or ih < srcH then srcW, srcH = iw, ih end
      local maxW, maxH = ctx.TOP_W - 32, ctx.TOP_H - 40
      local s = math.min(maxW / srcW, maxH / srcH)
      local x = math.floor((ctx.TOP_W - srcW * s) / 2)
      local y = math.floor((ctx.TOP_H - srcH * s) / 2)
      if ctx.drawFitted then
        ctx.drawFitted(img, x, y, srcW, srcH, s, s)
      else
        love.graphics.draw(img, x, y, 0, s, s)
      end
    else
      local s = 3
      local iw, ih = img:getWidth(), img:getHeight()
      love.graphics.draw(img, (ctx.TOP_W - iw * s) / 2, (ctx.TOP_H - ih * s) / 2, 0, s, s)
    end
  end
  if ctx.uiFont then love.graphics.setFont(ctx.uiFont) end
  love.graphics.setColor(0.08, 0.08, 0.08, 0.85)
  local tw = (ctx.uiFont and ctx.uiFont:getWidth(title)) or 80
  love.graphics.rectangle("fill", 12, 12, tw + 16, 20)
  love.graphics.setColor(1, 0.95, 0.85)
  love.graphics.print(title, 20, 14)
end

local function drawChoiceRow(ritual, items, phase, assets, BOT_W)
  local n = #items
  local slotW = math.floor((BOT_W - 20) / math.max(n, 1))
  for i, it in ipairs(items) do
    local x = 10 + (i - 1) * slotW
    local on = (i == ritual.pick)
    local boxW = slotW - 4
    love.graphics.setColor(on and 0.98 or 0.94, on and 0.88 or 0.9, on and 0.55 or 0.82)
    love.graphics.rectangle("fill", x, 48, boxW, 96)
    love.graphics.setColor(0.3, 0.2, 0.12)
    love.graphics.rectangle("line", x, 48, boxW, 96)
    local icon = F.choiceIcon(phase, it, assets)
    if icon then
      love.graphics.setColor(1, 1, 1, 1)
      local iw, ih = icon:getWidth(), icon:getHeight()
      local s = math.min(40 / iw, 40 / ih)
      love.graphics.draw(icon, x + (boxW - iw * s) / 2, 54, 0, s, s)
    end
    love.graphics.setColor(0.22, 0.14, 0.08)
    love.graphics.printf(F.choiceLabel(phase, it), x, 108, boxW, "center")
  end
  local cur = items[ritual.pick]
  if cur then
    love.graphics.setColor(0.4, 0.3, 0.2)
    love.graphics.printf(F.choiceNote(phase, cur), 12, 152, BOT_W - 24, "center")
  end
end

function F.drawBottom(ritual, assets, ctx)
  local BOT_W = ctx.BOT_W
  local phase, idx = F.phaseById(ritual.phase or "brew")
  local head = "钓鱼"
  if phase then
    if phase.kind == "brew" then
      head = tostring(idx) .. "·" .. #F.PHASES .. " " .. phase.head .. " · " .. tostring(ritual.brewStep) .. "·4"
    else
      head = tostring(idx) .. "·" .. #F.PHASES .. " " .. phase.head
    end
  end
  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.printf(head, 10, 12, BOT_W - 20, "left")

  if phase and phase.kind == "choice" then
    drawChoiceRow(ritual, F.catalogFor(phase), phase, assets, BOT_W)
  elseif phase and phase.kind == "confirm" then
    love.graphics.setColor(0.25, 0.18, 0.1)
    love.graphics.printf("瞄好落点，轻轻抛出去。", 20, 80, BOT_W - 40, "center")
    if assets and assets.fishAnim and assets.fishAnim[1] then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(assets.fishAnim[1], 100, 100, 0, 1, 1)
    end
  else
    love.graphics.setColor(0.25, 0.18, 0.1)
    local S = F.spots[ritual.spotI]
    local B = F.baits[ritual.baitI]
    local St = F.styles[ritual.styleI]
    love.graphics.printf((S and S.name or "?") .. " · " .. (B and B.name or "?")
      .. " · " .. (St and St.name or "?"), 16, 70, BOT_W - 32, "center")
    love.graphics.printf("溪水轻轻响。慢慢来。", 16, 100, BOT_W - 32, "center")
  end

  love.graphics.setColor(0.35, 0.55, 0.35)
  love.graphics.rectangle("fill", 100, 210, 120, 22)
  love.graphics.setColor(1, 1, 1)
  local btn = "A 确认"
  if phase and phase.kind == "brew" then btn = "A 下一步"
  elseif phase and phase.kind == "confirm" then btn = "A 抛竿" end
  love.graphics.printf(btn, 100, 213, 120, "center")
  love.graphics.setColor(0.55, 0.4, 0.35)
  love.graphics.rectangle("fill", 230, 210, 70, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("取消", 248, 213)
end

function F.bindHost(h)
  F.bind({
    say = h.say,
    playSfx = h.playSfx,
    getRitual = h.getRitual,
    setRitual = h.setRitual,
    clearRitual = h.clearRitual,
    ensureRitual = h.ensureRitual,
    onFishSplash = h.onFishSplash,
    addFish = h.addFish,
    fishName = h.fishName
  })
end

return F
