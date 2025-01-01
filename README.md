# Formal verification of a GEMM Systolic Array

This project contains a parameterized SystemVerilog RTL implementation for an INT8 Systolic Array computing General Matrix-Matrix Multiply that has been formally verified to be equivalent with the mathematical triple-loop definition using SymbiYosys and SystemVerilog Assertions.

Several I/O interfaces have been implemented and compared. All of them input a row and output a row at the same time. The difference between implementations lies in the programmability of weights and whether the input is stallable:

- Interface 1 (`GEMM_Fixed_Weights_Each_Cycle.sv`): The weights are fixed and cannot change over time, but they are arbitrary (modeled as `(* anyconst *)`), and every cycle a new row of the input matrix is provided (there's no stalling capability).
- Interface 2 (`GEMM_Fixed_Weights.sv`): The weights are still fixed and arbitrary, but the input can be stalled. A new input row is only fed when `should_advance_computation` is true.
- Interface 3 (`GEMM.sv`): Completely programmable interface. Each clock cycle, a different command can be performed: `CMD_WRITE_WEIGHTS` to write new weights into the systolic array, `CMD_STREAM` to perform a computation with a new input matrix row or `CMD_NONE` to do nothing.

Additionally, several additional handcrafted assertions have been added to try to speed-up the formal verification tools, and all configurations have been thoroughly benchmarked to understand the limitations of current formal verification tools when managing complex dataflow circuits and to evaluate the impact of I/O interfaces on verification performance.

### Folder Structure

- `systolic_array/RTL` contains the parameterizable RTL implementation of the Systolic Array and the different interfaces.
- `systolic_array/TB` contains standard simulation-based testbenches to test the Systolic Array implementation using standard simulation tools.
- `systolic_array/VivadoProject` contains Xilinx Vivado project files that can be used to simulate the testbenches.
- `systolic_array/FV` contains the bulk of the formal verification files. It contains:
    - Several formal verification harnesses based on System Verilog Assertions (almost all `.sv` files), such as `FV_GEMM_Fixed_Weights_Each_Cycle_driver.sv`.
    - SymbiYosys `.sby` files for each configuration. They are ready to be run using SymbiYosys to formally verify the systolic array.
    - `FV_Matrix_Playground.sv`, a formal verification harness that uses `cover` properties in an interesting way to perform matrix inversion and LU decomposition.
    - `run_benchmarks.py`, a Python tool to automatically run benchmarks and store the results in text files. It uses `.sby.tpl` template files to dynamically generate the appropriate `.sby` file for a given configuration and run SymbiYosys without manual intervention. 
    - `benchmark_output`, a folder containing the output of running the benchmark tool.
    - `.gtkw` files with waveform configurations for the GTKWave. Useful to examine `.vcd` files output by `cover` or failed assertions.
- `plotting` contains a Python script to replicate all the plots that appear in the presentation and report.

### How to run and verify

First of all, [Tabby Cad Suite](https://www.yosyshq.com/tabby-cad-datasheet) needs to be installed and have a valid license, to be able to use the Verific parser for System Verilog Assertions with SymbiYosys. At the time of writing this document, YosysHQ offers evaluation licenses on request.

Once installed, and if `PATH` variables are correctly configured, the script `systolic_array/FV/run_benchmarks.py` can be executed to automatically run all benchmarks.

Otherwise, a single configuration can be run using the following command in the `systolic_array/FV` folder (with `mode` being one of `bmc`, `live`, `prove` or `cover`):

```bash
sby --prefix symbiyosys_output_artifact_folder -f configuration.sby mode
```

For example, the following command runs SymbiYosys in `bmc` mode for Interface 1: 

```bash
sby --prefix symbiyosys_FV_GEMM_Fixed_Weights_Each_Cycle_driver -f FV_GEMM_Fixed_Weights_Each_Cycle_driver.sby bmc
```

### Report and presentation

TODO: Upload and describe where to find them.