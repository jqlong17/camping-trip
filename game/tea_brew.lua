--[[
  露营之旅 — 泡茶模块（见 docs/泡茶模块-SPEC.md）
  require("tea_brew")；main 调用 TeaBrew.bind{...}。
]]

local T = {
  CUPS_PER_POT = 3,
  taste = nil,
  last = nil,
  leaves = {
    { id = "longjing", name = "龙井", note = "豆香清甜", aroma = 3, sweet = 2, bitter = 1, body = 1 },
    { id = "tieguanyin", name = "铁观音", note = "兰花音韵", aroma = 3, sweet = 2, bitter = 1, body = 2 },
    { id = "dianhong", name = "滇红", note = "蜜香醇厚", aroma = 2, sweet = 3, bitter = 1, body = 3 },
    { id = "yinzhen", name = "银针", note = "毫香鲜爽", aroma = 3, sweet = 2, bitter = 1, body = 1 },
    { id = "genmaicha", name = "玄米", note = "米香暖胃", aroma = 2, sweet = 2, bitter = 1, body = 2 }
  },
  amounts = {
    { id = "light", name = "少许", note = "清透" },
    { id = "medium", name = "适中", note = "日常" },
    { id = "full", name = "满杯", note = "更浓" }
  },
  wares = {
    { id = "gaiwan", name = "盖碗", note = "扬香" },
    { id = "glass", name = "公道杯", note = "观色" },
    { id = "zisha", name = "紫砂壶", note = "更厚" },
    { id = "piaoyi", name = "飘逸杯", note = "省事" },
    { id = "enamel", name = "搪瓷缸", note = "野营风" }
  },
  temps = {
    { c = 80, name = "80度", note = "护香" },
    { c = 85, name = "85度", note = "绿茶宜" },
    { c = 90, name = "90度", note = "均衡" },
    { c = 95, name = "95度", note = "乌龙宜" },
    { c = 100, name = "100度", note = "红茶宜" }
  },
  steeps = { 1, 2, 3, 4 },
  amountMod = {
    light = { aroma = 1, body = -1 },
    full = { body = 1, bitter = 1 }
  },
  wareMod = {
    gaiwan = { aroma = 1 },
    glass = { aroma = 1, body = -1 },
    zisha = { body = 1, sweet = 1 },
    piaoyi = { body = 1 },
    enamel = { body = 1, bitter = 1 }
  },
  steepMod = {
    [1] = { body = 1, bitter = 1 },
    [3] = { sweet = 1, aroma = 1 },
    [4] = { aroma = 1, body = -1 }
  },
  steepNotes = { [1] = "更浓", [2] = "稳", [3] = "回甘", [4] = "更透" },
  brewLabels = { "注水", "闷泡", "出汤" }
}

T.PHASES = {
  { id = "leaf", head = "选茶叶", kind = "choice", catalog = "leaves", store = "leafI", defaultPick = 1, assetBag = "leaves",
    enterToast = "选茶叶 · 左右切换 · A 确认", enterSfx = "ui_ok" },
  { id = "amount", head = "投茶量", kind = "choice", catalog = "amounts", store = "amountI", defaultPick = 2, assetBag = "amounts",
    enterSfx = "ui_ok" },
  { id = "ware", head = "选茶器", kind = "choice", catalog = "wares", store = "wareI", defaultPick = 1, assetBag = "wares",
    enterSfx = "ui_ok" },
  { id = "rinse", head = "温杯烫壶", kind = "confirm",
    enterToast = "温杯烫壶 · 按 A", enterSfx = "ui_ok" },
  { id = "temp", head = "水温", kind = "choice", catalog = "temps", store = "tempC", valueKey = "c", defaultPick = 3, assetBag = "temps",
    enterSfx = "ui_ok" },
  { id = "steeps", head = "出汤次数", kind = "choice", catalog = "steeps", store = "steeps", list = true, defaultPick = 2, assetBag = "steeps",
    enterSfx = "ui_ok" },
  { id = "brew", head = "泡茶", kind = "brew", brewSteps = 3,
    enterToast = "注水 · 按 A 下一步", enterSfx = "pour" }
}

local hooks = nil
local function H()
  assert(hooks, "TeaBrew.bind required")
  return hooks
end

function T.bind(h) hooks = h end
function T.resetTrip() T.taste, T.last = nil, nil end

