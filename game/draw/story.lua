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
      depart = { x = 182, y = 130, facing = 0 },
      arrive = { x = 168, y = 124, facing = 1 },
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

function StoryDraw.destinationTop()
  local id = State.destination.ids[State.destination.i] or "forest"
  local pack = Destinations.get(id)
  local img = Assets.ensureTopPreview(pack.preview)
  love.graphics.setColor(0.12, 0.18, 0.20)
  love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H)
  if img then Assets.drawFitted(img, 40, 16, 320, 180, 1, 1) end
  love.graphics.setColor(0.06, 0.08, 0.10, 0.86)
  love.graphics.rectangle("fill", 40, 196, 320, 30)
  love.graphics.setColor(1, 0.95, 0.82)
  love.graphics.printf(pack.name, 40, 202, 320, "center")
  StoryDraw.toast()
end

function StoryDraw.destinationBottom()
  love.graphics.setColor(0.92, 0.86, 0.72)
  love.graphics.rectangle("fill", 0, 0, R.BOT_W, R.BOT_H)
  love.graphics.setColor(0.24, 0.16, 0.10)
  love.graphics.print("这次去哪里？", 16, 18)
  for i, pack in ipairs(Destinations.all()) do
    local x = i == 1 and 16 or 164
    local selected = i == State.destination.i
    love.graphics.setColor(selected and 0.98 or 0.86, selected and 0.86 or 0.82, selected and 0.48 or 0.70)
    love.graphics.rectangle("fill", x, 56, 140, 116)
    love.graphics.setColor(0.30, 0.20, 0.12)
    love.graphics.rectangle("line", x, 56, 140, 116)
    love.graphics.printf(pack.name, x + 4, 78, 132, "center")
    love.graphics.setColor(0.40, 0.30, 0.18)
    local note = pack.id == "coast" and "沙滩 · 海浪 · 海鸟" or "小溪 · 树影 · 萤火虫"
    love.graphics.printf(note, x + 8, 112, 124, "center")
  end
  love.graphics.setColor(0.35, 0.55, 0.35)
  love.graphics.rectangle("fill", 100, 204, 120, 24)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("A 确认目的地", 112, 208)
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
  local preview = Assets.ensureCastPreview and Assets.ensureCastPreview(State.cast.i)
  local img = preview or Assets.ensureCast(State.cast.i)
  if img then
    love.graphics.setColor(1, 1, 1, 1)
    if preview then
      Assets.drawFitted(img, math.floor((R.TOP_W - 320) / 2), 16, 320, 180, 1, 1)
    else
      local iw, ih = img:getWidth(), img:getHeight()
      local scale = math.max(1, math.floor(160 / math.max(ih, 1)))
      love.graphics.draw(img, math.floor((R.TOP_W - iw * scale) / 2), 28, 0, scale, scale)
    end
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
  love.graphics.setColor(0.42, 0.28, 0.16, 1)
  love.graphics.rectangle("fill", 0, 0, R.TOP_W, R.TOP_H)
  love.graphics.setColor(1, 1, 1, 1)
  local desk = Assets.ensureStory("diary_desk") or Assets.ensureStory("diary")
  if desk then
    Assets.drawStoryFrame(desk, 0, 0, R.TOP_W, R.TOP_H)
  end

  -- 手帐本固定内容区 120×210（真机 T3X 可能被 pad 到 2 的幂）
  local tn = Assets.ensureStory("diary_tn")
  local tnW, tnH = 120, 210
  local tnX = math.floor((R.TOP_W - tnW) / 2 - 28)
  local tnY = math.floor((R.TOP_H - tnH) / 2)
  if tn then
    local iw, ih = tn:getWidth(), tn:getHeight()
    local cw, ch = math.min(tnW, iw), math.min(tnH, ih)
    local scale = math.min(tnW / cw, tnH / ch)
    local ox = tnX + math.floor((tnW - cw * scale) / 2)
    local oy = tnY + math.floor((tnH - ch * scale) / 2)
    if cw == iw and ch == ih then
      love.graphics.draw(tn, ox, oy, 0, scale, scale)
    else
      local ok, quad = pcall(love.graphics.newQuad, 0, 0, cw, ch, iw, ih)
      if ok and quad then
        love.graphics.draw(tn, quad, ox, oy, 0, scale, scale)
      else
        love.graphics.draw(tn, ox, oy, 0, scale, scale)
      end
    end
  end

  -- 上屏只营造“写过日记”的感觉：细小像素笔迹，不承担真实文字阅读。
  local inkX, inkY = tnX + 9, tnY + 31
  local strokes = {
    { 8, 5, 9, 4 }, { 13, 3, 7, 7 }, { 6, 8, 5, 6 },
    { 11, 6, 8, 3 }, { 7, 4, 12, 3 }, { 14, 5, 5, 5 },
    { 9, 7, 6, 6 }, { 5, 5, 10, 8 }, { 12, 4, 7, 4 },
  }
  love.graphics.setColor(0.18, 0.13, 0.09, 0.72)
  for row, parts in ipairs(strokes) do
    local x = inkX + ((row * 3) % 5)
    local y = inkY + (row - 1) * 12
    for i, len in ipairs(parts) do
      love.graphics.rectangle("fill", x, y + ((row + i) % 2), len, 1)
      if (row + i) % 3 == 0 then
        love.graphics.rectangle("fill", x + 2, y + 2, math.max(2, len - 3), 1)
      end
      x = x + len + 2
    end
  end

