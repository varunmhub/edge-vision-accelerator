# Edge Vision Accelerator

A 3x3 convolution accelerator for 8-bit image-sensor data on a Xilinx Artix-7 (Digilent Basys 3).
Incoming pixels are quantized on-chip to a **4-bit sign-magnitude code**, and every multiply is
replaced by a **shift-and-decode** operation. The result is an accelerator that uses **zero DSP48
slices and zero block RAM**, closes timing with large margin, and produces **640 / 640 outputs
bit-exact** against a NumPy golden model.

Device: `xc7a35tcpg236-1` &middot; Toolchain: Vivado ML Standard 2024.1 &middot; Clock: 100 MHz &middot; RTL: Verilog-2001

---

## Headline results

All figures below are measured from Vivado synthesis, place-and-route and simulation reports. None
are estimates.

| Metric | Value |
| --- | --- |
| Functional accuracy | **640 / 640** outputs bit-exact vs NumPy golden model |
| DSP48 slices | **0** / 90 |
| Block RAM tiles | **0** / 50 |
| Worst negative slack (post-route) | **+3.788 ns** at 100 MHz |
| Worst hold slack | +0.106 ns |
| Failing timing endpoints | **0** of 675 |
| Slice LUTs / Slice registers | 141 / 103 (accelerator core) |
| Bonded IOB | 3 / 106 |
| Core dynamic power | 0.015 W |
| Area vs runtime-weight multiplier baseline | **1.84x fewer LUTs, 2.29x less carry logic** |
| Bitstream | `write_bitstream Complete` |
| Memory saving, 4-bit vs 8-bit line buffer | exact **2.00x** (40 vs 80 RAMS64E) |

---

## Dataflow

```
            top_basys3  (synthesis top, 3 pins: clk / RsRx / RsTx)
            |
  UART RX --+--> top_accelerator ------------------------------+--> UART TX
  115200 8N1     |                                             |    high byte first
                 |  8-bit pixel                                |
                 v                                             |
           quantizer_8to4    ->  4-bit sign-magnitude code      |
                 |                                             |
                 v                                             |
            line_buffer      ->  two IMG_W-deep rows (SRL16E)   |
                 |                                             |
                 v                                             |
            window_gen       ->  3x3 window, 36 bits            |
                 |                                             |
                 v                                             |
           pe_array_3x3      ->  9 shift PEs + adder tree       |
                 |                +  bias  +  ReLU             |
                 +---------------------------------------------+
                    16-bit signed output
```

Pipeline latency is **4 cycles**; every downstream stage keys off a `valid` handshake.

---

## Numeric format

The design never multiplies. Both activations and weights are encoded as
`{sign, magnitude_index[2:0]}`, where the magnitude index selects a power-of-two rung on a fixed
ladder. A product is therefore a sign XOR plus an index addition plus a barrel shift.

| Quantity | Value |
| --- | --- |
| Magnitude ladder | 0, 1, 2, 4, 8, 16, 32, 64 |
| Quantizer thresholds | 2, 6, 11, 23, 45, 91, 181 |
| Weight codes (3x3, hex) | `c 2 e f 6 7 6 7 7` |
| Weights (decoded) | -8, +2, -32 / -64, +32, +64 / +32, +64, +64 |
| Bias | `0x091d` = 2333 |
| Widths | product 14b -> accumulator 18b -> bias 16b -> ReLU -> output 16b signed |
| Image | 8x8 input, SAME padding 1 -> padded 10x10, 100 pixels row-major, 64 outputs |

The weight set is a left-to-right edge detector.

---

## Repository layout

```
rtl/            synthesizable Verilog-2001 sources
sim/            five self-checking testbenches
constraints/    Basys 3 pin and timing XDC
host/           Python: golden-model generator and on-board test script
```

