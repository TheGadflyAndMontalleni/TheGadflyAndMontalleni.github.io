---
title: CUDA 算子优化：GEMM
published: 2026-10-08
updated: 2026-10-09
description: 从朴素实现出发，沿着分块、共享内存、寄存器分块、双缓冲一路推到 Tensor Core，把每一步"到底在省什么"算清楚。
image: ""
tags: [CUDA, GEMM, 性能优化, 并行计算]
category: 编程
series: CUDA 算子优化
seriesOrder: 1
slug: programming/cuda-gemm
---

矩阵乘法是深度学习里出现频率最高的算子，也是学 CUDA 优化最好的起点：目标明确、指标单一，每一步优化省下了什么都可以算出来。这篇笔记按优化顺序记一遍。

## 先把账算清楚

计算的是

$$
C = \alpha AB + \beta C, \quad A \in \mathbb{R}^{M \times K},\ B \in \mathbb{R}^{K \times N}
$$

以 $M = N = K = 4096$ 的 FP32 为例：

| 项目 | 数值 |
|---|---|
| 计算量 | $2MNK \approx 1.37 \times 10^{11}$ FLOPs |
| 访存量（各读一遍） | $4(MK + KN + MN) \approx 201$ MB |
| 算术强度 | $\approx 682$ FLOPs/Byte |

而一张 A100 的 FP32 算力约 19.5 TFLOPS、显存带宽约 1.55 TB/s，也就是每读 1 字节最多只能配到约 12.6 次浮点运算。682 远大于 12.6，说明 GEMM 本身是**计算密集**的——理论上有 50 倍以上的余量。但朴素实现完全拿不到这个余量，因为它把数据搬了太多遍。

## 朴素实现错在哪

```cuda title="gemm_naive.cu"
__global__ void gemm_naive(const float* A, const float* B, float* C,
                           int M, int N, int K) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= M || col >= N) return;

    float acc = 0.f;
    for (int k = 0; k < K; ++k)
        acc += A[row * K + k] * B[k * N + col];

    C[row * N + col] = acc;
}
```

一个线程算一个输出元素，逻辑没错，但每算一次乘加就要从显存读两个 float。整个 kernel 的实际访存量是 $4 \times 2MNK \approx 5.5 \times 10^{11}$ 字节，比理论下界多了 2700 倍。**算一次乘法等一次显存**，而显存延迟是几百个时钟周期，算力全部空转。

优化方向由此确定：让每个从显存读进来的数，被尽可能多地复用。复用发生在三个层次上——共享内存、寄存器、以及线程块内的数据交换。

## 分块：把复用做进共享内存

把输出切分成 $32 \times 32$ 的小块，一个线程块负责一块。沿 $K$ 维推进时，把 A、B 对应的两个 $32 \times 32$ 分块先搬进共享内存，块内所有线程共享：

```cuda title="gemm_tiled.cu"
#define TILE 32
#define PAD  1   // 加一列，打散 bank conflict

__global__ void gemm_tiled(const float* A, const float* B, float* C,
                           int M, int N, int K) {
    __shared__ float As[TILE][TILE + PAD];
    __shared__ float Bs[TILE][TILE + PAD];

    int tx = threadIdx.x, ty = threadIdx.y;
    int row = blockIdx.y * TILE + ty;
    int col = blockIdx.x * TILE + tx;

    float acc = 0.f;
    for (int t = 0; t < (K + TILE - 1) / TILE; ++t) {
        // 协作搬运：每个线程搬 2 个元素（一块有 TILE*TILE 个）
        As[ty][tx] = (row < M && t * TILE + tx < K) ? A[row * K + t * TILE + tx] : 0.f;
        Bs[ty][tx] = (t * TILE + ty < K && col < N) ? B[(t * TILE + ty) * N + col] : 0.f;
        __syncthreads();          // 搬完才能算

        #pragma unroll
        for (int k = 0; k < TILE; ++k)
            acc += As[ty][k] * Bs[k][tx];

        __syncthreads();          // 算完才能搬下一轮
    }

    if (row < M && col < N) C[row * N + col] = acc;
}
```

访存量降到了每个输出元素读 $2K/\text{TILE}$ 次，也就是降了 32 倍。看起来很美，但这个版本**几乎不加速**——因为每个线程每个 $k$ 只做一次乘加，却要访问两次共享内存。此时瓶颈从显存换成了共享内存，只是把等待挪了个地方。

