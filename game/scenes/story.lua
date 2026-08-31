-- 序章、出发与回家分镜数据。

local Story = {
  prologue = {
    i = 1,
    beats = {
      { img = "p1", line = "……终于周末了。" },
      { img = "p2", line = "电脑关上。咖啡器具、帐篷……都带上。" },
      { img = "p3", line = "去有小河的那片林子吧。" },
    },
  },
  depart = {
    i = 1,
    beats = {
      { img = "d1", line = "林间小路……空气真好。" },
      { img = "d2", line = "到了。先安顿下来吧。" },
    },
  },
  homecoming = {
    i = 1,
    beats = {
      { img = "h1", line = "回到城里了。下周……再去吧。" },
    },
  },
}

function Story.reset()
  Story.prologue.i = 1
  Story.depart.i = 1
  Story.homecoming.i = 1
end

function Story.advance(name)
  local story = Story[name]
  if story.i < #story.beats then
    story.i = story.i + 1
    return true
  end
  return false
end

return Story
