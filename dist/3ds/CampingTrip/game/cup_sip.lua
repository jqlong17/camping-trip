--[[ 露营之旅 — 杯子品尝加深（见 docs/杯子品尝-SPEC.md）]]

local C = {}
local hooks = nil

local function H()
  assert(hooks, "CupSip.bind required")
  return hooks
end

function C.bind(h) hooks = h end

function C.modLine(style, kind)
  if not style then return "" end
  if kind == "tea" then return style.teaMod or "" end
  return style.coffeeMod or ""
end

function C.composeSipLine(baseTaste, style, kind, sipIndex, potMax)
  local name = style and style.name or "杯子"
  local mod = C.modLine(style, kind)
  local drink = kind == "tea" and "茶" or "咖啡"
  local core = baseTaste and (baseTaste .. " · ") or ""
  if mod ~= "" then core = core .. mod .. " · " end
  return name .. " · " .. core .. drink .. "第" .. tostring(sipIndex) .. "口"
end

function C.start(kind)
  local h = H()
  h.ensureRitual()
  h.setRitual({
    kind = "cup_sip",
    drinkKind = kind,
    brewStep = 1,
    brewSteps = 2
  })
  h.playSfx("cup")
end

function C.advance()
  local h = H()
  local r = h.getRitual()
  if not r or r.kind ~= "cup_sip" then return end
  if r.brewStep < (r.brewSteps or 2) then
    r.brewStep = r.brewStep + 1
    h.playSfx("ui_ok")
  else
    h.clearRitual()
  end
end

function C.drawTop(ritual, assets, context)
  local frames = assets and assets.cupSip
  local img = frames and frames[ritual.brewStep]
  love.graphics.setColor(0.1, 0.1, 0.12, 1)
  love.graphics.rectangle("fill", 0, 0, context.TOP_W, context.TOP_H)
  love.graphics.setColor(1, 1, 1, 1)
  if img then
    local s = 2
    love.graphics.draw(img, (context.TOP_W - img:getWidth() * s) / 2, (context.TOP_H - img:getHeight() * s) / 2, 0, s, s)
  end
end

function C.drawBottom(ritual, assets, context)
  love.graphics.setColor(0.95, 0.92, 0.86, 1)
  love.graphics.rectangle("fill", 0, 0, context.BOT_W, context.BOT_H or 240)
  love.graphics.setColor(0.2, 0.16, 0.12, 1)
  local labels = { "抬杯", "入口" }
  love.graphics.printf((labels[ritual.brewStep] or "品尝") .. " · A 继续", 12, 100, context.BOT_W - 24, "center")
end

return C
