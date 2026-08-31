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

  -- 手帐本固定内容区 120×210（真机纹理可能更大）
  local tn = Assets.ensureStory("diary_tn")
  local tnW, tnH = 120, 210
  local tnX = math.floor((R.TOP_W - tnW) / 2 - 28)
  local tnY = math.floor((R.TOP_H - tnH) / 2)
  if tn then
    if Assets.drawFitted then
      Assets.drawFitted(tn, tnX, tnY, tnW, tnH, 1, 1)
    else
      love.graphics.draw(tn, tnX, tnY)
    end
  end

  if R.uiFont then love.graphics.setFont(R.uiFont) end
  -- 左页墨水：加宽 + 自动换行，禁止单行截成「周末手…」
  local inkX = tnX + 8
  local inkY = tnY + 28
  local inkW = math.max(44, math.floor(tnW * 0.46) - 6)
  local lineH = 12
  local utf8 = rawget(_G, "utf8") or require("utf8")
  local function inkPrintWrapped(text, yy)
    local y = yy
    local s = text or ""
    while #s > 0 do
      if y > tnY + tnH - 36 then return y end
      local chunk = s
      if R.uiFont then
        while #chunk > 0 and R.uiFont:getWidth(chunk) > inkW do
          local n = utf8.len(chunk)
          if not n or n <= 1 then break end
          local off = utf8.offset(chunk, n)
          if not off or off <= 1 then break end
          chunk = chunk:sub(1, off - 1)
        end
      end
      love.graphics.setColor(0.12, 0.09, 0.06, 1)
      love.graphics.print(chunk, inkX, y)
      y = y + lineH
      if chunk == s then break end
      local cut = #chunk
      if cut < 1 then break end
      s = s:sub(cut + 1)
    end
    return y
  end
  local y = inkPrintWrapped("周末手帐", inkY)
  y = y + 4
  for _, line in ipairs(GearPlay.diaryTripLines()) do
    y = inkPrintWrapped(line, y)
    if y > tnY + tnH - 36 then break end
  end

  -- Photo taped on right page (walk sprite of current cast)
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
  love.graphics.setColor(0.93, 0.88, 0.74)
  love.graphics.rectangle("fill", 20, 36, R.BOT_W - 40, 150)
  love.graphics.setColor(0.55, 0.42, 0.28)
  love.graphics.rectangle("line", 20, 36, R.BOT_W - 40, 150)
  if R.uiFont then love.graphics.setFont(R.uiFont) end
  love.graphics.setColor(0.22, 0.14, 0.08)
  local textW = R.BOT_W - 72
  love.graphics.printf("本趟写进手帐了", 36, 52, textW, "left")
  local haul = State.trip.haul or {}
  love.graphics.printf(string.format(
    "果 %d · 鱼 %d · 咖啡 %d · 茶 %d",
    haul.fruit or 0,
    (Persist.fishTotalOf and Persist.fishTotalOf(haul.fish)) or 0,
    haul.coffee or 0,
    haul.tea or 0
  ), 36, 78, textW, "left")
  local save, totals = State.save.data, State.save.data.totals or {}
  love.graphics.printf(string.format(
    "累计 · 露营%d次 · 果%d · 鱼%d · 咖啡%d",
    save.trips or 0, totals.fruit or 0, totals.fishTotal or 0, totals.coffee or 0
  ), 36, 104, textW, "left")
  love.graphics.setColor(0.45, 0.32, 0.18)
  love.graphics.printf("按 A 保存并回标题", 36, 148, textW, "left")
end

--- 供 playtest：手帐墨水是否被截断 / 换行是否丢字
function StoryDraw.diaryAudit()
  local report = { ok = true, issues = {}, lines = {}, inkW = 0, title = "周末手帐" }
  local tnW, tnH = 120, 210
  local inkW = math.max(44, math.floor(tnW * 0.46) - 6)
  report.inkW = inkW
  if inkW < 44 then
    report.ok = false
    report.issues[#report.issues + 1] = "inkW_too_narrow:" .. tostring(inkW)
  end

  local desk = Assets.ensureStory("diary_desk") or Assets.ensureStory("diary")
  local tn = Assets.ensureStory("diary_tn")
  if not desk then
    report.ok = false
    report.issues[#report.issues + 1] = "missing_diary_desk"
  end
  if not tn then
    report.ok = false
    report.issues[#report.issues + 1] = "missing_diary_tn"
  end

  local utf8 = rawget(_G, "utf8") or require("utf8")
  local function rebuildWrapped(text)
    local s = text or ""
    local out = {}
    while #s > 0 do
      local chunk = s
      if R.uiFont then
        while #chunk > 0 and R.uiFont:getWidth(chunk) > inkW do
          local n = utf8.len(chunk)
          if not n or n <= 1 then break end
          local off = utf8.offset(chunk, n)
          if not off or off <= 1 then break end
          chunk = chunk:sub(1, off - 1)
        end
      end
      out[#out + 1] = chunk
      if chunk == s then break end
      local cut = #chunk
      if cut < 1 then
        return table.concat(out), false
      end
      s = s:sub(cut + 1)
    end
    return table.concat(out), true
  end

  local texts = { report.title }
  for _, line in ipairs(GearPlay.diaryTripLines()) do
    texts[#texts + 1] = line
  end
  report.lines = texts
  if #texts < 2 then
    report.ok = false
    report.issues[#report.issues + 1] = "too_few_ink_lines:" .. tostring(#texts)
  end

  for _, line in ipairs(texts) do
    if line:find("…", 1, true) then
      report.ok = false
      report.issues[#report.issues + 1] = "ellipsis:" .. line
    end
    local rebuilt, okWrap = rebuildWrapped(line)
    if not okWrap or rebuilt ~= line then
      report.ok = false
      report.issues[#report.issues + 1] = "wrap_loss:" .. line
    end
  end

  local blob = table.concat(texts, "\n")
  if not blob:find("周末手帐", 1, true) then
    report.ok = false
    report.issues[#report.issues + 1] = "missing_title"
  end
  local haul = State.trip.haul or {}
  if (haul.fruit or 0) > 0 and not blob:find("野果", 1, true) then
    report.ok = false
    report.issues[#report.issues + 1] = "missing_fruit_line"
  end
  if (haul.coffee or 0) > 0 and not blob:find("手冲咖啡", 1, true) then
    report.ok = false
    report.issues[#report.issues + 1] = "missing_coffee_line"
  end
  if (haul.meals or 0) > 0 and not blob:find("顿饭", 1, true) then
    report.ok = false
    report.issues[#report.issues + 1] = "missing_meal_line"
  end
  if TentGear.mood and not blob:find("帐：", 1, true) then
    report.ok = false
    report.issues[#report.issues + 1] = "missing_tent_mood"
  end

  report.bottomHaul = string.format(
    "果 %d · 鱼 %d · 咖啡 %d · 茶 %d",
    haul.fruit or 0,
    (Persist.fishTotalOf and Persist.fishTotalOf(haul.fish)) or 0,
    haul.coffee or 0,
    haul.tea or 0
  )
  if report.bottomHaul:find("…", 1, true) then
    report.ok = false
    report.issues[#report.issues + 1] = "bottom_ellipsis"
  end
  return report
end

return StoryDraw
