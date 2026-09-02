local R = require("runtime")
local AP = require("asset_paths")
local Session = require("session")
local PlayDraw = {}

function PlayDraw.playerAt(px, py)
  CampTiles.drawDropShadow(px, py, "sm")
  love.graphics.setColor(1, 1, 1, 1)
  local walk = Assets.ensureWalk(R.player.castId)
  local scale = 28 / 40
  if walk and walk.sheet and walk.quads then
    local quads = walk.quads[R.player.facing or 0]
    local quad = quads and quads[R.player.walkFrame or 0]
    if quad then
      love.graphics.draw(walk.sheet, quad, px + (R.TILE - 40 * scale) / 2, py + R.TILE - 40 * scale, 0, scale, scale)
      return
    end
  end
  local img = Assets.get().player
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local fallbackScale = 28 / ih
    love.graphics.draw(img, px + (R.TILE - iw * fallbackScale) / 2, py + R.TILE - ih * fallbackScale, 0, fallbackScale, fallbackScale)
  end
end

function PlayDraw.worldFx()
  if R.brewActive and Assets.get().brewKit then
    local bx, by = R.brewX * R.TILE, R.brewY * R.TILE
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Assets.get().brewKit, bx + 2, by + R.TILE - Assets.get().brewKit:getHeight())
    if Assets.get().steam then
      local frame = Assets.get().steam[math.floor(R.waterPhase) % 3 + 1]
      if frame then love.graphics.draw(frame, bx + 4, by - 6) end
    end
  end
  if R.potSimmer > 0 then
    local firepit = CampMap.getFirepit()
    love.graphics.setColor(1, 1, 1, 0.5 + 0.3 * math.sin(R.waterPhase * 4))
    love.graphics.circle("fill", firepit.x * R.TILE + 8, firepit.y * R.TILE, 4)
  end
end

function PlayDraw.ritualOverlay()
  local ritual = R.ritual
  if not ritual then return end
  local context = {
    TOP_W = R.TOP_W, TOP_H = R.TOP_H, BOT_W = R.BOT_W,
    uiFont = R.uiFont, drawFitted = Assets.drawFitted,
    loadTopPreview = Assets.ensureTopPreview,
  }
  local assets = Assets.get().ritual
  if ritual.kind == "drip" then DripBrew.drawTop(ritual, assets, context); return end
  if ritual.kind == "tea" then TeaBrew.drawTop(ritual, assets, context); return end
  if ritual.kind == "rod" then FishRod.drawTop(ritual, assets, context); return end
  if ritual.kind == "tent" then TentGear.drawTop(ritual, assets, context); return end
  if ritual.kind == "cup_sip" then CupSip.drawTop(ritual, assets, context); return end
  if ritual.kind == "cook" then CookMeal.drawTop(ritual, assets, context); return end
end

local function gearGrid()
  for i, gear in ipairs(R.gear) do
    local on = i == R.selected
    love.graphics.setColor(0.98, on and 0.9 or 0.95, on and 0.55 or 0.88)
    love.graphics.rectangle("fill", gear.x, gear.y, 80, 62)
    love.graphics.setColor(0.3, 0.2, 0.12)
    love.graphics.rectangle("line", gear.x, gear.y, 80, 62)
    if gear.icon then
      local iw, ih = gear.icon:getWidth(), gear.icon:getHeight()
      local scale = math.min(36 / iw, 28 / ih)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(gear.icon, gear.x + (80 - iw * scale) / 2, gear.y + 4, 0, scale, scale)
    end
    love.graphics.setColor(0.22, 0.16, 0.1)
    local width = R.uiFont and R.uiFont:getWidth(gear.name) or 28
    love.graphics.print(gear.name, gear.x + (80 - width) / 2, gear.y + 42)
  end
end