## 寄存器分块：真正的加速来自这里

关键一步：让一个线程算一小片输出（比如 $8 \times 8$），而不是一个点。这样它从共享内存读一次 $A$ 的元素，就能被 8 个 $B$ 元素复用；读一次 $B$ 元素，也能被 8 个 $A$ 元素复用。

常见的配置是「$128 \times 128$ 的线程块 + $8 \times 8$ 的线程块布局」，共 256 个线程，每个线程负责 $8 \times 8 = 64$ 个输出：

```cuda
// 每个线程持有 8x8 的累加器，常驻寄存器
float acc[8][8] = {0.f};

for (int k = 0; k < TILE; ++k) {
    // 从共享内存取一列 A、一行 B，在寄存器里展开成 8x8 次乘加
    float a_frag[8], b_frag[8];
    #pragma unroll
    for (int i = 0; i < 8; ++i) a_frag[i] = As[ty * 8 + i][k];
    #pragma unroll
    for (int j = 0; j < 8; ++j) b_frag[j] = Bs[k][tx * 8 + j];

    #pragma unroll
    for (int i = 0; i < 8; ++i)
        #pragma unroll
        for (int j = 0; j < 8; ++j)
            acc[i][j] += a_frag[i] * b_frag[j];
}
```

每次访问共享内存，换来 8 次乘加。共享内存的带宽压力降到 $1/8$，而且乘加可以靠指令级并行填满流水线。到这一步，kernel 才真正跑在算力上。

这也是所有高性能 GEMM 的共同骨架：**大线程块 + 小线程块（thread tile）+ 寄存器累加器**。cuBLAS、CUTLASS 都是这个结构的工程化版本。

## 双缓冲与异步拷贝

上面的 `__syncthreads()` 之间，线程不是在搬数据就是在算，两者串行。让「搬下一块」和「算当前块」重叠起来，就能把这部分等待藏掉：

- 老办法：双缓冲，用 `__syncthreads()` 手动流水；
- 新办法：`cp.async`（Ampere 起）让数据从显存直接进共享内存，不占用寄存器，也不需要线程等待，配合 `cp.async.wait_group` 控制提交节奏。

## Tensor Core

从 Volta 开始，矩阵乘加有了专用硬件。用 `wmma` / `mma` 指令，一次指令完成 $16 \times 16 \times 16$ 级别的运算，FP16 输入的吞吐是 FP32 的数倍。代价是：

- 输入要先转成 FP16/BF16/TF32，涉及精度取舍；
- 数据的**布局**必须符合硬件要求（fragment 的排布、ldmatrix 的加载方式），这通常是手写 Tensor Core kernel 最费时的部分；
- 小矩阵、形状不规则时收益有限，还要额外处理边界。

## 怎么知道优化到位了

不要凭感觉，看指标：

| 现象 | 看什么 | 说明 |
|---|---|---|
| 算力用不满 | `sm__throughput` 与 `dram__throughput` | 谁接近峰值，瓶颈就在谁那里 |
| 显存打满 | `dram__bytes_read/write` | 访存超过理论下界，复用没做好 |
| 共享内存打满 | `l1tex__data_bank_conflicts` | 多半是没加 padding |
| 停顿多 | `smsp__warp_issue_stalled_*` | 看是等显存、等同步还是等依赖 |

配合 [[programming/memory-hierarchy]] 里的 Roofline 模型，可以判断一个 kernel 到底离硬件的两条天花板还有多远。

## 踩过的坑

> [!WARNING]
> 这几个问题我在写第一个 tiled kernel 时全踩了一遍，都是"结果对但很慢"或者"看起来对其实错"的类型。

- **忘了 padding，bank conflict 让共享内存的收益打了对折。** 把 `[TILE][TILE]` 改成 `[TILE][TILE + 1]` 就解决了。
- **`__syncthreads()` 位置不对。** 少一个就可能读到上一轮的数据，结果时对时错；多一个则损失流水。搬运前、计算前各一个，两个都不能省。
- **边界处理写成了分支地狱。** 与其在内层循环里判断，不如搬运时就补零，让内层循环干净无分支。
- **只跑一次就开始调参。** 第一次调用包含上下文初始化和显存分配，一定要先 warmup 再计时，且用 `cudaEventRecord` 而不是 CPU 计时。

## 接下来

- 存储层次与 Roofline 模型：[[programming/memory-hierarchy]]
