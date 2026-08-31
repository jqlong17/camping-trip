local R = require("runtime")
local StoryDraw = require("draw.story")
local MenuDraw = {}

local function packBackground()
  if Assets.get().packBg then
    love.graphics.setColor(1, 1, 1, 1)
    Assets.drawFitted(Assets.get().packBg, 0, 0, R.BOT_W, R.BOT_H)
  else
    love.graphics.setColor(0.93, 0.88, 0.76)
    love.graphics.rectangle("fill", 0, 0, R.BOT_W, R.BOT_H)
  end
end

function MenuDraw.titleTop()
  love.graphics.setColor(1, 1, 1, 1)
  if Assets.get().titleTop then Assets.drawFitted(Assets.get().titleTop, 0, 0, R.TOP_W, R.TOP_H)
  else love.graphics.setColor(0.35, 0.55, 0.4); love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H) end
  local alpha = 0.03 + 0.02 * math.sin(R.titlePulse * 1.1)
  love.graphics.setColor(1, 0.92, 0.72, alpha)
  love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H)
  local name, sub = "露营之旅", "夏天 · 林间"
  if R.titleFont then love.graphics.setFont(R.titleFont) end
  local nw = R.titleFont and R.titleFont:getWidth(name) or 120
  local nh = R.titleFont and R.titleFont:getHeight() or 28
  local nx = math.floor((R.TOP_W - nw) / 2)
  local boxW, boxH = nw + 36, nh + 40
  local bx, by = nx - 18, 58
  love.graphics.setColor(0.07, 0.05, 0.03, 0.48)
  love.graphics.rectangle("fill", bx, by, boxW, boxH)
  love.graphics.setColor(0.92, 0.82, 0.58, 0.55)
  love.graphics.rectangle("line", bx + 2, by + 2, boxW - 4, boxH - 4)
  love.graphics.setColor(1, 0.96, 0.86)
  love.graphics.print(name, nx, 68)
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  local sw = R.uiFont and R.uiFont:getWidth(sub) or 60
  love.graphics.setColor(0.95, 0.88, 0.7)
  love.graphics.print(sub, math.floor((R.TOP_W - sw) / 2), 68 + nh + 4)
  StoryDraw.toast()
end

function MenuDraw.titleBottom()
  love.graphics.setColor(1, 1, 1, 1)
  if Assets.get().titleBot then Assets.drawFitted(Assets.get().titleBot, 0, 0, R.BOT_W, R.BOT_H)
  else love.graphics.setColor(0.85, 0.75, 0.55); love.graphics.rectangle("fill", 0, 0, R.BOT_W, R.BOT_H) end
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  love.graphics.setColor(1, 0.95, 0.85)
  love.graphics.print("周末逃离城市", 22, 30)
  local x0, width = 40, R.BOT_W - 80
  for i, item in ipairs(State.menu.items) do
    local y, on = 64 + (i - 1) * 38, i == R.menuIndex
    if on then love.graphics.setColor(0.98, 0.88, 0.5)
    elseif item.enabled then love.graphics.setColor(0.96, 0.92, 0.82)
    else love.graphics.setColor(0.75, 0.7, 0.62) end
    love.graphics.rectangle("fill", x0, y, width, 32)
    love.graphics.setColor(0.35, 0.22, 0.12)
    love.graphics.rectangle("line", x0, y, width, 32)
    local label = item.label .. (item.enabled and "" or "（暂无）")
    if on then love.graphics.setColor(0.55, 0.35, 0.12); love.graphics.print(">", x0 + 10, y + 8) end
    love.graphics.setColor(item.enabled and 0.18 or 0.45, 0.12, 0.08)
    local lw = R.uiFont and R.uiFont:getWidth(label) or 80
    love.graphics.print(label, x0 + math.floor((width - lw) / 2), y + 8)
  end
end

