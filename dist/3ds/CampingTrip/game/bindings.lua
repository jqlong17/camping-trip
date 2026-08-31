-- 模块装配集中点；避免 main.lua 堆叠 host 闭包。

local R = require("runtime")
local Session = require("session")
local Flow = require("scene_flow")
local Input = require("input")
local Cast = require("scenes.cast")
local StoryDraw = require("draw.story")
local PlayDraw = require("draw.play")
local Bindings = {}
local campHost

local function appendLoadLog(line)
  if not R.isConsole and not Playtest.wanted() then return end
  pcall(function() love.filesystem.append("load_report.txt", line .. "\n") end)
end

function Bindings.appendLoadLog(line)
  appendLoadLog(line)
end

function Bindings.bind()
  local common = {
    TOP_W = R.TOP_W, TOP_H = R.TOP_H, BOT_W = R.BOT_W, TILE = R.TILE,
    isConsole = R.isConsole,
    staticPlayFx = R.staticPlayFx,
    campCanvasEnabled = R.campCanvasEnabled,
    cheapWindFx = R.cheapWindFx,
    critterFx = R.critterFx,
    perfMode = R.perfMode,
    AP = AP,
    gear = R.gear,
    Assets = Assets,
    CampMap = CampMap,
    CampPreload = CampPreload,
    CampWorld = CampWorld,
    CampTiles = CampTiles,
    appendLoadLog = appendLoadLog,
    getAssets = Assets.get,
    getScene = function() return R.scene end,
    getRitual = function() return R.ritual end,
    getPlayer = function() return R.player end,
    getLanternOn = function() return R.lanternOn end,
    getTentOpen = function() return R.tentOpen end,
    getTentPos = function() return R.tentPos end,
    getTentStyle = function() return R.tentColorI or 1, R.tentStyleI or 1, R.tentDoorI or 1 end,
    getFruitTrees = function() return State.trip.fruitTrees end,
    getTitlePulse = function() return R.titlePulse end,
    getWaterPhase = function() return R.waterPhase end,
    isNight = Time.isNight,
    starAlpha = Time.starAlpha,
    timeLabel = Time.slotName,
    getTimeTint = Time.tintRow,
    drawPlayerAt = PlayDraw.playerAt,
    drawWorldFx = PlayDraw.worldFx,
    drawRitualOverlay = PlayDraw.ritualOverlay,
    drawToast = StoryDraw.toast,
    buildCampGroundCanvas = CampTiles.buildCampGroundCanvas,
    getCupStyle = function() return R.cupStyle end,
    resetTent = function() R.tentOpen, R.tentPos = false, nil end,
    onBuildStart = CampWorld.resetCritters,
  }
  campHost = setmetatable(common, {
    __index = function(_, key)
      if key == "uiFont" then return R.uiFont end
    end,
  })

  Assets.bindHost({
    isConsole = R.isConsole,
    playtestWanted = Playtest.wanted,
    appendLoadLog = appendLoadLog,
    AP = AP,
  })
  CampMap.bindHost(campHost)
  CampPreload.bindHost(campHost)
  CampWorld.bindHost(campHost)
  CampTiles.bindHost(campHost)
  CampRender.bindHost(campHost)

  Time.bindHost({
    say = Toast.say,
    appendLoadLog = appendLoadLog,
    syncPlayBgm = Audio.syncPlayBgm,
    onEnterNight = function()
      local nightFX = CampWorld.getNightFX()
      nightFX.meteorT = 0.35
      CampWorld.onEnterNight()
      for _ = 1, 4 do CampWorld.spawnBug() end
    end,
    setCanGoHome = function(v) R.canGoHome = v end,
  })

  local helpers = {
    say = Toast.say,
    ensureStory = Assets.ensureStory,
    ensureCast = Assets.ensureCast,
    ensureWalk = Assets.ensureWalk,
    ensureRitual = Assets.ensureRitual,
  }
  Session.bindHost(helpers)
  Flow.bindHost(helpers)
  Input.bindHost(helpers)
  Cast.bindHost(helpers)

  local playHost = {
    confirmMenu = Flow.confirmMenu,
    advancePrologue = Flow.advancePrologue,
    confirmCast = Flow.confirmCast,
    advanceDepart = Flow.advanceDepart,
    tryMove = Session.tryMove,
    tryUseGear = Session.tryUseGear,
    goHomecoming = Flow.goHomecoming,
    advanceHome = Flow.advanceHome,
    finishDiary = Flow.finishDiary,
    goTitle = Flow.goTitle,
    moveCodex = function(delta) require("scenes.codex").move(R, delta) end,
    creekCenterX = CampMap.creekCenterX,
    spawnBird = CampWorld.spawnBird,
    spawnBug = CampWorld.spawnBug,
    spawnMeteor = CampWorld.spawnMeteor,
    spawnLeaf = CampWorld.spawnLeaf,
    drinkFromCup = Session.drinkFromCup,
    applyCupIcon = Session.applyCupIcon,
    cupStylesCount = #AP.CUP_STYLES,
  }
  setmetatable(playHost, {
    __index = function(_, key)
      if key == "scene" then return R.scene
      elseif key == "menuIndex" then return R.menuIndex
      elseif key == "selected" then return R.selected
      elseif key == "tentOpen" then return R.tentOpen
      elseif key == "tentPos" then return R.tentPos or { x = R.player.x, y = R.player.y }
      elseif key == "tentColorI" then return R.tentColorI
      elseif key == "tentStyleI" then return R.tentStyleI
      elseif key == "tentDoorI" then return R.tentDoorI
      elseif key == "ritual" then return R.ritual
      elseif key == "drippedOnce" then return R.drippedOnce
      elseif key == "coffeeCups" then return R.coffeeCups
      elseif key == "teaCups" then return R.teaCups
      elseif key == "cupStyle" then return R.cupStyle
      elseif key == "cupPick" then return R.cupPick
      elseif key == "lanternOn" then return R.lanternOn
      elseif key == "player" then return R.player
      elseif key == "gear" then return R.gear
      elseif key == "codex" then return R.codex
      elseif key == "critters" then return CampWorld.getCritters()
      elseif key == "splashFX" then return CampWorld.getSplashFX()
      elseif key == "nightFX" then return CampWorld.getNightFX()
      elseif key == "firepit" then return CampMap.getFirepit() end
    end,
    __newindex = function(_, key, value)
      if key == "menuIndex" then R.menuIndex = value
      elseif key == "selected" then R.selected = value
      elseif key == "canGoHome" then R.canGoHome = value
      elseif key == "cupStyle" then R.cupStyle = value
      elseif key == "cupPick" then R.cupPick = value
      else rawset(playHost, key, value) end
    end,
  })
  Playtest.bindHost(playHost)

  Audio.bindHost({
    isConsole = R.isConsole,
    assetPath = Assets.path,
    appendLoadLog = appendLoadLog,
    getScene = function() return R.scene end,
    playerNearWater = function(radius)
      radius = radius or 2
      for dy = -radius, radius do
        for dx = -radius, radius do
          local tile = CampMap.tileAt(R.player.x + dx, R.player.y + dy)
          if tile == 2 or tile == 8 then return true end
        end
      end
      return false
    end,
    playerNearBird = function(radius)
      radius = radius or 3
      for _, bird in ipairs(CampWorld.getCritters().birds or {}) do
        local bx, by = (bird.x or 0) / R.TILE, (bird.y or 0) / R.TILE
        if math.abs(bx - R.player.x) + math.abs(by - R.player.y) <= radius then return true end
      end
      return false
    end,
    isNight = Time.isNight,
  })
end

return Bindings
