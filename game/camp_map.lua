--[[ 露营之旅 — 营地地图与碰撞（DEV-068e P5 · docs/代码架构-SPEC.md） ]]

local CampMap = {}

local host

local map = {}
local decals = {}
local firepit = { x = 12, y = 10 }
local treeTiles = {}
local waterTiles = {}
local decalRows = {}
local propRows = {}
local treeVariants = {}
local nestTiles = {}
local TENT_HALF_WIDTH = 1

function CampMap.bindHost(h)
  host = h
end

function CampMap.isWater(t)
  local semantic = Destinations.current().tiles[t]
  return semantic and semantic.water == true or false
end

function CampMap.isDeepWater(t)
  local semantic = Destinations.current().tiles[t]
  return semantic and semantic.depth == "deep" or false
end

function CampMap.isOpenGround(t)
  local semantic = Destinations.current().tiles[t]
  return semantic and semantic.campable == true or false
end

function CampMap.isMeadow(t)
  local semantic = Destinations.current().tiles[t]
  return semantic and semantic.material == "grass" or false
end

function CampMap.creekCenterX(y)
  local wiggle = math.floor(1.4 * math.sin(y * 0.35) + 0.9 * math.sin(y * 0.72 + 0.8))
  return 17 + wiggle
end

function CampMap.tileKey(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

function CampMap.getMap() return map end
function CampMap.getDecals() return decals end
function CampMap.getFirepit() return firepit end
function CampMap.getTreeTiles() return treeTiles end
function CampMap.getWaterTiles() return waterTiles end
function CampMap.getDecalRows() return decalRows end
function CampMap.getPropRows() return propRows end
function CampMap.getTreeVariants() return treeVariants end
function CampMap.getNestTiles() return nestTiles end

function CampMap.tileAt(tx, ty)
  local row = map[ty]
  return row and row[tx] or nil
end

function CampMap.tentOccupies(tx, ty)
  if not host or not host.getTentOpen or not host.getTentOpen() then return false end
  local tent = host.getTentPos and host.getTentPos()
  return tent ~= nil
    and ty == tent.y
    and math.abs(tx - tent.x) <= TENT_HALF_WIDTH
end

function CampMap.canPitchTent(tx, ty)
  for x = tx - TENT_HALF_WIDTH, tx + TENT_HALF_WIDTH do
    if not map[ty] or not CampMap.isOpenGround(map[ty][x]) then return false end
  end
  return true
end

function CampMap.walkable(tx, ty)
  local row = map[ty]
  if not row then return false end
  -- 展开帐篷的布面约三格宽；底边三格不可穿过，前后仍可绕行。
  if CampMap.tentOccupies(tx, ty) then return false end
  local t = row[tx]
  local semantic = Destinations.current().tiles[t]
  return semantic and semantic.walkable == true or false
end

function CampMap.treeVariant(tx, ty)
  return treeVariants[CampMap.tileKey(tx, ty)] or ((tx * 5 + ty * 3) % 12)
end

function CampMap.pickOpenNear(tx, ty)
  local spots = {}
  for dy = -2, 3 do
    for dx = -3, 3 do
      local x, y = tx + dx, ty + dy
      if CampMap.walkable(x, y) and map[y] and CampMap.isOpenGround(map[y][x]) then
        spots[#spots + 1] = { x = x, y = y }
      end
    end
  end
  if #spots == 0 then return tx, ty + 1 end
  local s = spots[love.math.random(#spots)]
  return s.x, s.y
end

function CampMap.build()
  if not host then return end
  local TOP_W, TOP_H, TILE = host.TOP_W, host.TOP_H, host.TILE
  local cols, rows = TOP_W / TILE, TOP_H / TILE
  map = {}
  decals = {}
  treeTiles = {}
  if host.onBuildStart then host.onBuildStart() end

  local pack = Destinations.current()
  if pack.layoutBuilder == "coast" then
    for y = 0, rows - 1 do
      map[y] = {}
      for x = 0, cols - 1 do
        if y <= 2 then map[y][x] = 2
        elseif y == 3 then map[y][x] = 8
        elseif y == 4 then map[y][x] = 9
        elseif x >= 7 and x <= 16 and y >= 7 and y <= 12 then map[y][x] = 7
        else map[y][x] = 0 end
      end
    end
    local function place(kind, points, tile)
      for _, p in ipairs(points) do
        local x, y = p[1], p[2]
        if tile then map[y][x] = tile end
        decals[#decals + 1] = { x = x, y = y, kind = kind, v = p[3] or 0 }
        if kind == "coast-pine" then treeTiles[#treeTiles + 1] = { x = x, y = y, v = p[3] or 0 } end
      end
    end
    place("coast-pine", {{1,6},{22,6},{2,12},{21,12}}, 3)
    place("salt-shrub", {{4,7},{19,7},{3,10},{20,11}}, 6)
    place("beach-grass", {{6,5},{18,5},{1,9},{23,9},{5,13},{19,13}})
    place("reef-rock", {{3,4},{7,4},{18,4},{22,4},{2,8},{21,9}}, 4)
    place("driftwood", {{5,6},{18,10},{3,13}})
    local fruitTrees = host.getFruitTrees and host.getFruitTrees() or {}
    for k in pairs(fruitTrees) do fruitTrees[k] = nil end
    firepit.x, firepit.y = pack.firepit.x, pack.firepit.y
    if host.resetTent then host.resetTent() end
    return
  end

  for y = 0, rows - 1 do
    map[y] = {}
    local cx = CampMap.creekCenterX(y)
    local wide = 1
    for x = 0, cols - 1 do
      local t = ((x * 3 + y * 5) % 2 == 0) and 0 or 1
      local dx = x - cx
      if math.abs(dx) <= wide then
        t = 2
      elseif math.abs(dx) == wide + 1 then
        t = 8
      elseif math.abs(dx) == wide + 2 and ((x + y) % 3 ~= 0) then
        t = 8
      end
      map[y][x] = t
    end
  end

  for y = 8, 12 do
    for x = 8, 13 do
      if map[y] and map[y][x] and not CampMap.isWater(map[y][x]) then
        map[y][x] = 7
      end
    end
  end

  for y = 5, 9 do
    local cx = CampMap.creekCenterX(y)
    for x = cx - 2, cx + 2 do
      if map[y] and x >= 0 and map[y][x] ~= nil then
        if math.abs(x - cx) <= 1 then map[y][x] = 8
        elseif CampMap.isDeepWater(map[y][x]) then map[y][x] = 8 end
      end
    end
  end

  local trees = {
    {1,1,0},{2,0,8},{4,1,1},{6,0,9},{0,3,4},{3,4,10},{7,2,6},{9,0,11},
    {1,6,2},{2,8,0},{4,7,3},{0,10,8},{3,11,5},{5,13,9},{7,13,6},
    {10,1,1},{16,0,7},{18,0,10},{19,2,2},{21,1,3},{22,3,11},{23,0,4},
    {20,5,6},{22,6,0},{23,8,7},{23,10,8},{21,12,2},{23,13,5},
    {6,5,9},{8,3,2},{2,12,10},{0,7,1},{14,2,11},{15,12,8}
  }
  for _, p in ipairs(trees) do
    local x, y, v = p[1], p[2], p[3] or 0
    if map[y] and map[y][x] and not CampMap.isWater(map[y][x]) then
      map[y][x] = 3
      decals[#decals + 1] = { x = x, y = y, kind = "tree", v = v }
      treeTiles[#treeTiles + 1] = { x = x, y = y, v = v }
    end
  end

  for i = 1, math.min(4, #treeTiles) do
    local t = treeTiles[1 + (i * 5 + 2) % #treeTiles]
    decals[#decals + 1] = { x = t.x, y = t.y, kind = "nest", v = i % 3 }
  end

  local fruitTrees = host.getFruitTrees and host.getFruitTrees() or {}
  for k in pairs(fruitTrees) do fruitTrees[k] = nil end
  for _, p in ipairs({ {2, 8}, {4, 7}, {6, 5}, {8, 3}, {3, 11}, {5, 13}, {1, 6}, {7, 2} }) do
    local x, y = p[1], p[2]
    if map[y] and map[y][x] == 3 then
      fruitTrees[tostring(x) .. ":" .. tostring(y)] = 1 + ((x + y) % 2)
    end
  end

  for _, p in ipairs({ {5,3,0},{8,6,1},{13,5,2},{17,6,0},{11,11,1},{4,9,2},{19,10,0} }) do
    local x, y, v = p[1], p[2], p[3]
    if map[y] and map[y][x] and not CampMap.isWater(map[y][x]) and map[y][x] ~= 3 then
      map[y][x] = 6
      decals[#decals + 1] = { x = x, y = y, kind = "bush", v = v }
    end
  end

  for _, p in ipairs({ {8,7,0},{14,6,1},{6,12,2},{12,4,0},{20,5,1} }) do
    local x, y, v = p[1], p[2], p[3]
    if map[y] and map[y][x] and not CampMap.isWater(map[y][x]) and map[y][x] < 3 then
      map[y][x] = 4
      decals[#decals + 1] = { x = x, y = y, kind = "stone", v = v }
    end
  end

  for _, p in ipairs({
    {5,5,"flower",0},{7,4,"flower",1},{10,7,"flower",2},{13,9,"flower",3},
    {15,6,"flower",1},{3,7,"flower",0},{9,11,"flower",2},{18,4,"flower",3},
    {16,7,"reed",0},{19,8,"reed",0},{17,11,"reed",0},{21,6,"reed",0},
    {11,8,"log",0},{4,11,"log",0},
    {12,9,"stump",0},
    {6,8,"flower",0},{9,7,"flower",1},{14,8,"flower",2},{8,11,"flower",3},
    {10,12,"flower",1},{7,10,"flower",0}
  }) do
    local x, y, kind, v = p[1], p[2], p[3], p[4]
    if map[y] and map[y][x] and (CampMap.isOpenGround(map[y][x]) or CampMap.isWater(map[y][x])) then
      if kind == "reed" and not CampMap.isWater(map[y][x]) then
        -- reeds prefer water edge
      else
        decals[#decals + 1] = { x = x, y = y, kind = kind, v = v }
      end
    end
    if kind == "reed" then
      local cx = CampMap.creekCenterX(y)
      decals[#decals + 1] = { x = cx - 1, y = y, kind = "reed", v = 0 }
    end
  end

  map[10][11] = 7
  map[10][12] = 7
  if host.resetTent then host.resetTent() end
  firepit.x, firepit.y = pack.firepit.x, pack.firepit.y

  for _, p in ipairs({ {CampMap.creekCenterX(6), 6, 0}, {CampMap.creekCenterX(7) + 1, 7, 1}, {CampMap.creekCenterX(8), 8, 2} }) do
    local x, y, v = p[1], p[2], p[3]
    if map[y] and map[y][x] and CampMap.isWater(map[y][x]) then
      decals[#decals + 1] = { x = x, y = y, kind = "step", v = v }
    end
  end
  do
    local y, x = 13, CampMap.creekCenterX(13)
    if map[y] and map[y][x] then
      decals[#decals + 1] = { x = x, y = y, kind = "pier", v = 0 }
    end
  end

  -- 顶部五行由连续远景树林覆盖，并明确设为不可进入；不能把仍可行走、
  -- 仍会生成鸟的地图格藏在背景图下面。
  for y = 0, 4 do
    for x = 0, cols - 1 do map[y][x] = 10 end
  end
  local visibleDecals = {}
  for _, decal in ipairs(decals) do
    if decal.y >= 5 then visibleDecals[#visibleDecals + 1] = decal end
  end
  decals = visibleDecals
  local visibleTrees = {}
  for _, tree in ipairs(treeTiles) do
    if tree.y >= 5 then visibleTrees[#visibleTrees + 1] = tree end
  end
  treeTiles = visibleTrees
  for key in pairs(fruitTrees) do
    local y = tonumber(key:match(":(%d+)$"))
    if y and y < 5 then fruitTrees[key] = nil end
  end
end

function CampMap.indexRenderData()
  if not host then return end
  local TOP_W, TOP_H, TILE = host.TOP_W, host.TOP_H, host.TILE
  local cols, rows = TOP_W / TILE, TOP_H / TILE
  local assets = host.getAssets and host.getAssets() or {}
  local staticPlayFx = host.staticPlayFx
  local bakeProps = staticPlayFx and assets.campStaticBase ~= nil
  decalRows, propRows, treeVariants, nestTiles, waterTiles = {}, {}, {}, {}, {}
  for y = 0, rows - 1 do
    decalRows[y], propRows[y] = {}, {}
  end
  for _, d in ipairs(decals) do
    if decalRows[d.y] then decalRows[d.y][#decalRows[d.y] + 1] = d end
    if d.kind == "tree" then treeVariants[CampMap.tileKey(d.x, d.y)] = d.v % 12 end
    if d.kind == "nest" then nestTiles[CampMap.tileKey(d.x, d.y)] = true end
  end
  for y = 0, rows - 1 do
    for x = 0, cols - 1 do
      local t = map[y] and map[y][x]
      if t == 2 or t == 8 then
        if t == 2 and ((x + y) % 2 == 0) then
          waterTiles[#waterTiles + 1] = { x = x, y = y }
        end
      elseif bakeProps then
        if t == 5 then
          propRows[y][#propRows[y] + 1] = { t = t, x = x, y = y }
        end
      elseif t == 3 or t == 4 or t == 5 or t == 6 then
        propRows[y][#propRows[y] + 1] = { t = t, x = x, y = y }
      end
    end
  end
end

return CampMap