function MenuDraw.codexTop()
  love.graphics.setColor(1, 1, 1, 1)
  if Assets.get().titleTop then Assets.drawFitted(Assets.get().titleTop, 0, 0, R.TOP_W, R.TOP_H)
  else love.graphics.setColor(0.28, 0.38, 0.26); love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H) end
  love.graphics.setColor(0.06, 0.05, 0.03, 0.42)
  love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H)
  local gear = R.gear[R.codex.i]
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  love.graphics.setColor(0.08, 0.06, 0.04, 0.82)
  love.graphics.rectangle("fill", 28, 16, R.TOP_W - 56, 188)
  love.graphics.setColor(0.92, 0.82, 0.55, 0.55)
  love.graphics.rectangle("line", 32, 20, R.TOP_W - 64, 180)
  love.graphics.setColor(1, 0.96, 0.86)
  love.graphics.print("装备图鉴", 44, 30)
  if gear then
    love.graphics.setColor(0.78, 0.68, 0.42)
    love.graphics.print(gear.tag or "", 330, 30)
    if gear.icon then
      local iw, ih = gear.icon:getWidth(), gear.icon:getHeight()
      local scale = math.max(2, math.min(3, math.floor(64 / math.max(iw, ih, 1))))
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(gear.icon, math.floor((R.TOP_W - iw * scale) / 2), 54, 0, scale, scale)
    end
    love.graphics.setColor(1, 0.95, 0.82)
    local width = R.uiFont and R.uiFont:getWidth(gear.name) or 40
    love.graphics.print(gear.name, math.floor((R.TOP_W - width) / 2), 128)
    love.graphics.setColor(0.92, 0.86, 0.72)
    for i, line in ipairs(gear.lines or {}) do
      local lw = R.uiFont and R.uiFont:getWidth(line) or 80
      love.graphics.print(line, math.floor((R.TOP_W - lw) / 2), 150 + (i - 1) * 18)
    end
  end
  local hint = "方向键翻页 · B 返回"
  local width = R.uiFont and R.uiFont:getWidth(hint) or 140
  love.graphics.setColor(0.08, 0.08, 0.08, 0.75)
  love.graphics.rectangle("fill", 8, R.TOP_H - 22, width + 16, 18)
  love.graphics.setColor(0.9, 0.86, 0.7)
  love.graphics.print(hint, 16, R.TOP_H - 20)
end

function MenuDraw.codexBottom()
  packBackground()
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, R.BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print("点选装备 · 看用法", 14, 12)
  for i, gear in ipairs(R.gear) do
    local on = i == R.codex.i
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
  love.graphics.setColor(0.45, 0.4, 0.3)
  love.graphics.rectangle("fill", 100, 204, 120, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("B 返回标题", 122, 207)
end

function MenuDraw.aboutTop()
  love.graphics.setColor(1, 1, 1, 1)
  if Assets.get().titleTop then Assets.drawFitted(Assets.get().titleTop, 0, 0, R.TOP_W, R.TOP_H)
  else love.graphics.setColor(0.28, 0.38, 0.26); love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H) end
  love.graphics.setColor(0.06, 0.05, 0.03, 0.42)
  love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H)
  if R.titleFont then love.graphics.setFont(R.titleFont) end
  love.graphics.setColor(0.08, 0.06, 0.04, 0.82)
  love.graphics.rectangle("fill", 36, 22, R.TOP_W - 72, 176)
  love.graphics.setColor(0.92, 0.82, 0.55, 0.55)
  love.graphics.rectangle("line", 40, 26, R.TOP_W - 80, 168)
  local name = "露营之旅"
  local width = R.titleFont and R.titleFont:getWidth(name) or 120
  love.graphics.setColor(1, 0.96, 0.86)
  love.graphics.print(name, math.floor((R.TOP_W - width) / 2), 40)
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  local lines = {
    "夏天 · 林间", "爱好向小品 · 不上架", "",
    "一个上班族的周末：", "带上手冲和帐篷，去有小河的林子。",
    "搭帐、冲一杯、点灯过夜，第二天回家。",
  }
  local y = 78
  for _, line in ipairs(lines) do
    if line ~= "" then
      local lw = R.uiFont and R.uiFont:getWidth(line) or 80
      love.graphics.setColor(0.93, 0.88, 0.74)
      love.graphics.print(line, math.floor((R.TOP_W - lw) / 2), y)
    end
    y = y + 16
  end
  local hint = "A / B 返回标题"
  local hw = R.uiFont and R.uiFont:getWidth(hint) or 100
  love.graphics.setColor(0.08, 0.08, 0.08, 0.75)
  love.graphics.rectangle("fill", 8, R.TOP_H - 22, hw + 16, 18)
  love.graphics.setColor(0.9, 0.86, 0.7)
  love.graphics.print(hint, 16, R.TOP_H - 20)
end

function MenuDraw.aboutBottom()
  packBackground()
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  love.graphics.setColor(0.32, 0.22, 0.14)
  love.graphics.rectangle("fill", 6, 6, R.BOT_W - 12, 28)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print("关于这趟周末", 14, 12)
  local notes = {
    "平台  Nintendo 3DS 自制", "节奏  不战斗 · 慢慢走",
    "仪式  帐篷 / 手冲 / 点灯", "循环  下周还可以再来",
  }
  for i, line in ipairs(notes) do
    local y = 52 + (i - 1) * 34
    love.graphics.setColor(0.98, 0.94, 0.84)
    love.graphics.rectangle("fill", 28, y, R.BOT_W - 56, 28)
    love.graphics.setColor(0.35, 0.22, 0.12)
    love.graphics.rectangle("line", 28, y, R.BOT_W - 56, 28)
    love.graphics.setColor(0.22, 0.16, 0.1)
    love.graphics.print(line, 40, y + 6)
  end
  love.graphics.setColor(0.45, 0.4, 0.3)
  love.graphics.rectangle("fill", 100, 204, 120, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("B 返回标题", 122, 207)
end

return MenuDraw
