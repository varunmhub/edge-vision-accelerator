# host_demo.py -- drives the Basys 3 over USB-UART and checks every output
# against the same golden files the simulation used.
#
# Before running:
#   1. Program top_basys3.bit via Vivado Hardware Manager.
#   2. Set PORT below to the board's COM port (Device Manager -> Ports).
#
# Protocol: 100 pixel bytes out, 128 result bytes back, HIGH byte first.

import os
import serial

PORT = "COM4"          # <-- CHANGE THIS to your board's port
BAUD = 115200
MEM  = r"C:/Users/varun/Desktop/proj/mem"

NPIX   = 100           # padded 10x10 frame
NOUT   = 64            # SAME-conv outputs
NBYTES = NOUT * 2      # 16 bits per output


def load_mem(name, mask=0xFFFF):
    """Read a .mem file of hex words into a list of ints."""
    with open(os.path.join(MEM, name)) as f:
        return [int(line, 16) & mask for line in f if line.strip()]


tags   = [""] + [f"_{n}" for n in range(1, 10)]
passes = 0
fails  = 0

with serial.Serial(PORT, BAUD, timeout=3) as ser:
    for i, tag in enumerate(tags):
        pixels = load_mem(f"test_image_pixels{tag}.mem", 0xFF)
        gold   = load_mem(f"golden_output{tag}.mem")

        assert len(pixels) == NPIX, f"image {i}: {len(pixels)} pixels, expected {NPIX}"
        assert len(gold)   == NOUT, f"image {i}: {len(gold)} golden values, expected {NOUT}"

        ser.reset_input_buffer()
        ser.write(bytes(pixels))

        raw = ser.read(NBYTES)
        if len(raw) != NBYTES:
            print(f"FAIL image {i}: timed out, got {len(raw)} of {NBYTES} bytes")
            print("    -> check the COM port, the USB cable and that the .bit is programmed")
            fails += 1
            continue

        got = [(raw[2 * i] << 8) | raw[2 * i + 1] for i in range(NOUT)]

        bad = [(k, got[k], gold[k]) for k in range(NOUT) if got[k] != gold[k]]
        if not bad:
            print(f"PASS image {i}: {NOUT}/{NOUT} outputs bit-exact")
            passes += 1
        else:
            print(f"FAIL image {i}: {len(bad)} of {NOUT} outputs wrong")
            for k, g, e in bad[:10]:
                print(f"    idx={k} board={g} golden={e}")
            fails += 1

print()
if fails == 0:
    print(f"*** PASS: {passes}/10 images, all 640 outputs bit-exact ON HARDWARE ***")
else:
    print(f"*** FAIL: {fails} of 10 images failed ***")
