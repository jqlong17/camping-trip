--[[ 露营之旅 — 营地地砖/道具绘制（DEV-068e P6 · docs/代码架构-SPEC.md） ]]

local CampTiles = {}

local host
local campGroundCanvas = nil
local campGroundCanvasTried = false

function CampTiles.bindHost(h)
  host = h
end

function CampTiles.getCanvas()
  return campGroundCanvas
end

function CampTiles.resetCanvas()
  campGroundCanvas = nil
  campGroundCanvasTried = false
end

function CampTiles.drawWaterSparkles(px, py, tx, ty)
  local waterPhase = host.getWaterPhase()
  local phase = waterPhase * 3 + tx * 1.7 + ty * 2.3
  local n = 1 + ((tx * 3 + ty) % 2)
  for i = 0, n - 1 do
    local ox = (math.floor(phase + i * 5) % 12)
    local oy = 3 + ((tx + ty + i * 2) % 8)
    local twinkle = 0.35 + 0.55 * (0.5 + 0.5 * math.sin(phase * 2 + i))
    love.graphics.setColor(1, 1, 1, twinkle)
    love.graphics.rectangle("fill", px + ox, py + oy, 1, 1)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function CampTiles.drawGround(t, px, py, tx, ty)
  local assets = host.Assets.get()
  local CM = host.CampMap
  local waterPhase = host.getWaterPhase()
  love.graphics.setColor(1, 1, 1, 1)
  if t == 2 or t == 8 then
    local wi = (math.floor(waterPhase) + tx * 5 + ty * 3) % 4
    local sheet = (t == 8 and assets.shallow and assets.shallow[wi]) or (assets.water and assets.water[wi])
    if sheet then love.graphics.draw(sheet, px, py)
    else
      love.graphics.setColor(t == 8 and 0.4 or 0.2, 0.55, 0.5)
      love.graphics.rectangle("fill", px, py, host.TILE, host.TILE)
    end
    CampTiles.drawWaterSparkles(px, py, tx, ty)
    love.graphics.setColor(1, 1, 1, 1)
    return
  end
  -- 帐篷格(5)只表示道具层；地面仍用搭帐前的土地，避免误画成整格绿草
  local ground = t
  if t == 5 then
    ground = 7
    if host.getTentPos then
      local tp = host.getTentPos()
      if tp and tp.x == tx and tp.y == ty and tp.ground then
        ground = tp.ground
      end
    end
  end
  local useDirt = (Destinations.currentId() == "forest" and ground == 7)
    or (Destinations.currentId() == "coast" and ground == 9)
  if useDirt and assets.dirt and assets.dirt[(tx * 3 + ty * 5) % 4] then
    love.graphics.draw(assets.dirt[(tx * 3 + ty * 5) % 4], px, py)
    if assets.dirtFringe then
      if CM.isMeadow(CM.tileAt(tx, ty - 1)) and assets.dirtFringe.N then love.graphics.draw(assets.dirtFringe.N, px, py) end
      if CM.isMeadow(CM.tileAt(tx, ty + 1)) and assets.dirtFringe.S then love.graphics.draw(assets.dirtFringe.S, px, py) end
      if CM.isMeadow(CM.tileAt(tx + 1, ty)) and assets.dirtFringe.E then love.graphics.draw(assets.dirtFringe.E, px, py) end
      if CM.isMeadow(CM.tileAt(tx - 1, ty)) and assets.dirtFringe.W then love.graphics.draw(assets.dirtFringe.W, px, py) end
    end
  else
    local grass = assets.grass[(tx * 17 + ty * 31) % 8]
    if grass then love.graphics.draw(grass, px, py)
    else love.graphics.setColor(0.43, 0.66, 0.28); love.graphics.rectangle("fill", px, py, host.TILE, host.TILE) end
  end
  if not assets.shore then return end
  love.graphics.setColor(1, 1, 1, 1)
  local E = CM.isWater(CM.tileAt(tx + 1, ty))
  local W = CM.isWater(CM.tileAt(tx - 1, ty))
  local N = CM.isWater(CM.tileAt(tx, ty - 1))
  local S = CM.isWater(CM.tileAt(tx, ty + 1))
  local covered = {}
  for _, corner in ipairs({
    { "NE", "N", "E", N and E }, { "NW", "N", "W", N and W },
    { "SE", "S", "E", S and E }, { "SW", "S", "W", S and W },
  }) do
    if corner[4] and assets.shore[corner[1]] then
      love.graphics.draw(assets.shore[corner[1]], px, py)
      covered[corner[2]], covered[corner[3]] = true, true
    end
  end
  for _, edge in ipairs({ { "N", N }, { "S", S }, { "E", E }, { "W", W } }) do
    if edge[2] and not covered[edge[1]] and assets.shore[edge[1]] then
      love.graphics.draw(assets.shore[edge[1]], px, py)
    end
  end
