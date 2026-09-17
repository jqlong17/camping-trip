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

local function releaseValue(value)
  if type(value) == "userdata" then
    pcall(function()
      if value.release then value:release() end
    end)
  elseif type(value) == "table" then
    for key, item in pairs(value) do
      releaseValue(item)
      value[key] = nil
    end
  end
end

-- 离开营地时丢掉世界/仪式纹理，给回家分镜和日记腾显存。
function Assets.releasePlayTextures()
  for _, key in ipairs({
    "grass", "water", "shallow", "trees", "bushes", "flowers", "stones", "dirt",
    "campStaticBase", "coastOceanSunrise", "coastOceanSunset", "forestDistantCanopy",
    "reed", "log", "stump", "pier", "nest", "shore", "dirtFringe",
    "fish", "birds", "butterfly", "dragonfly", "firefly", "crab",
    "tentOpen", "tent", "tentPacked", "firepit", "brewKit", "steam", "cupIcons",
    "player", "shadow", "shadowSm", "shadowTree", "fruitIcon", "fishIcons",
    "ritual", "topPreview",
  }) do
    releaseValue(store[key])
    store[key] = nil
  end
  store.ritual = { ready = false, readyKinds = {}, drip = {}, fishAnim = {} }
  store.topPreview = {}
  store.cupIcons = {}
  failedImages = {}
  if collectgarbage then pcall(collectgarbage, "collect") end
  if host and host.appendLoadLog then
    host.appendLoadLog("releasePlayTextures")
  end
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

function Assets.releaseStory(key)
  if not store.story then return end
  releaseValue(store.story[key])
  store.story[key] = nil
  local AP = host and host.AP
  if AP then failedImages[AP.story(key)] = nil end
end

function Assets.ensureCupIcon(i)
  store.cupIcons = store.cupIcons or {}
  if store.cupIcons[i] then return store.cupIcons[i] end
  local AP = host and host.AP
  local style = AP and AP.CUP_STYLES[i]
  if not style then return nil end
  store.cupIcons[i] = Assets.load(AP.cupPath(style.file))
  return store.cupIcons[i]
end

function Assets.ensureCupIconsSlice()
  local AP = host and host.AP
  if not AP then return end
  store.cupIcons = store.cupIcons or {}
  for i = 1, #AP.CUP_STYLES do
    if not store.cupIcons[i] then
      Assets.ensureCupIcon(i)
      return
    end
  end
end

function Assets.ensureCoastOcean(timeIndex)
  local AP = host and host.AP
  if not AP then return end
  if timeIndex == 1 and not store.coastOceanSunrise then
    store.coastOceanSunrise = Assets.load(AP.sceneCamp("coast_ocean_sunrise.png"))
  elseif timeIndex == 4 and not store.coastOceanSunset then
    store.coastOceanSunset = Assets.load(AP.sceneCamp("coast_ocean_sunset.png"))
  end
end

function Assets.ensureCast(i)
  store.cast = store.cast or {}
  if not store.cast[i] then
    store.cast[i] = Assets.load("assets/cast/c" .. i .. ".png")
  end
  return store.cast[i]
end

function Assets.ensureTentOpen()
  if store.tentOpen then return store.tentOpen end
  local AP = host and host.AP
  if not AP then return nil end
  store.tentOpen = Assets.load(AP.forestCamp("tent_open_hd.png"))
  if store.tentOpen then store.tent = store.tentOpen end
  return store.tentOpen
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

function Assets.releaseOtherRituals()
  local bucket = store.ritual
  if not bucket then return end
  for key, value in pairs(bucket) do
    if key ~= "readyKinds" and key ~= "ready" and key ~= "fishAnim" then
      releaseValue(value)
      bucket[key] = nil
    end
  end
  bucket.drip = {}
  bucket.readyKinds = {}
  bucket.ready = false
  if collectgarbage then pcall(collectgarbage, "collect") end
  if host and host.appendLoadLog then
    host.appendLoadLog("releaseOtherRituals")
  end
end

function Assets.ensureRitual(kind)
  store.ritual = store.ritual or {
    drip = {},
    fishAnim = {},
  }
  local bucket = store.ritual
  bucket.readyKinds = bucket.readyKinds or {}
  bucket.drip = bucket.drip or {}
  bucket.fishAnim = bucket.fishAnim or {}
  if kind == nil then
    if host and host.isConsole then
      return bucket
    end
    Assets.ensureRitual("drip")
    Assets.ensureRitual("tea")
    Assets.ensureRitual("rod")
    Assets.ensureRitual("tent")
    Assets.ensureRitual("cup")
    Assets.ensureRitual("cook")
    bucket.ready = true
    return bucket
  end
  if bucket.readyKinds[kind] then return bucket end
  if host and host.isConsole then
    local busy = false
    for other, ready in pairs(bucket.readyKinds) do
      if ready and other ~= kind and other ~= "cup_sip" then busy = true end
    end
    if busy then
      Assets.releaseOtherRituals()
      bucket = store.ritual
    end
  end
  if host and host.appendLoadLog then
    host.appendLoadLog("ensureRitual kind=" .. tostring(kind))
  end
  if kind == "drip" then
    DripBrew.loadChoiceAssets(bucket, Assets.load)
  elseif kind == "tea" then
    TeaBrew.loadChoiceAssets(bucket, Assets.load)
  elseif kind == "rod" then
    FishRod.loadChoiceAssets(bucket, Assets.load)
  elseif kind == "tent" then
    TentGear.loadPitchFrames(bucket, Assets.load)
  elseif kind == "cup" or kind == "cup_sip" then
    CupSip.loadChoiceAssets(bucket, Assets.load)
  elseif kind == "cook" then
    CookMeal.loadChoiceAssets(bucket, Assets.load)
  end
  bucket.readyKinds[kind] = true
  bucket.readyKinds.cup_sip = bucket.readyKinds.cup or bucket.readyKinds.cup_sip
  bucket.ready = true
  return bucket
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
  store.ritual = { ready = false, readyKinds = {}, drip = {}, fishAnim = {} }
  if host and host.appendLoadLog then
    host.appendLoadLog("loadAssets title done fails=" .. loadFailCount)
  end
end

return Assets
