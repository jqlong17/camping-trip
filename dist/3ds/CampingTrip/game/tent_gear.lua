--[[ 露营之旅 — 帐篷选配（见 docs/帐篷模块-SPEC.md）]]

local T = {
  colors = {
    { id = "sand", name = "沙褐", note = "午后暖色" },
    { id = "pine", name = "松绿", note = "藏进林间" },
    { id = "mist", name = "雾蓝", note = "溪边清凉" }
  },
  styles = {
    { id = "dome", name = "穹顶", note = "好撑好收" },
    { id = "tunnel", name = "隧道", note = "空间更长" },
    { id = "peak", name = "小尖顶", note = "经典尖顶" }
  },
  doors = {
    { id = "shut", name = "门帘合", note = "挡风" },
    { id = "ajar", name = "门帘掀", note = "透气看景" }
  }
}

T.PHASES = {
  { id = "color", head = "选颜色", kind = "choice", catalog = "colors", store = "colorI", defaultPick = 1, assetBag = "tentColors",
    enterToast = "选帐篷颜色 · 左右 · A", enterSfx = "ui_ok" },
  { id = "style", head = "选款式", kind = "choice", catalog = "styles", store = "styleI", defaultPick = 1, assetBag = "tentStyles",
    enterSfx = "ui_ok" },
  { id = "door", head = "门帘", kind = "choice", catalog = "doors", store = "doorI", defaultPick = 1, assetBag = "tentDoors",
    enterSfx = "ui_ok" },
  { id = "confirm", head = "搭起来", kind = "confirm",
    enterToast = "平地确认 · A 搭起", enterSfx = "ui_ok" }
}

local hooks = nil
local function H()
  assert(hooks, "TentGear.bind required")
  return hooks
end

function T.bind(h) hooks = h end

function T.phaseById(id)
  for i, p in ipairs(T.PHASES) do
    if p.id == id then return p, i end
  end
end

function T.catalogFor(phase)
  if not phase or not phase.catalog then return nil end
  return T[phase.catalog]
end

function T.currentIds(colorI, styleI, doorI)
  local c = T.colors[colorI or 1] or T.colors[1]
  local s = T.styles[styleI or 1] or T.styles[1]
  local d = T.doors[doorI or 1] or T.doors[1]
  return c.id, s.id, d.id, c.name, s.name, d.name
end

function T.pitchKey(colorI, styleI, doorI)
  local c, s, d = T.currentIds(colorI, styleI, doorI)
  return "pitch_" .. s .. "_" .. c .. "_" .. d
end

function T.packKey(colorI)
  local c = T.colors[colorI or 1] or T.colors[1]
  return "pack_" .. c.id
end

local function toastEntering(phase)
  local h = H()
  if phase.enterSfx then h.playSfx(phase.enterSfx) end
  if phase.enterToast then h.say(phase.enterToast, 2.5) end
end

local function enterPhase(ritual, phaseIndex)
  local phase = T.PHASES[phaseIndex]
  ritual.phase = phase.id
  ritual.pick = phase.defaultPick or 1
  toastEntering(phase)
end

local function storePick(ritual, phase)
  ritual[phase.store] = ritual.pick
end

function T.finish()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "tent" then return end
  h.setTentStyle(ritual.colorI or 1, ritual.styleI or 1, ritual.doorI or 1)
  local ok = h.pitchTent()
  h.clearRitual()
  if ok then
    local _, _, _, cn, sn, dn = T.currentIds(ritual.colorI, ritual.styleI, ritual.doorI)
    h.playSfx("tent")
    h.say(cn .. "·" .. sn .. "·" .. dn .. " · 搭好了。", 3)
  else
    h.say("这里搭不了帐篷", 2)
  end
end

function T.start()
  local h = H()
  if h.getTentOpen() then
    h.packTent()
    h.playSfx("tent")
    h.say("帐篷收起来了。", 2)
    return
  end
  local px, py = h.playerXY()
  if not h.walkable(px, py) then
    h.say("这里搭不了帐篷", 2)
    return
  end
  h.ensureRitual()
  local c, s, d = h.getTentStyle()
  h.setRitual({
    kind = "tent",
    phase = "color",
    pick = c or 1,
    colorI = c or 1,
    styleI = s or 1,
    doorI = d or 1
  })
  h.playSfx("ui_ok")
  h.say("选帐篷颜色 · 左右 · A", 3)
end

