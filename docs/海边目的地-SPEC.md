# 海边目的地 Destination Pack SPEC

> 状态：已实现（2026-09-02）  
> 档位：C 场景包；复用现有 A 档帐篷、手冲、泡茶、钓鱼、品杯、做饭玩法。

## 1. 范围与流程

海边是第二个真实可玩目的地，不是日出/日落两个目的地。完整流程：

`title → prologue → cast（仅首次）→ destination → depart → play → homecoming → diary → title`

首次与后续新旅程都选择「林间营地 / 海边营地」。旧存档缺少目的地字段时默认
`forest`；当前行程与日记快照记录 `destinationId`。

## 2. Destination Pack 数据契约

每个包必须声明：

- `id / name / sceneRoot / storyAtlas`
- `layoutBuilder / spawn / firepit`
- `tiles`：语义、可行走、可搭帐篷、水深
- `audio`：BGM 与环境音 profile
- `vegetation / nature / ecology / effects`
- `timeProfiles`：清晨、白天、日落、夜晚色调与事件
- `story.depart`：目的地自己的出发与抵达分镜

共享 Runtime 只读取当前 pack；不得复制 main、营地装备或仪式模块。目的地切换时卸载上一
目的地贴图并按需预载当前包，3DS 启动不同时载入 forest 与 coast。

## 3. 海边资源清单

- 上屏：目的地预览 320×180；出发/抵达分镜 400×240。
- 地表：沙地 4 变体、湿沙，以及连续 400×64 硬像素海浪带；海面不得用
  深浅和浪型不一致的 16px 方块随机拼接。
- 植被：海岸松、耐盐灌木、海滨草。
- 自然物：礁石、漂流木。
- 生态：海鸟 2 帧、螃蟹 2 帧。海鸥有效轮廓约 18×14px、以 1× 绘制并在
  潮线礁石活动；落地后贴地横走再起飞，不使用林鸟弹跳轨迹。螃蟹有效轮廓约
  26×13px，须清楚显示双钳、足和深色外轮廓。
- 合成：`coast_static_base.png`，供 Old 3DS 单纹理静态路径。

所有运行时 PNG 从 `docs/promo/*_gen_ref.png` 确定性切图、NEAREST 缩放与限色；
`scripts/build-coast-assets.py::ASSET_PROVENANCE` 登记来源。含绿色植被的环境 sheet
采用洋红幕 CKE，不使用绿幕。

## 4. 地图与交互

地图为 25×15 格。北侧海水不可进入，中部沙滩为主活动区，边缘分布海岸松、灌木、海草、
礁石和漂流木；出生点与篝火位都在高潮线以上。帐篷、手冲、泡茶、做饭、品杯沿用沙地
可搭/可走语义；钓鱼以浅海边界作为水边判定。

## 5. 时间与性能预算

- 清晨：`coast_ocean_sunrise.png`；左侧淡金太阳、冷蓝紫海面、窄幅碎金倒影。
- 白天：高亮蓝海与浅金沙。
- 日落：`coast_ocean_sunset.png`；右侧橙红太阳、靛紫海面、宽幅铜色倒影。
- 夜晚：深蓝色罩、少量星光；不生成 forest 萤火虫与落叶。
- 光影方向：日出道具影子右移，日落影子左移且略长。
- 动态上限：日出海鸟 2 / 螃蟹 1，日落海鸟最多 1 / 螃蟹最多 3；静态模式
  优先单张 400×240 合成图叠加 400×64 时段海面。
- 环境音：桌面使用独立 `amb_ocean_waves` 45 秒 OGG 无缝循环；Old 3DS 使用从同一
  母带生成的 12 秒、22050Hz mono PCM WAV 静态循环，避免 BGM 与环境音双 MP3
  stream 长时间并发造成底层音频锁死。营地全域保持低音量，靠近潮线时提高响度；
  真机只在播放状态或目标音量变化时操作 Source，不得每帧查询或重设。
- 上屏目的地纹理按需加载；离开行程后允许 GC，不预载另一个目的地。

## 6. Story Atlas

稳定新增对象：`CHO-DESTINATION`、`DEST-FOREST`、`DEST-COAST`、
`BEAT-COAST-DEPART`、`BEAT-COAST-ARRIVE`、`SCN-COAST`、
`EVENT-COAST-SUNRISE`、`EVENT-COAST-SUNSET`。旧节点与边 ID 不重排。

两个目的地各自物化六组：地表、水系、植被、自然物、动态生物、合成产物；摆放实例使用
`PLACE-FOREST-*` / `PLACE-COAST-*` 稳定命名。

## 7. 验收

- forest 与 coast 均完成选择→抵达→通用玩法→夜晚→回家→日记。
- 截图含目的地选择、海边抵达、白天、日出/日落、夜晚、玩法与日记。
- `build-3ds-textures`、像素审计、playtest、Story Atlas scan/test/build 全部通过。
- Story Atlas 缺图、断边、重复 ID、PNG 缺 T3X 均为 0。
