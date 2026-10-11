import type { ProfileConfig } from "../types/profileConfig";

export const profileConfig: ProfileConfig = {
	// 头像
	// 图片路径支持三种格式：
	// 1. public 目录（以 "/" 开头，不优化）："/assets/images/avatar.webp"
	// 2. src 目录（不以 "/" 开头，自动优化但会增加构建时间，推荐）："assets/images/avatar.webp"
	// 3. 远程 URL："https://example.com/avatar.jpg"
	// 换成自己的头像：把图片放进 src/assets/images/ 覆盖 avatar.avif 即可，这里不用改
	avatar: "assets/images/avatar.avif",

	// 名字
	name: "RIME_SUN",

	// 个人签名
	bio: "把学过的东西写下来，才算真的学会。",

	// 链接配置
	// 已经预装的图标集：fa7-brands，fa7-regular，fa7-solid，material-symbols，simple-icons
	// 访问 https://icones.js.org/ 获取图标代码
	// 如果想使用尚未包含的图标集，需要先安装：pnpm add @iconify-json/<icon-set-name>
	// showName: true 时显示图标和名称，false 时只显示图标
	links: [
		{
			name: "GitHub",
			icon: "fa7-brands:github",
			// TODO: 改成你自己的 GitHub 主页
			url: "https://github.com/",
			showName: false,
		},
		{
			name: "RSS",
			icon: "fa7-solid:rss",
			url: "/rss/",
			showName: false,
		},
	],
};
