local Codex = {}

function Codex.move(runtime, delta)
  runtime.codex.i = ((runtime.codex.i - 1 + delta) % #runtime.gear) + 1
  Audio.playSfx("ui_move")
end

function Codex.set(runtime, i)
  if i < 1 or i > #runtime.gear or i == runtime.codex.i then return end
  runtime.codex.i = i
  Audio.playSfx("ui_move")
end

return Codex
