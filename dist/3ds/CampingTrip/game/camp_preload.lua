--[[ 露营之旅 — 营地贴图按需预加载（DEV-068e P4 · docs/代码架构-SPEC.md） ]]

local CampPreload = {}

local host
local campReady = false
local state = { active = false, steps = nil, index = 1, startedAt = 0, useStaticBase = false }
local loadedDestinationId = nil

function CampPreload.bindHost(h)
  host = h
end

function CampPreload.ready()
  return campReady
end

function CampPreload.active()
  return state.active
end

function CampPreload.reset(destinationId)
  campReady = false
  loadedDestinationId = destinationId
  state = { active = false, steps = nil, index = 1, startedAt = 0, useStaticBase = false }
  local a = host and host.Assets.get() or {}
  for _, key in ipairs({
    "grass", "water", "shallow", "trees", "bushes", "flowers", "stones", "dirt",
    "campStaticBase", "coastOceanSunrise", "coastOceanSunset", "forestDistantCanopy",
    "reed", "log", "stump", "pier", "nest", "shore", "dirtFringe",
    "fish", "birds", "butterfly", "dragonfly", "firefly", "crab",
    "tentOpen", "tent", "tentPacked", "firepit", "brewKit", "steam",
  }) do a[key] = nil end
  if host and host.CampTiles and host.CampTiles.resetCanvas then host.CampTiles.resetCanvas() end
  if collectgarbage then pcall(collectgarbage, "collect") end
end

