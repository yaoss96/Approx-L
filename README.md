# Approx-L: Nearly Unbiased Approximate Floating-Point Divider with Multi-level Linearization

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Verilog](https://img.shields.io/badge/Language-Verilog-green)]()
[![Python](https://img.shields.io/badge/Language-Python-yellow)]()

## 📖 Introduction

**Approx-L** is an energy-efficient, nearly unbiased approximate floating-point divider designed for error-tolerant applications such as image processing, computer vision, and machine learning.

This repository implements the architecture proposed in the paper **"Approx-L: Nearly Unbiased Approximate Floating-Point Divider with Multi-level Linearization"** (IEEE TVLSI 2025).

### ✨ Key Features
*   **IEEE 754 Compliant**: Supports Single-Precision (32-bit) floating-point format.
*   **Nearly Unbiased**: Introduces an error-balanced mantissa division algorithm that prevents the systematic error accumulation often found in traditional logarithmic approximation methods.
*   **Multi-level Linearization**: Features a scalable compensation scheme (Level 1, 2, 3) using power-of-two coefficients, achieving high accuracy with simple shift and add logic.
*   **Hardware Efficient**: Achieves up to **65.6% reduction in Power-Delay Product (PDP)** compared to an exact divider, without requiring large multipliers or massive lookup tables.
*   **Application Verified**: Demonstrated on image background removal tasks, yielding visual quality nearly indistinguishable from exact division (PSNR: 39.88 dB, SSIM: 0.985).

## 📂 Repository Structure

```text
Approx-L/
├── rtl/                    # Verilog Source Code
│   ├── approx_l_div_fp32.v # Top-level module for Approx-L
│   ├── mantissa_div.v      # Core approximate mantissa division logic
│   ├── error_comp.v        # Multi-level linear error compensation module
│   └── ...
├── sim/                    # Simulation Files
│   ├── tb_image_divider.v  # Testbench for image processing application
│   └── tb_basic.v          # Basic functional verification testbench
├── image_test/             # Image Testing & Python Scripts
│   ├── gen_hex.py          # Converts input images to Hex format for Verilog
│   ├── reconstruct_img.py  # Reconstructs images from simulation output & calculates PSNR/SSIM
│   ├── input_images/       # Source test images
│   └── output_images/      # Resulting images from simulation
└── README.md
