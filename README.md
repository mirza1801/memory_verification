# Memory Verification

This is a small SystemVerilog memory verification project for a synchronous memory.

It uses a simple class-based testbench with:

* generator
* driver / BFM
* monitor
* scoreboard
* coverage
* environment

The testbench checks write and read operations using directed corner cases and random tests.

## Project Files

```text
memory_verification/
├── README.md
├── eda_playground_single_file.sv
├── mem_defs.svh
├── mem_intf.sv
├── memory.sv
├── mem_tx.sv
├── mem_common.sv
├── mem_gen.sv
├── mem_bfm.sv
├── mem_mon.sv
├── mem_cov.sv
├── mem_sbd.sv
├── mem_agent.sv
├── mem_env.sv
└── tb_top.sv
```

* The separate files are kept for cleaner project structure and readability.

## Result

* 91 writes
* 91 reads
* 100% functional coverage
* 0 mismatches

## EDA Playground

[Run on EDA Playground](https://www.edaplayground.com/x/vkT3)

Tested on EDA Playground using Questa/ModelSim.