end

function CampTiles.drawDecalsForRow(rowY)
  local assets = host.Assets.get()
  love.graphics.setColor(1, 1, 1, 1)
  local TILE = host.TILE
  for _, d in ipairs(host.CampMap.getDecalRows()[rowY] or {}) do
    local px, py = d.x * TILE, d.y * TILE
    if d.kind == "flower" and assets.flowers then
      local img = assets.flowers[d.v % 4]
      if img then love.graphics.draw(img, px + 3, py + 4) end
    elseif d.kind == "reed" and assets.reed then
      love.graphics.draw(assets.reed, px + 2, py + TILE - assets.reed:getHeight())
    elseif d.kind == "log" and assets.log then
      love.graphics.draw(assets.log, px - 2, py + 6)
    elseif d.kind == "stump" and assets.stump then
      CampTiles.drawDropShadow(px, py, "sm")
      love.graphics.draw(assets.stump, px + (TILE - assets.stump:getWidth()) / 2, py + TILE - assets.stump:getHeight())
    elseif d.kind == "step" and assets.stones then
      local img = assets.stones[d.v % 3]
      if img then love.graphics.draw(img, px + 2, py + 6) end
    elseif d.kind == "pier" and assets.pier then
      love.graphics.draw(assets.pier, px + TILE - assets.pier:getWidth() + 4, py + 4)
    elseif d.kind == "beach-grass" and assets.flowers and assets.flowers[0] then
      local img = assets.flowers[0]
      love.graphics.draw(img, px + (TILE - img:getWidth()) / 2, py + TILE - img:getHeight())
    elseif d.kind == "driftwood" and assets.log then
      love.graphics.draw(assets.log, px + (TILE - assets.log:getWidth()) / 2, py + TILE - assets.log:getHeight())
    end
  end
end

function CampTiles.drawDropShadow(px, py, kind)
  local assets = host.Assets.get()
  local TILE = host.TILE
  local img, ox, oy = assets.shadow, 4, 2
  if kind == "sm" then
    img, ox, oy = assets.shadowSm, 3, 2
  elseif kind == "tree" then
    img, ox, oy = assets.shadowTree or assets.shadow, 5, 3
  end
  if not img then return end
  if Destinations.currentId() == "coast" then
    -- 日出从左侧来光，影子向右；日落反向且略长。
    if Time.index() == 1 then ox = ox + 3
    elseif Time.index() == 4 then ox = ox - 7 end
  end
  local iw, ih = img:getWidth(), img:getHeight()
  love.graphics.setColor(1, 1, 1, 0.92)
  love.graphics.draw(img, px + TILE / 2 - iw / 2 + ox, py + TILE - ih + oy)
  love.graphics.setColor(1, 1, 1, 1)
end

function CampTiles.drawProp(t, px, py, tx, ty)
  local assets = host.Assets.get()
  local CM = host.CampMap
  local TILE = host.TILE
  local titlePulse = host.getTitlePulse()
  love.graphics.setColor(1, 1, 1, 1)
  if t == 3 then
    local tree = assets.trees and assets.trees[CM.treeVariant(tx, ty)]
    if tree then
      local iw, ih = tree:getWidth(), tree:getHeight()
      CampTiles.drawDropShadow(px, py, "tree")
      local sway = host.cheapWindFx and
        (math.sin(titlePulse * 1.5 + tx * 0.7 + ty) * (host.isNight() and 1.2 or 0.55)) or 0
      love.graphics.draw(tree, px + (TILE - iw) / 2 + sway, py + TILE - ih)
      if assets.nest and CM.getNestTiles()[CM.tileKey(tx, ty)] then
        love.graphics.draw(assets.nest, px + (TILE - assets.nest:getWidth()) / 2 + 2 + sway, py - 4)
      end
      local fruitTrees = host.getFruitTrees and host.getFruitTrees() or {}
      local left = fruitTrees[CM.tileKey(tx, ty)]
      if left and left > 0 then
        love.graphics.setColor(0.92, 0.28, 0.22, 1)
        for i = 1, left do
          love.graphics.rectangle("fill", px + 4 + i * 3 + sway, py + 2 + (i % 2), 3, 3)
        end
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  elseif t == 6 then
    local bush = assets.bushes and assets.bushes[(tx + ty) % 3]
    if bush then
      CampTiles.drawDropShadow(px, py, "sm")
      local sway = host.cheapWindFx and math.sin(titlePulse * 1.8 + tx) * 0.45 or 0
      love.graphics.draw(bush, px + (TILE - bush:getWidth()) / 2 + sway, py + TILE - bush:getHeight())
    end
  elseif t == 4 then
    local stone = assets.stones and assets.stones[(tx + ty) % 3]
    if stone then
      CampTiles.drawDropShadow(px, py, "sm")
      love.graphics.draw(stone, px, py + TILE - stone:getHeight())
    end
  elseif t == 5 then
    local tentOpen = host.getTentOpen and host.getTentOpen()
    local img = tentOpen and (assets.tentOpen or assets.tent) or assets.tentPacked
    if img then
      love.graphics.setColor(1, 1, 1, 1)
      local iw, ih = img:getWidth(), img:getHeight()
      CampTiles.drawDropShadow(px, py, "sm")
      -- 展开态使用独立 96×72 CKE 资源，以 0.5× 显示 2× 像素密度：
      -- 有效轮廓 92×68px → 46×34px，约 2.9×2.1 格。
      -- 收纳卷仍保持原尺寸，避免未展开时像一顶完整帐篷。
      local scale = tentOpen and 0.5 or math.min(1, (TILE * 1.75) / math.max(iw, 1))
      -- 高清展开图实体 bbox 底边 y=70/72；收纳图为 y=18/20。
      -- 始终按实体底边落地，不按透明画布底部，避免悬空。
      local opaqueBottom = tentOpen and 70 or (ih * 18 / 20)
      love.graphics.draw(
        img,
        px + (TILE - iw * scale) / 2,
        py + TILE + 1 - opaqueBottom * scale,
        0, scale, scale
      )
    end
  end
