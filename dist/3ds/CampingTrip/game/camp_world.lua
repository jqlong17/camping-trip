--[[ 露营之旅 — 营地生态与夜效 update/draw（DEV-068e P5 · docs/代码架构-SPEC.md） ]]

local CampWorld = {}

local host

local critters = { birds = {}, bugs = {}, birdT = 1.4, bugT = 2.2 }
local fishFX = { timer = 2.5, jumps = {} }
local nightFX = { stars = {}, meteors = {}, leaves = {}, meteorT = 1.6, leafT = 0.4 }
local splashFX = { drops = {} }

function CampWorld.bindHost(h)
  host = h
end

function CampWorld.getCritters() return critters end
function CampWorld.getFishFX() return fishFX end
function CampWorld.getNightFX() return nightFX end
function CampWorld.getSplashFX() return splashFX end

function CampWorld.resetCritters()
  critters.birds, critters.bugs = {}, {}
  critters.birdT, critters.bugT = 1.4, 2.2
end

function CampWorld.seedStars()
  nightFX.stars = {}
  local rng = love.math.newRandomGenerator(77)
  for i = 1, 36 do
    nightFX.stars[i] = {
      x = rng:random(6, host.TOP_W - 6),
      y = rng:random(4, i <= 22 and 72 or 108),
      p = rng:random() * 6.28,
      s = rng:random(1, 2),
      plus = (i % 7 == 0)
    }
  end
end

function CampWorld.spawnSplash(tx, ty)
  local TILE = host.TILE
  local baseX, baseY = tx * TILE + 4, ty * TILE + 10
  for _ = 1, 5 do
    splashFX.drops[#splashFX.drops + 1] = {
      x = baseX + love.math.random(-3, 8),
      y = baseY + love.math.random(-1, 3),
      vx = (love.math.random() - 0.5) * 28,
      vy = -12 - love.math.random() * 18,
      t = 0,
      life = 0.28 + love.math.random() * 0.18
    }
  end
end

function CampWorld.updateSplash(dt)
  local i = 1
  while i <= #splashFX.drops do
    local d = splashFX.drops[i]
    d.t = d.t + dt
    d.x = d.x + d.vx * dt
    d.y = d.y + d.vy * dt
    d.vy = d.vy + 70 * dt
    if d.t >= d.life then table.remove(splashFX.drops, i) else i = i + 1 end
  end
end

function CampWorld.drawSplash()
  for _, d in ipairs(splashFX.drops) do
    local a = 1 - d.t / d.life
    love.graphics.setColor(0.85, 0.95, 1.0, 0.35 + 0.5 * a)
    love.graphics.rectangle("fill", d.x, d.y, 2, 2)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function CampWorld.spawnFishJump()
  local map = host.CampMap.getMap()
  local TOP_W, TOP_H, TILE = host.TOP_W, host.TOP_H, host.TILE
  local rows = TOP_H / TILE
  local candidates = {}
  for y = 1, rows - 2 do
    for x = 0, TOP_W / TILE - 1 do
      if map[y] and host.CampMap.isDeepWater(map[y][x]) then
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

function CampWorld.updateFish(dt)
  fishFX.timer = fishFX.timer - dt
  if fishFX.timer <= 0 then
    fishFX.timer = 2.2 + love.math.random() * 2.8
    if host.getScene() == "play" and not host.getRitual() then
      CampWorld.spawnFishJump()
    end
  end
  for i = #fishFX.jumps, 1, -1 do
    local j = fishFX.jumps[i]
    j.t = j.t + dt
    if j.t >= j.life then table.remove(fishFX.jumps, i) end
  end
end

function CampWorld.drawFish()
  local assets = host.Assets.get()
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

