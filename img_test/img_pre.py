import numpy as np
import cv2
import struct

# 1. Set paths
image1_path = 'C:\\Users\\Razer\\Desktop\\DATE_divider\\image1.png' # Divisor
image2_path = 'C:\\Users\\Razer\\Desktop\\DATE_divider\\image2.png' # Dividend
output_hex_file1 = 'C:\\Users\\Razer\\Desktop\\DATE_divider\\img1_hex.txt'
output_hex_file2 = 'C:\\Users\\Razer\\Desktop\\DATE_divider\\img2_hex.txt'

# 2. Helper function: Convert float to IEEE 754 32-bit hex string
def float_to_hex(f):
    # Use struct library to pack float into 4-byte binary, then unpack as unsigned int
    return hex(struct.unpack('<I', struct.pack('<f', f))[0])[2:].zfill(8)

def process_images():
    # Read images (Read in grayscale mode for simplification)
    img1 = cv2.imread(image1_path, cv2.IMREAD_GRAYSCALE)
    img2 = cv2.imread(image2_path, cv2.IMREAD_GRAYSCALE)

    if img1 is None or img2 is None:
        print("Error: Cannot read images, please check the paths.")
        return

    # Ensure both images have the same size; if not, resize img2 to match img1
    if img1.shape != img2.shape:
        img2 = cv2.resize(img2, (img1.shape[1], img1.shape[0]))

    # Note: Add a very small value to img2 to avoid division by zero
    data1 = img1.astype(np.float32) / 255.0
    data2 = img2.astype(np.float32) / 255.0 + 0.001 

    # Flatten arrays to write line by line
    flat_data1 = data1.flatten()
    flat_data2 = data2.flatten()

    print(f"Processing images, size: {img1.shape}, total pixels: {len(flat_data1)}")

    # Write to files
    with open(output_hex_file1, 'w') as f1, open(output_hex_file2, 'w') as f2:
        for v1, v2 in zip(flat_data1, flat_data2):
            # Convert to hex string and write, one data point per line
            f1.write(float_to_hex(v1) + '\n')
            f2.write(float_to_hex(v2) + '\n')

    print(f"Conversion complete!\nFiles saved as: {output_hex_file1} and {output_hex_file2}")
    print(f"Total lines: {len(flat_data1)}")

if __name__ == "__main__":
    process_images()