local Menu = {}

function Menu.move(runtime, delta)
  runtime.menuIndex = ((runtime.menuIndex - 1 + delta) % #State.menu.items) + 1
  Audio.playSfx("ui_move")
end

function Menu.hit(lx, ly)
  local x0, w = 40, 240
  for i = 1, #State.menu.items do
    local y = 64 + (i - 1) * 38
    if lx >= x0 and lx <= x0 + w and ly >= y and ly <= y + 32 then return i end
  end
end

return Menu
