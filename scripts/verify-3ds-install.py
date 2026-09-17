#!/usr/bin/env python3
"""真机安装预检。挡住上次翻车的那几类问题；过了才能对用户说「可以插卡」。

用法:
  python3 scripts/verify-3ds-install.py
  python3 scripts/verify-3ds-install.py --require-sd
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
MAIN = GAME / "main.lua"
RSF = ROOT / "cia" / "info.rsf"
DEPLOY = ROOT / "scripts" / "deploy-to-sd.sh"
BUILD_CIA = ROOT / "scripts" / "build-cia.sh"
ROMFS = ROOT / "build" / "cia" / "romfs"
DIST = ROOT / "dist" / "3ds" / "CampingTrip"
HB_NAME = "CampingTrip"
CIA_NAME = "CampingTrip.cia"

SD_CANDIDATES = (
    "/Volumes/NO NAME",
    "/Volumes/Untitled",
    "/Volumes/3DS",
    "/Volumes/NINTENDO3DS",
)

ok_n = warn_n = fail_n = 0


def pot(n: int) -> bool:
    return n > 0 and (n & (n - 1)) == 0


def log(kind: str, msg: str) -> None:
    global ok_n, warn_n, fail_n
    if kind == "OK":
        ok_n += 1
    elif kind == "WARN":
        warn_n += 1
    else:
        fail_n += 1
    print(f"[{kind:4}] {msg}")


def find_sd() -> Path | None:
    import os

    env = os.environ.get("SD")
    if env and Path(env).is_dir():
        return Path(env)
    for c in SD_CANDIDATES:
        p = Path(c)
        if p.is_dir():
            return p
    for vol in Path("/Volumes").iterdir():
        if not vol.is_dir():
            continue
        if (vol / "Nintendo 3DS").is_dir() or (vol / "3ds").is_dir():
            return vol
    return None


def extract_fn(src: str, name: str) -> str:
    m = re.search(rf"local function {name}\b.*?\nend\n", src, re.S)
    return m.group(0) if m else ""


def check_lua() -> None:
    src = MAIN.read_text(encoding="utf-8")
    assets_src = (GAME / "assets.lua").read_text(encoding="utf-8")
    preload_src = (GAME / "camp_preload.lua").read_text(encoding="utf-8")
    load_start = assets_src.find("function Assets.loadBoot")
    load_end = assets_src.find("\nend", load_start)
    load = assets_src[load_start:load_end] if load_start >= 0 else ""
    if "Assets.loadBoot()" not in src or not load:
        log("FAIL", "main.lua 未委托 Assets.loadBoot()")
        return

    title_pos = load.find('AP.ui("title_top.png")')
    if title_pos < 0:
        title_pos = load.find("title_top")
    grass_pos = load.find("tile_grass")
    if title_pos < 0:
        log("FAIL", "Assets.loadBoot 没有先加载 title_top")
    elif grass_pos >= 0 and title_pos > grass_pos:
        log("FAIL", "title_top 必须在地砖之前加载")
    else:
        log("OK", "标题图在 Assets.loadBoot 里最先加载")

    if "function Assets.detectRoot" in assets_src and "load_report.txt" in src:
        log("OK", "真机会写 load_report.txt 并探测 game/assets 前缀")
    else:
        log("FAIL", "缺少 detectAssetRoot / load_report.txt（真机无图时没法对照日志）")
    if "mountFullPath" in assets_src and '"sdmc:/"' in assets_src:
        log("OK", "真机挂载 SD 根目录读取旁路资源")
    else:
        log("FAIL", "真机必须 mountFullPath(sdmc:/) 后读取图片")

    write_pos = src.find('write("load_report.txt"')
    detect_pos = src.find("pcall(Assets.detectRoot)")
    if write_pos >= 0 and detect_pos >= 0 and write_pos < detect_pos:
        log("OK", "love.load 先写 boot 再探测路径")
    else:
        log("FAIL", "love.load 必须先写 load_report.txt 再调用 detectAssetRoot")

    if "function Assets.writeProbe" in assets_src and "getDirectoryItems" in assets_src:
        log("FAIL", "writeLoadProbe 禁止 getDirectoryItems（真机列目录会卡死/黑屏）")
    else:
        log("OK", "启动探测不列目录")

    if "function CampPreload.ensure" in preload_src and "tile_grass" not in load:
        log("OK", "营地贴图按需加载（ensureCamp），启动不读地砖")
    else:
        log("FAIL", "loadAssets 仍在启动时加载地砖")

    if "function Assets.load" not in assets_src:
        log("FAIL", "找不到 loadImage()")
    elif "setFilter" in assets_src and "pcall" in assets_src:
        log("OK", "loadImage 里 setFilter 有 pcall")
    else:
        log("FAIL", "loadImage 的 setFilter 必须 pcall（LovePotion 可能没有）")

    sfx = extract_fn(src, "playSfx")
    audio_src = (ROOT / "game" / "audio.lua").read_text(encoding="utf-8")
    play_sfx = audio_src if audio_src else sfx
    if "isConsole" in play_sfx and "setPitch" not in play_sfx.split("if isConsole")[1].split("end")[0]:
        log("OK", "真机 playSfx 不走 clone/setPitch")
    elif "pcall" in play_sfx and "setPitch" in play_sfx:
        log("WARN", "playSfx 仍可能在真机上 clone/setPitch")
    else:
        log("FAIL", "playSfx 缺少真机保护")

    amb_3ds = GAME / "audio" / "3ds" / "amb_creek.wav"
    if amb_3ds.is_file() and amb_3ds.stat().st_size > 100_000:
        log("OK", "真机溪水环境音使用静态 PCM WAV，避免 MP3 stream 锁帧")
    else:
        log("FAIL", "缺少 game/audio/3ds/amb_creek.wav（真机安全静态循环）")

    ocean_3ds = GAME / "audio" / "3ds" / "amb_ocean_waves.wav"
    if ocean_3ds.is_file() and ocean_3ds.stat().st_size > 100_000:
        log("OK", "真机海浪环境音使用静态 PCM WAV，避免 MP3 stream 锁死")
    else:
        log("FAIL", "缺少 game/audio/3ds/amb_ocean_waves.wav（真机安全静态循环）")

    if "console_prox_amb_bgm_switch" in audio_src:
        log("OK", "audio.lua 真机模式 console_prox_amb_bgm_switch")
    else:
        log("FAIL", "audio.lua 未设 console_prox_amb_bgm_switch")

    deploy = DEPLOY.read_text(encoding="utf-8")
    if "COPYFILE_DISABLE" in deploy and "._*" in deploy:
        log("OK", "deploy 排除 macOS AppleDouble (._*)")
    else:
        log("FAIL", "deploy-to-sd.sh 必须 COPYFILE_DISABLE 并排除 ._*")
    if "build-camp-static-base.py" in deploy:
        log("OK", "deploy 会生成营地离线底图")
    else:
        log("FAIL", "deploy 必须先生成 camp_static_base，再转换 T3X")

    if re.search(r'AP\.story\(', load):
        log("OK", "分镜走 asset_paths.story()")
    elif re.search(r'Assets\.load\("assets/story/', load):
        log("FAIL", "Assets.loadBoot 仍一次性加载分镜（应走 ensureStory）")
    else:
        log("OK", "分镜未在启动时全量加载")

    if re.search(r"c\d+_walk\.png", load) or re.search(r"for i = 1, 9 do[\s\S]*_walk", load):
        log("FAIL", "Assets.loadBoot 仍一次性加载九人走表")
    else:
        log("OK", "走表未在启动时全量加载")

    for fn in ("ensureStory", "ensureCast", "ensureWalk", "drawFitted"):
        if f"function Assets.{fn}" in assets_src:
            log("OK", f"有 {fn}()")
        else:
            log("FAIL", f"缺少 {fn}()")

    rounded = []
    for path in GAME.rglob("*.lua"):
        text = path.read_text(encoding="utf-8")
        if re.search(r'rectangle\s*\(\s*"[^"]+"\s*,[^)]+,\s*\d+\s*,\s*\d+\s*\)', text):
            for i, line in enumerate(text.splitlines(), 1):
                if re.search(r'rectangle\s*\(\s*"[^"]+"\s*,.+\d+\s*,\s*\d+\s*\)', line) and line.count(",") >= 6:
                    rounded.append(f"{path.relative_to(ROOT)}:{i}")
    if rounded:
        log("FAIL", "rectangle 带圆角参数，真机下屏会停绘: " + ", ".join(rounded[:6]))
    else:
        log("OK", "rectangle 未使用 LovePotion 不支持的圆角参数")

    copies_cia_into_hb = [
        ln
        for ln in deploy.splitlines()
        if re.search(r"^\s*cp\s+.*3ds/.+\.cia", ln) and "cias/" not in ln
    ]
    if copies_cia_into_hb:
        log("FAIL", "deploy-to-sd.sh 仍会把 CIA 拷进 Homebrew 目录")
    else:
        log("OK", "deploy 不会把 CIA 放进 Homebrew 目录")
    if 'HB_NAME="CampingTrip"' in deploy:
        log("OK", "Homebrew 目录名是 CampingTrip（不是拼音 linjian）")
    else:
        log("FAIL", "deploy 仍在用拼音目录名")

    build = BUILD_CIA.read_text(encoding="utf-8")
    if 'mkdir -p "$ROMFS/game"' in build and '"$ROMFS/game/"' in build:
        log("OK", "CIA RomFS 含 game/ 目录")
    else:
        log("FAIL", "build-cia.sh 没有把 game/ 打进 RomFS")


def check_rsf() -> None:
    text = RSF.read_text(encoding="utf-8")
    if re.search(r"SystemModeExt\s*:\s*Legacy", text):
        log("OK", "RSF SystemModeExt=Legacy（Old 3DS）")
    else:
        log("FAIL", "cia/info.rsf 未设 SystemModeExt: Legacy")
    if re.search(r"CpuSpeed\s*:\s*268MHz", text):
        log("OK", "RSF CpuSpeed=268MHz（Old 3DS）")
    else:
        log("FAIL", "cia/info.rsf 未设 CpuSpeed: 268MHz")
    if re.search(r"EnableL2Cache\s*:\s*false", text):
        log("OK", "RSF 已关闭 New 3DS L2 cache")
    else:
        log("FAIL", "cia/info.rsf 必须 EnableL2Cache: false")
    if re.search(r"CanAccessCore2\s*:\s*false", text):
        log("OK", "RSF 已关闭 New 3DS Core2")
    else:
        log("FAIL", "cia/info.rsf 必须 CanAccessCore2: false")

    build = BUILD_CIA.read_text(encoding="utf-8")
    if 'UNIQUE_ID="0xF4C4A"' in build:
        log("OK", "CIA 使用新 Homebrew Title ID 000400000F4C4A00")
    else:
        log("FAIL", "CIA Unique ID 不是预期的 0xF4C4A")
    if 'CIA_WITH_BANNER="${CIA_WITH_BANNER:-0}"' in build:
        log("OK", "实验 CIA 默认关闭 banner/audio")
    else:
        log("FAIL", "实验 CIA 未默认关闭 banner/audio")


def check_pngs() -> None:
    try:
        from PIL import Image
    except ImportError:
        log("FAIL", "需要 Pillow：pip3 install Pillow")
        return

    required = [
        GAME / "assets" / "ui" / "title_top.png",
        GAME / "assets" / "ui" / "title_bot.png",
        GAME / "assets" / "ui" / "ui_pack_bg.png",
        GAME / "assets" / "scenes" / "forest" / "camp" / "camp_static_base.png",
    ]
    for key in ("p1", "p2", "p3", "d1", "d2"):
        required.append(GAME / "assets" / "scenes" / "forest" / "story" / f"{key}.png")
    for key in ("h1",):
        required.append(GAME / "assets" / "scenes" / "home" / "story" / f"{key}.png")

    for path in required:
        if not path.is_file():
            log("FAIL", f"缺文件 {path.relative_to(ROOT)}")
            continue
        im = Image.open(path)
        w, h = im.size
        if pot(w) and pot(h):
            log("OK", f"{path.relative_to(GAME)} {w}x{h} POT")
        else:
            log("FAIL", f"{path.relative_to(GAME)} {w}x{h} 不是 2 的幂（先跑 pad-pot-textures.py）")
        t3x = path.with_suffix(".t3x")
        if t3x.is_file() and t3x.stat().st_size > 32:
            log("OK", f"{t3x.relative_to(GAME)} 已转换")
        else:
            log("FAIL", f"缺少 {t3x.relative_to(GAME)}（LovePotion 真机不直接读 PNG）")


def check_romfs() -> None:
    if not ROMFS.is_dir():
        log("WARN", "还没有 build/cia/romfs（先打一次 CIA）")
        return
    need = [
        ROMFS / "main.lua",
        ROMFS / "assets" / "ui" / "title_top.png",
        ROMFS / "game" / "main.lua",
        ROMFS / "game" / "assets" / "ui" / "title_top.png",
        ROMFS / "game" / "conf.lua",
    ]
    missing = [p.relative_to(ROMFS) for p in need if not p.is_file()]
    if missing:
        log("FAIL", "RomFS 缺: " + ", ".join(str(p) for p in missing))
    else:
        log("OK", "RomFS 同时有 /main.lua 与 /game/main.lua")


def check_dist(allow_cia_experiment: bool = False) -> None:
    cia = DIST / CIA_NAME
    tdsx = DIST / f"{HB_NAME}.3dsx"
    title = DIST / "game" / "assets" / "ui" / "title_top.png"
    camp = DIST / "game" / "assets" / "scenes" / "forest" / "camp" / "camp_static_base.t3x"
    if tdsx.is_file() and tdsx.stat().st_size > 100_000:
        log("OK", f"dist 3dsx {(tdsx.stat().st_size / 1e6):.1f} MB")
    else:
        log("FAIL", f"缺少 dist/3ds/{HB_NAME}/{HB_NAME}.3dsx（先跑 deploy 或复制 3dsx）")
    if title.is_file():
        log("OK", "dist/game 含 title_top.png")
    else:
        log("WARN", "dist/game 还没有同步标题图")
    if camp.is_file() and camp.stat().st_size > 32:
        log("OK", "dist/game 含 camp_static_base.t3x")
    else:
        log("FAIL", "dist/game 缺 camp_static_base.t3x（真机营地静态底图）")
    if cia.is_file():
        if allow_cia_experiment:
            log("OK", f"实验 CIA 已生成 {(cia.stat().st_size / 1e6):.1f} MB")
        else:
            log("WARN", f"dist 留有 CIA {(cia.stat().st_size / 1e6):.1f} MB；默认不得安装")
    else:
        log("OK", "dist 无 CampingTrip.cia（仅部署 Homebrew）")


def check_sd(require: bool, allow_cia_experiment: bool = False) -> None:
    sd = find_sd()
    if not sd:
        log("FAIL" if require else "WARN", "未挂载 SD；插卡后重跑本脚本才能验卡上布局")
        return

    hb = sd / "3ds" / HB_NAME
    cias = sd / "cias" / CIA_NAME
    log("OK", f"SD = {sd}")

    if (sd / "3ds" / "linjian").is_dir():
        log("FAIL", "卡上还有旧目录 3ds/linjian（HB 列表会露出拼音，应已删掉）")

    if (hb / f"{HB_NAME}.3dsx").is_file() and (hb / "game" / "main.lua").is_file():
        log("OK", f"卡上有 3ds/{HB_NAME}/{HB_NAME}.3dsx + game/")
    else:
        log("FAIL", f"卡上缺少 3ds/{HB_NAME} 的 3dsx 或 game/main.lua")

    title = hb / "game" / "assets" / "ui" / "title_top.png"
    if title.is_file():
        log("OK", "卡上有标题图 title_top.png")
    else:
        log("FAIL", "卡上 game/assets 没有 title_top.png")
    title_t3x = title.with_suffix(".t3x")
    if title_t3x.is_file() and title_t3x.stat().st_size > 32:
        log("OK", "卡上有真机纹理 title_top.t3x")
    else:
        log("FAIL", "卡上缺 title_top.t3x；PNG 在真机不会被直接加载")
    camp = hb / "game" / "assets" / "scenes" / "forest" / "camp" / "camp_static_base.t3x"
    if camp.is_file() and camp.stat().st_size > 32:
        log("OK", "卡上有营地静态底图 camp_static_base.t3x")
    else:
        log("FAIL", "卡上缺 camp_static_base.t3x；营地性能优化不会生效")

    if hb.is_dir():
        stray = list(hb.glob("*.cia")) + list(hb.glob("._*.cia"))
        big = [p for p in hb.iterdir() if p.is_file() and p.stat().st_size > 8_000_000]
        if stray or big:
            names = ", ".join(p.name for p in (stray + big))
            log("FAIL", f"3ds/{HB_NAME}/ 里有不该存在的大文件/CIA：{names}")
        else:
            log("OK", f"3ds/{HB_NAME}/ 没有 CIA 或超大文件")

        apple = [p for p in hb.rglob("._*") if p.is_file()]
        if apple:
            log("FAIL", f"卡上 3ds/{HB_NAME}/ 有 {len(apple)} 个 macOS ._* 垃圾文件（会干扰加载/hbmenu）")
        else:
            log("OK", f"卡上 3ds/{HB_NAME}/ 没有 ._* AppleDouble")

    cia_tool = sd / "CIA(tool)" / CIA_NAME
    if cias.is_file() or cia_tool.is_file():
        if allow_cia_experiment:
            log("OK", "卡上实验 CIA 位于 cias/ 或 CIA(tool)/，未混入 Homebrew 目录")
        else:
            log("FAIL", "卡上仍有可误装的 CampingTrip.cia；应隔离，只跑 3dsx")
    else:
        log("OK", "卡上无可误装的 CampingTrip.cia")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--require-sd", action="store_true", help="没插卡也算失败")
    ap.add_argument("--skip-sd", action="store_true", help="只检查源码与本地 dist，不读取已插入的 SD")
    ap.add_argument(
        "--allow-cia-experiment",
        action="store_true",
        help="仅在用户明确要求 CIA 单变量实验时允许 dist/SD 中存在 CIA",
    )
    args = ap.parse_args()

    print("== 露营之旅 真机安装预检 ==")
    if not MAIN.is_file():
        log("FAIL", f"找不到 {MAIN}")
        return 1

    check_lua()
    check_rsf()
    check_pngs()
    check_romfs()
    check_dist(args.allow_cia_experiment)
    if not args.skip_sd:
        check_sd(args.require_sd, args.allow_cia_experiment)

    print(f"-- {ok_n} ok / {warn_n} warn / {fail_n} fail --")
    if fail_n:
        print("RESULT FAIL  不要告诉用户可以拔卡安装")
        return 1
    print("RESULT PASS  电脑侧闸门通过")
    if args.allow_cia_experiment:
        print("CIA EXPERIMENT 仅表示结构通过；真机启动仍有 HOME 菜单异常风险")
    else:
        print("真机仍须：Homebrew 选择 LovePotion/CampingTrip；默认禁止安装 CampingTrip.cia")
    return 0


if __name__ == "__main__":
    sys.exit(main())
