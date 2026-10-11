<#
.SYNOPSIS
    一键构建笔记站并上传到阿里云服务器。

.DESCRIPTION
    流程：本地 pnpm build → 打包 dist/ → scp 上传 → ssh 解包到 nginx 站点目录。
    站点是纯静态文件，上传完不需要重启任何服务。

.PARAMETER Server
    服务器地址，格式 user@host，例如 root@123.45.67.89

.PARAMETER WebRoot
    服务器上的站点目录，要和 docs/nginx.conf 里的 root 保持一致

.PARAMETER BuildOnly
    只本地构建，不上传

.PARAMETER Clean
    上传前先清空站点目录。会删除服务器上的旧文件，能避免残留旧页面，但要确认目录填对了

.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -BuildOnly
    .\deploy.ps1 -Server root@1.2.3.4 -WebRoot /var/www/rimesun-blog -Clean

.NOTES
    需要本机有 ssh / scp（Windows 10 以上自带 OpenSSH 客户端）和 tar。
    首次使用建议先按 docs/DEPLOY.md 手动走一遍，确认 nginx 配好了。
#>
param(
	[string]$Server = "root@your-server-ip",
	[string]$WebRoot = "/var/www/rimesun-blog",
	[switch]$BuildOnly,
	[switch]$Clean
)

$ErrorActionPreference = "Stop"

# 原生命令（pnpm / ssh / scp / tar）往 stderr 写内容时，Windows PowerShell 会把每一行
# 包装成 ErrorRecord；在 Stop 策略下这会被当成终止错误，导致命令其实成功了、脚本却半途
# 退出（npm 的 deprecation 警告就会触发）。这里在调用期间把策略降回 Continue，改用退出
# 码判断成败。
function Invoke-Native {
	param(
		[Parameter(Mandatory)][scriptblock]$Command,
		[Parameter(Mandatory)][string]$Action
	)
	$previous = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		& $Command
		$code = $LASTEXITCODE
	}
	finally {
		$ErrorActionPreference = $previous
	}
	if ($code -ne 0) { throw "$Action 失败（退出码 $code）" }
}

foreach ($tool in @("ssh", "scp", "tar")) {
	if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
		throw "缺少命令 $tool，请先安装（Windows 可在「设置 → 应用 → 可选功能」里安装 OpenSSH 客户端）"
	}
}

if ($Server -eq "root@your-server-ip" -and -not $BuildOnly) {
	throw "请先用 -Server 参数指定服务器地址，或先修改本脚本顶部的默认值"
}

Push-Location $PSScriptRoot
try {
	Write-Host "[1/3] 本地构建 ..." -ForegroundColor Cyan
	Invoke-Native { pnpm build } "本地构建"

	if ($BuildOnly) {
		Write-Host "已跳过上传，构建产物在 dist\ 目录。" -ForegroundColor Green
		return
	}

	$archive = Join-Path $env:TEMP "rimesun-dist.tar.gz"
	if (Test-Path $archive) { Remove-Item $archive -Force }

	Write-Host "[2/3] 打包 dist ..." -ForegroundColor Cyan
	Invoke-Native { tar -czf $archive -C dist . } "打包"
	$sizeMB = [math]::Round((Get-Item $archive).Length / 1MB, 1)
	Write-Host "      包大小 $sizeMB MB"

	Write-Host "[3/3] 上传到 $Server ..." -ForegroundColor Cyan
	Invoke-Native { ssh $Server "mkdir -p $WebRoot" } "连接服务器 $Server"

	if ($Clean) {
		Write-Host "      清空 $WebRoot ..." -ForegroundColor Yellow
		Invoke-Native { ssh $Server "rm -rf ${WebRoot}/*" } "清空站点目录"
	}

	Invoke-Native { scp $archive "${Server}:/tmp/rimesun-dist.tar.gz" } "上传"

	Invoke-Native { ssh $Server "tar -xzf /tmp/rimesun-dist.tar.gz -C $WebRoot && rm -f /tmp/rimesun-dist.tar.gz" } "服务器上解包"

	Remove-Item $archive -Force
	Write-Host "部署完成。" -ForegroundColor Green
	Write-Host "如果是首次部署，请继续按 docs/DEPLOY.md 配置 nginx 与 HTTPS。" -ForegroundColor Yellow
}
finally {
	Pop-Location
}