function CampWorld.spawnBird()
  local treeTiles = host.CampMap.getTreeTiles()
  if #treeTiles == 0 or #critters.birds >= 3 then return end
  local tree = treeTiles[love.math.random(#treeTiles)]
  local gx, gy = host.CampMap.pickOpenNear(tree.x, tree.y)
  local kind = love.math.random(0, 2)
  local TILE = host.TILE
  critters.birds[#critters.birds + 1] = {
    kind = kind, state = "perch", t = 0,
    perchWait = 0.8 + love.math.random() * 1.4,
    treeX = tree.x, treeY = tree.y,
    gx = gx, gy = gy, hop = 0,
    x = tree.x * TILE + 2, y = tree.y * TILE - 10,
    face = (gx >= tree.x) and 1 or -1
  }
end

function CampWorld.spawnBug()
  if #critters.bugs >= (host.isNight() and 6 or 4) then return end
  local roll = love.math.random()
  local kind = "butterfly"
  if host.isNight() and roll > 0.12 then kind = "firefly"
  elseif roll > 0.7 then kind = "dragonfly" end
  local x, y
  if kind == "dragonfly" then
    y = 4 + love.math.random(0, 8)
    x = host.CampMap.creekCenterX(y)
  else
    x = love.math.random(2, 20)
    y = love.math.random(2, 12)
  end
  local TILE = host.TILE
  critters.bugs[#critters.bugs + 1] = {
    kind = kind, t = 0, life = 4 + love.math.random() * 5,
    ox = x * TILE + 4, oy = y * TILE + 4,
    x = x * TILE + 4, y = y * TILE + 4,
    vx = (love.math.random() < 0.5) and 18 or -18
  }
end

function CampWorld.updateCritters(dt)
  critters.birdT = critters.birdT - dt
  critters.bugT = critters.bugT - dt
  if critters.birdT <= 0 then
    critters.birdT = 4.5 + love.math.random() * 5
    if host.getScene() == "play" and not host.getRitual() and not host.isNight() then
      CampWorld.spawnBird()
    end
  end
  if critters.bugT <= 0 then
    critters.bugT = 3.2 + love.math.random() * 4
    if host.getScene() == "play" and not host.getRitual() then
      CampWorld.spawnBug()
    end
  end

  local TILE = host.TILE
  for i = #critters.birds, 1, -1 do
    local b = critters.birds[i]
    b.t = b.t + dt
    if b.state == "perch" then
      if b.t >= b.perchWait then b.state, b.t = "down", 0 end
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
      if u.x < 8 or u.x > host.TOP_W - 12 then u.vx = -u.vx end
    else
      u.x = u.ox + math.sin(u.t * 1.3) * 10
      u.y = u.oy + math.cos(u.t * 1.8) * 7
    end
    if u.t >= u.life then table.remove(critters.bugs, i) end
  end
end

function CampWorld.drawCritters()
  local assets = host.Assets.get()
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
      -- drawn in drawNightSky after tint
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

function CampWorld.spawnMeteor()
  nightFX.meteors[#nightFX.meteors + 1] = {
    x = love.math.random(20, 260), y = love.math.random(8, 36),
    vx = 110 + love.math.random() * 40, vy = 48 + love.math.random() * 20,
    t = 0, life = 0.55 + love.math.random() * 0.25
  }
end

function CampWorld.spawnLeaf()
  local night = host.isNight()
  nightFX.leaves[#nightFX.leaves + 1] = {
    x = love.math.random(-10, host.TOP_W), y = love.math.random(-8, 40),
    vx = (night and 28 or 16) + love.math.random() * 18,
    vy = 12 + love.math.random() * 16,
    t = 0, life = 3.2 + love.math.random() * 2,
    kind = love.math.random(0, 2)
  }
end

function CampWorld.updateNight(dt)
  nightFX.leafT = nightFX.leafT - dt
  if nightFX.leafT <= 0 then
    nightFX.leafT = (host.isNight() and 0.35 or 0.9) + love.math.random() * 0.5
    if host.getScene() == "play" then CampWorld.spawnLeaf() end
  end
  nightFX.meteorT = nightFX.meteorT - dt
  if nightFX.meteorT <= 0 then
    nightFX.meteorT = 6 + love.math.random() * 8
    if host.getScene() == "play" and host.isNight() then CampWorld.spawnMeteor() end
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
    if lf.t >= lf.life or lf.y > host.TOP_H + 8 then table.remove(nightFX.leaves, i) end
  end
end

function CampWorld.drawNightSky()
  local a = host.staticPlayFx and 0 or host.starAlpha()
  local titlePulse = host.getTitlePulse()
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
  if host.isNight() then
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
  if not host.staticPlayFx then
    for _, lf in ipairs(nightFX.leaves) do
      if host.isNight() then
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
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function CampWorld.onEnterNight()
  nightFX.meteorT = 0.35
  for _ = 1, 4 do CampWorld.spawnBug() end
end

return CampWorld
