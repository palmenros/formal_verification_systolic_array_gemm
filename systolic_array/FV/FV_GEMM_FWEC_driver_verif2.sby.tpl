[tasks]
prove
cover
bmc
live

[options]
prove: mode prove
prove: depth $PROVE_DEPTH
bmc: mode bmc
bmc: depth $BMC_DEPTH
cover: mode cover
cover: depth 20
live: mode live

[engines]
cover: smtbmc boolector
bmc: smtbmc boolector
prove: smtbmc boolector
live: aiger suprove

[script]
read -verific
read -formal GEMM_pkg.sv
read -formal Delay_Skew_In_Each_Cycle.sv
read -formal Delay_Skew_Out_Each_Cycle.sv
read -formal GEMM_Fixed_Weights_Each_Cycle.sv
read -formal PE.sv
read -formal SA_Fixed_Weights_Each_Cycle.sv
read -formal FV_GEMM_FWEC_driver_verif2.sv
hierarchy -check -top FV_GEMM_Fixed_Weights_Each_Cycle -chparam SA_SIZE $SA_SIZE
prep -top FV_GEMM_Fixed_Weights_Each_Cycle

[files]
FV_GEMM_FWEC_driver_verif2.sv
../RTL/Delay_Skew_In_Each_Cycle.sv
../RTL/Delay_Skew_Out_Each_Cycle.sv
../RTL/GEMM_pkg.sv
../RTL/GEMM_Fixed_Weights_Each_Cycle.sv
../RTL/PE.sv
../RTL/SA_Fixed_Weights_Each_Cycle.sv