function T.phaseById(id)
  for i, p in ipairs(T.PHASES) do
    if p.id == id then return p, i end
  end
end

function T.catalogFor(phase)
  if not phase or not phase.catalog then return nil end
  if phase.list then
    local items = {}
    for _, n in ipairs(T[phase.catalog]) do items[#items + 1] = n end
    return items
  end
  return T[phase.catalog]
end

function T.choiceLabel(phase, item)
  if not item then return "?" end
  if phase.list then return tostring(item) .. " 次" end
  return item.name or tostring(item)
end

function T.choiceNote(phase, item)
  if phase.list then return T.steepNotes[item] or "" end
  return item.note or ""
end

function T.choiceIcon(phase, item, assets)
  if not assets or not phase.assetBag then return nil end
  local bag = assets[phase.assetBag]
  if not bag then return nil end
  if phase.list then return bag[item] end
  if phase.valueKey == "c" then return bag[tostring(item.c)] end
  return item.id and bag[item.id]
end

function T.pickCount(ritual)
  ritual = ritual or (hooks and hooks.getRitual and hooks.getRitual())
  if not ritual or ritual.kind ~= "tea" then return 0 end
  local phase = T.phaseById(ritual.phase)
  if not phase or phase.kind ~= "choice" then return 0 end
  local list = T.catalogFor(phase)
  return list and #list or 0
end

function T.nudge(dir)
  local ritual = H().getRitual()
  if not ritual or ritual.kind ~= "tea" then return end
  local n = T.pickCount(ritual)
  if n <= 0 then return end
  ritual.pick = ritual.pick + dir
  if ritual.pick < 1 then ritual.pick = n end
  if ritual.pick > n then ritual.pick = 1 end
  H().playSfx("ui_move")
end

local function applyMod(aroma, sweet, bitter, body, mod)
  if not mod then return aroma, sweet, bitter, body end
  aroma = aroma + (mod.aroma or 0)
  sweet = sweet + (mod.sweet or 0)
  bitter = bitter + (mod.bitter or 0)
  body = math.max(1, body + (mod.body or 0))
  return aroma, sweet, bitter, body
end

function T.computeTaste(r)
  local leaf = T.leaves[r.leafI]
  local amount = T.amounts[r.amountI]
  local ware = T.wares[r.wareI]
  local aroma, sweet, bitter, body = leaf.aroma, leaf.sweet, leaf.bitter, leaf.body
  aroma, sweet, bitter, body = applyMod(aroma, sweet, bitter, body, T.amountMod[amount.id])
  aroma, sweet, bitter, body = applyMod(aroma, sweet, bitter, body, T.wareMod[ware.id])
  if r.tempC and r.tempC >= 95 then
    aroma, sweet, bitter, body = applyMod(aroma, sweet, bitter, body, { bitter = 1, body = 1 })
  elseif r.tempC and r.tempC <= 85 then
    aroma, sweet, bitter, body = applyMod(aroma, sweet, bitter, body, { aroma = 1, sweet = 1 })
  end
  aroma, sweet, bitter, body = applyMod(aroma, sweet, bitter, body, T.steepMod[r.steeps])
  local traits = {
    { aroma, "清香悠长" },
    { sweet, "回甘生津" },
    { bitter, "微苦沉稳" },
    { body, "汤感扎实" }
  }
  table.sort(traits, function(a, b)
    if a[1] == b[1] then return a[2] < b[2] end
    return a[1] > b[1]
  end)
  return leaf.name .. " · " .. traits[1][2] .. "，带点" .. traits[2][2]
end

local function toastEntering(phase)
  local h = H()
  if phase.enterSfx then h.playSfx(phase.enterSfx) end
  if phase.enterToast then h.say(phase.enterToast, 3); return end
  if phase.kind == "choice" then
    local list = T.catalogFor(phase)
    local item = list and list[phase.defaultPick or 1]
    h.say(phase.head .. " · " .. T.choiceLabel(phase, item) .. " · A 确认", 2.5)
  end
end

local function enterPhase(ritual, phaseIndex)
  local phase = T.PHASES[phaseIndex]
  ritual.phase = phase.id
  ritual.pick = phase.defaultPick or 1
  if phase.kind == "brew" then ritual.brewStep = 1 end
  toastEntering(phase)
end

local function storePick(ritual, phase)
  local list = T.catalogFor(phase)
  local item = list and list[ritual.pick]
  if phase.list then ritual[phase.store] = item
  elseif phase.valueKey then ritual[phase.store] = item and item[phase.valueKey]
  else ritual[phase.store] = ritual.pick end
end

function T.finish()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "tea" then return end
  local taste = T.computeTaste(ritual)
  T.taste = taste
  T.last = {
    leaf = T.leaves[ritual.leafI].name,
    amount = T.amounts[ritual.amountI].name,
    ware = T.wares[ritual.wareI].name,
    temp = ritual.tempC,
    steeps = ritual.steeps,
    taste = taste
  }
  h.setPot(true, 1)
  h.selectCup()
  h.clearRitual()
  h.onBrewMap(nil, nil, 8)
  h.playSfx("cup")
  h.addTripTea(1)
  h.say(taste .. " · 第一口茶。还剩两口。", 3.5)
end

function T.start()
  local h = H()
  local ready, cups = h.getPot()
  if ready and cups > 0 and cups < T.CUPS_PER_POT then
    h.selectCup()
    h.drinkTea()
    return
  end
  h.ensureRitual()
  if ready and cups >= T.CUPS_PER_POT then
    h.setPot(false, 0)
    T.taste = nil
  end
  h.setRitual({
    kind = "tea",
    phase = "leaf",
    pick = 1,
    brewStep = 1,
    leafI = 1, amountI = 2, wareI = 1, tempC = 90, steeps = 2
  })
  local px, py = h.playerXY()
  h.onBrewMap(px, py, 12)
  h.playSfx("ui_ok")
  h.say("选茶叶 · 左右切换 · A 确认", 3)
end

function T.advance()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "tea" then return end
  local phase, idx = T.phaseById(ritual.phase)
  if not phase then return end
  if phase.kind == "brew" then
    local max = phase.brewSteps or 3
    if ritual.brewStep < max then
      ritual.brewStep = ritual.brewStep + 1
      if ritual.brewStep == 2 then h.playSfx("pour")
      elseif ritual.brewStep == 3 then h.playSfx("cup") end
      h.say((T.brewLabels[ritual.brewStep] or "泡茶") .. " · 按 A 下一步", 2.5)
    else
      T.finish()
    end
    return
  end
  if phase.kind == "choice" then storePick(ritual, phase) end
  local nextIdx = idx + 1
  if nextIdx > #T.PHASES then T.finish(); return end
  enterPhase(ritual, nextIdx)
end

function T.loadChoiceAssets(bucket, loadImage)
  local base = "assets/ritual/tea/"
  bucket.leaves, bucket.amounts, bucket.wares, bucket.temps, bucket.steeps = {}, {}, {}, {}, {}
  bucket.teaFrames = {}
  bucket.rinse = loadImage(base .. "tea_rinse.png")
  for _, L in ipairs(T.leaves) do
    bucket.leaves[L.id] = loadImage(base .. "leaf_" .. L.id .. ".png")
  end
  for _, a in ipairs(T.amounts) do
    bucket.amounts[a.id] = loadImage(base .. "tea_amount_" .. a.id .. ".png")
  end
  for _, w in ipairs(T.wares) do
    bucket.wares[w.id] = loadImage(base .. "ware_" .. w.id .. ".png")
  end
  for _, t in ipairs(T.temps) do
    bucket.temps[tostring(t.c)] = loadImage(base .. "tea_temp_" .. t.c .. ".png")
  end
  for _, n in ipairs(T.steeps) do
    bucket.steeps[n] = loadImage(base .. "tea_steeps_" .. n .. ".png")
  end
  for i = 1, 3 do
    bucket.teaFrames[i] = loadImage(base .. "tea_" .. i .. ".png")
  end
end

function T.topView(ritual, assets)
  local phase = T.phaseById(ritual.phase or "brew")
  local title, img, mode = "泡茶", nil, "icon"
  if not phase then return title, nil, mode end
  if phase.kind == "brew" then
    local labels = { "泡茶 · 注水", "泡茶 · 闷泡", "泡茶 · 出汤" }
    title = labels[ritual.brewStep] or "泡茶"
    img = assets and assets.teaFrames and assets.teaFrames[ritual.brewStep]
    mode = "brew"
  elseif phase.kind == "confirm" then
    title = "温杯烫壶"
    img = assets and assets.rinse
  elseif phase.kind == "choice" then
    local list = T.catalogFor(phase)
    local item = list and list[ritual.pick]
    title = phase.head .. " · " .. T.choiceLabel(phase, item)
    img = T.choiceIcon(phase, item, assets)
  end
  return title, img, mode
end

function T.drawTop(ritual, assets, ctx)
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, ctx.TOP_W, ctx.TOP_H)
  local title, img, mode = T.topView(ritual, assets)
  if img then
    love.graphics.setColor(1, 1, 1, 1)
    if mode == "brew" then
      local srcW, srcH, s = 120, 76, 2
      ctx.drawFitted(img, math.floor((ctx.TOP_W - srcW * s) / 2), 34, srcW, srcH, s, s)
    else
      local s = 3
      local iw, ih = img:getWidth(), img:getHeight()
      love.graphics.draw(img, (ctx.TOP_W - iw * s) / 2, 56, 0, s, s)
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
  local slotW = math.floor((BOT_W - 20) / math.min(n, 5))
  for i, it in ipairs(items) do
    local x = 10 + (i - 1) * slotW
    local on = (i == ritual.pick)
    love.graphics.setColor(on and 0.98 or 0.94, on and 0.88 or 0.9, on and 0.55 or 0.82)
    love.graphics.rectangle("fill", x, 48, slotW - 4, 110)
    love.graphics.setColor(0.3, 0.2, 0.12)
    love.graphics.rectangle("line", x, 48, slotW - 4, 110)
    local icon = T.choiceIcon(phase, it, assets)
    if icon then
      love.graphics.setColor(1, 1, 1, 1)
      local iw, ih = icon:getWidth(), icon:getHeight()
      local s = math.min(40 / iw, 36 / ih)
      love.graphics.draw(icon, x + (slotW - 4 - iw * s) / 2, 56, 0, s, s)
    end
    love.graphics.setColor(0.22, 0.14, 0.08)
    love.graphics.print(T.choiceLabel(phase, it), x + 4, 100)
    love.graphics.setColor(0.4, 0.3, 0.2)
    love.graphics.print(T.choiceNote(phase, it), x + 4, 118)
  end