end

function StoryDraw.diaryPages()
  local haul = State.trip.haul or {}
  local fish = (Persist.fishTotalOf and Persist.fishTotalOf(haul.fish)) or 0

  local coast = State.trip.destinationId == "coast"
  local first = coast
    and "把帐篷展开在海边以后，浪声把一路的疲惫都带走了。"
    or "把帐篷展开在林间以后，心也慢慢安静了下来。"
  if (haul.coffee or 0) > 0 and (haul.tea or 0) > 0 then
    first = first .. "咖啡和茶的香气轮流升起，时间好像走得更慢了。"
  elseif (haul.coffee or 0) > 0 then
    first = first .. "热水绕过咖啡粉时，林子里多了一阵温暖的香气。"
  elseif (haul.tea or 0) > 0 then
    first = first .. "茶汤暖起来时，溪水声也显得格外清亮。"
  else
    first = first .. (coast and "什么都不赶，只听浪一遍遍靠岸。" or "什么都不赶，只听风从树梢经过。")
  end

  local second
  if (haul.meals or 0) > 0 then
    second = "热饭出锅的那一刻，突然觉得今天已经很圆满。"
  else
    second = coast and "坐在潮线外发了一会儿呆，海风把下午吹得很长。"
      or "坐在溪边发了一会儿呆，原来安静也能装满一个下午。"
  end
  if fish > 0 then
    second = second .. "溪水还送来了一份小小的惊喜。"
  elseif FishRod.mood then
    second = second .. "鱼最后留在溪水里，也算彼此打了个招呼。"
  elseif (haul.fruit or 0) > 0 then
    second = second .. "路过树下时，还收下了林子送的小礼物。"
  end

  local third
  if fish == 0 and FishRod.mood then
    third = "下次还想坐回这段溪边，换个耐心一点的下午，看看会不会等到那条鱼。"
  elseif (haul.coffee or 0) > 0 then
    third = "下次想换一种豆子，再早一点出发。也许晨雾里的第一杯，会有完全不同的味道。"
  elseif (haul.tea or 0) > 0 then
    third = "下次带另一种茶来，也给风和溪水留一杯。"
  else
    third = coast and "下次还来，想再看一次海上的日出。" or "下次还来。也许不需要计划，只要再把周末还给自己。"
  end

  return {
    { title = "这次的周末", body = first },
    { title = "记住这一刻", body = second },
    { title = "下次再来", body = third },
  }
end

function StoryDraw.diaryBottom()
  love.graphics.setColor(0.16, 0.12, 0.09)
  love.graphics.rectangle("fill", 0, 0, R.BOT_W, R.BOT_H)
  love.graphics.setColor(0.93, 0.88, 0.74)
  love.graphics.rectangle("fill", 12, 24, R.BOT_W - 24, 176)
  love.graphics.setColor(0.55, 0.42, 0.28)
  love.graphics.rectangle("line", 12, 24, R.BOT_W - 24, 176)
  if R.uiFont then love.graphics.setFont(R.uiFont) end

  local pages = StoryDraw.diaryPages()
  local pageIndex = math.max(1, math.min(#pages, R.diaryPage or 1))
  local page = pages[pageIndex]
  love.graphics.setColor(0.22, 0.14, 0.08)
  love.graphics.printf(page.title, 32, 42, R.BOT_W - 64, "center")
  love.graphics.setColor(0.31, 0.22, 0.14)
  love.graphics.printf(page.body, 34, 72, R.BOT_W - 68, "left")

  love.graphics.setColor(0.45, 0.32, 0.18)
  love.graphics.print(pageIndex > 1 and "< 上一页" or "  上一页", 20, 214)
  love.graphics.print("A 保存", 132, 214)
  love.graphics.print(pageIndex < #pages and "下一页 >" or "下一页  ", 232, 214)
  love.graphics.printf(pageIndex .. "/" .. #pages, 0, 184, R.BOT_W, "center")
end

--- 供 playtest：三页齐全、无流水账数字，且日记上屏不叠角色。
function StoryDraw.diaryAudit()
  local report = {
    ok = true,
    issues = {},
    pages = StoryDraw.diaryPages(),
    characterOverlay = false,
  }
  local desk = Assets.ensureStory("diary_desk") or Assets.ensureStory("diary")
  local tn = Assets.ensureStory("diary_tn")
  if not desk then report.issues[#report.issues + 1] = "missing_diary_desk" end
  if not tn then report.issues[#report.issues + 1] = "missing_diary_tn" end
  if #report.pages ~= 3 then report.issues[#report.issues + 1] = "page_count:" .. #report.pages end

  for i, page in ipairs(report.pages) do
    if not page.title or page.title == "" then
      report.issues[#report.issues + 1] = "missing_title:" .. i
    end
    if not page.body or #page.body < 18 then
      report.issues[#report.issues + 1] = "body_too_short:" .. i
    elseif page.body:find("%d") then
      report.issues[#report.issues + 1] = "ledger_number:" .. i
    end
  end
  report.ok = #report.issues == 0
  return report
end

return StoryDraw
