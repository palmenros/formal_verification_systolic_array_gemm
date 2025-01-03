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
prove: smtbmc boolector
bmc: smtbmc boolector
live: aiger suprove

[script]
read -verific
read -formal GEMM_pkg.sv
read -formal Delay_Skew_In.sv
read -formal Delay_Skew_Out.sv
read -formal Count_To_Maximum.sv
read -formal PE.sv
read -formal SA_Fixed_Weights.sv
read -formal GEMM_Fixed_Weights.sv
read -formal FV_GEMM_Fixed_Weights_driver.sv
hierarchy -check -top FV_GEMM_Fixed_Weights -chparam SA_SIZE $SA_SIZE
prep -top FV_GEMM_Fixed_Weights

[files]
FV_GEMM_Fixed_Weights_driver.sv
../RTL/Delay_Skew_In.sv
../RTL/Delay_Skew_Out.sv
../RTL/GEMM_pkg.sv
../RTL/GEMM_Fixed_Weights.sv
../RTL/PE.sv
../RTL/SA_Fixed_Weights.sv
../RTL/Count_To_Maximum.sv