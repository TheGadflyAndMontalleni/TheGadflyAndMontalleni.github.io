---
title: 本站笔记怎么写（写作速查）
published: 2026-10-10
description: 这个站点是怎么组织的：frontmatter 字段、Obsidian 双链、提示框、公式与图表语法，以及本地预览和构建的命令，一页写完，方便随时回来查。
image: ""
tags: [写作, Markdown, Obsidian, 站点说明]
category: 站点说明
slug: notes/how-to-write
pinned: true
---

这页是写给未来的自己看的：隔一段时间不动笔就容易忘，需要什么直接翻这里。

## 笔记放在哪

所有笔记都是 `src/content/posts/` 下的 Markdown 文件，目录按主题分：

| 目录 | 放什么 |
|---|---|
| `programming/` | 语言、库、框架、性能优化 |
| `algorithms/` | 算法与数据结构 |
| `systems/` | 操作系统、网络、体系结构 |
| `notes/` | 站点说明、读书笔记、杂项 |

文件名只影响引用，真正决定网址的是 frontmatter 里的 `slug`：`slug: notes/how-to-write` 就对应 `/posts/notes/how-to-write/`。

## frontmatter 字段速查

只有 `title` 和 `published` 是必填的，其余都可以不写。

```yaml
---
title: 标题                     # 必填
published: 2026-10-10           # 必填，用于归档和排序
updated: 2026-10-20             # 可选，写了会显示"上次编辑"
description: 一句话摘要           # 列表页和搜索结果里显示
image: ""                       # 封面图，留空则没有封面
tags: [CUDA, 性能优化]           # 细粒度关键词，建议 2~4 个
category: 编程                   # 顶层分类，一篇只能有一个
series: CUDA 算子优化            # 可选，有先后顺序的连续笔记
seriesOrder: 1                  # 系列内的序号
pinned: false                   # true 则置顶到首页
draft: false                    # true 则只在本地可见，不会发布
slug: programming/cuda-gemm     # 网址，建议和文件路径保持一致
---
```

## 双链：把笔记连起来

正文里写 `[[programming/cuda-gemm]]` 就能链到另一篇笔记。它单独成段时会渲染成一张卡片：

[[programming/cuda-gemm]]

出现在句子中间时则变成普通链接，链接文字自动取目标笔记的标题；想改文字就用 `|`：`[[programming/cuda-gemm|上一篇]]`。

链接目标按「slug → 文件路径 → 裸文件名」的顺序匹配，用**文件路径**（相对 `src/content/posts`）最稳妥。

## 用 Obsidian 写笔记

把 `src/content/posts` 这个目录本身作为 Obsidian 仓库（vault）打开，就能用 Obsidian 的编辑器写、用它的关系图谱看笔记之间的连接。

改一个设置会让双链完全对齐：**设置 → 文件与链接 → 链接 → 内部链接类型 → 基于仓库根目录的绝对路径**。这样 Obsidian 插入的 `[[programming/cuda-gemm]]` 正好就是站点需要的写法，不需要任何转换。

## 提示框、公式、图表

提示框用 GitHub 风格：

> [!NOTE]
> 用来补充说明，四种类型分别是 `NOTE` / `TIP` / `IMPORTANT` / `WARNING`。

行内公式写成 `$E = mc^2$`，独立成行的公式用 `$$` 包起来：

$$
\text{AI} = \frac{2MNK}{4(MK + KN + MN)}
$$

流程图/时序图直接放 `mermaid` 代码块：

```mermaid
flowchart LR
  A[写笔记] --> B{本地预览}
  B -->|满意| C[构建]
  B -->|不满意| A
  C --> D[上传服务器]
```

代码块会带上语言标签、行号和复制按钮，长代码可以折叠：

```python title="binary_search.py" showLineNumbers collapse={3-6}
def lower_bound(nums: list[int], target: int) -> int:
    lo, hi = 0, len(nums)
    while lo < hi:
        mid = (lo + hi) // 2
        if nums[mid] < target:
            lo = mid + 1
        else:
            hi = mid
    return lo
```

## 日常命令

```bash
pnpm dev          # 本地预览，改动即时刷新（http://localhost:4321）
pnpm new-post     # 按模板新建一篇笔记
pnpm check        # 检查文章与配置有没有写错
pnpm build        # 构建到 dist/，顺便生成搜索索引
pnpm preview      # 用构建产物起一个本地服务，最接近线上效果
```

发布到服务器的步骤写在仓库根目录的 [README.md](/about/) 和 `docs/nginx.conf` 里。
