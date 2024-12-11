import GEMM_pkg::*;

module GEMM #(
    parameter SA_SIZE = 4,
    
    // This module uses INT-N weights weights and activations
    parameter WEIGHT_ACTIVATION_SIZE = 8
) (
    input logic resetn,
    input logic clk,

    // All weights are loaded at once when cmd = CMD_WRITE_WEIGHTS
    input logic[WEIGHT_ACTIVATION_SIZE-1:0] weight_inputs[SA_SIZE][SA_SIZE],

    input logic[WEIGHT_ACTIVATION_SIZE-1:0] activation_inputs[SA_SIZE],
    output logic[WEIGHT_ACTIVATION_SIZE-1:0] activation_outputs[SA_SIZE],

    input command_t cmd,

    output logic output_valid
);

logic[WEIGHT_ACTIVATION_SIZE-1:0] systolic_array_inputs[SA_SIZE];
logic[WEIGHT_ACTIVATION_SIZE-1:0] systolic_array_outputs[SA_SIZE];

SA #(
    .SA_SIZE            (SA_SIZE),
    .WEIGHT_SIZE        (WEIGHT_ACTIVATION_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_SA (
    .resetn             (resetn),
    .clk                (clk),
    .weight_inputs      (weight_inputs),
    .inputs             (systolic_array_inputs),
    .outputs            (systolic_array_outputs),
    .cmd (cmd)
);

Delay_Skew_In #(
    .SA_SIZE            (SA_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_Delay_Skew_In (
    .resetn             (resetn),
    .clk                (clk),
    .in                 (activation_inputs),
    .outputs            (systolic_array_inputs),
    .should_advance_computation (cmd == CMD_STREAM)
);

Delay_Skew_Out #(
    .SA_SIZE            (SA_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_Delay_Skew_Out (
    .resetn             (resetn),
    .clk                (clk),
    .inputs             (systolic_array_outputs),
    .out                (activation_outputs),
    .should_advance_computation  (cmd == CMD_STREAM)
);

Count_To_Maximum #(
    .MAX_COUNT(2*SA_SIZE)
) u_Count_To_Maximum (
    .resetn             (resetn),
    .clk                (clk),
    .clear              (cmd == CMD_WRITE_WEIGHTS),
    .increment_counter  (cmd == CMD_STREAM),
    .is_counter_at_max (output_valid)
);

endmodule
