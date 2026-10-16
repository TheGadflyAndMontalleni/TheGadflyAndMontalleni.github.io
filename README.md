

## 快速开始

需要 Node.js >= 22.23 与 pnpm 11（`package.json` 里的 `preinstall` 会强制检查包管理器）。

```bash
pnpm install      # 首次安装依赖（.npmrc 已配好国内镜像）
pnpm dev          # 本地预览，改完即时刷新 → http://localhost:4321
pnpm build        # 构建到 dist/
pnpm preview      # 用构建产物起本地服务，最接近线上效果
pnpm check        # 检查文章与配置有没有写错
pnpm new-post     # 按模板新建一篇笔记
```

