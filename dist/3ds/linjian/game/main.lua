--[[
  露营之旅 — full weekend loop (LovePotion / desktop LÖVE)
  title → prologue → cast → depart → play → homecoming → title
]]

local TOP_W, TOP_H = 400, 240
local BOT_W, BOT_H = 320, 240
local TILE = 16

local isConsole = love.system.getOS() == "Horizon" or love.system.getOS() == "3DS"
local desktopBottom
local uiFont, titleFont
local assets = {}
local bgm = { title = nil, morning = nil, night = nil, current = nil }
local amb = { birds = nil, crickets = nil, creek = nil }
local sfx = {}

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

local map = {}
local decals = {} -- {x=, y=, kind=, v=}
local firepit = { x = 12, y = 10 }
local fishFX = { timer = 2.5, jumps = {} } -- occasional splash jumps
local treeTiles = {}
local critters = { birds = {}, bugs = {}, birdT = 1.4, bugT = 2.2 }
local updateFish, spawnFishJump, drawFish, drawDecalsForRow, updateTimedRitual, goCodex, goAbout
local updateCritters, spawnBird, spawnBug, drawCritters
local updateNight, drawNightSky, spawnMeteor, spawnLeaf

-- tile: 0/1 grass, 2 creek, 3 tree, 4 rock, 5 tent, 6 bush, 7 dirt pad, 8 shallow ford
local function isWater(t) return t == 2 or t == 8 end
local function isDeepWater(t) return t == 2 end
local function isOpenGround(t) return t == 0 or t == 1 or t == 7 end

local playtest = { on = false, t = 0, step = 0, done = false, log = {}, outDir = "playtest", _walk = 0 }
local playtestTick

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

local nightFX = { stars = {}, meteors = {}, leaves = {}, meteorT = 1.6, leafT = 0.4 }

local function seedStars()
  nightFX.stars = {}
  local rng = love.math.newRandomGenerator(77)
  for i = 1, 36 do
    nightFX.stars[i] = {
      x = rng:random(6, TOP_W - 6),
      y = rng:random(4, i <= 22 and 72 or 108),
      p = rng:random() * 6.28,
      s = rng:random(1, 2),
      plus = (i % 7 == 0)
    }
  end
end

local function walkable(tx, ty)
  local row = map[ty]
  if not row then return false end
  local t = row[tx]
  -- 小溪可趟过去；泥地空场可走；树/灌木/大石阻挡
  return t == 0 or t == 1 or t == 2 or t == 5 or t == 7 or t == 8
end

local function say(msg, sec)
  toast = msg
  toastT = sec or 2.5
end

local function loadImage(path)
  local ok, img = pcall(love.graphics.newImage, path)
  if ok and img then
    img:setFilter("nearest", "nearest")
    return img
  end
  return nil
end

local function newFontSized(size)
  if isConsole then
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

local function creekCenterX(y)
  -- 效果图：小溪靠右，弯度一次只偏一格，少折线台阶
  local wiggle = math.floor(1.7 * math.sin(y * 0.40) + 0.7 * math.sin(y * 0.88 + 1.0))
  return 17 + wiggle
end

