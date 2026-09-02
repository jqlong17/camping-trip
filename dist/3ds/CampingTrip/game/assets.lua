--[[ 露营之旅 — 资源加载与懒加载（DEV-068e P4 · docs/代码架构-SPEC.md） ]]

local Assets = {}

local host
local store = {}
local assetRoot = ""
local loadFailCount = 0
local failedImages = {}
local fitQuads = {}

function Assets.bindHost(h)
  host = h
end

function Assets.get()
  return store
end

function Assets.failCount()
  return loadFailCount
end

function Assets.root()
  return assetRoot
end

function Assets.detectRoot()
  assetRoot = ""
  if host and host.isConsole and love.filesystem.mountFullPath then
    local ok, mounted = pcall(
      love.filesystem.mountFullPath,
      "sdmc:/",
      "sdmc",
      "read",
      true
    )
    if host.appendLoadLog then
      host.appendLoadLog("mountFullPath ok=" .. tostring(ok) .. " mounted=" .. tostring(mounted))
    end
    if ok and mounted then
      assetRoot = "sdmc/3ds/CampingTrip/game/"
      return
    end
  end
  if love.filesystem.getInfo and love.filesystem.getInfo("assets/ui/title_top.png") then
    return
  end
  if love.filesystem.getInfo and love.filesystem.getInfo("game/assets/ui/title_top.png") then
    assetRoot = "game/"
  end
end

function Assets.path(rel)
  return assetRoot .. rel
end

local function tryNewImage(path)
  local ok, img = pcall(love.graphics.newImage, path)
  if ok and img then return img, nil end
  return nil, img
end

function Assets.load(path)
  if failedImages[path] then return nil end
  local resolved = Assets.path(path)
  local img, err = tryNewImage(resolved)
  if img then
    pcall(function() img:setFilter("nearest", "nearest") end)
    return img
  end
  failedImages[path] = true
  loadFailCount = loadFailCount + 1
  if host and host.appendLoadLog then
    host.appendLoadLog("fail " .. resolved .. " " .. tostring(err))
  end
  return nil
end

function Assets.writeProbe()
  if not host or not host.isConsole then return end
  local log = host.appendLoadLog
  if not log then return end
  log("os=" .. tostring(love.system.getOS()))
  if love.filesystem.getIdentity then
    log("identity=" .. tostring(love.filesystem.getIdentity()))
  end
  if love.filesystem.getSaveDirectory then
    log("save=" .. tostring(love.filesystem.getSaveDirectory()))
  end
  if love.filesystem.getSource then
    log("source=" .. tostring(love.filesystem.getSource()))
  end
  log("assetRoot=" .. assetRoot)
  for _, p in ipairs({
    Assets.path("assets/ui/title_top.png"),
    "assets/ui/title_top.png",
    "game/assets/ui/title_top.png",
    "assets/tile_grass0.png",
    "assets/story/p1.png"
  }) do
    local info = love.filesystem.getInfo and love.filesystem.getInfo(p)
    log("info " .. p .. " " .. (info and tostring(info.size or "ok") or "nil"))
  end
end

function Assets.drawFitted(img, x, y, srcW, srcH, sx, sy)
  if not img then return end
  sx, sy = sx or 1, sy or 1
  local iw, ih = img:getWidth(), img:getHeight()
  if srcW and srcH and (iw > srcW or ih > srcH) then
    local q = fitQuads[img]
    if not q then
      local ok, made = pcall(love.graphics.newQuad, 0, 0, srcW, srcH, iw, ih)
      if ok then
        q = made
        fitQuads[img] = q
      end
    end
    if q then
      love.graphics.draw(img, q, x, y, 0, sx, sy)
      return
    end
  end
  love.graphics.draw(img, x, y, 0, sx, sy)
end

-- 分镜全屏：POT 512×256 只取左上 400×240 内容区，nearest 对齐上屏（避免整图被糊缩放）
function Assets.drawStoryFrame(img, x, y, dw, dh)
  if not img then return end
  dw = dw or 400
  dh = dh or 240
  local iw, ih = img:getWidth(), img:getHeight()
  local cw, ch = iw, ih
  if iw >= 400 and ih >= 240 then
    cw, ch = math.min(400, iw), math.min(240, ih)
  end
  local scale = math.min(dw / cw, dh / ch)
  if math.abs(scale - 1) < 0.03 then scale = 1 end
  local ox = x + math.floor((dw - cw * scale) / 2 + 0.5)
  local oy = y + math.floor((dh - ch * scale) / 2 + 0.5)
  if cw == iw and ch == ih then
    love.graphics.draw(img, ox, oy, 0, scale, scale)
    return
  end
  local q = fitQuads[img]
  if not q then
    local ok, made = pcall(love.graphics.newQuad, 0, 0, cw, ch, iw, ih)
    if ok then
      q = made
      fitQuads[img] = q
    end
  end
  if q then
    love.graphics.draw(img, q, ox, oy, 0, scale, scale)
  else
    love.graphics.draw(img, ox, oy, 0, scale, scale)
  end
