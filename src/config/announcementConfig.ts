import type { AnnouncementConfig } from "../types/announcementConfig";

export const announcementConfig: AnnouncementConfig = {
	// 公告标题，留空则走 i18n 默认标题
	title: "关于本站",

	// 公告内容
	content:
		"这里是我的技术笔记本：编程语言、算法、系统与工具链，边学边记、持续修订。",

	// 是否允许用户关闭公告
	closable: true,

	link: {
		// 启用链接
		enable: true,
		// 链接文本
		text: "笔记怎么写",
		// 链接 URL
		url: "/posts/notes/how-to-write/",
		// 内部链接
		external: false,
	},
};
