--[[
  露营之旅 — 权威运行时状态（见 docs/代码架构-SPEC.md）
  P1：trip / save / menu / cast（persist 与流程共用）
]]

local State = {}

State.trip = {
  haul = { fruit = 0, coffee = 0, tea = 0, fish = { ayu = 0, trout = 0, carp = 0 } },
  fruitTrees = {},
}

State.save = {
  file = "save.json",
  data = {
    castId = 1,
    castChosen = false,
    trips = 0,
    totals = {
      coffee = 0,
      fruit = 0,
      fish = { ayu = 0, trout = 0, carp = 0 },
      fishTotal = 0,
    },
    lastTrip = nil,
    history = {},
  },
}

State.menu = {
  items = {
    { id = "start", label = "开始旅程", enabled = true },
    { id = "continue", label = "继续", enabled = false },
    { id = "cast", label = "切换角色", enabled = true },
    { id = "codex", label = "装备图鉴", enabled = true },
    { id = "about", label = "关于", enabled = true },
  },
}

State.cast = {
  i = 1,
  names = {
    "眼镜上班族", "草帽姑娘", "背心男生", "绿帽女孩", "丸子头",
    "银发polo", "钓鱼姑娘", "条纹少年", "格子衫",
  },
  genders = { "boy", "girl", "boy", "girl", "girl", "boy", "girl", "boy", "girl" },
}

State.castMode = "journey"

function State.resetTripHaul(emptyFish)
  State.trip.haul = {
    fruit = 0,
    coffee = 0,
    tea = 0,
    fish = emptyFish and emptyFish() or { ayu = 0, trout = 0, carp = 0 },
  }
end

return State
