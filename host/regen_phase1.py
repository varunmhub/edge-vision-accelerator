# regen_phase1.py -- regenerates every Phase 1 export the RTL testbenches read.
# Run:  python regen_phase1.py
# Writes 35 .mem files into OUT. The seed is fixed, so reruns are identical
# and the golden vectors stay comparable across the whole project.

import os
import numpy as np

OUT = r"C:/Users/varun/Desktop/proj/mem"
os.makedirs(OUT, exist_ok=True)

rng = np.random.default_rng(7)        # fixed seed -> reproducible exports

# ---- the locked numeric format ------------------------------------------
LADDER  = [0, 1, 2, 4, 8, 16, 32, 64]          # magnitude for idx 0..7
THRESH  = [2, 6, 11, 23, 45, 91, 181]          # sqrt(2) midpoints, pixel domain
W_CODES = [0xc, 0x2, 0xe, 0xf, 0x6, 0x7, 0x6, 0x7, 0x7]   # 3x3 edge detector
BIAS    = 2333                                 # 0x091d

N_IMG = 10
IMG   = 8                                      # unpadded image is 8x8
PW    = IMG + 2                                # padded width  = 10
PH    = IMG + 2                                # padded height = 10


def decode(code):
    """4-bit sign-magnitude code -> signed integer."""
    mag = LADDER[code & 0x7]
    return -mag if (code & 0x8) else mag


def quantize(pix):
    """8-bit unsigned pixel -> 4-bit code. Mirrors quantizer_8to4.v exactly."""
    idx = 0
    for q, t in enumerate(THRESH):
        if pix >= t:
            idx = q + 1
    return 0 if idx == 0 else idx          # unsigned input -> sign bit is 0


def make_image(n):
    """Deterministic test frames. 0-2 are structured so a wrong window
    ordering is visible by eye; 3-9 are random for coverage."""
    a = np.zeros((IMG, IMG), dtype=np.int32)
    if n == 0:                                  # vertical edge
        a[:, IMG // 2:] = 255
    elif n == 1:                                # horizontal edge
        a[IMG // 2:, :] = 255
    elif n == 2:                                # diagonal ramp
        for r in range(IMG):
            for c in range(IMG):
                a[r, c] = min(255, (r + c) * 16)
    else:
        a = rng.integers(0, 256, size=(IMG, IMG), dtype=np.int32)
    return a


def pad(a):
    p = np.zeros((PH, PW), dtype=np.int32)
    p[1:1 + IMG, 1:1 + IMG] = a
    return p


def write_mem(name, values, fmt):
    with open(os.path.join(OUT, name), "w") as f:
        for v in values:
            f.write(format(v, fmt) + "\n")


# ---- spec files (5) -----------------------------------------------------
# decoder_lut.mem: all 16 codes as 8-bit two's complement, for the PE reference
write_mem("decoder_lut.mem",
          [decode(c) & 0xFF for c in range(16)], "02x")
write_mem("conv1_weights.mem", W_CODES, "x")
write_mem("conv1_bias.mem", [BIAS & 0xFFFF], "04x")
write_mem("act_thresholds.mem", THRESH, "03x")
write_mem("quant_ref_256.mem", [quantize(p) for p in range(256)], "x")

# ---- per-image files (3 x 10) ------------------------------------------
tags = [""] + [f"_{n}" for n in range(1, N_IMG)]
codes_seen = set()

for n, tag in enumerate(tags):
    raw    = make_image(n)
    padded = pad(raw)

    # what the FPGA receives: 100 padded 8-bit pixels, row-major
    pixels = padded.flatten().tolist()
    write_mem(f"test_image_pixels{tag}.mem", pixels, "02x")

    # the quantized codes, kept for debugging the front end in isolation
    qcodes = [[quantize(int(v)) for v in row] for row in padded]
    inner  = [qcodes[r][c]
              for r in range(1, 1 + IMG) for c in range(1, 1 + IMG)]
    write_mem(f"test_image_codes{tag}.mem", inner, "x")
    codes_seen.update(inner)

    # golden convolution: quantize, MAC in the code domain, bias, ReLU
    gold = []
    for r in range(IMG):
        for c in range(IMG):
            acc = BIAS
            for k in range(9):
                a = qcodes[r + k // 3][c + k % 3]
                acc += decode(a) * decode(W_CODES[k])
            gold.append(max(0, acc) & 0xFFFF)
    write_mem(f"golden_output{tag}.mem", gold, "04x")

print("activation codes exercised:", sorted(codes_seen))
print(f"wrote {5 + 3 * N_IMG} files to {OUT}")
