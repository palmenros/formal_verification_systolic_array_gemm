import TicSAT_pkg::*;

module TicSAT #(
    parameter SA_SIZE = 4,

    // This module uses INT-N weights weights and activations
    parameter WEIGHT_ACTIVATION_SIZE = 8

) (
    input logic resetn,
    input logic clk,

    // Used to load both weights and activations, depending on cmd
    input logic[WEIGHT_ACTIVATION_SIZE-1:0] in_val,

    // Used to select in which FIFO position to write the input and read the output
    input logic[$clog2(SA_SIZE)-1:0] in_idx,

    output logic[WEIGHT_ACTIVATION_SIZE-1:0] out,

    input command_t cmd
);

logic[WEIGHT_ACTIVATION_SIZE-1:0] systolic_array_inputs[SA_SIZE-1:0];
logic[WEIGHT_ACTIVATION_SIZE-1:0] systolic_array_outputs[SA_SIZE-1:0];

SA_FP32 #(
    .SA_SIZE            (SA_SIZE),
    .WEIGHT_SIZE        (WEIGHT_ACTIVATION_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_SA_FP32 (
    .resetn             (resetn),
    .clk                (clk),
    .weight_input       (in_val),
    .inputs             (systolic_array_inputs),
    .outputs            (systolic_array_outputs),
    .cmd                (cmd)
);

FIFO_in #(
    .SA_SIZE            (SA_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_FIFO_in (
    .resetn             (resetn),
    .clk                (clk),
    .in                 (in_val),
    .in_row_idx         (in_idx),
    .outputs            (systolic_array_inputs),
    .cmd                (cmd)
);

FIFO_out #(
    .SA_SIZE            (SA_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_FIFO_out (
    .resetn             (resetn),
    .clk                (clk),
    .inputs             (systolic_array_outputs),
    .in_row_idx         (in_idx),
    .out                (out),
    .cmd                (cmd)
);

endmodule