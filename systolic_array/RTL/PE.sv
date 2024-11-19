module PE #(
    // This module uses INT-N weights weights and activations
    parameter WEIGHT_SIZE = 8,
    parameter ACTIVATION_SIZE = 8
) (
    input logic resetn,
    input logic clk,

    input logic signed[ACTIVATION_SIZE-1:0] in,
    input logic signed[ACTIVATION_SIZE-1:0] acc,
    input logic signed[WEIGHT_SIZE-1:0] w,

    output logic signed[ACTIVATION_SIZE-1:0] out
);

logic signed[ACTIVATION_SIZE+WEIGHT_SIZE-1:0] mult;
logic signed[ACTIVATION_SIZE+WEIGHT_SIZE:0] mult_acc;

assign mult = in * w;
assign mult_acc = mult + acc;
assign out = mult_acc[ACTIVATION_SIZE-1:0];

endmodule
