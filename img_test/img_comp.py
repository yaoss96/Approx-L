import struct
import numpy as np
import matplotlib.pyplot as plt
from skimage.metrics import peak_signal_noise_ratio as psnr
from skimage.metrics import structural_similarity as ssim
import os

# ================= Configuration Parameters =================
IMG_H = 877
IMG_W = 658
FILE_IMG1 = "C:\\Users\\Razer\\Desktop\\DATE_divider\\img1_hex.txt"
FILE_IMG2 = "C:\\Users\\Razer\\Desktop\\DATE_divider\\img2_hex.txt"
FILE_RESULT = "C:\\Users\\Razer\\Desktop\\DATE_divider\\result_hex.txt"

# Output Filenames
OUT_VERILOG_PNG = "verilog_result_pure.png"
OUT_PYTHON_PNG = "python_ref_pure.png"

# ================= Helper Functions =================

def hex_to_float(hex_str):
    """ Convert 32-bit hex string to IEEE 754 single-precision float """
    try:
        clean_hex = hex_str.strip()
        if not clean_hex:
            return 0.0
        return struct.unpack('!f', bytes.fromhex(clean_hex))[0]
    except Exception:
        return 0.0

def load_hex_file_to_arr(filename, shape):
    """ Read hex file and convert to numpy array """
    if not os.path.exists(filename):
        print(f"Warning: File {filename} not found. Generating zeros.")
        return np.zeros(shape, dtype=np.float32)

    data_list = []
    with open(filename, 'r') as f:
        lines = f.readlines()
        for line in lines:
            if 'x' in line or 'z' in line:
                data_list.append(0.0)
            else:
                data_list.append(hex_to_float(line))
    
    expected_len = shape[0] * shape[1]
    if len(data_list) < expected_len:
        print(f"Warning: Not enough data in {filename}. Padding with zeros.")
        data_list += [0.0] * (expected_len - len(data_list))
    
    return np.array(data_list[:expected_len], dtype=np.float32).reshape(shape)

# ================= Main Logic =================
def main():
    print("--- Starting Verification (Save Only Mode) ---")
    
    # 1. Load Data
    print("Loading hex files...")
    img1 = load_hex_file_to_arr(FILE_IMG1, (IMG_H, IMG_W)) # Illumination
    img2 = load_hex_file_to_arr(FILE_IMG2, (IMG_H, IMG_W)) # Observed
    verilog_result = load_hex_file_to_arr(FILE_RESULT, (IMG_H, IMG_W))
    
    # 2. Generate Python Golden Reference
    print("Calculating Python reference...")
    safe_illumination = np.where(img1 < 0.05, 0.05, img1) 
    python_ref = img2 / safe_illumination

    # 3. Set Display Range (Clipping)
    CLIP_MAX = 1.2 

    # 4. Calculate Metrics (Keep this part for verification)
    py_ref_clipped = np.clip(python_ref, 0, CLIP_MAX)
    ver_res_clipped = np.clip(verilog_result, 0, CLIP_MAX)
    
    score_psnr = psnr(py_ref_clipped, ver_res_clipped, data_range=CLIP_MAX)
    score_ssim = ssim(py_ref_clipped, ver_res_clipped, data_range=CLIP_MAX)

    print("\n" + "="*30)
    print(f"Verification Results:")
    print(f"PSNR: {score_psnr:.4f} dB")
    print(f"SSIM: {score_ssim:.4f}")
    print("="*30 + "\n")

    # 5. Save Pure Images (Core Modification)
    print(f"Saving pure images (Range: 0 ~ {CLIP_MAX})...")
    
    # Save Verilog Result
    plt.imsave(OUT_VERILOG_PNG, verilog_result, cmap='gray', vmin=0, vmax=CLIP_MAX)
    print(f"Saved: {OUT_VERILOG_PNG}")

    # Save Python Reference Result (If comparison is needed)
    plt.imsave(OUT_PYTHON_PNG, python_ref, cmap='gray', vmin=0, vmax=CLIP_MAX)
    print(f"Saved: {OUT_PYTHON_PNG}")

    print("Done.")

if __name__ == "__main__":
    main()