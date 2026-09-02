-- 数据驱动目的地注册表。共享 Runtime 只读取当前 pack。

local Registry = {}

local packs = {
  forest = {
    id = "forest",
    name = "林间营地",
    shortName = "林间",
    sceneRoot = "assets/scenes/forest",
    preview = "assets/previews/destinations/forest.png",
    layoutBuilder = "forest",
    spawn = { x = 10, y = 9 },
    firepit = { x = 12, y = 10 },
    tiles = {
      [0] = { material = "grass", walkable = true, campable = true },
      [1] = { material = "grass", walkable = true, campable = true },
      [2] = { material = "deep-water", walkable = true, water = true, depth = "deep" },
      [3] = { material = "tree", walkable = false },
      [4] = { material = "stone", walkable = false },
      [5] = { material = "tent", walkable = true },
      [6] = { material = "bush", walkable = false },
      [7] = { material = "dirt", walkable = true, campable = true },
      [8] = { material = "shallow-water", walkable = true, water = true, depth = "shallow" },
      [10] = { material = "distant-forest", walkable = false },
    },
    audio = { bgmDay = "morning", bgmNight = "night", ambienceDay = "birds", ambienceNight = "crickets", water = "creek" },
    vegetation = { "forest-tree", "bush", "flower", "reed" },
    nature = { "stone", "log", "stump", "nest" },
    ecology = { birds = 3, bugs = 4, fish = true, crab = false },
    effects = { leaves = true, meteors = true, fireflies = true, waves = false },
    story = { depart = { "d1", "d2" } },
    timeProfiles = {
      sunrise = { slot = "清晨", event = "晨雾从溪面散开了。" },
      sunset = { slot = "黄昏", event = "林梢慢慢染上晚霞。" },
    },
    storyAtlas = { destination = "DEST-FOREST", scene = "SCN-003" },
  },
  coast = {
    id = "coast",
    name = "海边营地",
    shortName = "海边",
    sceneRoot = "assets/scenes/coast",
    preview = "assets/previews/destinations/coast.png",
    layoutBuilder = "coast",
    spawn = { x = 11, y = 11 },
    firepit = { x = 12, y = 9 },
    tiles = {
      [0] = { material = "sand", walkable = true, campable = true },
      [2] = { material = "deep-sea", walkable = false, water = true, depth = "deep" },
      [3] = { material = "coast-pine", walkable = false },
      [4] = { material = "reef-rock", walkable = false },
      [5] = { material = "tent", walkable = true },
      [6] = { material = "salt-shrub", walkable = false },
      [7] = { material = "camp-sand", walkable = true, campable = true },
      [8] = { material = "shallow-sea", walkable = false, water = true, depth = "shallow" },
      [9] = { material = "wet-sand", walkable = true, campable = false },
    },
    audio = { bgmDay = "morning", bgmNight = "night", ambienceDay = "birds", ambienceNight = "crickets", water = "ocean" },
    vegetation = { "coast-pine", "salt-shrub", "beach-grass" },
    nature = { "reef-rock", "driftwood" },
    ecology = {
      birds = 2, birdScale = 1,
      bugs = 0, fish = false,
      crab = true, crabs = 3,
    },
    effects = { leaves = false, meteors = true, fireflies = false, waves = true },
    story = { depart = { "depart", "arrive" } },
    timeProfiles = {
      sunrise = { slot = "清晨", event = "太阳从海面升起来了。", tint = { 1.00, 0.66, 0.38, 0.20 } },
      day = { slot = "白天", tint = { 0.92, 1.00, 1.00, 0.05 } },
      sunset = { slot = "黄昏", event = "落日把浪尖染成了金红。", tint = { 1.00, 0.48, 0.30, 0.30 } },
      night = { slot = "夜晚", tint = { 0.12, 0.22, 0.48, 0.55 } },
    },
    storyAtlas = { destination = "DEST-COAST", scene = "SCN-COAST" },
  },
}

local order = { "forest", "coast" }
local active = "forest"

function Registry.all()
  local result = {}
  for _, id in ipairs(order) do result[#result + 1] = packs[id] end
  return result
end

function Registry.get(id)
  return packs[id] or packs.forest
end

function Registry.current()
  return Registry.get(active)
end

function Registry.currentId()
  return active
end

function Registry.set(id)
  active = packs[id] and id or "forest"
  return packs[active]
end

function Registry.scenePath(domain, name)
  return Registry.current().sceneRoot .. "/" .. domain .. "/" .. name
end

return Registry
