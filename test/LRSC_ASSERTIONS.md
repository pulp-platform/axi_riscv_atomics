# LR/SC transaction assertion guards

The two assertion blocks in `axi_riscv_lrsc` used `if (~rst_ni)`.
This condition disabled three transaction checks during normal operation.
The patch changes both conditions to `if (rst_ni)`.
The synthesizable source remains identical.

`tb_lrsc_checker.sv` instantiates the actual module with 32-bit addresses,
64-bit data, 2-bit IDs, and two read/write transaction slots.
It retains all dependency assertions and uses a 5 us HDL deadline.

| CASE | Input | Original | Patched |
| --- | --- | --- | --- |
| 0 | Normal AR/R and AW/W/B | No errors | No errors |
| 1 | R without a preceding AR | No error | One `Unexpected R with ID` |
| 2 | One forced write-queue enqueue failure | No error | One `Missed enqueuing of in-flight write!` |
| 3 | Normal AW/W, then one forced write-queue validity failure | No error | One `Unexpected B!` |

Cases 2 and 3 inject faults inside the isolated instance.
They measure assertion sensitivity. They do not establish reachable protocol bugs.
The test checks the exact predicate counts, returned normal data, and a unique completion marker.
All eight runs completed with the expected results on VCS W-2024.09-SP1.
The official base was `97a1dd2ac643c276880420a0cf8eea697f228aa9`.
Dependencies matched its Bender.lock: common_cells `9ca8a765` and axi `a256a3b8`.

The `lrsc_assertions` Bender target includes this fault-injection test.
Keep it separate from the normal `test` target. For example, generate the
compile script with `bender script vsim -t lrsc_assertions`.

## Reproduction

Obtain the dependencies at the revisions in Bender.lock.
Set `CELLS` and `AXI` to their checkout directories.
Run these commands from this repository root with Bash and VCS on PATH:

```bash
ROOT=$PWD
DEPS=("$CELLS/src/cf_math_pkg.sv" "$AXI/src/axi_pkg.sv")
for module in fifo_v3 lzc onehot_to_bin id_queue stream_fork stream_filter \
  rr_arb_tree stream_arbiter_flushable stream_arbiter fall_through_register \
  stream_register spill_register_flushable spill_register; do
  DEPS+=("$CELLS/src/$module.sv")
done
DEPS+=("$ROOT/src/axi_res_tbl.sv")
mkdir assertion-check
cd assertion-check
timeout 120 vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
  "+incdir+$CELLS/include" "${DEPS[@]}" "$ROOT/src/axi_riscv_lrsc.sv" \
  "$ROOT/test/tb_lrsc_checker.sv" -top tb_lrsc_checker -o simv -l compile.log
for case_id in 0 1 2 3; do
  mkdir "case$case_id"
  (cd "case$case_id"; timeout 60 ../simv "+CASE=$case_id" -l run.log)
done
```

For the original comparison, replace only the DUT source with the file from the stated base.
Use a separate output directory. Keep the same test and dependency files.
Each log must contain exactly one `LRSC_STIMULUS_DONE` and one normal `$finish`.
Match the assertion messages against the table. Do not classify deliberate negative cases by process exit code alone.
No new synthesis run is needed for this assertion-only change: all edits are inside existing `translate_off` blocks.
The fault-injection test is separate from the original normal-transaction regressions.

AI assistance: OpenAI Codex assisted the patch, test adaptation, and validation.

## Original regression entry

The two original testbenches remain in the Bender `test` target.
The full 32-master AMO test finishes normally with VCS W-2024.09-SP1.
Its drivers now wait for their constructors before the first access, which
removes a time-zero scheduling race. No transaction count or data check changes.

The original LR/SC test runs 10000 reads and writes with Questa 2024.1 and seed 1.
Its scoreboard previously rejected W accepted before AW. AXI permits that order
([AMBA IHI 0022H, A3.3](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf)). The scoreboard now retains early W beats until their
address records arrive, then checks every data, strobe, last and user field.
It also checks the final queue and observed/checked beat counts.
Both the original RTL and this assertion change pass the same revised test,
with all 9066 forwarded W beats checked and normal finish at 652655 ns.
The original scoreboard failure at 612937 ns remains recorded.
Both versions retain two Questa warnings for fixed page-mask slices in the
narrow-address test configuration. This change adds no such warnings.

The synthesis-visible RTL and dependency lock remain unchanged.
The installed Questa version differs from CI's 2022.3, so these are local results.
The internal GitLab workflow still needs the upstream repository's credentials.
