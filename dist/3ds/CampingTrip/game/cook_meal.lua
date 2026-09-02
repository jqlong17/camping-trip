--[[ 露营之旅 — 做饭模块（见 docs/做饭模块-SPEC.md）替换扇子 ]]

local C = {
  taste = nil,
  last = nil,
  cuisines = {
    { id = "bbq", name = "烧烤", note = "炭香油脂" },
    { id = "sushi", name = "寿司", note = "清爽米醋" },
    { id = "hotpot", name = "火锅", note = "热汤暖胃" },
    { id = "skewer", name = "烤串", note = "焦边咸香" },
    { id = "stew", name = "炖锅", note = "软烂入味" }
  },
  heats = {
    { id = "soft", name = "文火", note = "更嫩" },
    { id = "mid", name = "中火", note = "外香里嫩" },
    { id = "hot", name = "猛火", note = "焦香带边" }
  },
  seasons = {
    { id = "salt", name = "盐胡椒", note = "干净咸香" },
    { id = "soy", name = "酱油", note = "酱香回甘" },
    { id = "citrus", name = "柑橘", note = "酸香提味" }
  },
  brewLabels = { "开火", "翻面成形", "盛盘" },
  heatMod = { soft = "偏嫩", mid = "外香里嫩", hot = "焦香带边" },
  seasonMod = { salt = "干净咸香", soy = "酱香回甘", citrus = "酸香提味" }
}

C.PHASES = {
  { id = "cuisine", head = "选菜系", kind = "choice", catalog = "cuisines", store = "cuisineI", defaultPick = 1, assetBag = "cookCuisines",
    enterToast = "选菜系 · 左右 · A", enterSfx = "ui_ok" },
  { id = "heat", head = "火候", kind = "choice", catalog = "heats", store = "heatI", defaultPick = 2, assetBag = "cookHeats",
    enterSfx = "ui_ok" },
  { id = "season", head = "调味", kind = "choice", catalog = "seasons", store = "seasonI", defaultPick = 1, assetBag = "cookSeasons",
    enterSfx = "ui_ok" },
  { id = "prep", head = "备菜", kind = "confirm",
    enterToast = "备菜摆好 · A 开火", enterSfx = "ui_ok" },
  { id = "cook", head = "烹饪", kind = "brew", brewSteps = 3,
    enterToast = "开火 · 按 A 下一步", enterSfx = "ui_ok" }
}

local hooks = nil
local function H()
  assert(hooks, "CookMeal.bind required")
  return hooks
end

function C.bind(h) hooks = h end

function C.resetTrip()
  C.taste, C.last = nil, nil
end

function C.phaseById(id)
  for i, p in ipairs(C.PHASES) do
    if p.id == id then return p, i end
  end
end

function C.catalogFor(phase)
  if not phase or not phase.catalog then return nil end
  return C[phase.catalog]
end

function C.computeTaste(ritual)
  local cu = C.cuisines[ritual.cuisineI or 1] or C.cuisines[1]
  local he = C.heats[ritual.heatI or 2] or C.heats[2]
  local se = C.seasons[ritual.seasonI or 1] or C.seasons[1]
  local hm = C.heatMod[he.id] or he.note
  local sm = C.seasonMod[se.id] or se.note
  return cu.name .. " · " .. he.name .. " · " .. se.name .. " · " .. hm .. "带" .. sm
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

function C.finish()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "cook" then return end
  local taste = C.computeTaste(ritual)
  C.taste = taste
  local cu = C.cuisines[ritual.cuisineI or 1]
  C.last = { cuisine = cu and cu.name, taste = taste }
  h.clearRitual()
  h.addTripMeal(1)
  h.playSfx("cup")
  h.say(taste .. " · 开饭了。", 3.5)
end

function C.start()
  local h = H()
  h.ensureRitual()
  h.setRitual({
    kind = "cook",
    phase = "cuisine",
    pick = 1,
    brewStep = 1,
    cuisineI = 1, heatI = 2, seasonI = 1
  })
  h.playSfx("ui_ok")
  h.say("选菜系 · 左右 · A", 3)
end

function C.advance()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "cook" then return end
  local phase, idx = C.phaseById(ritual.phase)
  if not phase then return end
  if phase.kind == "brew" then
    local max = phase.brewSteps or 3
    if ritual.brewStep < max then
      ritual.brewStep = ritual.brewStep + 1
      h.playSfx("ui_ok")
      h.say((C.brewLabels[ritual.brewStep] or "做饭") .. " · 按 A 下一步", 2.5)
    else
      C.finish()
    end
    return
  end
  if phase.kind == "choice" then storePick(ritual, phase) end
  local nextIdx = idx + 1
  if nextIdx > #C.PHASES then C.finish(); return end
  enterPhase(ritual, nextIdx)
end