end

function T.drawBottom(ritual, assets, ctx)
  local BOT_W = ctx.BOT_W
  local phase, idx = T.phaseById(ritual.phase or "brew")
  local head = "泡茶"
  if phase then
    if phase.kind == "brew" then
      head = tostring(idx) .. "/" .. #T.PHASES .. " " .. phase.head .. " · " .. tostring(ritual.brewStep) .. "/3"
    else
      head = tostring(idx) .. "/" .. #T.PHASES .. " " .. phase.head
    end
  end
  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print(head, 14, 12)

  if phase and phase.kind == "choice" then
    drawChoiceRow(ritual, T.catalogFor(phase), phase, assets, BOT_W)
  elseif phase and phase.kind == "confirm" then
    love.graphics.setColor(0.25, 0.18, 0.1)
    love.graphics.print("先烫热杯壶，茶香才稳。", 40, 80)
    if assets and assets.rinse then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(assets.rinse, 136, 100, 0, 2, 2)
    end
  else
    love.graphics.setColor(0.25, 0.18, 0.1)
    local L = T.leaves[ritual.leafI]
    local W = T.wares[ritual.wareI]
    love.graphics.print((L and L.name or "?") .. " · " .. (W and W.name or "?")
      .. " · " .. tostring(ritual.tempC) .. "度 · " .. tostring(ritual.steeps) .. "次", 24, 70)
    love.graphics.print("茶烟轻轻的。慢慢来。", 24, 100)
  end

  love.graphics.setColor(0.35, 0.55, 0.35)
  love.graphics.rectangle("fill", 100, 210, 120, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print((phase and phase.kind == "brew") and "A 下一步" or "A 确认", 128, 213)
  love.graphics.setColor(0.55, 0.4, 0.35)
  love.graphics.rectangle("fill", 230, 210, 70, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("取消", 248, 213)
end

function T.potHint(ready, cups, highlight)
  if not ready then return nil end
  local left = math.max(0, T.CUPS_PER_POT - cups)
  if cups >= T.CUPS_PER_POT then return "茶壶空了 · 选泡茶再做" end
  if highlight then return "A 喝茶 · 还剩" .. left .. "口" end
  return "茶已泡好 · 还剩" .. left .. "口"
end

return T
