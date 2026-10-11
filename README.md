# RIME_SUN 笔记站

一个用来长期整理技术笔记的静态博客。

- **框架**：[Astro](https://astro.build/)（纯静态输出，没有后端、没有数据库）
- **主题**：[Firefly](https://github.com/CuteLeaf/Firefly)（基于 [Fuwari](https://github.com/saicaca/fuwari) 二次开发）
- **部署**：阿里云 ECS + nginx 发静态文件，见 [docs/DEPLOY.md](docs/DEPLOY.md)
- **搜索**：Pagefind，构建时生成索引，不需要服务端

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

## 写一篇新笔记

1. 在 `src/content/posts/` 下按主题建文件，例如 `src/content/posts/algorithms/union-find.md`
2. 文件头部写 frontmatter（只有 `title` 和 `published` 必填）：

```yaml
---
title: 并查集：路径压缩与按秩合并
published: 2026-10-12
description: 一句话摘要，会显示在列表页和搜索结果里。
tags: [算法, 并查集, 复杂度]
category: 算法
series: 数据结构复习          # 可选，有先后顺序的笔记系列
seriesOrder: 3                # 可选，系列内的序号
slug: algorithms/union-find    # 决定网址：/posts/algorithms/union-find/
---
```

3. 正文用 Markdown 写，可以用 `[[algorithms/binary-search]]` 链接到别的笔记（路径相对 `src/content/posts`，不带扩展名）；`$公式$`、` ```mermaid ` 图表、GitHub 风格提示框都能用
4. `pnpm dev` 看效果，满意后按 [docs/DEPLOY.md](docs/DEPLOY.md) 发布

更细的写法（frontmatter 全字段、双链、和 Obsidian 配合）写在站内那篇笔记里：`src/content/posts/notes/how-to-write.md`，部署后访问 `/posts/notes/how-to-write/`。

### 用 Obsidian 写

把 `src/content/posts` 目录本身作为 Obsidian 仓库（vault）打开即可，笔记之间的关系图谱也能直接用。建议把 **设置 → 文件与链接 → 内部链接类型** 改成"基于仓库根目录的绝对路径"，这样 Obsidian 生成的 `[[路径]]` 和站点要求完全一致，不需要任何转换。

## 目录结构

```
src/
├── config/              # 所有可调配置（改这里就能改站点，不用碰组件）
│   ├── siteConfig.ts        # 站点名、域名、主题色、页面开关、分页
│   ├── navBarConfig.ts      # 顶部导航菜单
│   ├── sidebarConfig.ts     # 左右侧边栏、移动端底部组件
│   ├── profileConfig.ts     # 头像、昵称、签名、社交链接
│   ├── announcementConfig.ts# 侧边栏公告
│   ├── fontConfig.ts        # 字体
│   └── musicConfig.ts       # 音乐播放器（默认关闭）
├── content/
│   ├── posts/           # ★ 所有笔记都在这里，按主题分目录
│   ├── spec/            # 关于页（about.md）
│   ├── dynamic/         # 动态（页面默认关闭）
│   └── projects/        # 项目展示（页面默认关闭）
├── components/          # 组件
├── layouts/             # 布局
└── pages/               # 路由
docs/
├── DEPLOY.md            # 部署到阿里云的完整步骤
├── nginx.conf           # nginx 配置示例（含缓存与压缩策略）
└── README.firefly-upstream.md  # 主题原始说明，留作参考
deploy.ps1               # 一键构建 + 上传
```

## 常用配置改哪里

| 想改什么 | 改哪个文件 | 改哪一项 |
|---|---|---|
| 站点名称 | `src/config/siteConfig.ts` | `title` |
| 站点域名（**部署前必改**） | `src/config/siteConfig.ts` | `site_url` |
| 副标题 | `src/config/siteConfig.ts` | `subtitle` |
| 主题色 | `src/config/siteConfig.ts` | `themeColor.hue`（0–360） |
| 每页文章数 | `src/config/siteConfig.ts` | `pagination.postsPerPage` |
| 显示/隐藏某个页面 | `src/config/siteConfig.ts` | 顶部 `pages` 对象 |
| 导航菜单 | `src/config/navBarConfig.ts` | `getDynamicNavBarConfig()` |
| 侧边栏组件 | `src/config/sidebarConfig.ts` | `leftComponents` / `rightComponents` |
| 头像与昵称 | `src/config/profileConfig.ts` | `avatar` / `name` / `bio` |
| 侧边栏公告 | `src/config/announcementConfig.ts` | `content` |
| 分享大图（OpenGraph） | `src/config/siteConfig.ts` | `post.generateOgImages` 改成 `true`（构建会明显变慢） |

> [!NOTE]
> 主题自带的社交与生活向页面（友链、留言、动态、项目、相册、书签、打赏）默认全部关闭，只保留了笔记主线。想启用其中某个，把 `siteConfig.ts` 里 `pages` 对应的 `false` 改成 `true`，导航菜单项会自动出现。

## 国内网络下的两个坑

搭建过程中遇到并已处理，换机器或重装依赖时可能还会碰到：

1. **npm 官方源很慢**：`.npmrc` 里已把 registry 指向 `https://registry.npmmirror.com`。
2. **`cdn.jsdelivr.net` 访问不到**，而 Astro 的字体插件默认从它下载字体，会导致构建直接失败。处理方式：
   - 字体改用 `npm` provider，从本地安装的 `@fontsource/*` 包读取字体信息；
   - 在 `astro.config.mjs` 里把 provider 的 `cdn` 换成可用镜像 `https://fastly.jsdelivr.net/npm`。

   如果你的网络能直连 jsdelivr，把 `astro.config.mjs` 里 `fontProviders.npm({...})` 的参数删掉即可。
3. **GitHub 直连不通**，升级主题时用 `codeload.github.com` 拉 tarball（`git clone` 会卡住）：

   ```powershell
   curl.exe -sL -o firefly.tar.gz https://codeload.github.com/CuteLeaf/Firefly/tar.gz/refs/heads/master
   ```

## 遇到问题先试这几条

| 现象 | 原因 | 处理 |
|---|---|---|
| 浏览器打不开 | 地址少了端口 | 必须是 **http://localhost:4321/**，只输 `localhost` 会走 80 端口 |
| 首次打开转圈十几秒 | Vite 在现编译页面，属正常 | 等一次就好，之后是毫秒级 |
| 提示 `Another astro dev server is already running` | 上次的 dev 进程还占着 4321 端口 | `pnpm dev:stop` |
| 某页报 `xxx content not found`，或改了笔记不生效 | `.astro` 里的内容缓存被中断（改配置文件会触发 dev 自动重启，重启被打断时可能发生） | 先 `pnpm dev:stop`，再 `pnpm dev:clean` |
| 构建时一堆红字 `npm warn` | npm 的配置提醒，不影响产物 | 忽略即可 |

> [!TIP]
> `.astro/` 只是缓存目录（已在 `.gitignore` 里），删掉没有任何副作用，下次启动会自动重建。凡是"内容明明在、dev 却说找不到"的怪问题，先试 `pnpm dev:clean`。

## 发布到服务器

```powershell
.\deploy.ps1 -Server root@你的服务器IP      # 构建并上传
```

首次部署（装 nginx、配站点、申请 HTTPS 证书）请看 **[docs/DEPLOY.md](docs/DEPLOY.md)**，nginx 配置直接用 [docs/nginx.conf](docs/nginx.conf)。

## 上游与许可

主题来自 [CuteLeaf/Firefly](https://github.com/CuteLeaf/Firefly)，其上游是 [saicaca/fuwari](https://github.com/saicaca/fuwari)，主题使用文档见 <https://docs-firefly.cuteleaf.cn>。本仓库保留主题原有的 [LICENSE](LICENSE)，主题原始 README 备份在 [docs/README.firefly-upstream.md](docs/README.firefly-upstream.md)。
