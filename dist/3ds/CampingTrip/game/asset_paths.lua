--[[ 露营之旅 — 资源路径（见 docs/资源目录-SPEC.md）]]

local AP = {
  scene = "forest",
  CUP_STYLES = {
    { id = "hakuji", name = "白瓷杯", file = "cup_01_hakuji.png", kind = "coffee" },
    { id = "aogama", name = "青磁湯吞", file = "cup_02_aogama.png", kind = "tea" },
    { id = "kozara", name = "茶杯碟", file = "cup_03_kozara.png", kind = "tea" },
    { id = "sumi", name = "墨釉马克", file = "cup_04_sumi.png", kind = "coffee" },
    { id = "beni", name = "朱泥茶盏", file = "cup_05_beni.png", kind = "tea" },
    { id = "matcha", name = "抹茶碗", file = "cup_06_matcha.png", kind = "tea" },
    { id = "enamel", name = "搪瓷马克", file = "cup_07_enamel.png", kind = "coffee" },
    { id = "take", name = "竹节杯", file = "cup_08_take.png", kind = "tea" },
    { id = "glass", name = "硝子咖啡", file = "cup_09_glass.png", kind = "coffee" }
  }
}

local HOME_STORY = { h1 = true, diary = true }

function AP.cupPath(file)
  return "assets/cups/" .. file
end

function AP.gearPath(id)
  return "assets/gear/" .. id .. ".png"
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

function AP.story(key)
  if HOME_STORY[key] then
    return "assets/scenes/home/story/" .. key .. ".png"
  end
  return "assets/scenes/forest/story/" .. key .. ".png"
end

return AP
