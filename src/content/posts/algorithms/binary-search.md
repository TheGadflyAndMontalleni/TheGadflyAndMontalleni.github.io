---
title: 二分查找：把边界条件一次想清楚
published: 2026-09-28
description: 二分查找的代码谁都写过，但边界条件总在悄悄出错。用循环不变式把三种写法和 lower_bound / upper_bound 一次讲清楚。
image: ""
tags: [算法, 二分查找, 复杂度]
category: 算法
slug: algorithms/binary-search
---

二分查找的思想很简单，实现却很容易写错：多一个等号、少一次赋值，就会死循环或者漏掉边界元素。这篇笔记不背模板，而是用**循环不变式**把边界条件推出来。

## 循环不变式

写二分之前先声明一件事：**我的区间表示什么。**

以「查找目标值的下标，不存在返回 −1」为例，取左闭右开区间 $[lo, hi)$，并维持不变式：

> 目标值如果存在，它的下标一定落在 $[lo, hi)$ 内。

每一轮循环都要让这个不变式继续成立，循环结束时 $lo = hi$，区间为空，说明目标不存在。

## 写法一：左闭右开（推荐）

```python title="binary_search.py" showLineNumbers
def binary_search(nums: list[int], target: int) -> int:
    lo, hi = 0, len(nums)          # 区间 [lo, hi)
    while lo < hi:                 # 区间为空时停止
        mid = lo + (hi - lo) // 2  # 防溢出，且 mid 一定落在 [lo, hi) 内
        if nums[mid] == target:
            return mid
        elif nums[mid] < target:
            lo = mid + 1           # mid 已排除，新区间 [mid+1, hi)
        else:
            hi = mid               # mid 已排除，新区间 [lo, mid)
    return -1
```

这个写法有三个不容易错的地方：

- `hi` 初值是 `len(nums)` 而不是 `len(nums) - 1`，因为区间是右开的；
- `lo = mid + 1` 与 `hi = mid` **不对称**——这是右开区间的必然结果，不是笔误；
- 循环条件 `lo < hi` 对应"区间非空"，不需要 `<=`。

## 写法二：闭区间

如果坚持用 $[lo, hi]$：

```python
def binary_search_closed(nums: list[int], target: int) -> int:
    lo, hi = 0, len(nums) - 1      # 区间 [lo, hi]
    while lo <= hi:                # 区间非空
        mid = lo + (hi - lo) // 2
        if nums[mid] == target:
            return mid
        elif nums[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1
```

对照着看：闭区间下 `hi = len(nums) - 1`、循环条件 `lo <= hi`、右边界收缩是 `hi = mid - 1`。**承诺什么区间，就配什么样的边界更新**，三者必须自洽。

## 两种边界的变体

实际写代码时，更常需要的是「第一个不小于 target 的位置」和「第一个大于 target 的位置」，它们统一叫 `lower_bound` / `upper_bound`：

| 函数 | 含义 | 返回值范围 |
|---|---|---|
| `lower_bound` | 第一个 $\ge$ target 的下标 | $[0, n]$ |
| `upper_bound` | 第一个 $>$ target 的下标 | $[0, n]$ |

```python
def lower_bound(nums: list[int], target: int) -> int:
    lo, hi = 0, len(nums)
    while lo < hi:
        mid = (lo + hi) // 2
        if nums[mid] < target:     # 只在"肯定不是答案"时右移
            lo = mid + 1
        else:                      # mid 可能是答案，保留
            hi = mid
    return lo
```

关键区别在于：**等于目标值时不要立刻返回**，而是继续缩小范围，把 `mid` 保留在区间里。`upper_bound` 只需把判断改成 `nums[mid] <= target`。

有了这两个，就可以直接表达很多问题：

- target 出现次数 = `upper_bound - lower_bound`；
- 第一个 $\ge$ target = `lower_bound`；
- 最后一个 $\le$ target = `lower_bound(target + 1) - 1`。

## 二分答案

二分不止能查下标，也能在**答案空间**上二分——只要答案具有单调性（满足条件的解都在某一侧）。模板长这样：

```python
def min_feasible(lo: int, hi: int, feasible) -> int:
    while lo < hi:
        mid = (lo + hi) // 2
        if feasible(mid):
            hi = mid          # mid 可行，答案可能是它或更小
        else:
            lo = mid + 1      # mid 不可行，答案一定更大
    return lo
```

典型问题：分割数组的最大值最小化、求最小的最大距离、整数平方根。难度不在二分本身，而在写对那个 `feasible` 函数。

## 复杂度

| 操作 | 时间复杂度 | 说明 |
|---|---|---|
| 单次查找 | $O(\log n)$ | $n = 10^9$ 时约 30 次比较 |
| 排序 + 二分 | $O(n \log n + q \log n)$ | $q$ 次查询时优于线性扫描 |
| 二分答案 | $O(\log(\text{值域}) \times T_{\text{check}})$ | 值域取对数，check 通常是 $O(n)$ |

## 常见错误

> [!WARNING]
> 下面每一条我都写过，而且写完还是"看起来对"的。

- **死循环**：`mid` 用了下取整，却写成 `lo = mid`，区间不收缩。要么保证 `lo` 一定前进，要么改成上取整 `mid = (lo + hi + 1) // 2`。
- **整数溢出**：`mid = (lo + hi) / 2` 在 `lo + hi` 超过类型上限时会溢出，写成 `lo + (hi - lo) // 2` 更安全（C++/Java 里尤其要注意）。
- **拿错边界**：要的是"第一个 $\ge$"，却按"找到就返回"写，遇到重复元素会返回中间某一个。
- **在无序区间上二分**：先确认单调性，二分不要求全局有序，但要求能根据 `mid` 判断答案在哪一侧。
- **`feasible` 写反**：二分答案最常见的 bug，用两个已知答案的小用例对拍一下。

## 相关

- 建议先读一下 Roofline 那篇里的"先判断瓶颈再优化"思路，二分同理：先确认单调性再动手：[[programming/memory-hierarchy]]
