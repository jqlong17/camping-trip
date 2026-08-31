--[[
  露营之旅 — full weekend loop (LovePotion / desktop LÖVE)
  title → prologue → cast → depart → play → homecoming → title
]]

local TOP_W, TOP_H = 400, 240
local BOT_W, BOT_H = 320, 240
local TILE = 16

AP = require("asset_paths")
DripBrew = require("drip_brew")
TeaBrew = require("tea_brew")
FishRod = require("fish_rod")
Audio = require("audio")
Assets = require("assets")
CampMap = require("camp_map")
CampPreload = require("camp_preload")
CampWorld = require("camp_world")
CampTiles = require("draw.camp_tiles")
CampRender = require("camp_render")

local isConsole = love.system.getOS() == "Horizon" or love.system.getOS() == "3DS"
local desktopBottom
local uiFont, titleFont
local buildId = "2026-08-31-precomposed-camp-coffee-cup"
-- First hardware diagnostic pass: isolate static-map cost from animated effects.
local staticPlayFx = isConsole or os.getenv("LINJIAN_PLAY_FX") == "static"
local perfMode = staticPlayFx and "static_play_fx" or "full_play_fx"
local campCanvasEnabled = staticPlayFx and not isConsole
local cheapWindFx = isConsole or not staticPlayFx
local critterFx = (not staticPlayFx) or isConsole or os.getenv("LINJIAN_CRITTER_FX") == "1"

-- Keep enough evidence to distinguish render stalls from audio stalls on hardware.
local perfWindow = 0
local perfFrames = 0
local perfSlowFrames = 0
local perfMaxDt = 0

local scene = "title"
local titlePulse, waterPhase = 0, 0
local menuIndex = 1
local menuItems = {
  { id = "start", label = "开始旅程", enabled = true },
  { id = "continue", label = "继续", enabled = false },
  { id = "codex", label = "装备图鉴", enabled = true },
  { id = "about", label = "关于", enabled = true }
}

local prologue = {
  i = 1,
  beats = {
    { img = "p1", line = "……终于周末了。" },
    { img = "p2", line = "电脑关上。咖啡器具、帐篷……都带上。" },
    { img = "p3", line = "去有小河的那片林子吧。" },
    { img = "p3", line = "走。" }
  }
}

local cast = {
  i = 1,
  names = {
    "眼镜上班族", "草帽姑娘", "背心男生", "绿帽女孩", "丸子头",
    "银发polo", "钓鱼姑娘", "条纹少年", "格子衫"
  }
}

local depart = {
  i = 1,
  beats = {
    { img = "d1", line = "林间小路……空气真好。" },
    { img = "d2", line = "到了。先安顿下来吧。" }
  }
}

local homecoming = {
  i = 1,
  beats = {
    { img = "h1", line = "回到城里了。下周……再去吧。" }
  }
}

local player = { x = 10, y = 9, facing = 0, castId = 1, walkFrame = 0, walkTimer = 0, idleT = 0 }
local toast, toastT = "", 0
local selected = 1
local lanternOn = false
local canGoHome = false
local tentOpen = false
local brewActive = false
local brewTimer = 0
local brewX, brewY = 10, 9
local potSimmer = 0
local drippedOnce = false
local coffeeCups = 0
local ritual = nil -- { kind="drip"|"tent", step=1, max=3 }

local timeSlots = { "清晨", "上午", "午后", "黄昏", "入夜", "深夜", "黎明" }
local timeIndex = 3 -- 午后
local timeTint = {
  {0.75, 0.85, 1.00, 0.18},
  {1.00, 1.00, 0.95, 0.05},
  {1.00, 0.95, 0.80, 0.08},
  {1.00, 0.70, 0.45, 0.22},
  {0.35, 0.40, 0.70, 0.40},
  {0.15, 0.18, 0.35, 0.55},
  {0.80, 0.85, 1.00, 0.20}
}

local gear = {
  { id = "tent", name = "帐篷", tag = "过夜", x = 24, y = 48,
    lines = { "周末从城里带出来的房子。", "靠近空地按 A，搭起或收起。" } },
  { id = "drip", name = "手冲", tag = "仪式", x = 120, y = 48,
    lines = { "V60 与分享壶。闷蒸、绕圈、入杯。", "营地里选中后按 A 开始三步。" } },
  { id = "pot", name = "小锅", tag = "炊事", x = 216, y = 48,
    lines = { "坐在营火边上才会冒热气。", "不求大餐，一锅热的就够。" } },
  { id = "rod", name = "钓竿", tag = "溪边", x = 24, y = 132,
    lines = { "小溪可以趟过去。站在水边甩一竿。", "偶尔有鱼跳起来。" } },
  { id = "cup", name = "杯子", tag = "品尝", x = 120, y = 132,
    lines = { "手冲完成后才能喝到味道。", "第一口，留给这个周末。" } },
  { id = "fan", name = "扇子", tag = "凉快", x = 216, y = 132,
    lines = { "午后热了就扇一阵。", "短短四下，风就来了。" } }
}

local codex = { i = 1 }


-- tile: 0/1 grass, 2 creek, 3 tree, 4 rock, 5 tent, 6 bush, 7 dirt pad, 8 shallow ford

local playtest = { on = false, t = 0, step = 0, done = false, log = {}, outDir = "playtest", _walk = 0 }
local playtestTick

local cupStyle = 1
local cupPick = false
local CUP_COLS = 3

local function cupSlotRect(i)
  local col = (i - 1) % CUP_COLS
  local row = math.floor((i - 1) / CUP_COLS)
  local slotW = 96
  return 16 + col * slotW, 44 + row * 58, slotW - 4, 54
end

function applyCupIcon()
  local a = Assets.get()
  if not a.cupIcons then return end
  for _, g in ipairs(gear) do
    if g.id == "cup" then g.icon = a.cupIcons[cupStyle] or g.icon end
  end
end

local function nudgeCupStyle(dx, dy)
  local n = #AP.CUP_STYLES
  if dx ~= 0 then
    cupStyle = ((cupStyle - 1 + dx) % n) + 1
  elseif dy ~= 0 then
    local nextI = cupStyle + dy * CUP_COLS
    if nextI < 1 then nextI = nextI + n elseif nextI > n then nextI = nextI - n end
    cupStyle = nextI
  end
  applyCupIcon()
  Audio.playSfx("ui_move")
end

