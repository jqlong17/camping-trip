-- 露营之旅 — 单次运行期状态；跨周数据仍由 state.lua / persist.lua 管理。

local Runtime = {
  TOP_W = 400,
  TOP_H = 240,
  BOT_W = 320,
  BOT_H = 240,
  TILE = 16,
  buildId = "2026-09-02-destination-pack-coast",
}

Runtime.isConsole = love.system.getOS() == "Horizon" or love.system.getOS() == "3DS"
Runtime.staticPlayFx = Runtime.isConsole or os.getenv("LINJIAN_PLAY_FX") == "static"
Runtime.perfMode = Runtime.staticPlayFx and "static_play_fx" or "full_play_fx"
Runtime.campCanvasEnabled = Runtime.staticPlayFx and not Runtime.isConsole
Runtime.cheapWindFx = Runtime.isConsole or not Runtime.staticPlayFx
Runtime.critterFx = (not Runtime.staticPlayFx) or Runtime.isConsole or os.getenv("LINJIAN_CRITTER_FX") == "1"

Runtime.scene = "title"
Runtime.destinationId = "forest"
Runtime.quitConfirm = false
Runtime.quitConfirmChoice = 1 -- 1=留下 2=返回标题
Runtime.diaryPage = 1
Runtime.titlePulse = 0
Runtime.waterPhase = 0
Runtime.menuIndex = 1
Runtime.player = { x = 10, y = 9, facing = 0, castId = 1, walkFrame = 0, walkTimer = 0, idleT = 0 }
Runtime.selected = 1
Runtime.lanternOn = false
Runtime.canGoHome = false
Runtime.tentOpen = false
Runtime.tentPos = nil
Runtime.tentColorI = 1
Runtime.tentStyleI = 1
Runtime.tentDoorI = 1
Runtime.teaReady = false
Runtime.teaCups = 0
Runtime.cupKind = nil
Runtime.cupStyle = 1
Runtime.cupPick = false
Runtime.brewActive = false
Runtime.brewTimer = 0
Runtime.brewX = 10
Runtime.brewY = 9
Runtime.potSimmer = 0
Runtime.drippedOnce = false
Runtime.coffeeCups = 0
Runtime.ritual = nil
Runtime.codex = { i = 1 }
Runtime.departPendingPlay = false
Runtime.desktopBottom = nil
Runtime.uiFont = nil
Runtime.titleFont = nil
Runtime.perfWindow = 0
Runtime.perfFrames = 0
Runtime.perfSlowFrames = 0
Runtime.perfMaxDt = 0

Runtime.gear = {
  { id = "tent", name = "帐篷", tag = "过夜", x = 24, y = 60,
    lines = { "米白尖顶帐篷，轻便好搭。", "站在平地按 A 展开；再按一次收起。" } },
  { id = "drip", name = "手冲", tag = "仪式", x = 120, y = 60,
    lines = { "V60 与分享壶。闷蒸、绕圈、入杯。", "营地里选中后按 A 开始三步。" } },
  { id = "tea", name = "泡茶", tag = "仪式", x = 216, y = 60,
    lines = { "盖碗或公道杯。温杯、注水、出汤。", "营地里选中后按 A 开始泡茶。" } },
  { id = "rod", name = "钓竿", tag = "溪边", x = 24, y = 138,
    lines = { "小溪可以趟过去。站在水边甩一竿。", "偶尔有鱼跳起来。" } },
  { id = "cup", name = "杯子", tag = "品尝", x = 120, y = 138,
    lines = { "杯型会改这一口的口感描述。", "确认后有抬杯特写。" } },
  { id = "cook", name = "做饭", tag = "开饭", x = 216, y = 138,
    lines = { "午后热了就扇一阵。", "短短四下，风就来了。" } },
}

return Runtime
