--[[ 露营之旅 — 营地上屏绘制编排（DEV-068e P6 · docs/代码架构-SPEC.md） ]]

local CampRender = {}

local host

function CampRender.bindHost(h)
  host = h
end

function CampRender.drawPlayTop()
  host.CampPreload.ensure()
  if host.uiFont then love.graphics.setFont(host.uiFont) end
  love.graphics.setColor(0.15, 0.18, 0.14)
  love.graphics.rectangle("fill", 0, 0, host.TOP_W, host.TOP_H)
  local cols, rows = host.TOP_W / host.TILE, host.TOP_H / host.TILE
  local canvas = host.CampTiles.getCanvas()
  if canvas then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
  else
    host.CampTiles.drawCampGroundLayer(cols, rows)
  end
  host.CampTiles.drawCreekLite()
  host.CampTiles.drawFruitOverlays()

  local firepit = host.CampMap.getFirepit()
  local propRows = host.CampMap.getPropRows()
  local assets = host.Assets.get()
  local TILE = host.TILE
  local player = host.getPlayer()

  for y = 0, rows - 1 do
    if y == firepit.y and assets.firepit then
      host.CampTiles.drawDropShadow(firepit.x * TILE, firepit.y * TILE, "sm")
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(assets.firepit, firepit.x * TILE, firepit.y * TILE + TILE - assets.firepit:getHeight())
      if host.getLanternOn() then
        love.graphics.setColor(1, 0.82, 0.32, host.staticPlayFx and 0.65 or 0.35)
        if host.staticPlayFx then
          love.graphics.rectangle("fill", firepit.x * TILE + 5, firepit.y * TILE + 6, 6, 6)
          love.graphics.rectangle("fill", firepit.x * TILE + 7, firepit.y * TILE + 2, 3, 8)
        else
          love.graphics.circle("fill", firepit.x * TILE + 8, firepit.y * TILE + 4, 22)
        end
      end
    end
    if y == player.y then host.drawPlayerAt(player.x * TILE, player.y * TILE) end
    for _, s in ipairs(propRows[y] or {}) do
      host.CampTiles.drawProp(s.t, s.x * TILE, s.y * TILE, s.x, s.y)
    end
  end

  if host.critterFx then
    host.CampWorld.drawFish()
    host.CampWorld.drawCritters()
  end
  host.CampWorld.drawSplash()
  host.drawWorldFx()

  local tint = host.getTimeTint()
  love.graphics.setColor(tint[1], tint[2], tint[3], tint[4])
  love.graphics.rectangle("fill", 0, 0, host.TOP_W, host.TOP_H)
  host.CampWorld.drawNightSky()

  local title = "露营"
  if host.getTentOpen() then title = title .. " · 帐" end
  if host.getLanternOn() then title = title .. " · 火" end
  if host.uiFont then love.graphics.setFont(host.uiFont) end
  local tw = (host.uiFont and host.uiFont:getWidth(title)) or 80
  if tw < 28 then tw = 48 end
  love.graphics.setColor(0.08, 0.08, 0.08, 0.85)
  love.graphics.rectangle("fill", 4, 4, tw + 10, 16)
  love.graphics.setColor(1, 0.95, 0.8)
  love.graphics.print(title, 8, 5)
  local timeText = host.timeLabel()
  local timeW = (host.uiFont and host.uiFont:getWidth(timeText)) or 84
  if timeW < 72 then timeW = 84 end
  local timeX = host.TOP_W - timeW - 14
  love.graphics.setColor(0.08, 0.08, 0.08, 0.85)
  love.graphics.rectangle("fill", timeX, 4, timeW + 10, 16)
  love.graphics.setColor(1, 0.95, 0.8)
  love.graphics.print(timeText, timeX + 5, 5)
  host.drawRitualOverlay()
  host.drawToast()
end

return CampRender
