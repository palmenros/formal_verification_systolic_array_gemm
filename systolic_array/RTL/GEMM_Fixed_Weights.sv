import GEMM_pkg::*;

module GEMM_Fixed_Weights #(
    parameter SA_SIZE = 4,

    // This module uses INT-N weights weights and activations
    parameter WEIGHT_ACTIVATION_SIZE = 8
) (
    input logic resetn,
    input logic clk,

    input logic[WEIGHT_ACTIVATION_SIZE-1:0] activation_inputs[SA_SIZE],
    output logic[WEIGHT_ACTIVATION_SIZE-1:0] activation_outputs[SA_SIZE],

    input logic should_advance_computation,

    output logic output_valid
);

logic[WEIGHT_ACTIVATION_SIZE-1:0] systolic_array_inputs[SA_SIZE];
logic[WEIGHT_ACTIVATION_SIZE-1:0] systolic_array_outputs[SA_SIZE];

SA_Fixed_Weights #(
    .SA_SIZE            (SA_SIZE),
    .WEIGHT_SIZE        (WEIGHT_ACTIVATION_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_SA (
    .resetn             (resetn),
    .clk                (clk),
    .inputs             (systolic_array_inputs),
    .outputs            (systolic_array_outputs),
    .should_advance_computation (should_advance_computation)
);

Delay_Skew_In #(
    .SA_SIZE            (SA_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_Delay_Skew_In (
    .resetn             (resetn),
    .clk                (clk),
    .in                 (activation_inputs),
    .outputs            (systolic_array_inputs),
    .should_advance_computation (should_advance_computation)
);

Delay_Skew_Out #(
    .SA_SIZE            (SA_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_Delay_Skew_Out (
    .resetn             (resetn),
    .clk                (clk),
    .inputs             (systolic_array_outputs),
    .out                (activation_outputs),
    .should_advance_computation (should_advance_computation)
);

Count_To_Maximum #(
    .MAX_COUNT(2*SA_SIZE)
) u_Count_To_Maximum (
    .resetn             (resetn),
    .clk                (clk),
    .clear              (1'b0),
    .increment_counter  (should_advance_computation),
    .is_counter_at_max (output_valid)
);

endmodule
