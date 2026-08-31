local R = require("runtime")
local StoryDraw = {}

function StoryDraw.toast()
  Toast.draw({ uiFont = R.uiFont, topH = R.TOP_H, topW = R.TOP_W })
end

function StoryDraw.storyTop(imgKey, line)
  love.graphics.setColor(1, 1, 1, 1)
  local img = Assets.ensureStory(imgKey)
  if img then
    Assets.drawStoryFrame(img, 0, 0, R.TOP_W, R.TOP_H)
  else
    love.graphics.setColor(0.2, 0.25, 0.2)
    love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H)
    if R.isConsole and R.uiFont then
      love.graphics.setColor(1, 0.85, 0.4)
      love.graphics.setFont(R.uiFont)
      love.graphics.print("无图 " .. tostring(imgKey), 8, 8)
    end
  end
  -- 出发分镜：用行走立绘站在小路上（营地同比例），勿用大头贴贴右下角
  if R.scene == "depart" and R.player and R.player.castId then
    local spots = {
      d1 = { x = 188, y = 98, facing = 0 },
      d2 = { x = 164, y = 100, facing = 1 },
    }
    local spot = spots[imgKey] or spots.d2
    local scale = 28 / 40
    local walk = Assets.ensureWalk(R.player.castId)
    love.graphics.setColor(1, 1, 1, 1)
    if walk and walk.sheet and walk.quads then
      local quads = walk.quads[spot.facing or 0]
      local quad = quads and quads[0]
      if quad then
        love.graphics.draw(walk.sheet, quad, spot.x, spot.y, 0, scale, scale)
      end
    else
      local castImg = Assets.ensureCast(R.player.castId)
      if castImg then
        local iw, ih = castImg:getWidth(), castImg:getHeight()
        local s = math.min(28 / iw, 28 / ih)
        love.graphics.draw(castImg, spot.x, spot.y, 0, s, s)
      end
    end
  end
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  local hint = "A 继续"
  local width = R.uiFont and R.uiFont:getWidth(hint) or 40
  local boxY = R.TOP_H - 28
  love.graphics.setColor(0.05, 0.05, 0.05, 0.78)
  love.graphics.rectangle("fill", 8, boxY, R.TOP_W - 16, 22)
  love.graphics.setColor(1, 0.96, 0.88)
  love.graphics.print(line, 16, boxY + 4)
  love.graphics.setColor(0.82, 0.76, 0.58)
  love.graphics.print(hint, R.TOP_W - width - 18, boxY + 4)
end

function StoryDraw.storyBottom(hint)
  love.graphics.setColor(0.18, 0.14, 0.10)
  love.graphics.rectangle("fill", 0, 0, R.BOT_W, R.BOT_H)
  love.graphics.setColor(0.92, 0.86, 0.72)
  love.graphics.rectangle("fill", 16, 80, R.BOT_W - 32, 80)
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  love.graphics.setColor(0.2, 0.14, 0.08)
  love.graphics.print(hint or "按 A / 点这里继续", 40, 110)
end

function StoryDraw.castTop()
  love.graphics.setColor(0.15, 0.18, 0.14)
  love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H)
  local img = Assets.ensureCast(State.cast.i)
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local scale = math.max(1, math.floor(160 / math.max(ih, 1)))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor((R.TOP_W - iw * scale) / 2), 28, 0, scale, scale)
  end
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  local name = State.cast.names[State.cast.i] or ("角色" .. State.cast.i)
  local width = R.uiFont and R.uiFont:getWidth(name) or 60
  love.graphics.setColor(0.08, 0.08, 0.08, 0.8)
  love.graphics.rectangle("fill", (R.TOP_W - width) / 2 - 8, 200, width + 16, 22)
  love.graphics.setColor(1, 0.95, 0.85)
  love.graphics.print(name, (R.TOP_W - width) / 2, 203)
  StoryDraw.toast()
end

function StoryDraw.castBottom()
  love.graphics.setColor(0.93, 0.88, 0.76)
  love.graphics.rectangle("fill", 0, 0, R.BOT_W, R.BOT_H)
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  love.graphics.setColor(0.25, 0.18, 0.1)
  love.graphics.print("选角色 · 这次谁去", 16, 16)
  for i = 1, 9 do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local x, y = 24 + col * 96, 48 + row * 56
    local on = i == State.cast.i
    love.graphics.setColor(on and 0.98 or 1, on and 0.9 or 0.96, on and 0.55 or 0.9)
    love.graphics.rectangle("fill", x, y, 88, 48)
    love.graphics.setColor(0.3, 0.2, 0.12)
    love.graphics.rectangle("line", x, y, 88, 48)
    local sprite = Assets.ensureCast(i)
    if sprite then
      local iw, ih = sprite:getWidth(), sprite:getHeight()
      local scale = math.min(40 / iw, 40 / ih)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(sprite, x + 4 + (40 - iw * scale) / 2, y + (48 - ih * scale) / 2, 0, scale, scale)
    end
    love.graphics.setColor(0.2, 0.15, 0.1)
    love.graphics.print(tostring(i), x + 58, y + 16)
  end
  love.graphics.setColor(0.35, 0.55, 0.35)
  love.graphics.rectangle("fill", 100, 210, 120, 22)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("A 确认出发", 118, 213)