| File | Role |
| --- | --- |
| `rtl/quantizer_8to4.v` | 8-bit pixel -> 4-bit sign-magnitude code |
| `rtl/line_buffer.v` | two shift-register rows, infers SRL16E |
| `rtl/line_buffer_ram.v` | block-RAM style variant used for the memory sweep |
| `rtl/window_gen.v` | assembles the 3x3 window and raises `win_valid` |
| `rtl/pe_shift_mult.v` | one shift-and-decode processing element |
| `rtl/pe_array_3x3.v` | 9 PEs, two-stage adder tree, bias, ReLU |
| `rtl/top_accelerator.v` | pure wiring of the datapath |
| `rtl/uart_rx.v`, `rtl/uart_tx.v` | 115200 8N1 serial bridge, `CLKS_PER_BIT = 868` |
| `rtl/top_basys3.v` | synthesis top: UART in, 64-result buffer, UART out |
| `host/regen_phase1.py` | writes the 35 `.mem` spec, stimulus and golden files |
| `host/host_demo.py` | streams 100 pixels over serial, checks 128 returned bytes |

---

## Verification

Five self-checking testbenches. Each one prints an explicit pass line and calls `$finish`.

| Testbench | What it proves | Pass line |
| --- | --- | --- |
| `tb_quantizer_exhaustive.v` | quantizer is exact on the entire 8-bit input space | `PASS: quantizer exact on all 256 input values` |
| `tb_window_gen_ramp.v` | 64 / 64 windows correct, 1152 element checks | `ALL PASSES OK` |
| `tb_pe_shift_mult_exhaustive.v` | PE is exact on all 256 activation/weight code pairs | `PASS: shift-PE exact on all 256 code pairs` |
| `tb_pe_array_random.v` | array + bias + ReLU on 500 random windows | `PASS: PE array + bias + ReLU exact on 500 random windows` |
| `tb_top_accelerator.v` | full datapath, 10 images | `PASS: 10/10 images, all 640 outputs bit-exact` |

The longest run finishes at 11495 ns, so the simulator runtime must be raised above the 10 us
default (see step 4 below).

---

## Reproducing the results

1. Generate the memory images.

   ```
   python host/regen_phase1.py
   ```

   This writes 35 files: 5 spec files (decoder LUT, weights, bias, thresholds, quantizer
   reference) and, for each of 10 test images, a pixel file, a code file and a golden output file.
   Edit `OUT` at the top of the script to point at your own directory.

2. Create a Vivado project for `xc7a35tcpg236-1` and add `rtl/*.v` as design sources, `sim/*.v` as
   simulation sources, and both files in `constraints/` as constraints.

3. Edit the absolute `.mem` paths inside the testbenches to match the directory you used in step 1.
   They currently point at a local Windows path. Forward slashes are required inside Verilog
   strings.

4. Set `xsim.simulate.runtime` to `50us` in Simulation Settings, otherwise `tb_top_accelerator`
   is cut off before it can print its verdict.

5. Run each of the five testbenches and confirm the pass lines in the table above.

6. Set `top_basys3` as the synthesis top, then run synthesis, implementation and
   `write_bitstream`. Confirm Bonded IOB reports **3** before generating the bitstream; a higher
   number means the wrong module is set as top and the DRC will fail on unconstrained ports.

7. Program the board from Hardware Manager: Open target, Auto Connect, select `xc7a35t_0`,
   Program Device. Do **not** use Write Memory Configuration File, which targets SPI flash.

8. Set `PORT` in `host/host_demo.py` to your board's COM port and run it. A timeout on image 0
   indicates a serial or wiring problem, not an RTL problem.

---

## Measured detail

### Area, post-route (`top_accelerator`, pipelined)

Slice LUTs 141 (135 logic + 6 memory), Slice registers 103, BRAM 0 / 50, DSP 0 / 90, IOB 28 / 106.
Primitives: `FDRE 103, LUT3 58, LUT6 40, LUT5 39, OBUF 17, CARRY4 17, LUT2 12, LUT4 11, IBUF 11,
LUT1 9, SRL16E 6, BUFG 1`.

Adding the pipeline register stage cost exactly +33 flip-flops, +1 slice LUT, -5 logic LUTs,
-1 CARRY4 and +4 mW, and moved worst negative slack from +0.416 ns to +3.747 ns.

### Timing

