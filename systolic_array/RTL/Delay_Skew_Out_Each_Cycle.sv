import GEMM_pkg::*;

module Delay_Skew_Out_Each_Cycle #(
    parameter SA_SIZE = 8,
    parameter ACTIVATION_SIZE = 32
) (
    input logic resetn,
    input logic clk,

    input logic[ACTIVATION_SIZE-1:0] inputs[SA_SIZE],
    output logic[ACTIVATION_SIZE-1:0] out[SA_SIZE]
);

// For each column, last_shift_reg contains the last value of the shift register
logic[ACTIVATION_SIZE-1:0] last_shift_reg[SA_SIZE];

assign out = last_shift_reg;

// For each column, we generate a shift register of size SA_SIZE-c, that is only shifted on CMD_STREAM,
//   with the first register input taken from inputs.
genvar r, c;
generate
    for (c = 0; c < SA_SIZE; c = c + 1) begin: R_GEN
        logic[ACTIVATION_SIZE-1:0] col_shift_reg[SA_SIZE-c-1:0];

        always_ff @(posedge clk) begin
            if (~resetn) begin
                col_shift_reg[0] <= '0;
            end else begin
                col_shift_reg[0] <= inputs[c];
            end
        end

        // Shift-registers
        for (r = 1; r < SA_SIZE - c; r = r + 1) begin: C_GEN
            // Shift on CMD_STREAM to the right
            always_ff @(posedge clk) begin
                if (~resetn) begin
                    col_shift_reg[r] <= '0;
                end else begin
                    col_shift_reg[r] <= col_shift_reg[r-1];
                end
            end
        end

        assign last_shift_reg[c] = col_shift_reg[SA_SIZE-c-1];
    end
endgenerate;

endmodule