function T.advance()
  local h = H()
  local ritual = h.getRitual()
  if not ritual or ritual.kind ~= "tent" then return end
  local phase, idx = T.phaseById(ritual.phase)
  if not phase then return end
  if phase.kind == "confirm" then
    T.finish()
    return
  end
  if phase.kind == "choice" then storePick(ritual, phase) end
  local nextIdx = idx + 1
  if nextIdx > #T.PHASES then T.finish(); return end
  enterPhase(ritual, nextIdx)
end

function T.nudge(dir)
  local ritual = H().getRitual()
  if not ritual or ritual.kind ~= "tent" then return end
  local phase = T.phaseById(ritual.phase)
  if not phase or phase.kind ~= "choice" then return end
  local list = T.catalogFor(phase)
  if not list then return end
  local n = #list
  ritual.pick = ((ritual.pick - 1 + dir) % n) + 1
  H().playSfx("ui_move")
end

function T.cancel()
  local h = H()
  local r = h.getRitual()
  if not r or r.kind ~= "tent" then return end
  h.clearRitual()
  h.say("取消了搭帐篷", 2)
end

local function drawChoiceRow(ritual, list, phase, assets, botW)
  if not list then return end
  local bag = assets and phase.assetBag and assets[phase.assetBag]
  local y = 70
  local n = #list
  local slot = math.floor((botW - 20) / math.max(n, 1))
  for i, item in ipairs(list) do
    local x = 10 + (i - 1) * slot
    local on = i == ritual.pick
    love.graphics.setColor(on and 0.95 or 0.2, on and 0.9 or 0.2, on and 0.7 or 0.2, on and 0.35 or 0.15)
    love.graphics.rectangle("fill", x, y, slot - 6, 78, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    local icon = bag and bag[item.id]
    if icon then
      love.graphics.draw(icon, x + (slot - 6 - icon:getWidth()) / 2, y + 8)
    end
    love.graphics.setColor(0.15, 0.12, 0.1, 1)
    love.graphics.printf(item.name, x, y + 54, slot - 6, "center")
  end
  local cur = list[ritual.pick]
  if cur then
    love.graphics.setColor(0.2, 0.18, 0.14, 1)
    love.graphics.printf(cur.note or "", 12, 160, botW - 24, "center")
  end
end

function T.drawTop(ritual, assets, context)
  local key = T.pitchKey(ritual.colorI or ritual.pick, ritual.styleI or 1, ritual.doorI or 1)
  if ritual.phase == "color" then
    local item = T.colors[ritual.pick]
    key = T.pitchKey(ritual.pick, ritual.styleI or 1, ritual.doorI or 1)
  elseif ritual.phase == "style" then
    key = T.pitchKey(ritual.colorI or 1, ritual.pick, ritual.doorI or 1)
  elseif ritual.phase == "door" then
    key = T.pitchKey(ritual.colorI or 1, ritual.styleI or 1, ritual.pick)
  end
  local img = assets and assets.tentPitch and assets.tentPitch[key]
  love.graphics.setColor(0.12, 0.16, 0.12, 1)
  love.graphics.rectangle("fill", 0, 0, context.TOP_W, context.TOP_H)
  love.graphics.setColor(1, 1, 1, 1)
  if img then
    local s = 3
    love.graphics.draw(img, context.TOP_W / 2 - img:getWidth() * s / 2, context.TOP_H / 2 - img:getHeight() * s / 2, 0, s, s)
  end
end

function T.drawBottom(ritual, assets, context)
  local phase = T.phaseById(ritual.phase)
  local BOT_W = context.BOT_W
  love.graphics.setColor(0.95, 0.92, 0.86, 1)
  love.graphics.rectangle("fill", 0, 0, BOT_W, context.BOT_H or 240)
  love.graphics.setColor(0.2, 0.16, 0.12, 1)
  local idx = select(2, T.phaseById(ritual.phase)) or 1
  love.graphics.print(tostring(idx) .. "/" .. #T.PHASES .. " " .. (phase and phase.head or "帐篷"), 12, 16)
  if phase and phase.kind == "choice" then
    drawChoiceRow(ritual, T.catalogFor(phase), phase, assets, BOT_W)
  elseif phase and phase.kind == "confirm" then
    local _, _, _, cn, sn, dn = T.currentIds(ritual.colorI, ritual.styleI, ritual.doorI)
    love.graphics.printf(cn .. " · " .. sn .. " · " .. dn, 12, 90, BOT_W - 24, "center")
    love.graphics.printf("A 搭在脚下平地", 12, 130, BOT_W - 24, "center")
  end
  love.graphics.setColor(0.35, 0.3, 0.25, 1)
  love.graphics.print(phase and phase.kind == "confirm" and "A 搭起" or "A 确认", 128, 213)
  love.graphics.print("B 取消", 220, 213)
end

return T