end

function StoryDraw.diaryTop()
  love.graphics.setColor(1, 1, 1, 1)
  local desk = Assets.ensureStory("diary_desk") or Assets.ensureStory("diary")
  if desk then Assets.drawFitted(desk, 0, 0, R.TOP_W, R.TOP_H) end

  local tn = Assets.ensureStory("diary_tn")
  local tnX, tnY, tnW, tnH = 72, 16, 110, 200
  if tn then
    tnW, tnH = tn:getWidth(), tn:getHeight()
    tnX = math.floor((R.TOP_W - tnW) / 2 - 28)
    tnY = math.floor((R.TOP_H - tnH) / 2)
    love.graphics.draw(tn, tnX, tnY)
  end

  if R.uiFont then love.graphics.setFont(R.uiFont) end
  -- Ink on left page — single-line truncate (no wrap columns on narrow page)
  local inkX = tnX + 10
  local inkY = tnY + 24
  local inkW = math.max(36, math.floor(tnW / 2) - 14)
  local function inkLine(text, yy)
    local s = text
    if R.uiFont then
      local utf8 = rawget(_G, "utf8") or require("utf8")
      while #s > 0 and R.uiFont:getWidth(s) > inkW do
        local off = utf8.offset(s, -1)
        if not off or off <= 1 then break end
        s = s:sub(1, off - 1)
      end
      if s ~= text and #s > 0 then s = s .. "…" end
    end
    love.graphics.setColor(0.12, 0.09, 0.06, 1)
    love.graphics.print(s, inkX, yy)
  end
  inkLine("周末手帐", inkY)
  local y = inkY + 16
  for _, line in ipairs(GearPlay.diaryTripLines()) do
    inkLine(line, y)
    y = y + 13
    if y > tnY + tnH - 40 then break end
  end

  -- Photo taped on right page (walk sprite, no white portrait plate)
  local walk = Assets.ensureWalk(R.player.castId)
  local px = tnX + math.floor(tnW * 0.54)
  local py = tnY + math.floor(tnH * 0.38)
  local pw, ph = 44, 50
  love.graphics.setColor(0.95, 0.91, 0.82, 1)
  love.graphics.rectangle("fill", px - 2, py - 2, pw + 4, ph + 4)
  love.graphics.setColor(0.48, 0.36, 0.24, 1)
  love.graphics.rectangle("line", px - 2, py - 2, pw + 4, ph + 4)
  love.graphics.setScissor(px, py, pw, ph)
  love.graphics.setColor(1, 1, 1, 1)
  if walk and walk.sheet and walk.quads and walk.quads[0] and walk.quads[0][0] then
    local sc = math.min(pw / 40, ph / 40) * 1.05
    love.graphics.draw(walk.sheet, walk.quads[0][0], px + (pw - 40 * sc) / 2, py + (ph - 40 * sc) / 2, 0, sc, sc)
  else
    local castImg = Assets.ensureCast(R.player.castId)
    if castImg then
      local iw, ih = castImg:getWidth(), castImg:getHeight()
      local sc = math.min(pw / iw, ph / ih)
      love.graphics.draw(castImg, px + (pw - iw * sc) / 2, py + (ph - ih * sc) / 2, 0, sc, sc)
    end
  end
  love.graphics.setScissor()

  love.graphics.setColor(0.30, 0.22, 0.14, 0.92)
  local hint = "A 合上保存"
  local hw = R.uiFont and R.uiFont:getWidth(hint) or 72
  love.graphics.print(hint, R.TOP_W - hw - 12, R.TOP_H - 18)
end

function StoryDraw.diaryBottom()
  love.graphics.setColor(0.16, 0.12, 0.09)
  love.graphics.rectangle("fill", 0, 0, R.BOT_W, R.BOT_H)
  -- note card
  love.graphics.setColor(0.93, 0.88, 0.74)
  love.graphics.rectangle("fill", 20, 36, R.BOT_W - 40, 150)
  love.graphics.setColor(0.55, 0.42, 0.28)
  love.graphics.rectangle("line", 20, 36, R.BOT_W - 40, 150)
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  love.graphics.setColor(0.22, 0.14, 0.08)
  love.graphics.print("本趟写进手帐了", 36, 52)
  local haul = State.trip.haul or {}
  love.graphics.print(string.format(
    "果 %d · 鱼 %d · 咖啡 %d · 茶 %d",
    haul.fruit or 0,
    (Persist.fishTotalOf and Persist.fishTotalOf(haul.fish)) or 0,
    haul.coffee or 0,
    haul.tea or 0
  ), 36, 78)
  local save, totals = State.save.data, State.save.data.totals or {}
  love.graphics.print(string.format(
    "累计 · 露营%d次 · 果%d · 鱼%d · 咖啡%d",
    save.trips or 0, totals.fruit or 0, totals.fishTotal or 0, totals.coffee or 0
  ), 36, 108)
  love.graphics.setColor(0.45, 0.32, 0.18)
  love.graphics.print("按 A 保存并回标题", 36, 148)
end

return StoryDraw