| Design | WNS | WHS | Failing endpoints |
| --- | --- | --- | --- |
| Combinational adder tree, post-route | +0.416 ns | +0.159 ns | 0 of 173 |
| Pipelined, post-route | +3.747 ns | +0.158 ns | 0 of 173 |
| `top_basys3` with UART bridge, post-route | **+3.788 ns** | +0.106 ns | **0 of 675** |

The UART bridge added 502 timing endpoints and cost zero slack.

### Memory sweep (`line_buffer_ram`, `IMG_W = 640`)

| Metric | 4-bit | 8-bit | Ratio |
| --- | --- | --- | --- |
| Storage | 5,120 bits | 10,240 bits | 2.00x |
| RAMS64E | 40 | 80 | **2.00x** |
| LUT as Memory | 40 | 80 | 2.00x |
| Slice LUTs | 56 | 100 | 1.79x |
| RAMB18E1 | 1 | 1 | flat |

A RAMB18 holds 18,432 bits, so at this image width both variants fit in the same single tile. The
memory saving must therefore be quoted as distributed-RAM primitives (RAMS64E), not block-RAM tile
count.

### Shift PE vs multiplier baseline

| Design | Weights | Slice LUTs | CARRY4 | DSP48 |
| --- | --- | --- | --- | --- |
| one shift PE | variable | ~3 cells | 0 | 0 |
| one multiplier PE | variable | 78 | 11 | 0 |
| 3x3 shift array | constant | 221 | 31 | 0 |
| 3x3 multiplier array | constant | 221 | 46 | 0 |
| 3x3 shift array | **runtime** | **448** | 49 | 0 |
| 3x3 multiplier array | **runtime** | **823** | 112 | 0 |

The defensible claim is the runtime-weight pair: **45% fewer LUTs, 56% less carry logic, identical
register count, identical I/O boundary, zero DSP48 in both.**

### Power

Core dynamic 0.015 W; total on-chip approximately 0.085 W. Vivado reports **Low** confidence
because more than 75% of input activity is unspecified. A SAIF-driven re-run is still outstanding.

---

## Honest caveats

These are stated explicitly because several of them contradict claims that a shift-based
accelerator is usually assumed to support.

- **The multiplier baseline also infers zero DSP48.** At this operand width Vivado maps a signed
  multiply into LUTs and carry chains, so DSP48 = 0 is not a differentiator. Six separate
  synthesis runs confirmed this.
- **Do not claim a 25x smaller array.** The 25x figure is a single-PE leaf-level comparison. With
  constant weights the synthesiser constant-folds the multiplier down to near-parity at array
  level. Only the runtime-weight comparison (1.84x) is defensible for the array.
- **The 16-bit output width does not cover the theoretical maximum.** The worst-case accumulator
  value is 39197, beyond the 32767 that a signed 16-bit output can carry. The largest value
  observed across all 640 golden outputs is 18205, so no saturation occurs for this weight set and
  this stimulus, but the width is not provably safe for arbitrary weights.
- **Weight and threshold provenance is a specification, not a trained model.** The ladder,
  thresholds and weights come from a NumPy reference implementation written for this project, not
  from quantizing a trained network.
- **The on-board demo has not been run yet.** Timing closes, the bitstream builds, and simulation
  is bit-exact, but the hardware loopback result is still outstanding.
- Benchmark comparison modules (`pe_mult_baseline`, `pe_array_3x3_baseline` and their
  runtime-weight variants) were built only to produce the area table above and are deliberately
  not included here.

---

## Debugging notes worth keeping

- The Messages panel is noisy. Trust the top-right status text instead. `Spawn failed: No error`
  and `No such file or directory` are benign.
- `report_timing_summary`, `report_utilization`, `report_power` and `report_drc` all require Open
  Synthesized Design or Open Implemented Design first.
- If XSim leaves a file lock on `simulate.log`, exit Vivado, kill `xsim.exe`, `xsimk.exe`,
  `xelab.exe` and `xvlog.exe`, delete the `.sim` directory, and reopen.
- After Set as Top, confirm the bold root in the Sources hierarchy and check Bonded IOB against
  the expected port count before running implementation.
