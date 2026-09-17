--[[ 露营之旅 — 单款帐篷：A 直接展开 / 收起。]]

local T = { mood = nil }
local hooks

local function H()
  assert(hooks, "TentGear.bind required")
  return hooks
end

function T.bind(h)
  hooks = h
end

function T.start()
  local h = H()
  if h.getTentOpen() then
    h.packTent()
    T.mood = nil
    h.playSfx("tent")
    h.say("帐篷收起来了。", 2)
    return
  end

  local px, py = h.playerXY()
  if not h.walkable(px, py) then
    h.say("这里搭不了帐篷", 2)
    return
  end

  if h.pitchTent() then
    if h.ensureTentOpen then h.ensureTentOpen() end
    T.mood = "米白尖顶帐篷 · 今晚的窝搭好了"
    h.playSfx("tent")
    h.say("帐篷展开了。", 2.5)
  else
    h.say("这里搭不了帐篷", 2)
  end
end

-- 保留兼容入口；单款帐篷不再创建 ritual。
function T.advance() end
function T.nudge() end
function T.cancel() end
function T.loadPitchFrames() end
function T.drawTop() end
function T.drawBottom() end

return T
