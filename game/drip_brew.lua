--[[
  露营之旅 — 手冲模块（见 docs/手冲模块-SPEC.md）
  require("drip_brew")；main 调用 DripBrew.bind{...} 后使用。
]]

local D = {
  CUPS_PER_POT = 3,
  taste = nil,
  last = nil,
  beans = {
    { id = "ethiopia", name = "埃塞", note = "花香明亮", acid = 3, sweet = 2, body = 1, bitter = 1 },
    { id = "peru", name = "秘鲁", note = "坚果可可", acid = 1, sweet = 2, body = 3, bitter = 1 },
    { id = "colombia", name = "哥伦比亚", note = "均衡甜感", acid = 2, sweet = 3, body = 2, bitter = 1 },
    { id = "kenya", name = "肯尼亚", note = "莓果酸质", acid = 3, sweet = 2, body = 2, bitter = 1 },
    { id = "brazil", name = "巴西", note = "巧克力感", acid = 1, sweet = 2, body = 3, bitter = 2 }
  },
  grinds = {
    { id = "fine", name = "细研磨", note = "萃取更深" },
    { id = "medium", name = "中研磨", note = "日常均衡" },
    { id = "coarse", name = "粗研磨", note = "更干净轻盈" }
  },
  drippers = {
    { id = "v60", name = "V60", note = "锥形单孔" },
    { id = "kalita", name = "梯形三孔", note = "平底更稳" },
    { id = "single", name = "平底单孔", note = "流速偏慢" },
    { id = "origami", name = "折纸滤杯", note = "棱面透气" },
    { id = "metal", name = "金属滤网", note = "油脂更足" }
  },
  temps = {
    { c = 92, name = "92度", note = "护住酸甜" },
    { c = 100, name = "100度", note = "更重更厚" }
  },
  pours = { 2, 3, 4 },
  -- 口感修正：按选项 id（避免散落 if）
  grindMod = {
    fine = { body = 1, bitter = 1 },
    coarse = { acid = 1, body = -1 }
  },
  dripperMod = {
    v60 = { acid = 1 },
    kalita = { body = 1, sweet = 1 },
    single = { body = 1 },
    origami = { acid = 1, sweet = 1 },
    metal = { body = 1, bitter = 1 }
  },
  pourMod = {
    [2] = { body = 1, bitter = 1 },
    [4] = { acid = 1, sweet = 1 }
  },
  brewLabels = { "闷蒸", "绕圈注水", "分享入杯" },
  pourNotes = { [2] = "更浓", [3] = "经典", [4] = "更透" }
}

-- 相位表：扩展优先改这里
D.PHASES = {
  { id = "bean", head = "选豆子", kind = "choice", catalog = "beans", store = "beanI", defaultPick = 1, assetBag = "beans",
    enterToast = "选豆子 · 左右切换 · A 确认", enterSfx = "ui_ok" },
  { id = "grind", head = "研磨", kind = "choice", catalog = "grinds", store = "grindI", defaultPick = 2, assetBag = "grinds",
    enterToast = nil, enterSfx = "ui_ok" },
  { id = "dripper", head = "选滤杯", kind = "choice", catalog = "drippers", store = "dripperI", defaultPick = 1, assetBag = "drippers",
    enterToast = nil, enterSfx = "ui_ok" },
  { id = "paper", head = "放滤纸", kind = "confirm",
    enterToast = "放滤纸 · 按 A 叠好", enterSfx = "ui_ok" },
  { id = "temp", head = "水温", kind = "choice", catalog = "temps", store = "tempC", valueKey = "c", defaultPick = 1, assetBag = "temps",
    enterToast = nil, enterSfx = "ui_ok" },
  { id = "pours", head = "冲几次", kind = "choice", catalog = "pours", store = "pours", list = true, defaultPick = 2, assetBag = "pours",
    enterToast = nil, enterSfx = "ui_ok" },
  { id = "brew", head = "冲煮", kind = "brew", brewSteps = 3,
    enterToast = "闷蒸 · 按 A 下一步", enterSfx = "pour" }
}

