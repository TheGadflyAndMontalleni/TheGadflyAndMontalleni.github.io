# 部署到 GitHub Pages

站点是纯静态产物，托管在 GitHub Pages 上，**完全免费**：不需要服务器、不需要备案、HTTPS 自动配置。

- **站点地址**：<https://thegadflyandmontalleni.github.io/>
- **仓库**：`TheGadflyAndMontalleni/TheGadflyAndMontalleni.github.io`
- **部署方式**：推送 `main` 分支 → GitHub Actions 自动构建 → 发布到 Pages

> [!IMPORTANT]
> 用的是 **用户主页仓库**（仓库名 = `<用户名>.github.io`），所以网址没有子路径，`astro.config.mjs` 里不需要配 `base`，笔记里写的 `/rss/`、`/posts/...` 这类绝对链接都能正常工作。这也是当初选这个仓库名的原因。

---

## 一、首次部署

### 1. 在 GitHub 上建空仓库

打开这个链接（仓库名已经填好）：

<https://github.com/new?name=TheGadflyAndMontalleni.github.io>

- 仓库名：`TheGadflyAndMontalleni.github.io`（必须一模一样，大小写无所谓）
- 可见性：**Public**（免费账号的 Pages 只支持公开仓库）
- **不要**勾选 "Add a README file"、".gitignore"、"license"——要一个完全空的仓库，否则推送时会有冲突

### 2. 打开 Pages（用 Actions 发布）

仓库页面 → **Settings → Pages** → 把 **Source** 选成 **GitHub Actions**。

（如果这里保持 "Deploy from a branch"，工作流产出的站点不会被发布。）

### 3. 推送代码

```powershell
cd D:\FOR_BLOG
git push -u origin main
```

第一次推送会弹出 **Git Credential Manager** 的 GitHub 登录窗口（浏览器授权或设备码），登录一次之后就不用再管了。

> [!NOTE]
> 本仓库已经在 `.git/config` 里配了 `http.https://github.com.proxy = http://127.0.0.1:12000`，因为这台机器直连 `github.com` 是不通的（`git clone` 会卡死）。
>
> - 如果你换了代理端口，或者不再需要用代理：`git config --unset http.https://github.com.proxy`
> - 代理没开的时候推送会失败，报 `Failed to connect ... 443`，那就先把代理客户端打开

### 4. 等构建完成

推送后到仓库的 **Actions** 标签页看 "Deploy to GitHub Pages"：绿色勾就说明发布成功，大约 2~4 分钟。第一次构建比较慢（要装 1100 多个依赖包）。

完成后访问 <https://thegadflyandmontalleni.github.io/>。

---

## 二、以后怎么更新笔记

```powershell
cd D:\FOR_BLOG
git add -A
git commit -m "notes: 新增 xxx 笔记"
git push
```

推送即发布，不需要在本地执行 `pnpm build`（构建在 GitHub 的机器上跑）。想先在本地确认效果，就用 `pnpm dev`。

---

## 三、换绑自定义域名（可选）

1. 在仓库里新建文件 `public/CNAME`，内容就一行你的域名，例如 `blog.example.com`（不要带 `https://`）；
2. 在域名商处添加 DNS 解析（4 条 A 记录指向 GitHub 的 IP，或者一条 CNAME 指向 `thegadflyandmontalleni.github.io`）：

   ```
   185.199.108.153
   185.199.109.153
   185.199.110.153
   185.199.111.153
   ```

3. 仓库 **Settings → Pages → Custom domain** 填上域名并保存，勾选 **Enforce HTTPS**（证书自动签发，可能要等几分钟）；
4. 把 `src/config/siteConfig.ts` 里的 `site_url` 改成 `https://你的域名`，提交推送。

> [!TIP]
> 用 GitHub Pages + 自己的域名**不需要 ICP 备案**，因为服务器在境外。代价是国内部分网络访问会偏慢或不稳定。

---

## 四、常见问题

| 现象 | 原因与处理 |
|---|---|
| Actions 里没有工作流 | 推送的分支名不是 `main`（工作流只监听 `main`），或者 `.github/workflows/deploy.yml` 没推上去 |
| 工作流报 `pnpm install` 失败 | 先看完整日志。国内镜像已写在 `.npmrc` 里，GitHub 的机器访问 `registry.npmmirror.com` 是通的 |
| 构建成功但页面 404 | Settings → Pages 里的 Source 没选成 "GitHub Actions" |
| 页面能开但样式全丢 | `_astro/` 目录被 Jekyll 吞了。本项目已放 `public/.nojekyll`，工作流里也有 `touch dist/.nojekyll`，正常情况下不会发生 |
| 推送报 `Failed to connect ... 443` | 本机代理没开（见第一部分第 3 步的说明） |
| 推送报 `Repository not found` | 仓库还没建，或者名字拼错了（必须是 `TheGadflyAndMontalleni.github.io`） |
| 想只改站点内容不触发部署 | 目前任何推送到 `main` 都会部署。可以在工作流 `on.push` 下加 `paths-ignore` |

---

## 五、和阿里云方案的关系

两种托管用的是**同一份构建产物**，随时可以切换，代码不用改（只改 `site_url`）：

- 想用国内服务器加速：按 [DEPLOY.md](DEPLOY.md) 走阿里云 + nginx，把 `dist/` 上传即可；
- 想省钱省运维：就用现在的 GitHub Pages。

`docs/nginx.conf` 和根目录的 `deploy.ps1` 都还留着，将来要搬回阿里云可以直接用。
