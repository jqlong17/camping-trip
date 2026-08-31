--[[ 露营之旅 — 下屏/上屏 toast（见 docs/代码架构-SPEC.md） ]]

local Toast = { msg = "", t = 0 }

function Toast.say(msg, sec)
  Toast.msg = msg or ""
  Toast.t = sec or 2.5
end

function Toast.clear()
  Toast.msg = ""
  Toast.t = 0
end

function Toast.update(dt)
  if Toast.t > 0 then Toast.t = Toast.t - dt end
end

function Toast.draw(opts)
  opts = opts or {}
  if Toast.t <= 0 or Toast.msg == "" then return end
  local uiFont = opts.uiFont
  local topH = opts.topH or 240
  local topW = opts.topW or 400
  if uiFont then love.graphics.setFont(uiFont) end
  local toastW = uiFont and uiFont:getWidth(Toast.msg) or 120
  love.graphics.setColor(0.08, 0.08, 0.08, 0.82)
  love.graphics.rectangle("fill", 4, topH - 22, math.min(topW - 8, toastW + 12), 18)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(Toast.msg, 8, topH - 20)
end

return Toast