local function cupPicker()
  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, R.BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print("选杯子 · 方向键 · A 喝", 14, 12)
  local assets = Assets.get()
  for i, style in ipairs(AP.CUP_STYLES) do
    local x, y, width, height = Session.cupSlotRect(i)
    local on = i == R.cupStyle
    love.graphics.setColor(on and 0.98 or 0.95, on and 0.9 or 0.92, on and 0.55 or 0.84)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.3, 0.2, 0.12)
    love.graphics.rectangle("line", x, y, width, height)
    local icon = assets.cupIcons and assets.cupIcons[i]
    if icon then
      local iw, ih = icon:getWidth(), icon:getHeight()
      local scale = math.min((width - 8) / iw, 28 / ih)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(icon, x + (width - iw * scale) / 2, y + 4, 0, scale, scale)
    end
    love.graphics.setColor(0.2, 0.14, 0.08)
    local nameWidth = R.uiFont and R.uiFont:getWidth(style.name) or 40
    love.graphics.print(style.name, x + (width - nameWidth) / 2, y + height - 14)
  end
  love.graphics.setColor(0.35, 0.55, 0.35)
  love.graphics.rectangle("fill", 100, 210, 120, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("A 喝一口", 128, 213)
end

function PlayDraw.bottom()
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  if Assets.get().packBg then
    love.graphics.setColor(1, 1, 1, 1)
    Assets.drawFitted(Assets.get().packBg, 0, 0, R.BOT_W, R.BOT_H)
  else
    love.graphics.setColor(0.93, 0.88, 0.76)
    love.graphics.rectangle("fill", 0, 0, R.BOT_W, R.BOT_H)
  end
  if R.ritual then
    local context = {
      TOP_W = R.TOP_W, TOP_H = R.TOP_H, BOT_W = R.BOT_W,
      uiFont = R.uiFont, drawFitted = Assets.drawFitted,
    }
    local assets = Assets.get().ritual
    if R.ritual.kind == "drip" then DripBrew.drawBottom(R.ritual, assets, context); return end
    if R.ritual.kind == "tea" then TeaBrew.drawBottom(R.ritual, assets, context); return end
    if R.ritual.kind == "rod" then FishRod.drawBottom(R.ritual, assets, context); return end
    if R.ritual.kind == "tent" then TentGear.drawBottom(R.ritual, assets, context); return end
    if R.ritual.kind == "cup_sip" then CupSip.drawBottom(R.ritual, assets, context); return end
    if R.ritual.kind == "cook" then CookMeal.drawBottom(R.ritual, assets, context); return end
  end
  if R.cupPick then cupPicker(); return end

  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, R.BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print("背包 · 夏天露营", 14, 12)
  local haul = State.trip.haul
  local hint = DripBrew.potHint(R.drippedOnce, R.coffeeCups, R.selected == 5 or R.selected == 2)
  if not hint and R.teaReady then hint = TeaBrew.potHint(R.teaReady, R.teaCups, R.selected == 5 or R.selected == 3) end
  if hint then
    love.graphics.setColor(0.98, 0.94, 0.76)
    love.graphics.rectangle("fill", 118, 10, 190, 20)
    love.graphics.setColor(0.26, 0.18, 0.10)
    love.graphics.print(hint, 126, 13)
  end
  love.graphics.setColor(0.98, 0.94, 0.76)
  love.graphics.rectangle("fill", 6, 36, R.BOT_W - 12, 20)
  love.graphics.setColor(0.26, 0.18, 0.10)
  love.graphics.print(string.format(
    "收获 · 果%d 鱼%d 咖啡%d 茶%d",
    haul.fruit or 0, Persist.fishTotalOf(haul.fish), haul.coffee or 0, haul.tea or 0
  ), 14, 39)
  gearGrid()
  love.graphics.setColor(0.45, 0.55, 0.4)
  love.graphics.rectangle("fill", 20, 210, 130, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("过一会儿 (X)", 36, 213)
  if R.canGoHome then
    love.graphics.setColor(0.55, 0.4, 0.3)
    love.graphics.rectangle("fill", 170, 210, 130, 22)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("收拾回家", 198, 213)
  end
end

return PlayDraw
