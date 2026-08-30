-- 露营之旅 — LÖVE / LovePotion config
function love.conf(t)
  t.identity = "camping-trip"
  t.version = "11.4"
  t.console = false

  -- Desktop preview (stacked 3DS screens). Ignored on console.
  if t.window then
    t.window.title = "露营之旅"
    t.window.width = 400
    t.window.height = 480
    t.window.resizable = false
  end
end