local function makeSteps()
  local steps = {}
  local function add(fn) steps[#steps + 1] = fn end
  local load = function(p) return host.Assets.load(p) end
  local assets = function() return host.Assets.get() end
  local AP = host.AP
  local pack = Destinations.current()

  if pack.id == "coast" then
    add(function()
      local a = assets()
      a.grass, a.water, a.shallow, a.dirt = {}, {}, {}, {}
      a.trees, a.bushes, a.flowers, a.stones = {}, {}, {}, {}
      a.campStaticBase = host.staticPlayFx and load(AP.sceneCamp("coast_static_base.png")) or nil
      a.coastOceanSunrise = load(AP.sceneCamp("coast_ocean_sunrise.png"))
      a.coastOceanSunset = load(AP.sceneCamp("coast_ocean_sunset.png"))
      state.useStaticBase = host.staticPlayFx and a.campStaticBase ~= nil
    end)
    add(function()
      if state.useStaticBase then return end
      local a = assets()
      for i = 0, 3 do a.grass[i] = load(AP.sceneCamp("tile_sand" .. i .. ".png")) end
      for i = 4, 7 do a.grass[i] = a.grass[i % 4] end
      for i = 0, 3 do
        a.water[i] = load(AP.sceneCamp("tile_ocean" .. i .. ".png"))
        a.shallow[i] = a.water[i]
      end
      a.dirt[0] = load(AP.sceneCamp("tile_wet_sand.png"))
      for i = 1, 3 do a.dirt[i] = a.dirt[0] end
    end)
    add(function()
      if state.useStaticBase then return end
      local a = assets()
      a.trees[0] = load(AP.sceneCamp("coast_pine.png"))
      for i = 1, 11 do a.trees[i] = a.trees[0] end
      a.bushes[0] = load(AP.sceneCamp("salt_shrub.png"))
      for i = 1, 2 do a.bushes[i] = a.bushes[0] end
      a.flowers[0] = load(AP.sceneCamp("beach_grass.png"))
      for i = 1, 3 do a.flowers[i] = a.flowers[0] end
      a.stones[0] = load(AP.sceneCamp("reef_rock.png"))
      for i = 1, 2 do a.stones[i] = a.stones[0] end
      a.log = load(AP.sceneCamp("driftwood.png"))
    end)
    add(function()
      local a = assets()
      a.shadow = load(AP.shared("prop_shadow.png"))
      a.shadowSm = load(AP.shared("prop_shadow_sm.png"))
      a.shadowTree = load(AP.shared("prop_shadow_tree.png"))
      a.birds = {
        [0] = { perch = load(AP.sceneWorld("seabird_0.png")), fly = {
          load(AP.sceneWorld("seabird_0.png")), load(AP.sceneWorld("seabird_1.png"))
        } }
      }
      a.crab = { load(AP.sceneWorld("crab_0.png")), load(AP.sceneWorld("crab_1.png")) }
      a.fish, a.butterfly, a.firefly = {}, {}, {}
    end)
    add(function()
      local a = assets()
      a.tentOpen = load(AP.forestCamp("tent_open_hd.png"))
      a.tent, a.tentPacked = a.tentOpen, load(AP.forestCamp("tile_tent_packed.png"))
      a.firepit = load(AP.forestCamp("prop_firepit.png"))
      a.steam = {}
    end)
    add(function()
      host.Assets.ensureCast(1)
      local a = assets()
      a.player = a.cast[1] or load(AP.shared("player.png"))
      for _, g in ipairs(host.gear) do g.icon = load(AP.gearPath(g.id == "cup" and "cup" or g.id)) end
      a.cupIcons = {}
      for _, st in ipairs(AP.CUP_STYLES) do a.cupIcons[#a.cupIcons + 1] = load(AP.cupPath(st.file)) end
      a.fruitIcon = load(AP.forestWorld("fruit_icon.png"))
      a.fishIcons = {
        ayu = load(AP.forestWorld("fish_icon_ayu.png")),
        trout = load(AP.forestWorld("fish_icon_trout.png")),
        carp = load(AP.forestWorld("fish_icon_carp.png")),
      }
    end)
    add(function()
      if collectgarbage then pcall(collectgarbage, "collect") end
      if host.buildCampGroundCanvas then host.buildCampGroundCanvas() end
    end)
    return steps
  end

  add(function()
    local a = assets()
    a.grass, a.water, a.shallow, a.trees = {}, {}, {}, {}
    a.bushes, a.flowers, a.stones, a.dirt = {}, {}, {}, {}
    a.campStaticBase = host.staticPlayFx and load(AP.forestCamp("camp_static_base.png")) or nil
    state.useStaticBase = host.staticPlayFx and a.campStaticBase ~= nil
    a.forestDistantCanopy = state.useStaticBase and nil
      or load(AP.forestCamp("forest_distant_canopy.png"))
  end)
  add(function()
    if state.useStaticBase then return end
    local a = assets()
    for i = 0, 3 do a.grass[i] = load(AP.forestCamp("tile_grass" .. i .. ".png")) end
  end)
  add(function()
    if state.useStaticBase then return end
    local a = assets()
    for i = 4, 7 do a.grass[i] = load(AP.forestCamp("tile_grass" .. i .. ".png")) end
  end)
  add(function()
    if state.useStaticBase then return end
    local a = assets()
    for i = 0, 3 do a.dirt[i] = load(AP.forestCamp("tile_dirt" .. i .. ".png")) end
  end)
  add(function()
    if state.useStaticBase then
      local a = assets()
      a.water, a.shallow = {}, {}
      return
    end
    local a = assets()
    for i = 0, 3 do a.water[i] = load(AP.forestCamp("tile_water" .. i .. ".png")) end
    for i = 0, 3 do a.shallow[i] = load(AP.forestCamp("tile_shallow" .. i .. ".png")) end
  end)
  add(function()
    if state.useStaticBase then return end
    local a = assets()
    for i = 0, 3 do a.trees[i] = load(AP.shared("tile_tree" .. i .. ".png")) end
  end)
  add(function()
    if state.useStaticBase then return end
    local a = assets()
    for i = 4, 7 do a.trees[i] = load(AP.shared("tile_tree" .. i .. ".png")) end
  end)
  add(function()
    if state.useStaticBase then return end
    local a = assets()
    for i = 8, 11 do a.trees[i] = load(AP.shared("tile_tree" .. i .. ".png")) end
  end)
  add(function()
    if state.useStaticBase then return end
    local a = assets()
    for i = 0, 2 do a.bushes[i] = load(AP.shared("tile_bush" .. i .. ".png")) end
    for i = 0, 3 do a.flowers[i] = load(AP.shared("prop_flower" .. i .. ".png")) end
  end)
  add(function()
    if state.useStaticBase then return end
    local a = assets()
    for i = 0, 2 do a.stones[i] = load(AP.shared("tile_stone" .. i .. ".png")) end
  end)
  add(function()
    if state.useStaticBase then return end
    local a = assets()
    a.reed = load(AP.forestCamp("prop_reed.png"))
    a.log = load(AP.shared("prop_log.png"))
    a.stump = load(AP.shared("prop_stump.png"))
    a.pier = load(AP.forestCamp("prop_pier.png"))
  end)
  add(function()
    local a = assets()
    a.shadow = load(AP.shared("prop_shadow.png"))
    a.shadowSm = load(AP.shared("prop_shadow_sm.png"))
    a.shadowTree = load(AP.shared("prop_shadow_tree.png"))
  end)
  add(function()
    local a = assets()
    if not host.critterFx then
      a.fish, a.birds, a.butterfly, a.firefly = {}, {}, {}, {}
      return
    end
    a.fish = {}
    for i = 0, 4 do a.fish[i] = load(AP.forestWorld("fish_" .. i .. ".png")) end
  end)
  add(function()
    if not host.critterFx then return end
    local a = assets()
    a.birds = {}
    for i = 0, 2 do
      a.birds[i] = {
        perch = load(AP.forestWorld("bird_" .. i .. "_perch.png")),
        fly = {
          load(AP.forestWorld("bird_" .. i .. "_fly0.png")),
          load(AP.forestWorld("bird_" .. i .. "_fly1.png"))
        }
      }
    end
  end)
  add(function()
    if not host.critterFx then return end
    local a = assets()
    a.butterfly = { load(AP.forestWorld("butterfly_0.png")), load(AP.forestWorld("butterfly_1.png")) }
    a.dragonfly = load(AP.forestWorld("dragonfly.png"))
    a.firefly = { load(AP.forestWorld("firefly_0.png")), load(AP.forestWorld("firefly_1.png")) }
  end)
  add(function()
    local a = assets()
    if state.useStaticBase then
      a.nest, a.shore, a.dirtFringe = nil, nil, nil
      return
    end
    a.nest = load(AP.forestWorld("nest.png"))
    a.shore = {
      E = load(AP.forestCamp("shore_E.png")), W = load(AP.forestCamp("shore_W.png")),
      N = load(AP.forestCamp("shore_N.png")), S = load(AP.forestCamp("shore_S.png")),
      SE = load(AP.forestCamp("shore_SE.png")), NE = load(AP.forestCamp("shore_NE.png")),
      NW = load(AP.forestCamp("shore_NW.png")), SW = load(AP.forestCamp("shore_SW.png"))
    }
    a.dirtFringe = {
      N = load(AP.forestCamp("dirt_fringe_N.png")),
      S = load(AP.forestCamp("dirt_fringe_S.png")),
      E = load(AP.forestCamp("dirt_fringe_E.png")),
      W = load(AP.forestCamp("dirt_fringe_W.png"))
    }
  end)
  add(function()
    local a = assets()
    -- 地图使用独立 96×72 高清 CKE 资源；gear/tent.png 只供背包目录。
    a.tentOpen = load(AP.forestCamp("tent_open_hd.png"))
    a.tent = a.tentOpen
    a.tentPacked = load(AP.forestCamp("tile_tent_packed.png"))
    a.firepit = load(AP.forestCamp("prop_firepit.png"))
  end)
  add(function()
    local a = assets()
    if host.staticPlayFx then
      a.steam = {}
    else
      a.brewKit = load(AP.forestWorld("brew_kit.png"))
      a.steam = {
        load(AP.forestWorld("steam_0.png")),
        load(AP.forestWorld("steam_1.png")),
        load(AP.forestWorld("steam_2.png"))
      }
    end
  end)
  add(function()
    host.Assets.ensureCast(1)
    local a = assets()
    a.player = a.cast[1] or load(AP.shared("player.png"))
  end)
  add(function()
    local a = assets()
    for _, g in ipairs(host.gear) do
      g.icon = load(AP.gearPath(g.id == "cup" and "cup" or g.id))
    end
    a.cupIcons = {}
    for _, st in ipairs(AP.CUP_STYLES) do
      a.cupIcons[#a.cupIcons + 1] = load(AP.cupPath(st.file))
    end
    if a.cupIcons[1] then
      local cupStyle = host.getCupStyle and host.getCupStyle() or 1
      for _, g in ipairs(host.gear) do
        if g.id == "cup" then g.icon = a.cupIcons[cupStyle] or g.icon end
      end
    end
    a.fruitIcon = load(AP.forestWorld("fruit_icon.png"))
    a.fishIcons = {
      ayu = load(AP.forestWorld("fish_icon_ayu.png")),
      trout = load(AP.forestWorld("fish_icon_trout.png")),
      carp = load(AP.forestWorld("fish_icon_carp.png"))
    }
  end)
  add(function()
    if collectgarbage then pcall(collectgarbage, "collect") end
    if host.buildCampGroundCanvas then host.buildCampGroundCanvas() end
  end)

  return steps
end

function CampPreload.begin(reason)
  if loadedDestinationId ~= Destinations.currentId() then CampPreload.reset(Destinations.currentId()) end
  if campReady or state.active then return end
  state.active = true
  state.index = 1
  state.startedAt = love.timer.getTime()
  state.useStaticBase = false
  state.steps = makeSteps()
  if host and host.appendLoadLog then
    host.appendLoadLog("camp_preload_begin reason=" .. tostring(reason or "unknown") .. " mode=" .. tostring(host.perfMode))
  end
end

function CampPreload.runSlice(maxSteps)
  if campReady then return true end
  CampPreload.begin("forced")
  maxSteps = maxSteps or 1
  for _ = 1, maxSteps do
    local step = state.steps and state.steps[state.index]
    if not step then
      campReady = true
      state.active = false
      if host and host.appendLoadLog then
        host.appendLoadLog(string.format(
          "ensureCamp done fails=%d durationMs=%.1f mode=%s staticBase=%s steps=%d",
          host.Assets.failCount(),
          (love.timer.getTime() - state.startedAt) * 1000,
          tostring(host.perfMode),
          tostring(state.useStaticBase),
          state.index - 1
        ))
      end
      return true
    end
    local stepIndex = state.index
    local stepStartedAt = love.timer.getTime()
    local ok, err = pcall(step)
    if host and host.appendLoadLog then
      host.appendLoadLog(string.format(
        "camp_preload_step index=%d durationMs=%.1f ok=%s",
        stepIndex,
        (love.timer.getTime() - stepStartedAt) * 1000,
        tostring(ok)
      ))
    end
    if not ok and host and host.appendLoadLog then
      host.appendLoadLog("camp_preload_step_fail index=" .. state.index .. " err=" .. tostring(err))
    end
    state.index = state.index + 1
  end
  return false
end

function CampPreload.ensure()
  while not CampPreload.runSlice(99) do end
end

return CampPreload