end

function Assets.ensureStory(key)
  local AP = host and host.AP
  store.story = store.story or {}
  if not store.story[key] and AP then
    store.story[key] = Assets.load(AP.story(key))
  end
  return store.story[key]
end

function Assets.ensureCast(i)
  store.cast = store.cast or {}
  if not store.cast[i] then
    store.cast[i] = Assets.load("assets/cast/c" .. i .. ".png")
  end
  return store.cast[i]
end

function Assets.ensureWalk(i)
  store.walk = store.walk or {}
  if store.walk[i] then return store.walk[i] end
  local sheet = Assets.load("assets/cast/c" .. i .. "_walk.png")
  if not sheet then return nil end
  local quads = {}
  for row = 0, 3 do
    quads[row] = {}
    for col = 0, 2 do
      local ok, q = pcall(love.graphics.newQuad, col * 40, row * 40, 40, 40, sheet:getDimensions())
      if not ok then return nil end
      quads[row][col] = q
    end
  end
  store.walk[i] = { sheet = sheet, quads = quads }
  return store.walk[i]
end

-- TOP previews are intentionally a one-texture cache. A 320×180 PNG becomes a
-- 512×256 POT texture on 3DS (~512 KiB RGBA8888); retaining every catalog
-- option would waste tens of MiB. Bottom-screen icons remain in ritual bags.
function Assets.ensureTopPreview(path)
  if not path then return nil end
  store.topPreview = store.topPreview or {}
  if store.topPreview.path == path then return store.topPreview.image end
  store.topPreview.path = path
  store.topPreview.image = Assets.load(path)
  return store.topPreview.image
end

function Assets.ensureCodexPreview(id)
  if not id or id == "tea" then return nil end
  return Assets.ensureTopPreview("assets/previews/codex/" .. id .. ".png")
end

function Assets.ensureCastPreview(i)
  if not i then return nil end
  return Assets.ensureTopPreview("assets/previews/cast/c" .. tostring(i) .. ".png")
end

function Assets.ensureRitual()
  if store.ritual and store.ritual.ready then return store.ritual end
  store.ritual = {
    ready = true,
    drip = {},
    fishAnim = {},
  }
  local AP = host and host.AP
  DripBrew.loadChoiceAssets(store.ritual, Assets.load)
  TeaBrew.loadChoiceAssets(store.ritual, Assets.load)
  FishRod.loadChoiceAssets(store.ritual, Assets.load)
  TentGear.loadPitchFrames(store.ritual, Assets.load)
  CupSip.loadChoiceAssets(store.ritual, Assets.load)
  CookMeal.loadChoiceAssets(store.ritual, Assets.load)
  return store.ritual
end

function Assets.newFont(size)
  if host and host.isConsole then
    local ok, font = pcall(love.graphics.newFont, "chinese", size)
    if ok and font then return font end
    ok, font = pcall(love.graphics.newFont, size)
    return ok and font or nil
  end
  for _, path in ipairs({
    "fonts/zh-ui.ttf",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc"
  }) do
    local ok, font = pcall(love.graphics.newFont, path, size)
    if ok and font then return font end
  end
  return love.graphics.newFont(size)
end

function Assets.loadBoot()
  local AP = host and host.AP
  if not AP then return end
  store.titleTop = Assets.load(AP.ui("title_top.png"))
  store.titleBot = Assets.load(AP.ui("title_bot.png"))
  store.packBg = Assets.load(AP.ui("ui_pack_bg.png"))
  store.story, store.cast, store.walk = {}, {}, {}
  store.topPreview = {}
  store.ritual = { ready = false, drip = {}, fishAnim = {} }
  if host and host.appendLoadLog then
    host.appendLoadLog("loadAssets title done fails=" .. loadFailCount)
  end
end

return Assets
