# Benchmark modules

These four modules are **not part of the datapath**. They exist only to produce
the area comparison in the project report: a conventional decode-then-multiply
MAC measured against the shift-based PE, under identical adder tree, bias, ReLU
and pipeline structure, so the only variable is the multiplier itself.

To reproduce a row, set the module as top in Vivado, run synthesis, open the
synthesized design and run `report_utilization`. Check the Bonded IOB count
first — if it does not match the expected value below, the wrong module is set
as top and the numbers are meaningless.

| Module | Weights | Expected IOB | Slice LUTs | CARRY4 | DSP48 |
|---|---|---|---|---|---|
| `pe_shift_mult` (in `../rtl/`) | variable | 22 | ~3 cells | 0 | 0 |
| `pe_mult_baseline` | variable | 22 | 78 | 11 | 0 |
| `pe_array_3x3` (in `../rtl/`) | constant | 56 | 221 | 31 | 0 |
| `pe_array_3x3_baseline` | constant | 56 | 221 | 46 | 0 |
| `pe_array_3x3_varw` | runtime | 92 | 448 | 49 | 0 |
| `pe_array_3x3_baseline_varw` | runtime | 92 | 823 | 112 | 0 |

The headline comparison is the **runtime-weight pair**: 448 vs 823 slice LUTs
(1.84x) and 49 vs 112 CARRY4 (2.29x), with identical register count and
identical I/O boundary. DSP48 usage is zero in every run — the operand range is
too small for Vivado to infer a DSP48 in either design, so this is not a
DSP-saving result.

With constant weights the comparison largely collapses (221 vs 221 slice LUTs)
because constant folding removes most of the multiplier. Do not quote the
constant-weight pair as the headline.
