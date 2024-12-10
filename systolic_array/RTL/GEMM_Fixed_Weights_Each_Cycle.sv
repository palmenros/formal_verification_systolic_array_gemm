import GEMM_pkg::*;

module GEMM_Fixed_Weights_Each_Cycle #(
    parameter SA_SIZE = 4,

    // This module uses INT-N weights weights and activations
    parameter WEIGHT_ACTIVATION_SIZE = 8
) (
    input logic resetn,
    input logic clk,

    input logic[WEIGHT_ACTIVATION_SIZE-1:0] activation_inputs[SA_SIZE],
    output logic[WEIGHT_ACTIVATION_SIZE-1:0] activation_outputs[SA_SIZE],

    output logic[WEIGHT_ACTIVATION_SIZE-1:0] pe_out[SA_SIZE][SA_SIZE],

    output logic output_valid
);

logic[WEIGHT_ACTIVATION_SIZE-1:0] systolic_array_inputs[SA_SIZE];
logic[WEIGHT_ACTIVATION_SIZE-1:0] systolic_array_outputs[SA_SIZE];

SA_Fixed_Weights_Each_Cycle #(
    .SA_SIZE            (SA_SIZE),
    .WEIGHT_SIZE        (WEIGHT_ACTIVATION_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_SA (
    .resetn             (resetn),
    .clk                (clk),
    .inputs             (systolic_array_inputs),
    .outputs            (systolic_array_outputs),
    .pe_out             (pe_out)
);

Delay_Skew_In_Each_Cycle #(
    .SA_SIZE            (SA_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_Delay_Skew_In (
    .resetn             (resetn),
    .clk                (clk),
    .in                 (activation_inputs),
    .outputs            (systolic_array_inputs)
);

Delay_Skew_Out_Each_Cycle #(
    .SA_SIZE            (SA_SIZE),
    .ACTIVATION_SIZE    (WEIGHT_ACTIVATION_SIZE)
) u_Delay_Skew_Out (
    .resetn             (resetn),
    .clk                (clk),
    .inputs             (systolic_array_outputs),
    .out                (activation_outputs)
);

logic[$clog2(2*SA_SIZE):0] counter;
logic counter_reach_max;

assign output_valid = counter_reach_max;

always_ff @(posedge clk) begin
    if (!resetn) begin
        counter <= '0;
        counter_reach_max <= '0;
    end else if (counter != 2*SA_SIZE) begin
        counter <= counter + 1'b1;
        if (counter == 2*SA_SIZE - 1) begin
            counter_reach_max <= 1'b1;
        end
    end
end

endmodule
