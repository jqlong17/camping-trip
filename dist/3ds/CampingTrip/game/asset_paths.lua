--[[ 露营之旅 — 资源路径（见 docs/资源目录-SPEC.md）]]

local AP = {
  scene = "forest",
  CUP_STYLES = {
    { id = "hakuji", name = "白瓷杯", file = "cup_01_hakuji.png", kind = "coffee",
      coffeeMod = "衬出酸甜", teaMod = "清透" },
    { id = "aogama", name = "青磁湯吞", file = "cup_02_aogama.png", kind = "tea",
      coffeeMod = "釉色压火感", teaMod = "压苦显香" },
    { id = "kozara", name = "茶杯碟", file = "cup_03_kozara.png", kind = "tea",
      coffeeMod = "小口细品", teaMod = "小口回甘" },
    { id = "sumi", name = "墨釉马克", file = "cup_04_sumi.png", kind = "coffee",
      coffeeMod = "加重醇厚", teaMod = "更沉" },
    { id = "beni", name = "朱泥茶盏", file = "cup_05_beni.png", kind = "tea",
      coffeeMod = "暖土气", teaMod = "暖甜" },
    { id = "matcha", name = "抹茶碗", file = "cup_06_matcha.png", kind = "tea",
      coffeeMod = "碗大口散", teaMod = "茶汤更浓" },
    { id = "enamel", name = "搪瓷马克", file = "cup_07_enamel.png", kind = "coffee",
      coffeeMod = "野营烟火气", teaMod = "粗犷" },
    { id = "take", name = "竹节杯", file = "cup_08_take.png", kind = "tea",
      coffeeMod = "微竹香", teaMod = "竹香" },
    { id = "glass", name = "硝子咖啡", file = "cup_09_glass.png", kind = "coffee",
      coffeeMod = "观色偏明亮", teaMod = "见汤色" }
  }
}

local HOME_STORY = { h1 = true, diary = true, diary_desk = true, diary_tn = true }
local PROLOGUE_STORY = { p1 = true, p2 = true, p3 = true }

function AP.cupPath(file)
  return "assets/cups/" .. file
end

function AP.gearPath(id)
  return "assets/gear/" .. id .. ".png"
end

function AP.tentGear(name)
  return "assets/gear/tent/" .. name
end

function AP.tentCamp(name)
  return "assets/scenes/forest/camp/tent/" .. name
end

function AP.cupRitual(name)
  return "assets/ritual/cup/" .. name
end

function AP.ui(name)
  return "assets/ui/" .. name
end

function AP.shared(name)
  return "assets/shared/" .. name
end

function AP.forestCamp(name)
  return "assets/scenes/forest/camp/" .. name
end

function AP.forestWorld(name)
  return "assets/scenes/forest/world/" .. name
end

function AP.sceneCamp(name)
  return Destinations.scenePath("camp", name)
end

function AP.sceneWorld(name)
  return Destinations.scenePath("world", name)
end

function AP.story(key)
  if HOME_STORY[key] then
    return "assets/scenes/home/story/" .. key .. ".png"
  end
  if PROLOGUE_STORY[key] then
    return "assets/scenes/forest/story/" .. key .. ".png"
  end
  return Destinations.scenePath("story", key .. ".png")
end

return AP
