--[[ 露营之旅 — BGM/SFX/环境音（DEV-069 · docs/真机音频扩展-SPEC.md） ]]

local Audio = {}

local host

Audio.bgm = { title = nil, morning = nil, night = nil, current = nil }
Audio.amb = { birds = nil, crickets = nil, creek = nil }

local sfx = {}
local consoleAudioRoot = "audio/3ds/"
local consoleAudioMode = "desktop_full_audio"
local consoleReady = false

local birdChirpT = 0
local BIRD_CHIRP_RADIUS = 2

local function assetPath(rel)
  return host and host.assetPath and host.assetPath(rel) or rel
end

local function appendLog(line)
  if host and host.appendLoadLog then host.appendLoadLog(line) end
end

local function isConsole()
  return host and host.isConsole
end

local sfxLabels = setmetatable({}, { __mode = "k" })

local function tagSrc(src, label)
  if src then sfxLabels[src] = label end
  return src
end

function Audio.bindHost(h)
  host = h
  if h and h.isConsole then
    consoleAudioMode = "console_prox_amb_bgm_switch"
  end
end

function Audio.consoleMode()
  return consoleAudioMode
end

function Audio.loadBgm()
  local prefix = isConsole() and consoleAudioRoot or "audio/"
  local function tryLoad(path, vol)
    local ok, src = pcall(love.audio.newSource, assetPath(prefix .. path), "stream")
    if ok and src then
      src:setLooping(true)
      src:setVolume(vol or 0.55)
      return src
    end
  end

  if isConsole() then
    Audio.bgm.title = tagSrc(tryLoad("bgm_01_title.mp3"), "title")
    Audio.bgm.morning = tagSrc(tryLoad("bgm_02_morning.mp3") or tryLoad("bgm_02_morning.ogg"), "morning")
    Audio.bgm.night = tagSrc(tryLoad("bgm_03_night.mp3"), "night")
    Audio.amb.creek = tryLoad("amb_creek.mp3", 0.22)
    appendLog("audio mode=" .. consoleAudioMode .. " bgm=3 amb=creek_prox")
    return
  end

  Audio.bgm.title = tagSrc(tryLoad("bgm_01_title.ogg") or tryLoad("bgm_01_title.mp3"), "title")
  Audio.bgm.morning = tagSrc(tryLoad("bgm_02_morning.ogg") or tryLoad("bgm_02_morning.mp3"), "morning")
  Audio.bgm.night = tagSrc(tryLoad("bgm_03_night.ogg") or tryLoad("bgm_03_night.mp3"), "night")
  Audio.amb.birds = tryLoad("amb_birds.mp3", 0.22)
  Audio.amb.crickets = tryLoad("amb_crickets.mp3", 0.26)
  Audio.amb.creek = tryLoad("amb_creek.mp3", 0.16)
end

function Audio.loadSfx()
  local function tryStatic(path, vol)
    local ok, src = pcall(love.audio.newSource, assetPath(path), "static")
    if ok and src then
      src:setVolume(vol or 0.5)
      return src
    end
  end
  sfx.step = tryStatic("audio/sfx_step.wav", 0.4)
  sfx.tent = tryStatic("audio/sfx_tent.wav", 0.55)
  sfx.pour = tryStatic("audio/sfx_pour.wav", 0.5)
  sfx.cup = tryStatic("audio/sfx_cup.wav", 0.55)
  sfx.bird = tryStatic("audio/sfx_bird.wav", 0.4)
  sfx.fan = tryStatic("audio/sfx_fan.wav", 0.45)
  sfx.lantern = tryStatic("audio/sfx_lantern.wav", 0.6)
  sfx.ui_move = tryStatic("audio/sfx_ui_move.wav", 0.35)
  sfx.ui_ok = tryStatic("audio/sfx_ui_ok.wav", 0.5)
end

function Audio.playSfx(name)
  local src = sfx[name]
  if not src then return end
  if isConsole() then
    pcall(function()
      if src:isPlaying() then return end
      src:play()
    end)
    return
  end
  local ok, inst = pcall(function() return src:clone() end)
  local voice = (ok and inst) and inst or src
  if voice == src then src:stop() end
  pcall(function() voice:setPitch(0.92 + love.math.random() * 0.16) end)
  voice:play()
end