local hooks = nil

local function H()
  assert(hooks, "DripBrew.bind required")
  return hooks
end

function D.bind(h)
  hooks = h
end

function D.resetTrip()
  D.taste, D.last = nil, nil
end

function D.phaseById(id)
  for i, p in ipairs(D.PHASES) do
    if p.id == id then return p, i end
  end
end

function D.phaseIndex(id)
  local _, i = D.phaseById(id)
  return i or 1
end

function D.catalogFor(phase)
  if not phase or not phase.catalog then return nil end
  if phase.list then
    local items = {}
    for _, n in ipairs(D[phase.catalog]) do items[#items + 1] = n end
    return items
  end
  return D[phase.catalog]
end

function D.choiceLabel(phase, item)
  if not item then return "?" end
  if phase.list then return tostring(item) .. " 次" end
  return item.name or tostring(item)
end

function D.choiceNote(phase, item)
  if phase.list then return D.pourNotes[item] or "" end
  return item.note or ""
end

function D.choiceIcon(phase, item, assets)
  if not assets or not phase.assetBag then return nil end
  local bag = assets[phase.assetBag]
  if not bag then return nil end
  if phase.list then return bag[item] end
  if phase.valueKey == "c" then return bag[tostring(item.c)] end
  return item.id and bag[item.id]
end

function D.pickCount(ritual)
  ritual = ritual or (hooks and hooks.getRitual and hooks.getRitual())
  if not ritual or ritual.kind ~= "drip" then return 0 end
  local phase = D.phaseById(ritual.phase)
  if not phase or phase.kind ~= "choice" then return 0 end
  local list = D.catalogFor(phase)
  return list and #list or 0
end

function D.nudge(dir)
  local ritual = H().getRitual()
  if not ritual or ritual.kind ~= "drip" then return end
  local n = D.pickCount(ritual)
  if n <= 0 then return end
  ritual.pick = ritual.pick + dir
  if ritual.pick < 1 then ritual.pick = n end
  if ritual.pick > n then ritual.pick = 1 end
  H().playSfx("ui_move")
end

local function applyMod(acid, sweet, body, bitter, mod)
  if not mod then return acid, sweet, body, bitter end
  acid = acid + (mod.acid or 0)
  sweet = sweet + (mod.sweet or 0)
  body = math.max(1, body + (mod.body or 0))
  bitter = bitter + (mod.bitter or 0)
  return acid, sweet, body, bitter
end

function D.computeTaste(r)
  local bean = D.beans[r.beanI]
  local grind = D.grinds[r.grindI]
  local dripper = D.drippers[r.dripperI]
  local acid, sweet, body, bitter = bean.acid, bean.sweet, bean.body, bean.bitter
  acid, sweet, body, bitter = applyMod(acid, sweet, body, bitter, D.grindMod[grind.id])
  if r.tempC == 100 then
    acid, sweet, body, bitter = applyMod(acid, sweet, body, bitter, { bitter = 1, body = 1 })
  else
    acid, sweet, body, bitter = applyMod(acid, sweet, body, bitter, { acid = 1, sweet = 1 })
  end
  acid, sweet, body, bitter = applyMod(acid, sweet, body, bitter, D.dripperMod[dripper.id])
  acid, sweet, body, bitter = applyMod(acid, sweet, body, bitter, D.pourMod[r.pours])
  local traits = {
    { acid, "明亮果酸" },
    { sweet, "甜感回甘" },
    { bitter, "偏苦厚重" },
    { body, "醇厚扎实" }
  }
  table.sort(traits, function(a, b)
    if a[1] == b[1] then return a[2] < b[2] end
    return a[1] > b[1]
  end)
  return bean.name .. " · " .. traits[1][2] .. "，带点" .. traits[2][2]
end

local function toastEntering(phase)
  local h = H()
  if phase.enterSfx then h.playSfx(phase.enterSfx) end
  if phase.enterToast then
    h.say(phase.enterToast, 3)
    return
  end
  if phase.kind == "choice" then
    local list = D.catalogFor(phase)
    local item = list and list[phase.defaultPick or 1]
    local label = D.choiceLabel(phase, item)
    h.say(phase.head .. " · " .. label .. " · A 确认", 2.5)
  end
end

local function enterPhase(ritual, phaseIndex)
  local phase = D.PHASES[phaseIndex]
  ritual.phase = phase.id
  ritual.pick = phase.defaultPick or 1
  if phase.kind == "brew" then
    ritual.brewStep = 1
  end
  toastEntering(phase)
end

local function storePick(ritual, phase)
  local list = D.catalogFor(phase)
  local item = list and list[ritual.pick]
  if phase.list then
    ritual[phase.store] = item
  elseif phase.valueKey then
    ritual[phase.store] = item and item[phase.valueKey]
  else
    ritual[phase.store] = ritual.pick
  end
end

function D.finish()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "drip" then return end
  local taste = D.computeTaste(ritual)
  D.taste = taste
  D.last = {
    bean = D.beans[ritual.beanI].name,
    grind = D.grinds[ritual.grindI].name,
    dripper = D.drippers[ritual.dripperI].name,
    temp = ritual.tempC,
    pours = ritual.pours,
    taste = taste
  }
  h.setPot(true, 1)
  h.selectCup()
  h.clearRitual()
  h.onBrewMap(nil, nil, 8)
  h.playSfx("cup")
  h.addTripCoffee(1)
  h.say(taste .. " · 第一口。还剩两口。", 3.5)
end

function D.start()
  local h = H()
  local dripped, cups = h.getPot()
  if dripped and cups > 0 and cups < D.CUPS_PER_POT then
    h.selectCup()
    h.drinkCoffee()
    return
  end
  h.ensureRitual()
  if dripped and cups >= D.CUPS_PER_POT then
    h.setPot(false, 0)
    D.taste = nil
  end
  local ritual = {
    kind = "drip",
    phase = "bean",
    pick = 1,
    brewStep = 1,
    beanI = 1, grindI = 2, dripperI = 1, tempC = 92, pours = 3
  }
  h.setRitual(ritual)
  local px, py = h.playerXY()
  h.onBrewMap(px, py, 12)
  h.playSfx("ui_ok")
  h.say("选豆子 · 左右切换 · A 确认", 3)
end

function D.advance()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "drip" then return end
  local phase, idx = D.phaseById(ritual.phase)
  if not phase then return end

  if phase.kind == "brew" then
    local max = phase.brewSteps or 3
    if ritual.brewStep < max then
      ritual.brewStep = ritual.brewStep + 1
      local labels = D.brewLabels
      if ritual.brewStep == 2 then h.playSfx("pour")
      elseif ritual.brewStep == 3 then h.playSfx("cup") end
      h.say((labels[ritual.brewStep] or "手冲") .. " · 按 A 下一步", 2.5)
    else
      D.finish()
    end
    return
  end

  if phase.kind == "choice" then
    storePick(ritual, phase)
  end
  local nextIdx = idx + 1
  if nextIdx > #D.PHASES then
    D.finish()
    return
  end
  enterPhase(ritual, nextIdx)
end

function D.loadChoiceAssets(bucket, loadImage)
  local base = "assets/ritual/drip/"
  bucket.drippers, bucket.beans, bucket.grinds, bucket.temps, bucket.pours = {}, {}, {}, {}, {}
  bucket.paper = loadImage(base .. "drip_paper.png")
  bucket.drip = {
    loadImage(base .. "drip_1.png"),
    loadImage(base .. "drip_2.png"),
    loadImage(base .. "drip_3.png")
  }
  for _, d in ipairs(D.drippers) do
    bucket.drippers[d.id] = loadImage(base .. "dripper_" .. d.id .. ".png")
  end
  for _, b in ipairs(D.beans) do
    bucket.beans[b.id] = loadImage(base .. "bean_" .. b.id .. ".png")
  end
  for _, g in ipairs(D.grinds) do
    bucket.grinds[g.id] = loadImage(base .. "grind_" .. g.id .. ".png")
  end
  for _, t in ipairs(D.temps) do
    bucket.temps[tostring(t.c)] = loadImage(base .. "temp_" .. t.c .. ".png")
  end
  for _, n in ipairs(D.pours) do
    bucket.pours[n] = loadImage(base .. "pours_" .. n .. ".png")
  end
end

function D.topView(ritual, assets)
  local phase = D.phaseById(ritual.phase or "brew")
  local title = "手冲"
  local img, mode = nil, "icon"
  if not phase then return title, nil, mode end
  if phase.kind == "brew" then
    local labels = { "手冲 · 闷蒸", "手冲 · 绕圈注水", "手冲 · 分享入杯" }
    title = labels[ritual.brewStep] or "手冲"
    img = assets and assets.drip and assets.drip[ritual.brewStep]
    mode = "brew"
  elseif phase.kind == "confirm" then
    title = "放滤纸"
    img = assets and assets.paper
  elseif phase.kind == "choice" then
    local list = D.catalogFor(phase)
    local item = list and list[ritual.pick]
    title = phase.head .. " · " .. D.choiceLabel(phase, item)
    img = D.choiceIcon(phase, item, assets)
  end
  return title, img, mode
end

function D.drawTop(ritual, assets, ctx)
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, ctx.TOP_W, ctx.TOP_H)
  local title, img, mode = D.topView(ritual, assets)
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
    local icon = D.choiceIcon(phase, it, assets)
    if icon then
      love.graphics.setColor(1, 1, 1, 1)
      local iw, ih = icon:getWidth(), icon:getHeight()
      local s = math.min(40 / iw, 36 / ih)
      love.graphics.draw(icon, x + (slotW - 4 - iw * s) / 2, 56, 0, s, s)
    end
    love.graphics.setColor(0.22, 0.14, 0.08)
    love.graphics.print(D.choiceLabel(phase, it), x + 4, 100)
    love.graphics.setColor(0.4, 0.3, 0.2)
    love.graphics.print(D.choiceNote(phase, it), x + 4, 118)
  end
