# Approx-L: Nearly Unbiased Approximate Floating-Point Divider with Multi-level Linearization

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
│   ├── approx_l.v # Top-level module for Approx-L
├── sim/                    # Simulation Files
│   ├── fp32_tb.v  # Testbench for image processing application
├── image_test/             # Image Testing & Python Scripts
│   ├── img_pre.py          # Converts input images to Hex format for Verilog
│   ├── img_comp.py  # Reconstructs images from simulation output & calculates PSNR/SSIM
│   ├── img.v       
│   ├── image1.png        # Source test image1
│   ├── image2.png       # Source test image2
└── README.md
