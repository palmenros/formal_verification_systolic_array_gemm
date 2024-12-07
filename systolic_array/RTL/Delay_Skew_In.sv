import GEMM_pkg::*;

module Delay_Skew_In #(
    parameter SA_SIZE = 8,
    parameter ACTIVATION_SIZE = 32
) (
    input logic resetn,
    input logic clk,

    input logic[ACTIVATION_SIZE-1:0] in[SA_SIZE],
    output logic[ACTIVATION_SIZE-1:0] outputs[SA_SIZE],

    input command_t cmd
);

// For each row, generate a shift register of size r+1, that is only shifted on CMD_STREAM.
// On CMD_QUEUE or CMD_STREAM, the input in is loaded into the first register at position in_row_idx.
genvar r, c;
generate
    for (r = 0; r < SA_SIZE; r = r + 1) begin: R_GEN
        logic[ACTIVATION_SIZE-1:0] row_shift_reg[r+1];

        // On CMD_QUEUE or CMD_STREAM, load the input into the first register (if at position in_row_idx)
        always_ff @(posedge clk) begin
            if (~resetn) begin
                row_shift_reg[0] <= '0;
            end else begin
                if (cmd == CMD_STREAM) begin
                    row_shift_reg[0] <= in[r];
                end
            end
        end

        // Shift-registers
        for (c = 1; c <= r; c = c + 1) begin: C_GEN
            // Shift on CMD_STREAM to the right
            always_ff @(posedge clk) begin
                if (~resetn) begin
                    row_shift_reg[c] <= '0;
                end else begin
                    if (cmd == CMD_STREAM) begin
                        row_shift_reg[c] <= row_shift_reg[c-1];
                    end
                end
            end
        end

        // Assign the output to the end of the shift-register
        assign outputs[r] = row_shift_reg[r];
    end
endgenerate;

endmodule
