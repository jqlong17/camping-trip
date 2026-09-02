# 露营之旅 · 故事资源图谱

本地 React 工具，用稳定编号查看完整故事走向、运行时资源、制作源和遗漏审计。
它不会进入 3DS 游戏包。

## 启动

```bash
cd tools/story-atlas
npm install
npm run dev
```

浏览器打开终端显示的本地地址。`npm run dev` 会先重新扫描资源。

## 常用命令

```bash
npm run scan   # 更新 graph-index.json 与新资源编号
npm test       # 本地路径安全测试
npm run build  # 类型检查和静态构建
```

## 编号与数据

- `data/story-manifest.json`：剧情对象与关系，编号显式维护。
- `data/resource-registry.json`：资源路径到 `RES-####` 的永久映射。
- `data/review-status.json`：网页中保存的“待检查/待重做”标记。
- `public/graph-index.json`：扫描生成的网页数据。

资源删除后编号进入 tombstone，不会分配给新资源。请不要手工重新排序或复用编号。

## 本地文件权限

Vite 开发服务提供图片/音频预览和 Finder 定位，只允许访问当前仓库的
`game`、`docs`、`cia`、`scripts` 与 `tools/story-atlas`。绝对路径、目录穿越和指向仓库外的符号链接会被拒绝。

详细设计见 `docs/故事资源图谱-SPEC.md`。