local function playtestLog(msg)
  playtest.log[#playtest.log + 1] = msg
  print("[playtest] " .. msg)
end

local function playtestWanted()
  if arg then
    for _, a in ipairs(arg) do
      if a == "--playtest" then return true end
    end
  end
  return os.getenv("LINJIAN_PLAYTEST") == "1"
end

local function timeLabel()
  return timeSlots[timeIndex]
end

local function isNight()
  return timeIndex >= 5 and timeIndex <= 6
end

local function starAlpha()
  if isNight() then return 1 end
  if timeIndex == 4 then return 0.35 end -- 黄昏
  if timeIndex == 7 then return 0.25 end -- 黎明
  return 0
end


local function say(msg, sec)
  toast = msg
  toastT = sec or 2.5
end

-- 真机 LovePotion 有时把 3dsx 目录当根，资源实际在 game/assets/
local assetRoot = ""
local loadFailCount = 0
local failedImages = {}

local function appendLoadLog(line)
  if not isConsole and not playtestWanted() then return end
  pcall(function()
    love.filesystem.append("load_report.txt", line .. "\n")
  end)
end


local function applyCast(id)
  player.castId = id
  ensureCast(id)
  ensureWalk(id)
  Assets.get().player = Assets.get().cast[id] or Assets.get().player
end

local function syncSceneBgm()
  if scene == "play" then
    Audio.syncPlayBgm()
    return
  end
  if scene == "title" or scene == "codex" or scene == "about" or scene == "homecoming" then
    if Audio.bgm.title then Audio.playBgm(Audio.bgm.title) end
  elseif scene == "prologue" or scene == "depart" or scene == "cast" then
    if Audio.bgm.morning then Audio.playBgm(Audio.bgm.morning) end
  end
end

local function goTitle()
  scene = "title"
  prologue.i, depart.i, homecoming.i = 1, 1, 1
  cast.i = 1
  lanternOn, canGoHome = false, false
  timeIndex = 3
  Audio.stopAmb()
  syncSceneBgm()
  say("触摸或方向键选择 · A 确认", 3)
end

local function goPrologue()
  scene = "prologue"
  prologue.i = 1
  ensureStory("p1")
  Audio.stopAmb()
  syncSceneBgm()
  toast, toastT = "", 0
end

local function goCast()
  scene = "cast"
  for i = 1, 9 do ensureCast(i) end
  say("这次谁去？选好后按 A 确认", 3)
end

local function goDepart()
  scene = "depart"
  depart.i = 1
  ensureStory("d1")
  toast, toastT = "", 0
end

local function goPlay()
  scene = "play"
  CampPreload.ensure()
  ensureWalk(player.castId or 1)
  player.x, player.y = 10, 9
  player.facing, player.walkFrame, player.walkTimer = 0, 0, 0
  selected = 1
  timeIndex = 2 -- 上午抵达
  lanternOn, canGoHome = false, false
  tentOpen, brewActive, brewTimer, potSimmer = false, false, 0, 0
  drippedOnce = false
  coffeeCups = 0
  cupStyle, cupPick = 1, false
  ritual = nil
  CampWorld.resetCritters()
  local critters = CampWorld.getCritters()
  critters.birdT, critters.bugT = 0.4, 0.6
  Audio.stopBgm()
  Audio.syncPlayBgm()
  say("到了 · 林间有小溪，可以趟过去", 3.5)
end

local function clearRitual()
  ritual = nil
end

local function startDripRitual()
  if drippedOnce then
    selected = 5
    Audio.playSfx("cup")
    coffeeCups = coffeeCups + 1
    say("喝了一口咖啡 · 第" .. coffeeCups .. "口", 2.5)
    return
  end
  ensureRitual()
  ritual = { kind = "drip", step = 1, max = 3 }
  brewActive = true
  brewX, brewY = player.x, player.y
  brewTimer = 8
  Audio.playSfx("pour")
  say("闷蒸 · 按 A 下一步", 3)
end

local function advanceDripRitual()
  if not ritual or ritual.kind ~= "drip" then return end
  if ritual.step < ritual.max then
    ritual.step = ritual.step + 1
    local labels = { "闷蒸", "绕圈注水", "分享入杯" }
    if ritual.step == 2 then Audio.playSfx("pour")
    elseif ritual.step == 3 then Audio.playSfx("cup") end
    say(labels[ritual.step] .. " · 按 A 下一步", 2.5)
  else
    drippedOnce = true
    selected = 5
    clearRitual()
    brewTimer = 6
    Audio.playSfx("cup")
    coffeeCups = coffeeCups + 1
    say("第一口咖啡……周末真好。杯子可继续喝。", 3)
    if timeIndex < 4 then
      timeIndex = timeIndex + 1
      say("时间到了 · " .. timeSlots[timeIndex], 2)
      Audio.syncPlayBgm()
    end
  end
end

local function drinkCoffee()
  if not drippedOnce then
    say("杯子还是空的 · 先手冲吧。", 2.5)
    return
  end
  if not cupPick then
    cupPick = true
    say("选杯子 · 方向键 · A 喝一口", 2.8)
    return
  end
  coffeeCups = coffeeCups + 1
  cupPick = false
  Audio.playSfx("cup")
  local nm = AP.CUP_STYLES[cupStyle] and AP.CUP_STYLES[cupStyle].name or "杯子"
  say(nm .. " · 第" .. coffeeCups .. "口", 2.5)
end

local function startRodRitual()
  ensureRitual()
  ritual = { kind = "rod", step = 1, max = 4, t = 0, frameDur = 0.45 }
  fishFX = CampWorld.getFishFX()
  fishFX.timer = 0.2
  say("抛竿……", 1.5)
end

local function startFanRitual()
  ensureRitual()
  ritual = { kind = "fan", step = 1, max = 4, t = 0, frameDur = 0.35 }
  Audio.playSfx("fan")
  say("扇风……", 1.2)
end

updateTimedRitual = function(dt)
  if not ritual or not ritual.frameDur then return end
  ritual.t = (ritual.t or 0) + dt
  if ritual.t < ritual.frameDur then return end
  ritual.t = 0
  if ritual.step < ritual.max then
    ritual.step = ritual.step + 1
    if ritual.kind == "rod" and ritual.step == 4 then
      fishFX = CampWorld.getFishFX()
      fishFX.timer = 0.05
      say("有鱼！……又溜了。", 2.5)
    elseif ritual.kind == "fan" and ritual.step == 3 then
      Audio.playSfx("fan")
      say("凉快一点了。", 2)
    end
  else
    local kind = ritual.kind
    clearRitual()
    if kind == "rod" then say("今天先这样。", 2)
    elseif kind == "fan" then say("风停了。", 1.5) end
  end
end

local function toggleTent()
  local nearTent = math.abs(player.x - 11) + math.abs(player.y - 10) <= 2
  if not nearTent then
    say("靠近空地再搭帐篷", 2)
    return
  end
  tentOpen = not tentOpen
  Audio.playSfx("tent")
  if tentOpen then
    say("帐篷搭好了。", 2.5)
  else
    say("帐篷收起来了。", 2)
  end
end

local function tryUseGear()
  if ritual then
    if ritual.kind == "drip" then
      advanceDripRitual()
    elseif ritual.kind == "rod" or ritual.kind == "fan" then
      ritual.step = ritual.max
      ritual.t = ritual.frameDur
      updateTimedRitual(0)
    end
    return
  end
  local g = gear[selected]
  if not g then return end
  local firepit = CampMap.getFirepit()
  local nearFire = math.abs(player.x - firepit.x) + math.abs(player.y - firepit.y) <= 2

  if g.id == "tent" then
    toggleTent()
  elseif g.id == "drip" then
    startDripRitual()
  elseif g.id == "pot" then
    if nearFire then
      potSimmer = 3
      say("小锅咕嘟响了一会儿。", 2.5)
    else
      say("去营火旁再烧水吧。", 2)
    end
  elseif g.id == "rod" then
    local nearCreek = false
    for _, d in ipairs({ {0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1} }) do
      local row = CampMap.getMap()[player.y + d[2]]
      local tt = row and row[player.x + d[1]]
      if tt == 2 or tt == 8 then nearCreek = true; break end
    end
    if nearCreek then
      startRodRitual()
    else
      say("去小溪边再试试。", 2.5)
    end
  elseif g.id == "cup" then
    drinkCoffee()
  elseif g.id == "fan" then
    startFanRitual()
  else
    say("拿起了" .. g.name, 2)
  end

  if nearFire and timeIndex >= 5 and not lanternOn then
    lanternOn = true
    canGoHome = true
    Audio.playSfx("lantern")
    say("点亮了露营灯 · 夜色温柔。", 3.5)
  end
end

local function tryMove(dx, dy)
  if ritual then return end
  local nx, ny = player.x + dx, player.y + dy
  if CampMap.walkable(nx, ny) then
    player.x, player.y = nx, ny
    player.walkFrame = (player.walkFrame == 1) and 2 or 1
    player.idleT = 0.28
    Audio.playSfx("step")
  end
  if dx ~= 0 or dy ~= 0 then
    if math.abs(dx) > math.abs(dy) then
      player.facing = dx > 0 and 2 or 1
    else
      player.facing = dy > 0 and 0 or 3
    end
  end
end

local function goHomecoming()
  scene = "homecoming"
  homecoming.i = 1
  ensureStory("h1")
  ritual = nil
  Audio.stopAmb()
  syncSceneBgm()
  toast, toastT = "", 0
end

local function advancePrologue()
  if prologue.i < #prologue.beats then
    prologue.i = prologue.i + 1
  else
    goCast()
  end
end

local function advanceDepart()
  if depart.i < #depart.beats then
    depart.i = depart.i + 1
  else
    goPlay()
  end
end

local function advanceHome()
  if homecoming.i < #homecoming.beats then
    homecoming.i = homecoming.i + 1
  else
    goTitle()
    say("周末结束 · 下周见", 3)
  end
end

local function confirmCast()
  Audio.playSfx("ui_ok")
  applyCast(cast.i)
  goDepart()
end

local function setCast(i)
  if cast.i == i then return end
  cast.i = i
  ensureCast(i)
  Audio.playSfx("ui_move")
end

local function startJourney()
  goPrologue()
end

local function confirmMenu()
  local item = menuItems[menuIndex]
  if not item or not item.enabled then
    if item and item.id == "continue" then say("还没有存档", 2) end
    return
  end
  Audio.playSfx("ui_ok")
  if item.id == "start" then startJourney()
  elseif item.id == "codex" then goCodex()
  elseif item.id == "about" then goAbout()
  end
end

goCodex = function()
  scene = "codex"
  CampPreload.ensure()
  codex.i = 1
  toast, toastT = "", 0
  syncSceneBgm()
end

goAbout = function()
  scene = "about"
  toast, toastT = "", 0
  syncSceneBgm()
end

local function moveCodex(delta)
  local n = #gear
  codex.i = ((codex.i - 1 + delta) % n) + 1
  Audio.playSfx("ui_move")
end

local function setCodex(i)
  if i < 1 or i > #gear or i == codex.i then return end
  codex.i = i
  Audio.playSfx("ui_move")
end

local function moveMenu(delta)
  menuIndex = ((menuIndex - 1 + delta) % #menuItems) + 1
  Audio.playSfx("ui_move")
end

local function menuHit(lx, ly)
  local x0, w = 40, BOT_W - 80
  for i = 1, #menuItems do
    local y = 64 + (i - 1) * 38
    if lx >= x0 and lx <= x0 + w and ly >= y and ly <= y + 32 then return i end
  end
end

local function castHit(lx, ly)
  for i = 1, 9 do
    local col = (i - 1) % 3
    local row = math.floor((i - 1) / 3)
    local x, y = 24 + col * 96, 48 + row * 56
    if lx >= x and lx <= x + 88 and ly >= y and ly <= y + 48 then return i end
  end
end

local function advanceTime()
  if timeIndex < #timeSlots then
    timeIndex = timeIndex + 1
    say("时间到了 · " .. timeLabel(), 2.5)
    if timeSlots[timeIndex] == "入夜" or timeSlots[timeIndex] == "深夜" then
      nightFX = CampWorld.getNightFX()
      nightFX.meteorT = 0.35
      CampWorld.onEnterNight()
      for _ = 1, 4 do spawnBug() end
      say("入夜了 · 营火旁按 A 点灯。抬头有星星。", 3.5)
    elseif timeSlots[timeIndex] == "黎明" then
      canGoHome = true
      say("天亮了 · 可以收拾回家（下屏按钮）", 3.5)
    end
    Audio.syncPlayBgm()
  else
    canGoHome = true
    say("可以回家了", 2)
  end
end

-- drip ritual may bump time after finish (advanceTime exists now)

local function advancePrimary()
  if scene == "title" then confirmMenu()
  elseif scene == "prologue" then Audio.playSfx("ui_ok"); advancePrologue()
  elseif scene == "cast" then confirmCast()
  elseif scene == "depart" then Audio.playSfx("ui_ok"); advanceDepart()
  elseif scene == "play" then tryUseGear()
  elseif scene == "homecoming" then Audio.playSfx("ui_ok"); advanceHome()
  end
end

local function hitGear(lx, ly)
  for i, g in ipairs(gear) do
    if lx >= g.x and lx <= g.x + 80 and ly >= g.y and ly <= g.y + 72 then return i end
    end
  end

local function playActionHit(lx, ly)
  -- 过一会儿 button
  if lx >= 20 and lx <= 150 and ly >= 210 and ly <= 232 then return "wait" end
  if canGoHome and lx >= 170 and lx <= 300 and ly >= 210 and ly <= 232 then return "home" end
end

local function onBottomTouch(lx, ly)
  if scene == "title" then
    local i = menuHit(lx, ly)
    if i then
      if menuIndex ~= i then Audio.playSfx("ui_move") end
      menuIndex = i
      confirmMenu()
    end
  elseif scene == "codex" then
    local i = hitGear(lx, ly)
    if i then setCodex(i)
    elseif lx >= 100 and lx <= 220 and ly >= 204 and ly <= 226 then goTitle()
    end
  elseif scene == "about" then
    if lx >= 100 and lx <= 220 and ly >= 204 and ly <= 226 then goTitle() end
  elseif scene == "prologue" or scene == "depart" or scene == "homecoming" then
    advancePrimary()
  elseif scene == "cast" then
    local i = castHit(lx, ly)
    if i then setCast(i)
    elseif lx >= 100 and lx <= 220 and ly >= 210 and ly <= 232 then confirmCast()
    end
  elseif scene == "play" then
    if ritual then
      if ritual.kind == "drip" then
        if lx >= 100 and lx <= 220 and ly >= 210 and ly <= 232 then tryUseGear()
        elseif lx >= 230 and lx <= 300 and ly >= 210 and ly <= 232 then
          ritual = nil; brewActive = false; say("取消了手冲", 2)
        end
      else
        if lx >= 100 and lx <= 220 and ly >= 210 and ly <= 232 then tryUseGear() end
      end
      return
    end
    local act = playActionHit(lx, ly)
    if act == "wait" then advanceTime()
    elseif act == "home" then goHomecoming()
    else
  local i = hitGear(lx, ly)
  if i then
        if selected ~= i then Audio.playSfx("ui_move") end
    selected = i
    say("选中 · " .. gear[i].name)
      end
    end
  end
end


local departPendingPlay = false

local function bindCampModules()
  local campHost = {
    TOP_W = TOP_W, TOP_H = TOP_H, BOT_W = BOT_W, TILE = TILE,
    isConsole = isConsole,
    staticPlayFx = staticPlayFx,
    campCanvasEnabled = campCanvasEnabled,
    cheapWindFx = cheapWindFx,
    critterFx = critterFx,
    perfMode = perfMode,
    AP = AP,
    gear = gear,
    Assets = Assets,
    CampMap = CampMap,
    CampPreload = CampPreload,
    CampWorld = CampWorld,
    CampTiles = CampTiles,
    appendLoadLog = appendLoadLog,
    getAssets = function() return Assets.get() end,
    getScene = function() return scene end,
    getRitual = function() return ritual end,
    getPlayer = function() return player end,
    getLanternOn = function() return lanternOn end,
    getTentOpen = function() return tentOpen end,
    getTitlePulse = function() return titlePulse end,
    getWaterPhase = function() return waterPhase end,
    isNight = isNight,
    starAlpha = starAlpha,
    timeLabel = timeLabel,
    getTimeTint = function() return timeTint[timeIndex] or timeTint[3] end,
    uiFont = uiFont,
    drawPlayerAt = drawPlayerAt,
    drawWorldFx = drawWorldFx,
    drawRitualOverlay = drawRitualOverlay,
    drawToast = drawToast,
    buildCampGroundCanvas = function() CampTiles.buildCampGroundCanvas() end,
    getCupStyle = function() return 1 end,
    resetTent = function()
      tentOpen = false
    end,
    onBuildStart = function() CampWorld.resetCritters() end,
  }
  Assets.bindHost({
    isConsole = isConsole,
    playtestWanted = playtestWanted,
    appendLoadLog = appendLoadLog,
    AP = AP,
  })
  CampMap.bindHost(campHost)
  CampPreload.bindHost(campHost)
  CampWorld.bindHost(campHost)
  CampTiles.bindHost(campHost)
  CampRender.bindHost(campHost)
  Audio.bindHost({
    isConsole = isConsole,
    assetPath = Assets.path,
    appendLoadLog = appendLoadLog,
    getScene = function() return scene end,
    playerNearWater = function(r)
      r = r or 2
      for dy = -r, r do
        for dx = -r, r do
          local t = CampMap.tileAt(player.x + dx, player.y + dy)
          if t == 2 or t == 8 then return true end
        end
      end
      return false
    end,
    playerNearBird = function(r)
      r = r or 3
      for _, b in ipairs(CampWorld.getCritters().birds or {}) do
        local bx = (b.x or 0) / TILE
        local by = (b.y or 0) / TILE
        if math.abs(bx - player.x) + math.abs(by - player.y) <= r then return true end
      end
      return false
    end,
    isNight = isNight,
  })
end

function loadAssets() Assets.loadBoot() end
function detectAssetRoot() Assets.detectRoot() end
function loadImage(path) return Assets.load(path) end
function drawFitted(...) return Assets.drawFitted(...) end
function ensureStory(k) return Assets.ensureStory(k) end
function ensureCast(i) return Assets.ensureCast(i) end
function ensureWalk(i) return Assets.ensureWalk(i) end
function ensureRitual() return Assets.ensureRitual() end
function tileAt(tx, ty) return CampMap.tileAt(tx, ty) end
function drawPlayTop() CampRender.drawPlayTop() end

function love.load()
  -- 真机第一句先落盘，后面崩了也知道进过 love.load
  if isConsole or playtestWanted() then
    pcall(function() love.filesystem.write("load_report.txt", "boot build=" .. buildId .. "\n") end)
  end
  pcall(love.graphics.setDefaultFilter, "nearest", "nearest")
  pcall(detectAssetRoot)
  Assets.writeProbe()
  CampMap.build()
  CampMap.indexRenderData()
  loadAssets()
  if not isConsole then
    Audio.loadBgm()
    Audio.loadSfx()
  end
  uiFont = Assets.newFont(14)
  titleFont = Assets.newFont(26) or uiFont
  if uiFont then love.graphics.setFont(uiFont) end
  CampWorld.seedStars()
  if not isConsole then
    desktopBottom = love.graphics.newCanvas(BOT_W, BOT_H)
    love.window.setMode(TOP_W, TOP_H + BOT_H)
  end
  if isConsole then
    Audio.ensureConsoleLoaded()
    syncSceneBgm()
  else
    syncSceneBgm()
  end
  say("触摸或方向键选择 · A 确认", 4)
  if playtestWanted() and not isConsole then
    playtest.on = true
    playtestLog("begin " .. love.filesystem.getSaveDirectory())
  end
end

local function playtestShot(name)
  love.filesystem.createDirectory(playtest.outDir)
  love.graphics.captureScreenshot(playtest.outDir .. "/" .. name .. ".png")
  playtestLog("shot " .. name)
end

playtestTick = function(dt)
  if not playtest.on or playtest.done then return end
  playtest.t = playtest.t + dt
  local s, t = playtest.step, playtest.t

  local function nextStep()
    playtest.step = playtest.step + 1
    playtest.t = 0
  end

  if s == 0 and t > 0.35 then playtestShot("01_title"); nextStep()
  elseif s == 1 and t > 0.25 then menuIndex = 1; confirmMenu(); playtestLog("-> " .. scene); nextStep()
  elseif s == 2 and t > 0.35 then playtestShot("02_prologue"); nextStep()
  elseif s == 3 and t > 0.2 then advancePrologue(); nextStep()
  elseif s == 4 and t > 0.2 then advancePrologue(); nextStep()
  elseif s == 5 and t > 0.2 then advancePrologue(); nextStep()
  elseif s == 6 and t > 0.2 then advancePrologue(); playtestLog("-> " .. scene); nextStep()
  elseif s == 7 and t > 0.35 then playtestShot("03_cast"); cast.i = 1; nextStep()
  elseif s == 8 and t > 0.25 then confirmCast(); playtestLog("-> " .. scene); nextStep()
  elseif s == 9 and t > 0.35 then playtestShot("04_depart"); nextStep()
  elseif s == 10 and t > 0.2 then advanceDepart(); nextStep()
  elseif s == 11 and t > 0.2 then advanceDepart(); playtestLog("-> " .. scene); nextStep()
  elseif s == 12 and t > 1.15 then
    CampWorld.spawnBird(); CampWorld.spawnBird(); CampWorld.spawnBug(); CampWorld.spawnBug()
    playtestShot("05_camp")
    local critters = CampWorld.getCritters()
    playtestLog("wildlife birds=" .. #critters.birds .. " bugs=" .. #critters.bugs)
    nextStep()
  elseif s == 12 then
    -- let birds leave the branch before the camp shot
    if t > 0.35 and #CampWorld.getCritters().birds == 0 then CampWorld.spawnBird() end
    if t > 0.55 and #CampWorld.getCritters().bugs == 0 then CampWorld.spawnBug() end
  elseif s == 13 then
    -- four directions
    if t >= 0.12 then
      local dirs = { {1,0}, {0,1}, {-1,0}, {0,-1} }
      local d = dirs[(playtest._walk % 4) + 1]
      tryMove(d[1], d[2])
      playtest.t = 0
      playtest._walk = playtest._walk + 1
      if playtest._walk >= 4 then playtest._walk = 0; playtestLog("walk_dirs_ok"); nextStep() end
    end
  elseif s == 14 and t > 0.25 then
    player.x, player.y = 11, 9
    selected = 1
    tryUseGear()
    playtestLog("tentOpen=" .. tostring(tentOpen))
    nextStep()
  elseif s == 15 and t > 0.35 then playtestShot("05b_tent_open"); nextStep()
  elseif s == 16 and t > 0.2 then
    selected = 2
    tryUseGear() -- start drip
    playtestLog("ritual=" .. tostring(ritual and ritual.kind))
    nextStep()
  elseif s == 17 and t > 0.35 then playtestShot("05c_drip_ritual"); nextStep()
  elseif s == 18 and t > 0.15 then tryUseGear(); nextStep() -- step2
  elseif s == 19 and t > 0.15 then tryUseGear(); nextStep() -- step3
  elseif s == 20 and t > 0.15 then
    tryUseGear()
    tryUseGear()
    playtestLog("dripped=" .. tostring(drippedOnce) .. " coffeeCups=" .. tostring(coffeeCups))
    nextStep()
  elseif s == 21 and t > 0.2 then
    selected = 6 -- fan
    tryUseGear()
    playtestLog("fan=" .. tostring(ritual and ritual.kind))
    nextStep()
  elseif s == 22 and t > 0.5 then playtestShot("05d_fan"); tryUseGear(); nextStep() -- skip fan
  elseif s == 23 and t > 0.2 then
    -- walk toward creek and fish
    player.x, player.y = CampMap.creekCenterX(7), 7
    selected = 4 -- rod
    tryUseGear()
    playtestLog("rod=" .. tostring(ritual and ritual.kind))
    nextStep()
  elseif s == 24 and t > 0.5 then playtestShot("05e_fish"); tryUseGear(); nextStep()
  elseif s == 25 and t > 0.25 then
    timeIndex = 5; selected = 3
    local firepit = CampMap.getFirepit()
    player.x, player.y = firepit.x - 1, firepit.y
    tryUseGear()
    playtestLog("lantern=" .. tostring(lanternOn))
    CampWorld.spawnMeteor(); CampWorld.spawnLeaf(); CampWorld.spawnLeaf(); CampWorld.spawnBug(); CampWorld.spawnBug()
    for _, u in ipairs(CampWorld.getCritters().bugs) do u.kind = "firefly" end
    nextStep()
  elseif s == 26 and t > 0.55 then
    playtestShot("06_night_lamp")
    local nightFX = CampWorld.getNightFX()
    playtestLog("night stars=" .. #nightFX.stars .. " meteors=" .. #nightFX.meteors)
    nextStep()
  elseif s == 27 and t > 0.25 then goHomecoming(); playtestLog("-> " .. scene); nextStep()
  elseif s == 28 and t > 0.35 then playtestShot("07_home"); nextStep()
  elseif s == 29 and t > 0.25 then advanceHome(); playtestLog("-> " .. scene); nextStep()
  elseif s == 30 and t > 0.35 then playtestShot("08_back_title"); nextStep()
  elseif s == 31 and t > 0.2 then
    menuIndex = 3
    confirmMenu()
    playtestLog("-> " .. scene)
    nextStep()
  elseif s == 32 and t > 0.35 then playtestShot("09_codex"); nextStep()
  elseif s == 33 and t > 0.15 then moveCodex(1); nextStep()
  elseif s == 34 and t > 0.25 then
    playtestLog("codex=" .. tostring(gear[codex.i] and gear[codex.i].id))
    nextStep()
  elseif s == 35 and t > 0.2 then
    goTitle()
    menuIndex = 4
    confirmMenu()
    playtestLog("-> " .. scene)
    nextStep()
  elseif s == 36 and t > 0.35 then
    playtestShot("10_about")
    love.filesystem.write(playtest.outDir .. "/result.txt", table.concat(playtest.log, "\n") .. "\nPASS\n")
    playtest.done = true
    playtestLog("PASS")
    love.event.quit()
  end
end

function love.update(dt)
  perfWindow = perfWindow + dt
  perfFrames = perfFrames + 1
  if dt > 0.05 then perfSlowFrames = perfSlowFrames + 1 end
  if dt > perfMaxDt then perfMaxDt = dt end
  if perfWindow >= 5 then
    appendLoadLog(string.format(
      "perf scene=%s frames=%d slow=%d maxDtMs=%.1f mode=%s",
      scene, perfFrames, perfSlowFrames, perfMaxDt * 1000, perfMode .. "/" .. Audio.consoleMode()
    ))
    perfWindow, perfFrames, perfSlowFrames, perfMaxDt = 0, 0, 0, 0
  end
  Audio.ensureConsoleLoaded()
  titlePulse = titlePulse + dt
  waterPhase = waterPhase + dt * 2.2
  if toastT > 0 then toastT = toastT - dt end
  if brewTimer > 0 then
    brewTimer = brewTimer - dt
    if brewTimer <= 0 and not ritual then brewActive = false end
  end
  if potSimmer > 0 then potSimmer = potSimmer - dt end
  if scene == "play" then
    if player.idleT > 0 then
      player.idleT = player.idleT - dt
      if player.idleT <= 0 then player.walkFrame = 0 end
    end
    if not staticPlayFx then
      CampWorld.updateFish(dt)
      CampWorld.updateCritters(dt)
      CampWorld.updateNight(dt)
    end
    Audio.tick(dt, titlePulse)
    updateTimedRitual(dt)
  end
  playtestTick(dt)
end

function love.keypressed(key)
  if key == "escape" then
    if ritual then ritual = nil; brewActive = false; say("取消了手冲", 2); return end
    if scene == "title" then love.event.quit() else goTitle() end
    return
  end

  if scene == "title" then
    if key == "up" or key == "w" then moveMenu(-1)
    elseif key == "down" or key == "s" then moveMenu(1)
    elseif key == "return" or key == "space" or key == "a" then confirmMenu()
    end
  elseif scene == "codex" then
    if key == "left" then moveCodex(-1)
    elseif key == "right" then moveCodex(1)
    elseif key == "up" or key == "w" then moveCodex(-3)
    elseif key == "down" or key == "s" then moveCodex(3)
    elseif key == "return" or key == "space" or key == "a" or key == "b" then goTitle()
    end
  elseif scene == "about" then
    if key == "return" or key == "space" or key == "a" or key == "b" then goTitle() end
  elseif scene == "prologue" or scene == "depart" or scene == "homecoming" then
    if key == "return" or key == "space" or key == "a" then advancePrimary() end
  elseif scene == "cast" then
    if key == "left" then setCast(cast.i == 1 and 9 or cast.i - 1)
    elseif key == "right" then setCast(cast.i == 9 and 1 or cast.i + 1)
    elseif key == "up" then setCast(cast.i <= 3 and cast.i + 6 or cast.i - 3)
    elseif key == "down" then setCast(cast.i >= 7 and cast.i - 6 or cast.i + 3)
    elseif key == "return" or key == "space" or key == "a" then confirmCast()
    end
  elseif scene == "play" then
    if cupPick then
      if key == "left" or key == "a" then nudgeCupStyle(-1, 0)
      elseif key == "right" or key == "d" then nudgeCupStyle(1, 0)
      elseif key == "up" or key == "w" then nudgeCupStyle(0, -1)
      elseif key == "down" or key == "s" then nudgeCupStyle(0, 1)
      elseif key == "return" or key == "space" or key == "z" then drinkCoffee()
      elseif key == "b" then cupPick = false
      end
      return
    end
    if key == "up" or key == "w" then tryMove(0, -1)
    elseif key == "down" or key == "s" then tryMove(0, 1)
    elseif key == "left" then tryMove(-1, 0)
    elseif key == "right" or key == "d" then tryMove(1, 0)
    elseif key == "a" then tryMove(-1, 0) -- desktop WASD; 3DS uses gamepad
    elseif key == "return" or key == "space" or key == "z" then tryUseGear()
    elseif key == "x" then advanceTime()
    elseif key == "h" and canGoHome then goHomecoming()
    end
  end
end

function love.gamepadpressed(_, button)
  if button == "start" then love.event.quit(); return end
  if button == "back" or button == "b" then
    if ritual then ritual = nil; brewActive = false; say("取消了手冲", 2); return end
    if scene ~= "title" then goTitle() end
    return
  end
  if scene == "title" then
    if button == "dpup" then moveMenu(-1)
    elseif button == "dpdown" then moveMenu(1)
    elseif button == "a" then confirmMenu()
    end
  elseif scene == "codex" then
    if button == "dpleft" then moveCodex(-1)
    elseif button == "dpright" then moveCodex(1)
    elseif button == "dpup" then moveCodex(-3)
    elseif button == "dpdown" then moveCodex(3)
    elseif button == "a" then goTitle()
    end
  elseif scene == "about" then
    if button == "a" then goTitle() end
  elseif scene == "prologue" or scene == "depart" or scene == "homecoming" then
    if button == "a" then advancePrimary() end
  elseif scene == "cast" then
    if button == "dpleft" then setCast(cast.i == 1 and 9 or cast.i - 1)
    elseif button == "dpright" then setCast(cast.i == 9 and 1 or cast.i + 1)
    elseif button == "dpup" then setCast(cast.i <= 3 and cast.i + 6 or cast.i - 3)
    elseif button == "dpdown" then setCast(cast.i >= 7 and cast.i - 6 or cast.i + 3)
    elseif button == "a" then confirmCast()
    end
  elseif scene == "play" then
    if cupPick then
      if button == "dpleft" then nudgeCupStyle(-1, 0)
      elseif button == "dpright" then nudgeCupStyle(1, 0)
      elseif button == "dpup" then nudgeCupStyle(0, -1)
      elseif button == "dpdown" then nudgeCupStyle(0, 1)
      elseif button == "a" then drinkCoffee()
      elseif button == "b" then cupPick = false
      end
      return
    end
    if button == "dpup" then tryMove(0, -1)
    elseif button == "dpdown" then tryMove(0, 1)
    elseif button == "dpleft" then tryMove(-1, 0)
    elseif button == "dpright" then tryMove(1, 0)
    elseif button == "a" then tryUseGear()
    elseif button == "x" then advanceTime()
    elseif button == "y" and canGoHome then goHomecoming()
    end
  end
end

function love.touchpressed(_, x, y)
  if isConsole then onBottomTouch(x, y) end
end

function love.mousepressed(x, y, button)
  if button ~= 1 or isConsole then return end
  if y >= TOP_H and x >= 40 and x < 40 + BOT_W then
    onBottomTouch(x - 40, y - TOP_H)
  end
end

-- —— draw helpers ——

function drawToast()
  if toastT <= 0 or toast == "" then return end
  if uiFont then love.graphics.setFont(uiFont) end
  local toastW = uiFont and uiFont:getWidth(toast) or 120
  love.graphics.setColor(0.08, 0.08, 0.08, 0.82)
  love.graphics.rectangle("fill", 4, TOP_H - 22, math.min(TOP_W - 8, toastW + 12), 18)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(toast, 8, TOP_H - 20)
end

local function drawStoryTop(imgKey, line)
  love.graphics.setColor(1, 1, 1, 1)
  local img = ensureStory(imgKey)
  if img then
    drawFitted(img, 0, 0, TOP_W, TOP_H)
  else
    love.graphics.setColor(0.2, 0.25, 0.2)
    love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
    if isConsole and uiFont then
      love.graphics.setColor(1, 0.85, 0.4)
      love.graphics.setFont(uiFont)
      love.graphics.print("无图 " .. tostring(imgKey) .. " " .. assetRoot, 8, 8)
    end
  end
  if uiFont then love.graphics.setFont(uiFont) end
  local hint = "A 继续"
  local hw = uiFont and uiFont:getWidth(hint) or 40
  local boxH, boxY = 22, TOP_H - 28
  love.graphics.setColor(0.05, 0.05, 0.05, 0.78)
  love.graphics.rectangle("fill", 8, boxY, TOP_W - 16, boxH)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print(line, 16, boxY + 4)
  love.graphics.setColor(0.82, 0.76, 0.58)
  love.graphics.print(hint, TOP_W - hw - 18, boxY + 4)
end

local function drawStoryBottom(hint)
  love.graphics.setColor(0.18, 0.14, 0.10)
  love.graphics.rectangle("fill", 0, 0, BOT_W, BOT_H)
  love.graphics.setColor(0.92, 0.86, 0.72)
  love.graphics.rectangle("fill", 16, 80, BOT_W - 32, 80)
  if uiFont then love.graphics.setFont(uiFont) end
  love.graphics.setColor(0.2, 0.14, 0.08)
  love.graphics.print(hint or "按 A / 点这里继续", 40, 110)
end

local function drawTitleTop()
  love.graphics.setColor(1, 1, 1, 1)
  if Assets.get().titleTop then drawFitted(Assets.get().titleTop, 0, 0, TOP_W, TOP_H)
  else
    love.graphics.setColor(0.35, 0.55, 0.4)
    love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
    if isConsole and uiFont then
      love.graphics.setColor(1, 0.85, 0.4)
      love.graphics.setFont(uiFont)
      love.graphics.print("无标题图 root=" .. assetRoot .. " fail=" .. loadFailCount, 8, 8)
    end
  end
  local a = 0.03 + 0.02 * math.sin(titlePulse * 1.1)
  love.graphics.setColor(1, 0.92, 0.72, a)
  love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
  local name, sub = "露营之旅", "夏天 · 林间"
  if titleFont then love.graphics.setFont(titleFont) end
  local nw = titleFont and titleFont:getWidth(name) or 120
  local nh = titleFont and titleFont:getHeight() or 28
  local nx = math.floor((TOP_W - nw) / 2)
  local boxW, boxH = nw + 36, nh + 40
  local bx, by = nx - 18, 58
  love.graphics.setColor(0.07, 0.05, 0.03, 0.48)
  love.graphics.rectangle("fill", bx, by, boxW, boxH)
  love.graphics.setColor(0.92, 0.82, 0.58, 0.55)
  love.graphics.rectangle("line", bx + 2, by + 2, boxW - 4, boxH - 4)
  love.graphics.setColor(1, 0.96, 0.86)
  love.graphics.print(name, nx, 68)
  if uiFont then love.graphics.setFont(uiFont) end
  local sw = uiFont and uiFont:getWidth(sub) or 60
  love.graphics.setColor(0.95, 0.88, 0.7)
  love.graphics.print(sub, math.floor((TOP_W - sw) / 2), 68 + nh + 4)
  drawToast()
end

local function drawTitleBottom()
  love.graphics.setColor(1, 1, 1, 1)
  if Assets.get().titleBot then drawFitted(Assets.get().titleBot, 0, 0, BOT_W, BOT_H)
  else love.graphics.setColor(0.85, 0.75, 0.55); love.graphics.rectangle("fill", 0, 0, BOT_W, BOT_H) end
  if uiFont then love.graphics.setFont(uiFont) end
  love.graphics.setColor(1, 0.95, 0.85)
  love.graphics.print("周末逃离城市", 22, 30)
  local x0, w = 40, BOT_W - 80
  for i, item in ipairs(menuItems) do
    local y = 64 + (i - 1) * 38
    local on = (i == menuIndex)
    if on then love.graphics.setColor(0.98, 0.88, 0.5)
    elseif item.enabled then love.graphics.setColor(0.96, 0.92, 0.82)
    else love.graphics.setColor(0.75, 0.7, 0.62) end
    love.graphics.rectangle("fill", x0, y, w, 32)
    love.graphics.setColor(0.35, 0.22, 0.12)
    love.graphics.rectangle("line", x0, y, w, 32)
    local label = item.label
    if not item.enabled then label = label .. "（暂无）" end
    if on then love.graphics.setColor(0.55, 0.35, 0.12); love.graphics.print(">", x0 + 10, y + 8) end
    love.graphics.setColor(item.enabled and 0.18 or 0.45, 0.12, 0.08)
    local lw = uiFont and uiFont:getWidth(label) or 80
    love.graphics.print(label, x0 + math.floor((w - lw) / 2), y + 8)
  end
end

local function drawCodexTop()
  love.graphics.setColor(1, 1, 1, 1)
  if Assets.get().titleTop then drawFitted(Assets.get().titleTop, 0, 0, TOP_W, TOP_H)
  else love.graphics.setColor(0.28, 0.38, 0.26); love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H) end
  love.graphics.setColor(0.06, 0.05, 0.03, 0.42)
  love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
  local g = gear[codex.i]
  if uiFont then love.graphics.setFont(uiFont) end
  love.graphics.setColor(0.08, 0.06, 0.04, 0.82)
  love.graphics.rectangle("fill", 28, 16, TOP_W - 56, 188)
  love.graphics.setColor(0.92, 0.82, 0.55, 0.55)
  love.graphics.rectangle("line", 32, 20, TOP_W - 64, 180)
  love.graphics.setColor(1, 0.96, 0.86)
  love.graphics.print("装备图鉴", 44, 30)
  if g then
    love.graphics.setColor(0.78, 0.68, 0.42)
    love.graphics.print(g.tag or "", 330, 30)
    if g.icon then
      local iw, ih = g.icon:getWidth(), g.icon:getHeight()
      local s = math.max(2, math.min(3, math.floor(64 / math.max(iw, ih, 1))))
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(g.icon, math.floor((TOP_W - iw * s) / 2), 54, 0, s, s)
    end
    love.graphics.setColor(1, 0.95, 0.82)
    local nw = uiFont and uiFont:getWidth(g.name) or 40
    love.graphics.print(g.name, math.floor((TOP_W - nw) / 2), 128)
    love.graphics.setColor(0.92, 0.86, 0.72)
    for i, line in ipairs(g.lines or {}) do
      local lw = uiFont and uiFont:getWidth(line) or 80
      love.graphics.print(line, math.floor((TOP_W - lw) / 2), 150 + (i - 1) * 18)
    end
  end
  love.graphics.setColor(0.08, 0.08, 0.08, 0.75)
  local hint = "方向键翻页 · B 返回"
  local hw = uiFont and uiFont:getWidth(hint) or 140
  love.graphics.rectangle("fill", 8, TOP_H - 22, hw + 16, 18)
  love.graphics.setColor(0.9, 0.86, 0.7)
  love.graphics.print(hint, 16, TOP_H - 20)
end

local function drawCodexBottom()
  if Assets.get().packBg then
    love.graphics.setColor(1, 1, 1, 1)
    drawFitted(Assets.get().packBg, 0, 0, BOT_W, BOT_H)
  else
    love.graphics.setColor(0.93, 0.88, 0.76)
    love.graphics.rectangle("fill", 0, 0, BOT_W, BOT_H)
  end
  if uiFont then love.graphics.setFont(uiFont) end
  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print("点选装备 · 看用法", 14, 12)
  for i, g in ipairs(gear) do
    local on = (i == codex.i)
    love.graphics.setColor(on and 0.98 or 0.98, on and 0.9 or 0.95, on and 0.55 or 0.88)
    love.graphics.rectangle("fill", g.x, g.y, 80, 62)
    love.graphics.setColor(0.3, 0.2, 0.12)
    love.graphics.rectangle("line", g.x, g.y, 80, 62)
    love.graphics.setColor(1, 1, 1, 1)
    if g.icon then
      local iw, ih = g.icon:getWidth(), g.icon:getHeight()
      local s = math.min(36 / iw, 28 / ih)
      love.graphics.draw(g.icon, g.x + (80 - iw * s) / 2, g.y + 4, 0, s, s)
    end
    love.graphics.setColor(0.22, 0.16, 0.1)
    local nw = uiFont and uiFont:getWidth(g.name) or 28
    love.graphics.print(g.name, g.x + (80 - nw) / 2, g.y + 42)
  end
  love.graphics.setColor(0.45, 0.4, 0.3)
  love.graphics.rectangle("fill", 100, 204, 120, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("B 返回标题", 122, 207)
end

local function drawAboutTop()
  love.graphics.setColor(1, 1, 1, 1)
  if Assets.get().titleTop then drawFitted(Assets.get().titleTop, 0, 0, TOP_W, TOP_H)
  else love.graphics.setColor(0.28, 0.38, 0.26); love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H) end
  love.graphics.setColor(0.06, 0.05, 0.03, 0.42)
  love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
  if titleFont then love.graphics.setFont(titleFont) end
  love.graphics.setColor(0.08, 0.06, 0.04, 0.82)
  love.graphics.rectangle("fill", 36, 22, TOP_W - 72, 176)
  love.graphics.setColor(0.92, 0.82, 0.55, 0.55)
  love.graphics.rectangle("line", 40, 26, TOP_W - 80, 168)
  local name = "露营之旅"
  local nw = titleFont and titleFont:getWidth(name) or 120
  love.graphics.setColor(1, 0.96, 0.86)
  love.graphics.print(name, math.floor((TOP_W - nw) / 2), 40)
  if uiFont then love.graphics.setFont(uiFont) end
  local lines = {
    "夏天 · 林间",
    "爱好向小品 · 不上架",
    "",
    "一个上班族的周末：",
    "带上手冲和帐篷，去有小河的林子。",
    "搭帐、冲一杯、点灯过夜，第二天回家。"
  }
  local y = 78
  for _, line in ipairs(lines) do
    if line ~= "" then
      local lw = uiFont and uiFont:getWidth(line) or 80
      love.graphics.setColor(0.93, 0.88, 0.74)
      love.graphics.print(line, math.floor((TOP_W - lw) / 2), y)
    end
    y = y + 16
  end
  local hint = "A / B 返回标题"
  local hw = uiFont and uiFont:getWidth(hint) or 100
  love.graphics.setColor(0.08, 0.08, 0.08, 0.75)
  love.graphics.rectangle("fill", 8, TOP_H - 22, hw + 16, 18)
  love.graphics.setColor(0.9, 0.86, 0.7)
  love.graphics.print(hint, 16, TOP_H - 20)
end

local function drawAboutBottom()
  if Assets.get().packBg then
    love.graphics.setColor(1, 1, 1, 1)
    drawFitted(Assets.get().packBg, 0, 0, BOT_W, BOT_H)
  else
    love.graphics.setColor(0.93, 0.88, 0.76)
    love.graphics.rectangle("fill", 0, 0, BOT_W, BOT_H)
  end
  if uiFont then love.graphics.setFont(uiFont) end
  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print("关于这趟周末", 14, 12)
  local notes = {
    "平台  Nintendo 3DS 自制",
    "节奏  不战斗 · 慢慢走",
    "仪式  帐篷 / 手冲 / 点灯",
    "循环  下周还可以再来"
  }
  for i, line in ipairs(notes) do
    local y = 52 + (i - 1) * 34
    love.graphics.setColor(0.98, 0.94, 0.84)
    love.graphics.rectangle("fill", 28, y, BOT_W - 56, 28)
    love.graphics.setColor(0.35, 0.22, 0.12)
    love.graphics.rectangle("line", 28, y, BOT_W - 56, 28)
    love.graphics.setColor(0.22, 0.16, 0.1)
    love.graphics.print(line, 40, y + 6)
  end
  love.graphics.setColor(0.45, 0.4, 0.3)
  love.graphics.rectangle("fill", 100, 204, 120, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("B 返回标题", 122, 207)
end

local function drawCastTop()
  love.graphics.setColor(0.15, 0.18, 0.14)
  love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
  local img = ensureCast(cast.i)
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    -- integer nearest scale so pixels stay chunky, not soft
    local s = math.max(1, math.floor(160 / math.max(ih, 1)))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor((TOP_W - iw * s) / 2), 28, 0, s, s)
  end
  if uiFont then love.graphics.setFont(uiFont) end
  local name = cast.names[cast.i] or ("角色" .. cast.i)
  local nw = uiFont and uiFont:getWidth(name) or 60
  love.graphics.setColor(0.08, 0.08, 0.08, 0.8)
  love.graphics.rectangle("fill", (TOP_W - nw) / 2 - 8, 200, nw + 16, 22)
  love.graphics.setColor(1, 0.95, 0.85)
  love.graphics.print(name, (TOP_W - nw) / 2, 203)
  drawToast()
end

local function drawCastBottom()
  love.graphics.setColor(0.93, 0.88, 0.76)
  love.graphics.rectangle("fill", 0, 0, BOT_W, BOT_H)
  if uiFont then love.graphics.setFont(uiFont) end
  love.graphics.setColor(0.25, 0.18, 0.1)
  love.graphics.print("选角色 · 这次谁去", 16, 16)
  for i = 1, 9 do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local x, y = 24 + col * 96, 48 + row * 56
    local on = (i == cast.i)
    love.graphics.setColor(on and 0.98 or 1, on and 0.9 or 0.96, on and 0.55 or 0.9)
    love.graphics.rectangle("fill", x, y, 88, 48)
    love.graphics.setColor(0.3, 0.2, 0.12)
    love.graphics.rectangle("line", x, y, 88, 48)
    local spr = ensureCast(i)
    if spr then
      local iw, ih = spr:getWidth(), spr:getHeight()
      local s = math.min(40 / iw, 40 / ih)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(spr, x + 4 + (40 - iw * s) / 2, y + (48 - ih * s) / 2, 0, s, s)
    end
    love.graphics.setColor(0.2, 0.15, 0.1)
    love.graphics.print(tostring(i), x + 58, y + 16)
  end
  love.graphics.setColor(0.35, 0.55, 0.35)
  love.graphics.rectangle("fill", 100, 210, 120, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("A 确认出发", 118, 213)
end

function drawPlayerAt(px, py)
  drawDropShadow(px, py, "sm")
  love.graphics.setColor(1, 1, 1, 1)
  local walk = ensureWalk(player.castId)
  local s = 28 / 40
  if walk and walk.sheet and walk.quads then
    local row = player.facing or 0
    local col = player.walkFrame or 0
    local q = walk.quads[row] and walk.quads[row][col]
    if q then
      love.graphics.draw(walk.sheet, q, px + (TILE - 40 * s) / 2, py + TILE - 40 * s, 0, s, s)
      return
    end
  end
  local img = Assets.get().player
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local sc = 28 / ih
    love.graphics.draw(img, px + (TILE - iw * sc) / 2, py + TILE - ih * sc, 0, sc, sc)
  end
end

function drawWorldFx()
  if brewActive and Assets.get().brewKit then
    local bx, by = brewX * TILE, brewY * TILE
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Assets.get().brewKit, bx + 2, by + TILE - Assets.get().brewKit:getHeight())
    if Assets.get().steam then
      local fi = math.floor(waterPhase) % 3
      local st = Assets.get().steam[fi + 1]
      if st then love.graphics.draw(st, bx + 4, by - 6) end
    end
  end
  if potSimmer > 0 then
    local firepit = CampMap.getFirepit()
    love.graphics.setColor(1, 1, 1, 0.5 + 0.3 * math.sin(waterPhase * 4))
    love.graphics.circle("fill", firepit.x * TILE + 8, firepit.y * TILE, 4)
  end
end

function drawRitualOverlay()
  if not ritual then return end
  if ritual.kind == "drip" then
    love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
    local img = Assets.get().ritual and Assets.get().ritual.drip and Assets.get().ritual.drip[ritual.step]
    if img then
      love.graphics.setColor(1, 1, 1, 1)
      local srcW, srcH = 120, 76
      local s = 2
      drawFitted(img, math.floor((TOP_W - srcW * s) / 2), 34, srcW, srcH, s, s)
    end
    if uiFont then love.graphics.setFont(uiFont) end
    local labels = { "手冲 · 闷蒸", "手冲 · 绕圈注水", "手冲 · 分享入杯" }
    local title = labels[ritual.step] or "手冲"
    love.graphics.setColor(0.08, 0.08, 0.08, 0.85)
    love.graphics.rectangle("fill", 12, 12, (uiFont and uiFont:getWidth(title) or 80) + 16, 20)
    love.graphics.setColor(1, 0.95, 0.85)
    love.graphics.print(title, 20, 14)
    return
  end

  if ritual.kind == "rod" or ritual.kind == "fan" then
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
    local frames = ritual.kind == "rod" and Assets.get().ritual.fishAnim or Assets.get().ritual.fanAnim
    local img = frames and frames[ritual.step]
    if img then
      love.graphics.setColor(1, 1, 1, 1)
      local s = 3
      local iw, ih = img:getWidth(), img:getHeight()
      love.graphics.draw(img, (TOP_W - iw * s) / 2, (TOP_H - ih * s) / 2 - 10, 0, s, s)
    end
    if uiFont then love.graphics.setFont(uiFont) end
    local title = ritual.kind == "rod" and ("钓鱼 · " .. ritual.step .. "/4") or ("扇子 · " .. ritual.step .. "/4")
    love.graphics.setColor(0.08, 0.08, 0.08, 0.85)
    love.graphics.rectangle("fill", 12, 12, (uiFont and uiFont:getWidth(title) or 80) + 16, 20)
    love.graphics.setColor(1, 0.95, 0.85)
    love.graphics.print(title, 20, 14)
  end
end

local function drawPlayBottom()
  if uiFont then love.graphics.setFont(uiFont) end
  if Assets.get().packBg then
    love.graphics.setColor(1, 1, 1, 1)
    drawFitted(Assets.get().packBg, 0, 0, BOT_W, BOT_H)
  else
    love.graphics.setColor(0.93, 0.88, 0.76)
    love.graphics.rectangle("fill", 0, 0, BOT_W, BOT_H)
  end

  if ritual and ritual.kind == "drip" then
    love.graphics.setColor(0.32, 0.22, 0.14)
    love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
    love.graphics.setColor(1, 0.96, 0.88)
    love.graphics.print("手冲仪式 · 第" .. ritual.step .. "/3 步", 14, 12)
    love.graphics.setColor(0.25, 0.18, 0.1)
    love.graphics.print("闻得到咖啡香了。慢慢来。", 24, 80)
    love.graphics.setColor(0.35, 0.55, 0.35)
    love.graphics.rectangle("fill", 100, 210, 120, 22)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("A 下一步", 128, 213)
    love.graphics.setColor(0.55, 0.4, 0.35)
    love.graphics.rectangle("fill", 230, 210, 70, 22)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("取消", 248, 213)
    return
  end

  if ritual and (ritual.kind == "rod" or ritual.kind == "fan") then
    love.graphics.setColor(0.32, 0.22, 0.14)
    love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
    love.graphics.setColor(1, 0.96, 0.88)
    local head = ritual.kind == "rod" and "钓鱼短片" or "扇风短片"
    love.graphics.print(head .. " · " .. ritual.step .. "/4", 14, 12)
    love.graphics.setColor(0.25, 0.18, 0.1)
    love.graphics.print("自动播放 · A 可跳过", 40, 100)
    love.graphics.setColor(0.35, 0.55, 0.35)
    love.graphics.rectangle("fill", 100, 210, 120, 22)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("A 跳过", 132, 213)
    return
  end

  if cupPick then
    love.graphics.setColor(0.32, 0.22, 0.14)
    love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
    love.graphics.setColor(1, 0.96, 0.88)
    love.graphics.print("选杯子 · 方向键 · A 喝", 14, 12)
    local a = Assets.get()
    for i, st in ipairs(AP.CUP_STYLES) do
      local x, y, w, h = cupSlotRect(i)
      local on = (i == cupStyle)
      love.graphics.setColor(on and 0.98 or 0.95, on and 0.9 or 0.92, on and 0.55 or 0.84)
      love.graphics.rectangle("fill", x, y, w, h)
      love.graphics.setColor(0.3, 0.2, 0.12)
      love.graphics.rectangle("line", x, y, w, h)
      local icon = a.cupIcons and a.cupIcons[i]
      if icon then
        love.graphics.setColor(1, 1, 1, 1)
        local iw, ih = icon:getWidth(), icon:getHeight()
        local s = math.min((w - 8) / iw, 28 / ih)
        love.graphics.draw(icon, x + (w - iw * s) / 2, y + 4, 0, s, s)
      end
      love.graphics.setColor(0.2, 0.14, 0.08)
      local nw = uiFont and uiFont:getWidth(st.name) or 40
      love.graphics.print(st.name, x + (w - nw) / 2, y + h - 14)
    end
    love.graphics.setColor(0.35, 0.55, 0.35)
    love.graphics.rectangle("fill", 100, 210, 120, 22)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("A 喝一口", 128, 213)
    return
  end

  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print("背包 · 夏天露营", 14, 12)
  if drippedOnce then
    local hint = "咖啡已冲好 · 选杯子按 A 喝"
    if selected == 5 or selected == 2 then hint = "A 喝咖啡 · 已喝" .. coffeeCups .. "口" end
    love.graphics.setColor(0.98, 0.94, 0.76)
    love.graphics.rectangle("fill", 118, 10, 190, 20)
    love.graphics.setColor(0.26, 0.18, 0.10)
    love.graphics.print(hint, 126, 13)
  end

  for i, g in ipairs(gear) do
    local on = (i == selected)
    love.graphics.setColor(on and 0.98 or 0.98, on and 0.9 or 0.95, on and 0.55 or 0.88)
    love.graphics.rectangle("fill", g.x, g.y, 80, 62)
    love.graphics.setColor(0.3, 0.2, 0.12)
    love.graphics.rectangle("line", g.x, g.y, 80, 62)
    love.graphics.setColor(1, 1, 1, 1)
    if g.icon then
      local iw, ih = g.icon:getWidth(), g.icon:getHeight()
      local s = math.min(36 / iw, 28 / ih)
      love.graphics.draw(g.icon, g.x + (80 - iw * s) / 2, g.y + 4, 0, s, s)
    end
    love.graphics.setColor(0.22, 0.16, 0.1)
    local nw = uiFont and uiFont:getWidth(g.name) or 28
    love.graphics.print(g.name, g.x + (80 - nw) / 2, g.y + 42)
  end

  love.graphics.setColor(0.45, 0.55, 0.4)
  love.graphics.rectangle("fill", 20, 210, 130, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("过一会儿 (X)", 36, 213)
  if canGoHome then
    love.graphics.setColor(0.55, 0.4, 0.3)
    love.graphics.rectangle("fill", 170, 210, 130, 22)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("收拾回家", 198, 213)
  end
end

local function drawTop()
  if scene == "title" then drawTitleTop()
  elseif scene == "codex" then drawCodexTop()
  elseif scene == "about" then drawAboutTop()
  elseif scene == "prologue" then
    local b = prologue.beats[prologue.i]
    drawStoryTop(b.img, b.line)
  elseif scene == "cast" then drawCastTop()
  elseif scene == "depart" then
    local b = depart.beats[depart.i]
    drawStoryTop(b.img, b.line)
  elseif scene == "homecoming" then
    local b = homecoming.beats[homecoming.i]
    drawStoryTop(b.img, b.line)
  else drawPlayTop()
  end
end

local function drawBottom()
  if scene == "title" then drawTitleBottom()
  elseif scene == "codex" then drawCodexBottom()
  elseif scene == "about" then drawAboutBottom()
  elseif scene == "prologue" then drawStoryBottom("按 A 继续故事")
  elseif scene == "cast" then drawCastBottom()
  elseif scene == "depart" then drawStoryBottom("按 A 前往营地")
  elseif scene == "homecoming" then drawStoryBottom("按 A 回到标题")
  else drawPlayBottom()
  end
end

function love.draw(screen)
  if screen == "bottom" then drawBottom(); return end
  if screen == "top" or screen == "left" or screen == "right" then drawTop(); return end
  drawTop()
  if desktopBottom then
    love.graphics.setCanvas(desktopBottom)
    love.graphics.clear(0.85, 0.75, 0.55)
    drawBottom()
    love.graphics.setCanvas()
    love.graphics.setColor(0.15, 0.15, 0.17)
    love.graphics.rectangle("fill", 0, TOP_H, 40, BOT_H)
    love.graphics.rectangle("fill", 360, TOP_H, 40, BOT_H)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(desktopBottom, 40, TOP_H)
  end
end

bindCampModules()
