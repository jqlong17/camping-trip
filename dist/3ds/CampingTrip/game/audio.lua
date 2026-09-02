--[[ 露营之旅 — BGM/SFX/环境音（DEV-069 · docs/真机音频扩展-SPEC.md） ]]

local Audio = {}

local host

Audio.bgm = { title = nil, morning = nil, night = nil, current = nil }
Audio.amb = { birds = nil, crickets = nil, creek = nil, ocean = nil }

local sfx = {}
local consoleAudioRoot = "audio/3ds/"
local consoleAudioMode = "desktop_full_audio"
local consoleReady = false

local birdChirpT = 0
local BIRD_CHIRP_RADIUS = 2
local ambientSyncT = 0
local consoleAmbient = { src = nil, playing = false, volume = nil, kind = "none" }

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
  local function tryLoad(path, vol, sourceType)
    local ok, src = pcall(love.audio.newSource, assetPath(prefix .. path), sourceType or "stream")
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
    -- 真机海浪使用短 PCM 静态循环，避免并行 MP3 stream 长时间运行后锁死音频线程。
    Audio.amb.ocean = tryLoad("amb_ocean_waves.wav", 0.18, "static")
    appendLog("audio mode=" .. consoleAudioMode .. " bgm=3 amb=creek_prox,ocean_pcm_static")
    return
  end

  Audio.bgm.title = tagSrc(tryLoad("bgm_01_title.ogg") or tryLoad("bgm_01_title.mp3"), "title")
  Audio.bgm.morning = tagSrc(tryLoad("bgm_02_morning.ogg") or tryLoad("bgm_02_morning.mp3"), "morning")
  Audio.bgm.night = tagSrc(tryLoad("bgm_03_night.ogg") or tryLoad("bgm_03_night.mp3"), "night")
  Audio.amb.birds = tryLoad("amb_birds.mp3", 0.22)
  Audio.amb.crickets = tryLoad("amb_crickets.mp3", 0.26)
  Audio.amb.creek = tryLoad("amb_creek.mp3", 0.16)
  Audio.amb.ocean = tryLoad("amb_ocean_waves.ogg", 0.16)
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
  for _, src in pairs({ Audio.amb.birds, Audio.amb.crickets, Audio.amb.creek, Audio.amb.ocean }) do
    if src then
      if isConsole() then pcall(function() src:stop() end)
      elseif src:isPlaying() then src:stop() end
    end
  end
  consoleAmbient = { src = nil, playing = false, volume = nil, kind = "none" }
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
  local waterKind = Destinations.current().audio.water
  local waterSrc = waterKind == "ocean" and Audio.amb.ocean or Audio.amb.creek
  local inactiveWaterSrc = waterKind == "ocean" and Audio.amb.creek or Audio.amb.ocean

  local nearW = host.playerNearWater and host.playerNearWater(2)
  local oceanTimeGain = 0
  if waterKind == "ocean" then
    if Time.index() == 1 then oceanTimeGain = -0.02
    elseif Time.index() == 4 then oceanTimeGain = 0.03 end
  end
  if isConsole() then
    local shouldPlay = waterSrc ~= nil and (waterKind == "ocean" or nearW)
    local wantedVolume = waterKind == "ocean"
      and ((nearW and 0.22 or 0.14) + oceanTimeGain)
      or 0.22
    if consoleAmbient.src ~= waterSrc then
      if consoleAmbient.src and consoleAmbient.playing then
        pcall(function() consoleAmbient.src:stop() end)
      end
      consoleAmbient = { src = waterSrc, playing = false, volume = nil, kind = waterKind }
    end
    if shouldPlay and not consoleAmbient.playing then
      pcall(function()
        waterSrc:setVolume(wantedVolume)
        waterSrc:play()
      end)
      consoleAmbient.playing, consoleAmbient.volume = true, wantedVolume
      appendLog("audio ambient_start kind=" .. waterKind .. " mode=" .. (waterKind == "ocean" and "pcm_static" or "stream"))
    elseif shouldPlay and consoleAmbient.volume ~= wantedVolume then
      pcall(function() waterSrc:setVolume(wantedVolume) end)
      consoleAmbient.volume = wantedVolume
    elseif not shouldPlay and consoleAmbient.playing then
      pcall(function() waterSrc:stop() end)
      consoleAmbient.playing = false
      appendLog("audio ambient_stop kind=" .. waterKind)
    end
    return
  end

  if inactiveWaterSrc and inactiveWaterSrc:isPlaying() then inactiveWaterSrc:stop() end

  local nearB = host.playerNearBird and host.playerNearBird(3)
  local night = host.isNight and host.isNight()
  if waterSrc then
    if waterKind == "ocean" then
      waterSrc:setVolume((nearW and 0.24 or 0.12) + oceanTimeGain)
      ensureAmb(waterSrc)
    elseif nearW then
      waterSrc:setVolume(0.28)
      ensureAmb(waterSrc)
    else
      waterSrc:setVolume(0.08)
      ensureAmb(waterSrc)
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
  ambientSyncT = ambientSyncT - dt
  if ambientSyncT <= 0 then
    ambientSyncT = 0.75
    Audio.syncAmbient()
  end
end

function Audio.debugState()
  if not isConsole() then return "desktop" end
  return consoleAmbient.kind .. ":" .. (consoleAmbient.playing and "playing" or "stopped")
end

function Audio.ensureConsoleLoaded()
  if not isConsole() or consoleReady then return end
  consoleReady = true
  pcall(Audio.loadBgm)
  pcall(Audio.loadSfx)
end

return Audio
