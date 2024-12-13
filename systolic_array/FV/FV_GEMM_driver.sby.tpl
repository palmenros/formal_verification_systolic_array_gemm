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
cover: depth 50
live: mode live

[engines]
cover: smtbmc boolector
bmc: smtbmc boolector
prove: smtbmc boolector
live: aiger suprove

[script]
read -verific
read -formal GEMM_pkg.sv
read -formal Count_To_Maximum.sv
read -formal Delay_Skew_In.sv
read -formal Delay_Skew_Out.sv
read -formal GEMM.sv
read -formal PE.sv
read -formal SA.sv
read -formal FV_GEMM_driver.sv
hierarchy -check -top FV_GEMM -chparam SA_SIZE $SA_SIZE
prep -top FV_GEMM

[files]
FV_GEMM_driver.sv
../RTL/Count_To_Maximum.sv
../RTL/Delay_Skew_In.sv
../RTL/Delay_Skew_Out.sv
../RTL/GEMM_pkg.sv
../RTL/GEMM.sv
../RTL/PE.sv
../RTL/SA.sv