function Audio.safeSwitchBgm(nextSrc)
  if not nextSrc then return end
  if nextSrc == Audio.bgm.current and nextSrc:isPlaying() then return end
  if Audio.bgm.current and Audio.bgm.current:isPlaying() then
    pcall(function() Audio.bgm.current:stop() end)
  end
  Audio.bgm.current = nextSrc
  if not nextSrc:isPlaying() then
    pcall(function() nextSrc:play() end)
  end
  appendLog("audio switch_bgm -> " .. (sfxLabels[nextSrc] or "?"))
end

function Audio.playBgm(src)
  if not src then return end
  if Audio.bgm.current == src and src:isPlaying() then return end
  if isConsole() then
    Audio.safeSwitchBgm(src)
    return
  end
  if Audio.bgm.current then Audio.bgm.current:stop() end
  Audio.bgm.current = src
  src:stop()
  src:play()
end

function Audio.stopBgm()
  if isConsole() then return end
  if Audio.bgm.current then Audio.bgm.current:stop() end
  Audio.bgm.current = nil
end

function Audio.stopAmb()
  if isConsole() then
    if Audio.amb.creek and Audio.amb.creek:isPlaying() then
      pcall(function() Audio.amb.creek:stop() end)
    end
    return
  end
  for _, src in pairs({ Audio.amb.birds, Audio.amb.crickets, Audio.amb.creek }) do
    if src then src:stop() end
  end
end

local function ensureAmb(src)
  if not src then return end
  if not src:isPlaying() then src:play() end
end

function Audio.syncAmbient()
  if not host or not host.getScene then return end
  if host.getScene() ~= "play" then
    Audio.stopAmb()
    return
  end
  if isConsole() then
    if Audio.amb.creek then
      if host.playerNearWater and host.playerNearWater(2) then
        ensureAmb(Audio.amb.creek)
      elseif Audio.amb.creek:isPlaying() then
        pcall(function() Audio.amb.creek:stop() end)
      end
    end
    return
  end
  local nearW = host.playerNearWater and host.playerNearWater(2)
  local nearB = host.playerNearBird and host.playerNearBird(3)
  local night = host.isNight and host.isNight()
  if Audio.amb.creek then
    if nearW then
      Audio.amb.creek:setVolume(0.28)
      ensureAmb(Audio.amb.creek)
    else
      Audio.amb.creek:setVolume(0.08)
      ensureAmb(Audio.amb.creek)
    end
  end
  if night then
    if Audio.amb.birds then Audio.amb.birds:stop() end
    ensureAmb(Audio.amb.crickets)
  else
    if Audio.amb.crickets then Audio.amb.crickets:stop() end
    if nearB and Audio.amb.birds then
      Audio.amb.birds:setVolume(0.34)
      ensureAmb(Audio.amb.birds)
    elseif Audio.amb.birds then
      Audio.amb.birds:setVolume(0.12)
      ensureAmb(Audio.amb.birds)
    end
  end
end

function Audio.syncPlayBgm()
  if not host or not host.getScene or host.getScene() ~= "play" then return end
  local night = host.isNight and host.isNight()
  if night and Audio.bgm.night then
    Audio.playBgm(Audio.bgm.night)
  elseif Audio.bgm.morning then
    Audio.playBgm(Audio.bgm.morning)
  end
  Audio.syncAmbient()
end

function Audio.syncSceneBgm()
  if not host or not host.getScene then return end
  local s = host.getScene()
  if s == "play" then
    Audio.syncPlayBgm()
    return
  end
  if s == "title" or s == "codex" or s == "about" or s == "homecoming" or s == "diary" then
    if Audio.bgm.title then Audio.playBgm(Audio.bgm.title) end
  elseif s == "prologue" or s == "depart" or s == "cast" then
    if Audio.bgm.morning then Audio.playBgm(Audio.bgm.morning) end
  end
end

function Audio.tick(dt, titlePulse)
  if not host or not host.getScene then return end
  if host.getScene() ~= "play" then return end
  birdChirpT = birdChirpT - dt
  if birdChirpT <= 0 and host.playerNearBird and host.playerNearBird(BIRD_CHIRP_RADIUS)
      and host.isNight and not host.isNight() then
    birdChirpT = 2.8 + love.math.random() * 1.5
    Audio.playSfx("bird")
  end
  if titlePulse and math.floor(titlePulse * 2) % 2 == 0 then
    Audio.syncAmbient()
  end
end

function Audio.ensureConsoleLoaded()
  if not isConsole() or consoleReady then return end
  consoleReady = true
  pcall(Audio.loadBgm)
  pcall(Audio.loadSfx)
end

return Audio