end

function CampTiles.drawCampGroundLayer(cols, rows)
  local assets = host.Assets.get()
  local map = host.CampMap.getMap()
  local TILE = host.TILE
  if assets.campStaticBase then
    love.graphics.setColor(1, 1, 1, 1)
    host.Assets.drawFitted(assets.campStaticBase, 0, 0, host.TOP_W, host.TOP_H)
    return
  end
  for y = 0, rows - 1 do
    for x = 0, cols - 1 do
      CampTiles.drawGround(map[y][x], x * TILE, y * TILE, x, y)
    end
    CampTiles.drawDecalsForRow(y)
  end
end

function CampTiles.drawCreekLite()
  local assets = host.Assets.get()
  if not assets.campStaticBase then return end
  -- 海边底图使用一整条连续文生图浪带；旧的逐格闪点与等距白条会
  -- 重新暴露 16px 网格，看起来像棋盘和人造栏杆，因此不再叠加。
  if Destinations.currentId() == "coast" then return end
  local TILE = host.TILE
  local waterPhase = host.getWaterPhase()
  for _, wt in ipairs(host.CampMap.getWaterTiles()) do
    local px, py = wt.x * TILE, wt.y * TILE
    CampTiles.drawWaterSparkles(px, py, wt.x, wt.y)
    if ((wt.x + wt.y + math.floor(waterPhase)) % 5) == 0 then
      love.graphics.setColor(0.85, 0.95, 1.0, 0.45)
      love.graphics.rectangle("fill", px + 2, py + 1, 2, 1)
      love.graphics.rectangle("fill", px + 9, py + TILE - 3, 3, 1)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function CampTiles.drawFruitOverlays()
  local assets = host.Assets.get()
  if not assets.campStaticBase then return end
  local TILE = host.TILE
  local fruitTrees = host.getFruitTrees and host.getFruitTrees() or {}
  for key, left in pairs(fruitTrees) do
    if left and left > 0 then
      local x = tonumber(key:match("^(%d+):")) or 0
      local y = tonumber(key:match(":(%d+)$")) or 0
      local px, py = x * TILE, y * TILE
      love.graphics.setColor(0.92, 0.28, 0.22, 1)
      for i = 1, left do
        love.graphics.rectangle("fill", px + 4 + i * 3, py + 2 + (i % 2), 3, 3)
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function CampTiles.buildCampGroundCanvas()
  if campGroundCanvasTried or not host.campCanvasEnabled then
    if host.isConsole and not campGroundCanvasTried then
      campGroundCanvasTried = true
      if host.appendLoadLog then
        host.appendLoadLog("camp_ground_canvas skipped=console_disabled")
      end
    end
    return
  end
  campGroundCanvasTried = true
  local startedAt = love.timer.getTime()
  local ok, err = pcall(function()
    campGroundCanvas = love.graphics.newCanvas(host.TOP_W, host.TOP_H)
    love.graphics.setCanvas(campGroundCanvas)
    love.graphics.clear(0.15, 0.18, 0.14, 1)
    CampTiles.drawCampGroundLayer(host.TOP_W / host.TILE, host.TOP_H / host.TILE)
    love.graphics.setCanvas()
  end)
  if not ok then
    campGroundCanvas = nil
    pcall(function() love.graphics.setCanvas() end)
  end
  if host.appendLoadLog then
    host.appendLoadLog(string.format(
      "camp_ground_canvas ok=%s durationMs=%.1f err=%s",
      tostring(ok and campGroundCanvas ~= nil),
      (love.timer.getTime() - startedAt) * 1000,
      ok and "nil" or tostring(err)
    ))
  end
end

return CampTiles