function C.nudge(dir)
  local ritual = H().getRitual()
  if not ritual or ritual.kind ~= "cook" then return end
  local phase = C.phaseById(ritual.phase)
  if not phase or phase.kind ~= "choice" then return end
  local list = C.catalogFor(phase)
  if not list then return end
  ritual.pick = ((ritual.pick - 1 + dir) % #list) + 1
  H().playSfx("ui_move")
end

function C.cancel()
  local h = H()
  if not h.getRitual() or h.getRitual().kind ~= "cook" then return end
  h.clearRitual()
  h.say("不做饭了", 2)
end

function C.loadChoiceAssets(bucket, loadImage)
  local base = "assets/ritual/cook/"
  bucket.cookCuisines, bucket.cookHeats, bucket.cookSeasons = {}, {}, {}
  bucket.cookBrew = {
    loadImage(base .. "cook_1.png"),
    loadImage(base .. "cook_2.png"),
    loadImage(base .. "cook_3.png")
  }
  for _, c in ipairs(C.cuisines) do
    bucket.cookCuisines[c.id] = loadImage(base .. "cuisine_" .. c.id .. ".png")
  end
  for _, h in ipairs(C.heats) do
    bucket.cookHeats[h.id] = loadImage(base .. "heat_" .. h.id .. ".png")
  end
  for _, s in ipairs(C.seasons) do
    bucket.cookSeasons[s.id] = loadImage(base .. "season_" .. s.id .. ".png")
  end
end

function C.drawTop(ritual, assets, context)
  local phase = C.phaseById(ritual.phase)
  love.graphics.setColor(0.12, 0.14, 0.12, 1)
  love.graphics.rectangle("fill", 0, 0, context.TOP_W, context.TOP_H)
  love.graphics.setColor(1, 1, 1, 1)
  local img, previewPath
  if phase and phase.kind == "brew" then
    img = assets and assets.cookBrew and assets.cookBrew[ritual.brewStep]
    previewPath = "assets/previews/ritual/cook/cook_" .. tostring(ritual.brewStep) .. ".png"
  elseif phase and phase.kind == "confirm" then
    local cu = C.cuisines[ritual.cuisineI or 1]
    img = assets and assets.cookCuisines and cu and assets.cookCuisines[cu.id]
    if cu then previewPath = "assets/previews/ritual/cook/cuisine_" .. cu.id .. ".png" end
  elseif phase and phase.kind == "choice" then
    local list = C.catalogFor(phase)
    local item = list and list[ritual.pick]
    local bag = assets and phase.assetBag and assets[phase.assetBag]
    img = bag and item and bag[item.id]
    if item then
      local prefix = ({ cookCuisines = "cuisine", cookHeats = "heat", cookSeasons = "season" })[phase.assetBag]
      if prefix then previewPath = "assets/previews/ritual/cook/" .. prefix .. "_" .. item.id .. ".png" end
    end
  end
  local preview = context.loadTopPreview and context.loadTopPreview(previewPath)
  if preview then img = preview end
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    if preview then
      local x, y = math.floor((context.TOP_W - 320) / 2), 30
      if context.drawFitted then context.drawFitted(img, x, y, 320, 180, 1, 1)
      else love.graphics.draw(img, x, y) end
    elseif phase and phase.kind == "brew" then
      local srcW, srcH = 160, 120
      if iw < srcW or ih < srcH then srcW, srcH = iw, ih end
      local maxW, maxH = context.TOP_W - 32, context.TOP_H - 40
      local s = math.min(maxW / srcW, maxH / srcH)
      local x = math.floor((context.TOP_W - srcW * s) / 2)
      local y = math.floor((context.TOP_H - srcH * s) / 2)
      if context.drawFitted then
        context.drawFitted(img, x, y, srcW, srcH, s, s)
      else
        love.graphics.draw(img, x, y, 0, s, s)
      end
    else
      love.graphics.draw(
        img,
        math.floor((context.TOP_W - iw) / 2),
        math.floor((context.TOP_H - ih) / 2)
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
  local idx = select(2, C.phaseById(ritual.phase)) or 1
  love.graphics.print(tostring(idx) .. "·" .. #C.PHASES .. " " .. (phase and phase.head or "做饭"), 12, 16)
  if phase and phase.kind == "choice" then
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
      love.graphics.setColor(0.2, 0.18, 0.14, 1)
      love.graphics.printf(cur.note or "", 12, 160, BOT_W - 24, "center")
    end
  elseif phase and phase.kind == "confirm" then
    local cu = C.cuisines[ritual.cuisineI or 1]
    local he = C.heats[ritual.heatI or 2]
    local se = C.seasons[ritual.seasonI or 1]
    love.graphics.printf((cu and cu.name or "") .. " · " .. (he and he.name or "") .. " · " .. (se and se.name or ""), 12, 90, BOT_W - 24, "center")
    love.graphics.printf("A 开火", 12, 130, BOT_W - 24, "center")
  elseif phase and phase.kind == "brew" then
    love.graphics.printf((C.brewLabels[ritual.brewStep] or "烹饪") .. " · A 下一步", 12, 100, BOT_W - 24, "center")
  end
  love.graphics.setColor(0.35, 0.3, 0.25, 1)
  love.graphics.print("A 确认", 128, 213)
  love.graphics.print("B 取消", 220, 213)
end

return C
