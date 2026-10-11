# 部署到阿里云服务器（nginx 静态托管）

这个站点构建出来就是一堆静态文件，服务器上不需要 Node、不需要数据库、不需要常驻进程，nginx 发文件即可。

下面以 **阿里云 ECS + Ubuntu 22.04/24.04** 为例，其他 Linux 发行版只需替换包管理命令。

---

## 0. 前置条件

- 一台阿里云 ECS（1 核 1G 足够，静态站几乎没有 CPU 消耗）
- 安全组放行 **22（SSH）、80、443** 端口
- 一个已解析到服务器公网 IP 的域名（`A` 记录）。没有域名也可以用 IP 访问，但 HTTPS 需要域名
- 本机能 `ssh root@你的服务器IP` 登录（建议配好密钥登录）

> [!NOTE]
> 站点不需要备案相关配置即可测试，但**用国内服务器 + 域名对外提供 Web 服务，按规定需要完成 ICP 备案**。备案前可以先用 IP 访问验证效果。

---

## 1. 本地构建

在项目根目录（本机 Windows）执行：

```powershell
pnpm install     # 首次，已配置 npmmirror 镜像
pnpm build       # 产物输出到 dist\
```

构建完成后 `dist\` 里就是完整站点，关键内容：

| 路径 | 内容 |
|---|---|
| `dist/index.html` | 首页 |
| `dist/posts/**/index.html` | 每篇笔记 |
| `dist/_astro/` | 带哈希的 CSS/JS/字体，可长期缓存 |
| `dist/pagefind/` | 全文搜索索引 |
| `dist/404.html` | 404 页面 |

想先本地确认效果：`pnpm preview`，然后访问 <http://localhost:4321>。

---

## 2. 服务器上装 nginx

```bash
ssh root@你的服务器IP

apt update && apt install -y nginx
systemctl enable --now nginx
nginx -v          # 确认版本
```

确认防火墙/安全组放行了 80 端口，此时访问服务器 IP 应该能看到 nginx 默认页。

---

## 3. 上传站点文件

### 方式 A：用仓库里的一键脚本（推荐，本机 Windows 执行）

```powershell
# 在项目根目录
.\deploy.ps1 -Server root@你的服务器IP
```

脚本会依次完成：构建 → 打包 → 上传 → 在服务器上解包到 `/var/www/rimesun-blog`。

常用参数：

```powershell
.\deploy.ps1 -BuildOnly                                    # 只构建
.\deploy.ps1 -WebRoot /var/www/other -Clean                # 指定目录并先清空旧文件
```

### 方式 B：手动上传

```powershell
# 本机：打包
tar -czf dist.tar.gz -C dist .

# 本机：上传
scp dist.tar.gz root@你的服务器IP:/tmp/

# 服务器：解包
ssh root@你的服务器IP
mkdir -p /var/www/rimesun-blog
tar -xzf /tmp/dist.tar.gz -C /var/www/rimesun-blog
rm /tmp/dist.tar.gz
chown -R www-data:www-data /var/www/rimesun-blog
```

解包后确认一下：

```bash
ls /var/www/rimesun-blog        # 应该能看到 index.html、_astro、pagefind 等
```

---

## 4. 配置 nginx

把仓库里的 `docs/nginx.conf` 上传到服务器的 `/etc/nginx/conf.d/`：

```powershell
# 本机
scp docs\nginx.conf root@你的服务器IP:/etc/nginx/conf.d/rimesun.conf
```

```bash
# 服务器：改域名
vim /etc/nginx/conf.d/rimesun.conf
#   把 server_name blog.example.com; 改成你的域名
#   确认 root 指向 /var/www/rimesun-blog

# 顺便把默认站点关掉，避免抢占 80 端口的默认响应
rm -f /etc/nginx/sites-enabled/default

nginx -t                 # 配置语法检查，必须通过
systemctl reload nginx
```

现在访问域名（或服务器 IP）就能看到站点。若出现 403/404，按第 7 节排查。

---

## 5. 开启 HTTPS（Let's Encrypt，免费）

```bash
apt install -y certbot python3-certbot-nginx
certbot --nginx -d blog.example.com
```

certbot 会自动申请证书并改写 nginx 配置（加 443 监听与 HTTP→HTTPS 跳转）。证书续期由系统定时任务自动完成，可手动验证：

```bash
certbot renew --dry-run
```

> [!TIP]
> 阿里云域名解析生效通常需要几分钟，`certbot` 报 "challenge failed" 时先确认 `dig 你的域名` 返回的是这台服务器的 IP。

---

## 6. 以后怎么更新

改了笔记之后，重新发布只要一条命令：

```powershell
.\deploy.ps1 -Server root@你的服务器IP
```

nginx 直接读磁盘上的文件，**不需要 reload、不需要重启**。浏览器端因为 HTML 不缓存、`_astro` 资源带哈希，访客刷新即可看到新内容。

---

## 7. 常见问题

| 现象 | 原因与处理 |
|---|---|
| 访问显示 nginx 默认页 | `sites-enabled/default` 还在，删掉它并 `systemctl reload nginx` |
| 首页正常，点进笔记 404 | `try_files` 写错，确认 `docs/nginx.conf` 里是 `try_files $uri $uri/ $uri/index.html =404;` |
| 样式丢失、代码块没高亮 | `dist/_astro/` 没上传完整，重新打包上传 |
| 搜索框用不了 | `dist/pagefind/` 没上传，或 nginx 把它拦成了 404 |
| 改了笔记但访问还是旧的 | 浏览器缓存了 HTML；本配置已让 HTML 不缓存，硬刷新（Ctrl+F5）确认 |
| 构建时卡在下载字体 | 本机访问不到 `cdn.jsdelivr.net`，见 README 的「国内网络下的两个坑」 |
| 构建输出一堆红字 `npm warn` | 那是 npm 的配置提醒，不影响构建产物。但如果你在 PowerShell 里把 `$ErrorActionPreference` 设成了 `Stop`，这些写往 stderr 的内容会被当成错误、让命令中途退出——仓库里的 `deploy.ps1` 已经处理了这种情况 |
| 服务器磁盘被占满 | 每次上传都会在 `/tmp` 留包，脚本会自动删；手动部署时记得 `rm /tmp/dist.tar.gz` |

---

## 8. 附：换服务器/迁移

站点没有任何服务端状态，迁移就是搬目录：

```bash
# 旧服务器
tar -czf site.tar.gz -C /var/www/rimesun-blog .
# 传到新服务器后解包到同样的目录，再照第 4、5 步配 nginx 即可
```

域名解析改到新 IP，等 DNS 生效就行。
