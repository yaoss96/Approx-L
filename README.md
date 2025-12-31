
# Approx-L: Nearly Unbiased Approximate Floating-Point Divider with Multi-level Linearization

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Verilog](https://img.shields.io/badge/language-Verilog-green.svg)]()
[![Python](https://img.shields.io/badge/language-Python-yellow.svg)]()

## 📖 Introduction (简介)

**Approx-L** 是一个高能效、近乎无偏的近似浮点除法器（Approximate Floating-Point Divider），专为图像处理、计算机视觉和机器学习等容错应用设计。

该项目实现了论文 **"Approx-L: Nearly Unbiased Approximate Floating-Point Divider with Multi-level Linearization"** (IEEE TVLSI 2025) 中提出的架构。

### ✨ Key Features (主要特性)
*   **IEEE 754 兼容**: 支持单精度（32-bit）浮点数格式。
*   **近乎无偏 (Nearly Unbiased)**: 采用误差平衡的尾数除法算法，避免了传统对数近似方法的误差累积问题。
*   **多级线性化补偿 (Multi-level Linearization)**: 提供可配置的精度等级（Level 1, 2, 3），通过简单的移位和加法操作实现高精度误差补偿。
*   **硬件高效**: 相比精确除法器，**PDP (Power-Delay Product)** 降低高达 **65.6%**，且无需大型乘法器或巨大的查找表。
*   **应用验证**: 在图像背景移除任务中，实现了与精确除法器几乎无法区分的视觉质量 (PSNR: 39.88 dB, SSIM: 0.985)。

## 📂 Repository Structure (仓库结构)

```text
Approx-L/
├── rtl/                    # Verilog 源代码
│   ├── approx_l_div_fp32.v # Approx-L 顶层模块
│   ├── mantissa_div.v      # 尾数近似除法核心
│   ├── error_comp.v        # 线性误差补偿模块
│   └── ...
├── sim/                    # 仿真文件
│   ├── tb_image_divider.v  # 图像处理测试激励 (Testbench)
│   └── tb_basic.v          # 基础功能验证
├── image_test/             # 图像测试与 Python 脚本
│   ├── gen_hex.py          # 将图片转换为 Hex 文件供 Verilog 读取
│   ├── reconstruct_img.py  # 将仿真结果 Hex 重建为图片并计算 PSNR/SSIM
│   ├── input_images/       # 测试图片
│   └── output_images/      # 结果图片
└── README.md