end

function D.drawBottom(ritual, assets, ctx)
  local BOT_W = ctx.BOT_W
  local phase, idx = D.phaseById(ritual.phase or "brew")
  local head = "手冲"
  if phase then
    if phase.kind == "brew" then
      head = tostring(idx) .. "/" .. #D.PHASES .. " " .. phase.head .. " · " .. tostring(ritual.brewStep) .. "/3"
    else
      head = tostring(idx) .. "/" .. #D.PHASES .. " " .. phase.head
    end
  end
  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print(head, 14, 12)

  if phase and phase.kind == "choice" then
    drawChoiceRow(ritual, D.catalogFor(phase), phase, assets, BOT_W)
  elseif phase and phase.kind == "confirm" then
    love.graphics.setColor(0.25, 0.18, 0.1)
    love.graphics.print("把滤纸折好，放进滤杯。", 40, 80)
    if assets and assets.paper then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(assets.paper, 136, 100, 0, 2, 2)
    end
  else
    love.graphics.setColor(0.25, 0.18, 0.1)
    local b = D.beans[ritual.beanI]
    local d = D.drippers[ritual.dripperI]
    love.graphics.print((b and b.name or "?") .. " · " .. (d and d.name or "?")
      .. " · " .. tostring(ritual.tempC) .. "度 · " .. tostring(ritual.pours) .. "次", 24, 70)
    love.graphics.print("闻得到咖啡香了。慢慢来。", 24, 100)
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

function D.potHint(drippedOnce, coffeeCups, highlight)
  if not drippedOnce then return nil end
  local left = math.max(0, D.CUPS_PER_POT - coffeeCups)
  if coffeeCups >= D.CUPS_PER_POT then return "壶空了 · 选手冲再做" end
  if highlight then return "A 喝咖啡 · 还剩" .. left .. "口" end
  return "咖啡已冲好 · 还剩" .. left .. "口"
end

return D