local function buildMap()
  local cols, rows = TOP_W / TILE, TOP_H / TILE
  decals = {}
  treeTiles = {}
  critters.birds, critters.bugs = {}, {}
  critters.birdT, critters.bugT = 1.4, 2.2
  for y = 0, rows - 1 do
    map[y] = {}
    local cx = creekCenterX(y)
    local wide = 1
    for x = 0, cols - 1 do
      local t = ((x * 3 + y * 5) % 2 == 0) and 0 or 1
      local dx = x - cx
      if math.abs(dx) <= wide then
        t = 2
      elseif math.abs(dx) == wide + 1 then
        t = 8 -- 浅滩 / 溪岸
      end
      map[y][x] = t
    end
  end

  -- 营地泥地空场（对标效果图中央 clearing）
  for y = 8, 12 do
    for x = 8, 13 do
      if map[y] and map[y][x] and not isWater(map[y][x]) then
        map[y][x] = 7
      end
    end
  end
  -- 浅滩渡口（更宽一段）
  for y = 5, 9 do
    local cx = creekCenterX(y)
    for x = cx - 2, cx + 2 do
      if map[y] and x >= 0 and map[y][x] ~= nil then
        if math.abs(x - cx) <= 1 then map[y][x] = 8
        elseif isDeepWater(map[y][x]) then map[y][x] = 8 end
      end
    end
  end

  local trees = {
    {1,1,0},{2,0,2},{4,1,1},{6,0,3},{0,3,4},{3,4,5},{7,2,6},{9,0,7},
    {1,6,2},{2,8,0},{4,7,3},{0,10,1},{3,11,5},{5,13,4},{7,13,6},
    {10,1,1},{16,0,7},{18,0,0},{19,2,2},{21,1,3},{22,3,5},{23,0,4},
    {20,5,6},{22,6,0},{23,8,7},{23,10,1},{21,12,2},{23,13,5},
    {6,5,3},{8,3,2},{2,12,4},{0,7,1}
  }
  for _, p in ipairs(trees) do
    local x, y, v = p[1], p[2], p[3] or 0
    if map[y] and map[y][x] and not isWater(map[y][x]) then
      map[y][x] = 3
      decals[#decals + 1] = { x = x, y = y, kind = "tree", v = v }
      treeTiles[#treeTiles + 1] = { x = x, y = y, v = v }
    end
  end
  -- 几棵树上有巢
  for i = 1, math.min(4, #treeTiles) do
    local t = treeTiles[1 + (i * 5 + 2) % #treeTiles]
    decals[#decals + 1] = { x = t.x, y = t.y, kind = "nest", v = i % 3 }
  end

  for _, p in ipairs({ {5,3,0},{8,6,1},{13,5,2},{17,6,0},{11,11,1},{4,9,2},{19,10,0} }) do
    local x, y, v = p[1], p[2], p[3]
    if map[y] and map[y][x] and not isWater(map[y][x]) and map[y][x] ~= 3 then
      map[y][x] = 6
      decals[#decals + 1] = { x = x, y = y, kind = "bush", v = v }
    end
  end

  for _, p in ipairs({ {8,7,0},{14,6,1},{6,12,2},{12,4,0},{20,5,1} }) do
    local x, y, v = p[1], p[2], p[3]
    if map[y] and map[y][x] and not isWater(map[y][x]) and map[y][x] < 3 then
      map[y][x] = 4
      decals[#decals + 1] = { x = x, y = y, kind = "stone", v = v }
    end
  end

  -- flowers / reeds / logs（不挡路）
  for _, p in ipairs({
    {5,5,"flower",0},{7,4,"flower",1},{10,7,"flower",2},{13,9,"flower",3},
    {15,6,"flower",1},{3,7,"flower",0},{9,11,"flower",2},{18,4,"flower",3},
    {16,7,"reed",0},{19,8,"reed",0},{17,11,"reed",0},{21,6,"reed",0},
    {11,8,"log",0},{4,11,"log",0},
    {12,9,"stump",0},
    {6,8,"flower",0},{9,7,"flower",1},{14,8,"flower",2},{8,11,"flower",3},
    {10,12,"flower",1},{7,10,"flower",0}
  }) do
    local x, y, kind, v = p[1], p[2], p[3], p[4]
    if map[y] and map[y][x] and (isOpenGround(map[y][x]) or isWater(map[y][x])) then
      if kind == "reed" and not isWater(map[y][x]) then
        -- reeds prefer water edge
      else
        decals[#decals + 1] = { x = x, y = y, kind = kind, v = v }
      end
    end
    if kind == "reed" then
      local cx = creekCenterX(y)
      decals[#decals + 1] = { x = cx - 1, y = y, kind = "reed", v = 0 }
    end
  end

  map[10][11] = 5
  map[10][12] = 7
  firepit.x, firepit.y = 12, 10

  -- 浅滩踏脚石 + 溪尾小码头
  for _, p in ipairs({ {creekCenterX(6), 6, 0}, {creekCenterX(7) + 1, 7, 1}, {creekCenterX(8), 8, 2} }) do
    local x, y, v = p[1], p[2], p[3]
    if map[y] and map[y][x] and isWater(map[y][x]) then
      decals[#decals + 1] = { x = x, y = y, kind = "step", v = v }
    end
  end
  do
    local y, x = 13, creekCenterX(13)
    if map[y] and map[y][x] then
      decals[#decals + 1] = { x = x, y = y, kind = "pier", v = 0 }
    end
  end
end

local function loadAssets()
  assets.grass, assets.water, assets.shallow, assets.trees = {}, {}, {}, {}
  assets.bushes, assets.flowers, assets.stones, assets.dirt = {}, {}, {}, {}
  for i = 0, 7 do assets.grass[i] = loadImage("assets/tile_grass" .. i .. ".png") end
  for i = 0, 3 do assets.dirt[i] = loadImage("assets/tile_dirt" .. i .. ".png") end
  for i = 0, 3 do assets.water[i] = loadImage("assets/tile_water" .. i .. ".png") end
  for i = 0, 3 do assets.shallow[i] = loadImage("assets/tile_shallow" .. i .. ".png") end
  for i = 0, 7 do assets.trees[i] = loadImage("assets/tile_tree" .. i .. ".png") end
  for i = 0, 2 do assets.bushes[i] = loadImage("assets/tile_bush" .. i .. ".png") end
  for i = 0, 3 do assets.flowers[i] = loadImage("assets/prop_flower" .. i .. ".png") end
  for i = 0, 2 do assets.stones[i] = loadImage("assets/tile_stone" .. i .. ".png") end
  assets.reed = loadImage("assets/prop_reed.png")
  assets.log = loadImage("assets/prop_log.png")
  assets.stump = loadImage("assets/prop_stump.png")
  assets.shadow = loadImage("assets/prop_shadow.png")
  assets.shadowSm = loadImage("assets/prop_shadow_sm.png")
  assets.shadowTree = loadImage("assets/prop_shadow_tree.png")
  assets.pier = loadImage("assets/prop_pier.png")
  assets.packBg = loadImage("assets/ui_pack_bg.png")
  assets.fish = {}
  for i = 0, 4 do assets.fish[i] = loadImage("assets/world/fish_" .. i .. ".png") end
  assets.birds = {}
  for i = 0, 2 do
    assets.birds[i] = {
      perch = loadImage("assets/world/bird_" .. i .. "_perch.png"),
      fly = {
        loadImage("assets/world/bird_" .. i .. "_fly0.png"),
        loadImage("assets/world/bird_" .. i .. "_fly1.png")
      }
    }
  end
  assets.nest = loadImage("assets/world/nest.png")
  assets.butterfly = {
    loadImage("assets/world/butterfly_0.png"),
    loadImage("assets/world/butterfly_1.png")
  }
  assets.dragonfly = loadImage("assets/world/dragonfly.png")
  assets.firefly = {
    loadImage("assets/world/firefly_0.png"),
    loadImage("assets/world/firefly_1.png")
  }
  assets.shore = {
    E = loadImage("assets/shore_E.png"), W = loadImage("assets/shore_W.png"),
    N = loadImage("assets/shore_N.png"), S = loadImage("assets/shore_S.png"),
    SE = loadImage("assets/shore_SE.png"), NE = loadImage("assets/shore_NE.png"),
    NW = loadImage("assets/shore_NW.png"), SW = loadImage("assets/shore_SW.png")
  }
  assets.tent = loadImage("assets/tile_tent.png")
  assets.tentOpen = loadImage("assets/tile_tent_open.png") or assets.tent
  assets.tentPacked = loadImage("assets/tile_tent_packed.png")
  assets.firepit = loadImage("assets/prop_firepit.png")
  assets.brewKit = loadImage("assets/world/brew_kit.png")
  assets.steam = {
    loadImage("assets/world/steam_0.png"),
    loadImage("assets/world/steam_1.png"),
    loadImage("assets/world/steam_2.png")
  }
  assets.ritual = {
    drip = {
      loadImage("assets/ritual/drip_1.png"),
      loadImage("assets/ritual/drip_2.png"),
      loadImage("assets/ritual/drip_3.png")
    },
    fishAnim = {},
    fanAnim = {}
  }
  for i = 0, 3 do
    assets.ritual.fishAnim[i + 1] = loadImage("assets/world/fish_anim_" .. i .. ".png")
    assets.ritual.fanAnim[i + 1] = loadImage("assets/world/fan_anim_" .. i .. ".png")
  end
  assets.titleTop = loadImage("assets/title_top.png")
  assets.titleBot = loadImage("assets/title_bot.png")
  assets.story = {
    p1 = loadImage("assets/story/p1.png"),
    p2 = loadImage("assets/story/p2.png"),
    p3 = loadImage("assets/story/p3.png"),
    d1 = loadImage("assets/story/d1.png"),
    d2 = loadImage("assets/story/d2.png"),
    h1 = loadImage("assets/story/h1.png")
  }
  assets.cast = {}
  assets.walk = {}
  for i = 1, 9 do
    assets.cast[i] = loadImage("assets/cast/c" .. i .. ".png")
    local sheet = loadImage("assets/cast/c" .. i .. "_walk.png")
    if sheet then
      local quads = {}
      for row = 0, 3 do
        quads[row] = {}
        for col = 0, 2 do
          quads[row][col] = love.graphics.newQuad(col * 40, row * 40, 40, 40, sheet:getDimensions())
        end
      end
      assets.walk[i] = { sheet = sheet, quads = quads }
    end
  end
  assets.player = assets.cast[1] or loadImage("assets/player.png")
  for _, g in ipairs(gear) do
    g.icon = loadImage("assets/gear_" .. g.id .. ".png")
  end
end

local function loadBgm()
  local function tryLoad(path, vol)
    local ok, src = pcall(love.audio.newSource, path, "stream")
    if ok and src then
      src:setLooping(true)
      src:setVolume(vol or 0.55)
      return src
    end
  end
  bgm.title = tryLoad("audio/bgm_01_title.ogg") or tryLoad("audio/bgm_01_title.mp3")
  bgm.morning = tryLoad("audio/bgm_02_morning.ogg") or tryLoad("audio/bgm_02_morning.mp3")
  bgm.night = tryLoad("audio/bgm_03_night.ogg") or tryLoad("audio/bgm_03_night.mp3")
  amb.birds = tryLoad("audio/amb_birds.mp3", 0.22)
  amb.crickets = tryLoad("audio/amb_crickets.mp3", 0.26)
  amb.creek = tryLoad("audio/amb_creek.mp3", 0.16)
end

local function loadSfx()
  local function tryStatic(path, vol)
    local ok, src = pcall(love.audio.newSource, path, "static")
    if ok and src then
      src:setVolume(vol or 0.5)
      return src
    end
  end
  sfx.step = tryStatic("audio/sfx_step.wav", 0.4)
  sfx.tent = tryStatic("audio/sfx_tent.wav", 0.55)
  sfx.pour = tryStatic("audio/sfx_pour.wav", 0.5)
  sfx.cup = tryStatic("audio/sfx_cup.wav", 0.55)
  sfx.fan = tryStatic("audio/sfx_fan.wav", 0.45)
  sfx.lantern = tryStatic("audio/sfx_lantern.wav", 0.6)
  sfx.ui_move = tryStatic("audio/sfx_ui_move.wav", 0.35)
  sfx.ui_ok = tryStatic("audio/sfx_ui_ok.wav", 0.5)
end

local function playSfx(name)
  local src = sfx[name]
  if not src then return end
  local ok, inst = pcall(function() return src:clone() end)
  if ok and inst then
    inst:setPitch(0.92 + love.math.random() * 0.16)
    inst:play()
  else
    src:stop()
    src:play()
  end
end

local function playBgm(src)
  if bgm.current == src and src and src:isPlaying() then return end
  if bgm.current then bgm.current:stop() end
  bgm.current = src
  if src then src:stop(); src:play() end
end

local function stopBgm()
  if bgm.current then bgm.current:stop() end
  bgm.current = nil
end

local function stopAmb()
  for _, src in pairs({ amb.birds, amb.crickets, amb.creek }) do
    if src then src:stop() end
  end
end

local function ensureAmb(src)
  if not src then return end
  if not src:isPlaying() then src:play() end
end

-- play: 溪水常垫；白天鸟鸣 / 入夜～深夜虫鸣（与 BGM 叠，音量更低）
local function syncAmbient()
  if scene ~= "play" then
    stopAmb()
    return
  end
  ensureAmb(amb.creek)
  local night = (timeIndex >= 5 and timeIndex <= 6)
  if night then
    if amb.birds then amb.birds:stop() end
    ensureAmb(amb.crickets)
  else
    if amb.crickets then amb.crickets:stop() end
    ensureAmb(amb.birds)
  end
end

-- play: 清晨～黄昏 = morning；入夜～深夜 = night；黎明回到 morning
local function syncPlayBgm()
  if scene ~= "play" then return end
  local night = (timeIndex >= 5 and timeIndex <= 6)
  if night and bgm.night then
    playBgm(bgm.night)
  elseif bgm.morning then
    playBgm(bgm.morning)
  end
  syncAmbient()
end

local function applyCast(id)
  player.castId = id
  assets.player = assets.cast[id] or assets.player
end

local function goTitle()
  scene = "title"
  prologue.i, depart.i, homecoming.i = 1, 1, 1
  cast.i = 1
  lanternOn, canGoHome = false, false
  timeIndex = 3
  stopAmb()
  playBgm(bgm.title)
  say("触摸或方向键选择 · A 确认", 3)
end

local function goPrologue()
  scene = "prologue"
  prologue.i = 1
  stopAmb()
  stopBgm()
  if bgm.morning then playBgm(bgm.morning) end
  toast, toastT = "", 0
end

local function goCast()
  scene = "cast"
  say("这次谁去？选好后按 A 确认", 3)
end

local function goDepart()
  scene = "depart"
  depart.i = 1
  toast, toastT = "", 0
end

local function goPlay()
  scene = "play"
  player.x, player.y = 10, 9
  player.facing, player.walkFrame, player.walkTimer = 0, 0, 0
  selected = 1
  timeIndex = 2 -- 上午抵达
  lanternOn, canGoHome = false, false
  tentOpen, brewActive, brewTimer, potSimmer = false, false, 0, 0
  drippedOnce = false
  ritual = nil
  critters.birds, critters.bugs = {}, {}
  critters.birdT, critters.bugT = 0.4, 0.6
  stopBgm()
  syncPlayBgm()
  say("到了 · 林间有小溪，可以趟过去", 3.5)
end

local function clearRitual()
  ritual = nil
end

local function startDripRitual()
  ritual = { kind = "drip", step = 1, max = 3 }
  brewActive = true
  brewX, brewY = player.x, player.y
  brewTimer = 8
  playSfx("pour")
  say("闷蒸 · 按 A 下一步", 3)
end

local function advanceDripRitual()
  if not ritual or ritual.kind ~= "drip" then return end
  if ritual.step < ritual.max then
    ritual.step = ritual.step + 1
    local labels = { "闷蒸", "绕圈注水", "分享入杯" }
    if ritual.step == 2 then playSfx("pour")
    elseif ritual.step == 3 then playSfx("cup") end
    say(labels[ritual.step] .. " · 按 A 下一步", 2.5)
  else
    drippedOnce = true
    clearRitual()
    brewTimer = 6
    playSfx("cup")
    say("第一口……周末真好。", 3)
    if timeIndex < 4 then
      timeIndex = timeIndex + 1
      say("时间到了 · " .. timeSlots[timeIndex], 2)
      syncPlayBgm()
    end
  end
end

local function startRodRitual()
  ritual = { kind = "rod", step = 1, max = 4, t = 0, frameDur = 0.45 }
  fishFX.timer = 0.2
  say("抛竿……", 1.5)
end

local function startFanRitual()
  ritual = { kind = "fan", step = 1, max = 4, t = 0, frameDur = 0.35 }
  playSfx("fan")
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
      fishFX.timer = 0.05
      say("有鱼！……又溜了。", 2.5)
    elseif ritual.kind == "fan" and ritual.step == 3 then
      playSfx("fan")
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
  playSfx("tent")
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
      local row = map[player.y + d[2]]
      local tt = row and row[player.x + d[1]]
      if tt == 2 or tt == 8 then nearCreek = true; break end
    end
    if nearCreek then
      startRodRitual()
    else
      say("去小溪边再试试。", 2.5)
    end
  elseif g.id == "cup" then
    if drippedOnce then
      playSfx("cup")
      say("喝了一口。周末真好。", 2.5)
    else
      say("杯子还是空的 · 先手冲吧。", 2.5)
    end
  elseif g.id == "fan" then
    startFanRitual()
  else
    say("拿起了" .. g.name, 2)
  end

  if nearFire and timeIndex >= 5 and not lanternOn then
    lanternOn = true
    canGoHome = true
    playSfx("lantern")
    say("点亮了露营灯 · 夜色温柔。", 3.5)
  end
end

local function tryMove(dx, dy)
  if ritual then return end
  local nx, ny = player.x + dx, player.y + dy
  if walkable(nx, ny) then
    player.x, player.y = nx, ny
    player.walkFrame = (player.walkFrame == 1) and 2 or 1
    player.idleT = 0.28
    playSfx("step")
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
  ritual = nil
  stopAmb()
  stopBgm()
  if bgm.title then playBgm(bgm.title) end
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
  playSfx("ui_ok")
  applyCast(cast.i)
  goDepart()
end

local function setCast(i)
  if cast.i == i then return end
  cast.i = i
  playSfx("ui_move")
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
  playSfx("ui_ok")
  if item.id == "start" then startJourney()
  elseif item.id == "codex" then goCodex()
  elseif item.id == "about" then goAbout()
  end
end

goCodex = function()
  scene = "codex"
  codex.i = 1
  toast, toastT = "", 0
  playBgm(bgm.title)
end

goAbout = function()
  scene = "about"
  toast, toastT = "", 0
  playBgm(bgm.title)
end

local function moveCodex(delta)
  local n = #gear
  codex.i = ((codex.i - 1 + delta) % n) + 1
  playSfx("ui_move")
end

local function setCodex(i)
  if i < 1 or i > #gear or i == codex.i then return end
  codex.i = i
  playSfx("ui_move")
end

local function moveMenu(delta)
  menuIndex = ((menuIndex - 1 + delta) % #menuItems) + 1
  playSfx("ui_move")
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
      nightFX.meteorT = 0.35
      for _ = 1, 4 do spawnBug() end
      say("入夜了 · 营火旁按 A 点灯。抬头有星星。", 3.5)
    elseif timeSlots[timeIndex] == "黎明" then
      canGoHome = true
      say("天亮了 · 可以收拾回家（下屏按钮）", 3.5)
    end
    syncPlayBgm()
  else
    canGoHome = true
    say("可以回家了", 2)
  end
end

-- drip ritual may bump time after finish (advanceTime exists now)

local function advancePrimary()
  if scene == "title" then confirmMenu()
  elseif scene == "prologue" then playSfx("ui_ok"); advancePrologue()
  elseif scene == "cast" then confirmCast()
  elseif scene == "depart" then playSfx("ui_ok"); advanceDepart()
  elseif scene == "play" then tryUseGear()
  elseif scene == "homecoming" then playSfx("ui_ok"); advanceHome()
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
      if menuIndex ~= i then playSfx("ui_move") end
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
        if selected ~= i then playSfx("ui_move") end
        selected = i
        say("选中 · " .. gear[i].name)
      end
    end
  end
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  buildMap()
  loadAssets()
  loadBgm()
  loadSfx()
  uiFont = newFontSized(14)
  titleFont = newFontSized(26) or uiFont
  if uiFont then love.graphics.setFont(uiFont) end
  seedStars()
  if not isConsole then
    desktopBottom = love.graphics.newCanvas(BOT_W, BOT_H)
    love.window.setMode(TOP_W, TOP_H + BOT_H)
  end
  playBgm(bgm.title)
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
    spawnBird(); spawnBird(); spawnBug(); spawnBug()
    playtestShot("05_camp")
    playtestLog("wildlife birds=" .. #critters.birds .. " bugs=" .. #critters.bugs)
    nextStep()
  elseif s == 12 then
    -- let birds leave the branch before the camp shot
    if t > 0.35 and #critters.birds == 0 then spawnBird() end
    if t > 0.55 and #critters.bugs == 0 then spawnBug() end
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
  elseif s == 20 and t > 0.15 then tryUseGear(); playtestLog("dripped=" .. tostring(drippedOnce)); nextStep()
  elseif s == 21 and t > 0.2 then
    selected = 6 -- fan
    tryUseGear()
    playtestLog("fan=" .. tostring(ritual and ritual.kind))
    nextStep()
  elseif s == 22 and t > 0.5 then playtestShot("05d_fan"); tryUseGear(); nextStep() -- skip fan
  elseif s == 23 and t > 0.2 then
    -- walk toward creek and fish
    player.x, player.y = creekCenterX(7), 7
    selected = 4 -- rod
    tryUseGear()
    playtestLog("rod=" .. tostring(ritual and ritual.kind))
    nextStep()
  elseif s == 24 and t > 0.5 then playtestShot("05e_fish"); tryUseGear(); nextStep()
  elseif s == 25 and t > 0.25 then
    timeIndex = 5; selected = 3
    player.x, player.y = firepit.x - 1, firepit.y
    tryUseGear()
    playtestLog("lantern=" .. tostring(lanternOn))
    spawnMeteor(); spawnLeaf(); spawnLeaf(); spawnBug(); spawnBug()
    for _, u in ipairs(critters.bugs) do u.kind = "firefly" end
    nextStep()
  elseif s == 26 and t > 0.55 then
    playtestShot("06_night_lamp")
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
    updateFish(dt)
    updateCritters(dt)
    updateNight(dt)
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

local function drawToast()
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
  local img = assets.story and assets.story[imgKey]
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local s = math.min(TOP_W / iw, TOP_H / ih)
    love.graphics.draw(img, (TOP_W - iw * s) / 2, (TOP_H - ih * s) / 2, 0, s, s)
  else
    love.graphics.setColor(0.2, 0.25, 0.2)
    love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
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
  if assets.titleTop then love.graphics.draw(assets.titleTop, 0, 0)
  else love.graphics.setColor(0.35, 0.55, 0.4); love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H) end
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
  if assets.titleBot then love.graphics.draw(assets.titleBot, 0, 0)
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
  if assets.titleTop then love.graphics.draw(assets.titleTop, 0, 0)
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
  if assets.packBg then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(assets.packBg, 0, 0)
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
  if assets.titleTop then love.graphics.draw(assets.titleTop, 0, 0)
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
  if assets.packBg then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(assets.packBg, 0, 0)
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
  local img = assets.cast[cast.i]
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
    local spr = assets.cast[i]
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

local function tileAt(tx, ty)
  local row = map[ty]
  return row and row[tx] or nil
end

local function drawGround(t, px, py, tx, ty)
  love.graphics.setColor(1, 1, 1, 1)
  if t == 2 or t == 8 then
    local wi = math.floor(waterPhase) % 4
    local sheet = (t == 8 and assets.shallow and assets.shallow[wi]) or (assets.water and assets.water[wi])
    if sheet then love.graphics.draw(sheet, px, py)
    else
      love.graphics.setColor(t == 8 and 0.4 or 0.2, 0.55, 0.5)
      love.graphics.rectangle("fill", px, py, TILE, TILE)
    end
    love.graphics.setColor(1, 1, 1, 1)
    -- 水边薄岸：画在水格上，打断方砖缝
    if assets.shore then
      if not isWater(tileAt(tx + 1, ty)) and assets.shore.E then love.graphics.draw(assets.shore.E, px, py) end
      if not isWater(tileAt(tx - 1, ty)) and assets.shore.W then love.graphics.draw(assets.shore.W, px, py) end
      if not isWater(tileAt(tx, ty - 1)) and assets.shore.N then love.graphics.draw(assets.shore.N, px, py) end
      if not isWater(tileAt(tx, ty + 1)) and assets.shore.S then love.graphics.draw(assets.shore.S, px, py) end
    end
    return
  end
  if t == 7 and assets.dirt and assets.dirt[(tx * 3 + ty * 5) % 4] then
    love.graphics.draw(assets.dirt[(tx * 3 + ty * 5) % 4], px, py)
  else
    local grass = assets.grass[(tx * 17 + ty * 31) % 8]
    if grass then love.graphics.draw(grass, px, py)
    else love.graphics.setColor(0.43, 0.66, 0.28); love.graphics.rectangle("fill", px, py, TILE, TILE) end
  end
  if not assets.shore then return end
  love.graphics.setColor(1, 1, 1, 1)
  local E = isWater(tileAt(tx + 1, ty))
  local W = isWater(tileAt(tx - 1, ty))
  local N = isWater(tileAt(tx, ty - 1))
  local S = isWater(tileAt(tx, ty + 1))
  if E and assets.shore.E then love.graphics.draw(assets.shore.E, px, py) end
  if W and assets.shore.W then love.graphics.draw(assets.shore.W, px, py) end
  if N and assets.shore.N then love.graphics.draw(assets.shore.N, px, py) end
  if S and assets.shore.S then love.graphics.draw(assets.shore.S, px, py) end
  if N and E and assets.shore.NE then love.graphics.draw(assets.shore.NE, px, py) end
  if N and W and assets.shore.NW then love.graphics.draw(assets.shore.NW, px, py) end
  if S and E and assets.shore.SE then love.graphics.draw(assets.shore.SE, px, py) end
  if S and W and assets.shore.SW then love.graphics.draw(assets.shore.SW, px, py) end
end

local function drawDropShadow(px, py, kind)
  local img, ox, oy = assets.shadow, 4, 2
  if kind == "sm" then
    img, ox, oy = assets.shadowSm, 3, 2
  elseif kind == "tree" then
    img, ox, oy = assets.shadowTree or assets.shadow, 5, 3
  end
  if not img then return end
  local iw, ih = img:getWidth(), img:getHeight()
  love.graphics.setColor(1, 1, 1, 0.92)
  love.graphics.draw(img, px + TILE / 2 - iw / 2 + ox, py + TILE - ih + oy)
  love.graphics.setColor(1, 1, 1, 1)
end

drawDecalsForRow = function(rowY)
  love.graphics.setColor(1, 1, 1, 1)
  for _, d in ipairs(decals) do
    if d.y == rowY then
      local px, py = d.x * TILE, d.y * TILE
      if d.kind == "flower" and assets.flowers then
        local img = assets.flowers[d.v % 4]
        if img then love.graphics.draw(img, px + 3, py + 4) end
      elseif d.kind == "reed" and assets.reed then
        love.graphics.draw(assets.reed, px + 2, py + TILE - assets.reed:getHeight())
      elseif d.kind == "log" and assets.log then
        love.graphics.draw(assets.log, px - 2, py + 6)
      elseif d.kind == "stump" and assets.stump then
        drawDropShadow(px, py, "sm")
        love.graphics.draw(assets.stump, px + (TILE - assets.stump:getWidth()) / 2, py + TILE - assets.stump:getHeight())
      elseif d.kind == "step" and assets.stones then
        local img = assets.stones[d.v % 3]
        if img then love.graphics.draw(img, px + 2, py + 6) end
      elseif d.kind == "pier" and assets.pier then
        love.graphics.draw(assets.pier, px + TILE - assets.pier:getWidth() + 4, py + 4)
      end
    end
  end
end

local function treeVariant(tx, ty)
  for _, d in ipairs(decals) do
    if d.kind == "tree" and d.x == tx and d.y == ty then return d.v % 8 end
  end
  return (tx * 5 + ty * 3) % 8
end

local function drawProp(t, px, py, tx, ty)
  love.graphics.setColor(1, 1, 1, 1)
  if t == 3 then
    local tree = assets.trees and assets.trees[treeVariant(tx, ty)]
    if tree then
      local iw, ih = tree:getWidth(), tree:getHeight()
      drawDropShadow(px, py, "tree")
      local sway = math.sin(titlePulse * 1.5 + tx * 0.7 + ty) * (isNight() and 1.4 or 0.7)
      love.graphics.draw(tree, px + (TILE - iw) / 2 + sway, py + TILE - ih)
      if assets.nest then
        for _, d in ipairs(decals) do
          if d.kind == "nest" and d.x == tx and d.y == ty then
            love.graphics.draw(assets.nest, px + (TILE - assets.nest:getWidth()) / 2 + 2 + sway, py - 4)
            break
          end
        end
      end
    end
  elseif t == 6 then
    local bush = assets.bushes and assets.bushes[(tx + ty) % 3]
    if bush then
      drawDropShadow(px, py, "sm")
      local sway = math.sin(titlePulse * 1.8 + tx) * 0.8
      love.graphics.draw(bush, px + (TILE - bush:getWidth()) / 2 + sway, py + TILE - bush:getHeight())
    end
  elseif t == 4 then
    local stone = assets.stones and assets.stones[(tx + ty) % 3]
    if stone then
      drawDropShadow(px, py, "sm")
      love.graphics.draw(stone, px, py + TILE - stone:getHeight())
    end
  elseif t == 5 then
    local img = tentOpen and (assets.tentOpen or assets.tent) or (assets.tentPacked or assets.tent)
    if img then
      local iw, ih = img:getWidth(), img:getHeight()
      drawDropShadow(px, py, "lg")
      love.graphics.draw(img, px + (TILE - iw) / 2, py + TILE - ih + 2)
    end
  end
end

spawnFishJump = function()
  local rows = TOP_H / TILE
  local candidates = {}
  for y = 1, rows - 2 do
    for x = 0, TOP_W / TILE - 1 do
      if map[y] and isDeepWater(map[y][x]) then
        candidates[#candidates + 1] = { x = x, y = y }
      end
    end
  end
  if #candidates == 0 then return end
  local c = candidates[love.math.random(#candidates)]
  fishFX.jumps[#fishFX.jumps + 1] = {
    x = c.x * TILE + 2, y = c.y * TILE + 4, t = 0, life = 0.7
  }
end

updateFish = function(dt)
  fishFX.timer = fishFX.timer - dt
  if fishFX.timer <= 0 then
    fishFX.timer = 2.2 + love.math.random() * 2.8
    if scene == "play" and not ritual then spawnFishJump() end
  end
  for i = #fishFX.jumps, 1, -1 do
    local j = fishFX.jumps[i]
    j.t = j.t + dt
    if j.t >= j.life then table.remove(fishFX.jumps, i) end
  end
end

drawFish = function()
  if not assets.fish then return end
  love.graphics.setColor(1, 1, 1, 1)
  for _, j in ipairs(fishFX.jumps) do
    local p = j.t / j.life
    local frame = math.min(4, math.floor(p * 5))
    local img = assets.fish[frame]
    if img then
      local arc = -math.sin(p * math.pi) * 14
      love.graphics.draw(img, j.x, j.y + arc)
    end
  end
end

local function pickOpenNear(tx, ty)
  local spots = {}
  for dy = -2, 3 do
    for dx = -3, 3 do
      local x, y = tx + dx, ty + dy
      if walkable(x, y) and map[y] and isOpenGround(map[y][x]) then
        spots[#spots + 1] = { x = x, y = y }
      end
    end
  end
  if #spots == 0 then return tx, ty + 1 end
  local s = spots[love.math.random(#spots)]
  return s.x, s.y
end

spawnBird = function()
  if #treeTiles == 0 or #critters.birds >= 3 then return end
  local tree = treeTiles[love.math.random(#treeTiles)]
  local gx, gy = pickOpenNear(tree.x, tree.y)
  local kind = love.math.random(0, 2)
  critters.birds[#critters.birds + 1] = {
    kind = kind, state = "perch", t = 0,
    perchWait = 0.8 + love.math.random() * 1.4,
    treeX = tree.x, treeY = tree.y,
    gx = gx, gy = gy, hop = 0,
    x = tree.x * TILE + 2, y = tree.y * TILE - 10,
    face = (gx >= tree.x) and 1 or -1
  }
end

spawnBug = function()
  if #critters.bugs >= (isNight() and 6 or 4) then return end
  local roll = love.math.random()
  local kind = "butterfly"
  if isNight() and roll > 0.12 then kind = "firefly"
  elseif roll > 0.7 then kind = "dragonfly" end
  local x, y
  if kind == "dragonfly" then
    y = 4 + love.math.random(0, 8)
    x = creekCenterX(y)
  else
    x = love.math.random(2, 20)
    y = love.math.random(2, 12)
  end
  critters.bugs[#critters.bugs + 1] = {
    kind = kind, t = 0, life = 4 + love.math.random() * 5,
    ox = x * TILE + 4, oy = y * TILE + 4,
    x = x * TILE + 4, y = y * TILE + 4,
    vx = (love.math.random() < 0.5) and 18 or -18
  }
end

updateCritters = function(dt)
  critters.birdT = critters.birdT - dt
  critters.bugT = critters.bugT - dt
  if critters.birdT <= 0 then
    critters.birdT = 4.5 + love.math.random() * 5
    if scene == "play" and not ritual and not isNight() then spawnBird() end
  end
  if critters.bugT <= 0 then
    critters.bugT = 3.2 + love.math.random() * 4
    if scene == "play" and not ritual then spawnBug() end
  end

  for i = #critters.birds, 1, -1 do
    local b = critters.birds[i]
    b.t = b.t + dt
    if b.state == "perch" then
      if b.t >= b.perchWait then
        b.state, b.t = "down", 0
      end
    elseif b.state == "down" then
      local p = math.min(1, b.t / 0.85)
      local sx, sy = b.treeX * TILE + 2, b.treeY * TILE - 10
      local dx, dy = b.gx * TILE + 4, b.gy * TILE + 6
      b.x = sx + (dx - sx) * p
      b.y = sy + (dy - sy) * p - math.sin(p * math.pi) * 18
      if p >= 1 then b.state, b.t, b.hop = "hop", 0, 0 end
    elseif b.state == "hop" then
      local p = (b.t % 0.35) / 0.35
      b.x = b.gx * TILE + 4 + b.hop * 5 * b.face
      b.y = b.gy * TILE + 6 - math.sin(p * math.pi) * 3
      if b.t > 0.35 then
        b.t, b.hop = 0, b.hop + 1
        if b.hop >= 3 then b.state, b.t = "up", 0 end
      end
    elseif b.state == "up" then
      local p = math.min(1, b.t / 0.9)
      local sx, sy = b.gx * TILE + 4, b.gy * TILE + 6
      local dx, dy = b.treeX * TILE + 2, b.treeY * TILE - 10
      b.x = sx + (dx - sx) * p
      b.y = sy + (dy - sy) * p - math.sin(p * math.pi) * 16
      if p >= 1 then table.remove(critters.birds, i) end
    end
  end

  for i = #critters.bugs, 1, -1 do
    local u = critters.bugs[i]
    u.t = u.t + dt
    if u.kind == "butterfly" then
      u.x = u.ox + math.sin(u.t * 2.4) * 16
      u.y = u.oy + math.cos(u.t * 1.7) * 8
    elseif u.kind == "dragonfly" then
      u.x = u.x + u.vx * dt
      u.y = u.oy + math.sin(u.t * 6) * 3
      if u.x < 8 or u.x > TOP_W - 12 then u.vx = -u.vx end
    else
      u.x = u.ox + math.sin(u.t * 1.3) * 10
      u.y = u.oy + math.cos(u.t * 1.8) * 7
    end
    if u.t >= u.life then table.remove(critters.bugs, i) end
  end
end

drawCritters = function()
  love.graphics.setColor(1, 1, 1, 1)
  for _, b in ipairs(critters.birds) do
    local pack = assets.birds and assets.birds[b.kind]
    if pack then
      local img = pack.perch
      if b.state == "down" or b.state == "up" then
        img = pack.fly and pack.fly[(math.floor(b.t * 10) % 2) + 1]
      end
      if img then
        local sc = 2
        local sx = (b.face < 0 and -sc or sc)
        local ox = sx < 0 and img:getWidth() * sc or 0
        love.graphics.draw(img, b.x + ox, b.y, 0, sx, sc)
      end
    end
  end
  for _, u in ipairs(critters.bugs) do
    if u.kind == "firefly" then
      -- 夜里在色罩之后再画，才亮得起来
    elseif u.kind == "butterfly" and assets.butterfly then
      love.graphics.setColor(1, 1, 1, 1)
      local img = assets.butterfly[(math.floor(u.t * 8) % 2) + 1]
      if img then love.graphics.draw(img, u.x, u.y, 0, 2, 2) end
    elseif u.kind == "dragonfly" and assets.dragonfly then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(assets.dragonfly, u.x, u.y, 0, 2, 2)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

spawnMeteor = function()
  nightFX.meteors[#nightFX.meteors + 1] = {
    x = love.math.random(20, 260), y = love.math.random(8, 36),
    vx = 110 + love.math.random() * 40, vy = 48 + love.math.random() * 20,
    t = 0, life = 0.55 + love.math.random() * 0.25
  }
end

spawnLeaf = function()
  local night = isNight()
  nightFX.leaves[#nightFX.leaves + 1] = {
    x = love.math.random(-10, TOP_W), y = love.math.random(-8, 40),
    vx = (night and 28 or 16) + love.math.random() * 18,
    vy = 12 + love.math.random() * 16,
    t = 0, life = 3.2 + love.math.random() * 2,
    kind = love.math.random(0, 2)
  }
end

updateNight = function(dt)
  nightFX.leafT = nightFX.leafT - dt
  if nightFX.leafT <= 0 then
    nightFX.leafT = (isNight() and 0.35 or 0.9) + love.math.random() * 0.5
    if scene == "play" then spawnLeaf() end
  end
  nightFX.meteorT = nightFX.meteorT - dt
  if nightFX.meteorT <= 0 then
    nightFX.meteorT = 6 + love.math.random() * 8
    if scene == "play" and isNight() then spawnMeteor() end
  end
  for i = #nightFX.meteors, 1, -1 do
    local m = nightFX.meteors[i]
    m.t = m.t + dt
    m.x = m.x + m.vx * dt
    m.y = m.y + m.vy * dt
    if m.t >= m.life then table.remove(nightFX.meteors, i) end
  end
  for i = #nightFX.leaves, 1, -1 do
    local lf = nightFX.leaves[i]
    lf.t = lf.t + dt
    lf.x = lf.x + lf.vx * dt
    lf.y = lf.y + lf.vy * dt + math.sin(lf.t * 5) * 8 * dt
    if lf.t >= lf.life or lf.y > TOP_H + 8 then table.remove(nightFX.leaves, i) end
  end
end

drawNightSky = function()
  local a = starAlpha()
  if a > 0 then
    for _, st in ipairs(nightFX.stars) do
      local tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(titlePulse * 2.2 + st.p))
      love.graphics.setColor(1, 0.96, 0.78, a * tw)
      love.graphics.rectangle("fill", st.x, st.y, st.s, st.s)
      if st.plus then
        love.graphics.setColor(1, 0.96, 0.78, a * tw * 0.55)
        love.graphics.rectangle("fill", st.x - 1, st.y, 1, st.s)
        love.graphics.rectangle("fill", st.x + st.s, st.y, 1, st.s)
        love.graphics.rectangle("fill", st.x, st.y - 1, st.s, 1)
        love.graphics.rectangle("fill", st.x, st.y + st.s, st.s, 1)
      end
    end
    for _, m in ipairs(nightFX.meteors) do
      local fade = 1 - m.t / m.life
      for i = 0, 6 do
        love.graphics.setColor(1, 0.93, 0.7, fade * (1 - i * 0.12))
        love.graphics.rectangle("fill", m.x - i * 3, m.y - i * 1, 3, 1)
      end
      love.graphics.setColor(1, 1, 0.9, fade)
      love.graphics.rectangle("fill", m.x, m.y, 2, 2)
    end
  end
  -- 萤火虫：色罩之后画硬像素亮点，不跟模糊光晕
  if isNight() then
    for _, u in ipairs(critters.bugs) do
      if u.kind == "firefly" then
        local blink = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(u.t * 7))
        local x, y = math.floor(u.x + 0.5), math.floor(u.y + 0.5)
        love.graphics.setColor(1, 0.92, 0.45, blink * 0.35)
        love.graphics.rectangle("fill", x - 1, y, 4, 2)
        love.graphics.rectangle("fill", x, y - 1, 2, 4)
        love.graphics.setColor(1, 0.98, 0.62, blink)
        love.graphics.rectangle("fill", x, y, 2, 2)
      end
    end
  end
  -- 落叶：硬像素小块，风从左往右
  for _, lf in ipairs(nightFX.leaves) do
    if isNight() then
      love.graphics.setColor(0.42, 0.38, 0.18, 0.9)
    else
      love.graphics.setColor(0.48, 0.62, 0.22, 0.9)
    end
    local wob = math.floor(math.sin(lf.t * 6) + 0.5)
    if lf.kind == 0 then
      love.graphics.rectangle("fill", lf.x, lf.y + wob, 3, 2)
    elseif lf.kind == 1 then
      love.graphics.rectangle("fill", lf.x, lf.y + wob, 2, 3)
    else
      love.graphics.rectangle("fill", lf.x + wob, lf.y, 3, 2)
      love.graphics.rectangle("fill", lf.x + 1, lf.y + 1 + wob, 2, 1)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function drawPlayerAt(px, py)
  drawDropShadow(px, py, "sm")
  love.graphics.setColor(1, 1, 1, 1)
  local walk = assets.walk[player.castId]
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
  local img = assets.player
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local sc = 28 / ih
    love.graphics.draw(img, px + (TILE - iw * sc) / 2, py + TILE - ih * sc, 0, sc, sc)
  end
end

local function drawWorldFx()
  if brewActive and assets.brewKit then
    local bx, by = brewX * TILE, brewY * TILE
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(assets.brewKit, bx + 2, by + TILE - assets.brewKit:getHeight())
    if assets.steam then
      local fi = math.floor(waterPhase) % 3
      local st = assets.steam[fi + 1]
      if st then love.graphics.draw(st, bx + 4, by - 6) end
    end
  end
  if potSimmer > 0 then
    love.graphics.setColor(1, 1, 1, 0.5 + 0.3 * math.sin(waterPhase * 4))
    love.graphics.circle("fill", firepit.x * TILE + 8, firepit.y * TILE, 4)
  end
end

local function drawRitualOverlay()
  if not ritual then return end
  if ritual.kind == "drip" then
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
    local img = assets.ritual and assets.ritual.drip and assets.ritual.drip[ritual.step]
    if img then
      love.graphics.setColor(1, 1, 1, 1)
      local iw, ih = img:getWidth(), img:getHeight()
      local s = (iw <= 160) and 2 or 1
      love.graphics.draw(img, math.floor((TOP_W - iw * s) / 2), 34, 0, s, s)
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
    local frames = ritual.kind == "rod" and assets.ritual.fishAnim or assets.ritual.fanAnim
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

local function drawPlayTop()
  if uiFont then love.graphics.setFont(uiFont) end
  love.graphics.setColor(0.15, 0.18, 0.14)
  love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
  local cols, rows = TOP_W / TILE, TOP_H / TILE
  for y = 0, rows - 1 do
    for x = 0, cols - 1 do
      drawGround(map[y][x], x * TILE, y * TILE, x, y)
    end
  end
  local sprites = {}
  for y = 0, rows - 1 do
    drawDecalsForRow(y)
    for x = 0, cols - 1 do
      local t = map[y][x]
      if t == 3 or t == 4 or t == 5 or t == 6 then
        sprites[#sprites + 1] = { y = y, kind = "prop", t = t, x = x }
      end
    end
  end
  sprites[#sprites + 1] = { y = firepit.y, kind = "firepit", x = firepit.x }
  sprites[#sprites + 1] = { y = player.y, kind = "player", x = player.x }
  table.sort(sprites, function(a, b)
    if a.y == b.y then return tostring(a.kind) < tostring(b.kind) end
    return a.y < b.y
  end)
  for _, s in ipairs(sprites) do
    if s.kind == "prop" then drawProp(s.t, s.x * TILE, s.y * TILE, s.x, s.y)
    elseif s.kind == "firepit" and assets.firepit then
      drawDropShadow(s.x * TILE, s.y * TILE, "sm")
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(assets.firepit, s.x * TILE, s.y * TILE + TILE - assets.firepit:getHeight())
      if lanternOn then
        love.graphics.setColor(1, 0.85, 0.4, 0.35)
        love.graphics.circle("fill", s.x * TILE + 8, s.y * TILE + 4, 22)
      end
    else
      drawPlayerAt(s.x * TILE, s.y * TILE)
    end
  end

  drawFish()
  drawCritters()
  drawWorldFx()


  -- time tint
  local tint = timeTint[timeIndex] or timeTint[3]
  love.graphics.setColor(tint[1], tint[2], tint[3], tint[4])
  love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
  drawNightSky()

  local title = "露营 · " .. timeLabel()
  if tentOpen then title = title .. " · 帐" end
  if lanternOn then title = title .. " · 灯" end
  local tw = uiFont and uiFont:getWidth(title) or 80
  love.graphics.setColor(0.08, 0.08, 0.08, 0.85)
  love.graphics.rectangle("fill", 4, 4, tw + 10, 16)
  love.graphics.setColor(1, 0.95, 0.8)
  love.graphics.print(title, 8, 5)
  drawRitualOverlay()
  drawToast()
end

local function drawPlayBottom()
  if uiFont then love.graphics.setFont(uiFont) end
  if assets.packBg then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(assets.packBg, 0, 0)
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

  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print("背包 · 夏天露营", 14, 12)

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
