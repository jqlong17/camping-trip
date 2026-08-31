local Cast = {}
local host

function Cast.bindHost(h)
  host = h
end

function Cast.set(i)
  if State.cast.i == i then return end
  State.cast.i = i
  host.ensureCast(i)
  Audio.playSfx("ui_move")
end

function Cast.move(direction)
  local i = State.cast.i
  if direction == "left" then Cast.set(i == 1 and 9 or i - 1)
  elseif direction == "right" then Cast.set(i == 9 and 1 or i + 1)
  elseif direction == "up" then Cast.set(i <= 3 and i + 6 or i - 3)
  elseif direction == "down" then Cast.set(i >= 7 and i - 6 or i + 3)
  end
end

function Cast.hit(lx, ly)
  for i = 1, 9 do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local x, y = 24 + col * 96, 48 + row * 56
    if lx >= x and lx <= x + 88 and ly >= y and ly <= y + 48 then return i end
  end
end

return Cast
