import TicSAT_pkg::*;

module FIFO_in #(
    parameter SA_SIZE = 8,
    parameter ACTIVATION_SIZE = 32
) (
    input logic resetn,
    input logic clk,

    input logic[ACTIVATION_SIZE-1:0] in,
    input logic[$clog2(SA_SIZE)-1:0] in_row_idx,

    output logic[ACTIVATION_SIZE-1:0] outputs[SA_SIZE-1:0],
    
    input command_t cmd
);
    

// For each row, generate a shift register of size r+1, that is only shifted on CMD_STREAM. 
// On CMD_QUEUE or CMD_STREAM, the input in is loaded into the first register at position in_row_idx.
genvar r, c;
generate
    for (r = 0; r < SA_SIZE; r = r + 1) begin: R_GEN
        logic[ACTIVATION_SIZE-1:0] row_shift_reg[r:0];

        // On CMD_QUEUE or CMD_STREAM, load the input into the first register (if at position in_row_idx)
        always_ff @(posedge clk) begin
            if (~resetn) begin
                row_shift_reg[0] <= '0;
            end else begin
                if ((cmd == CMD_QUEUE || cmd == CMD_STREAM) && in_row_idx == r) begin
                    row_shift_reg[0] <= in;
                end else begin
                    row_shift_reg[0] <= row_shift_reg[0];
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
                        // In the special case where we are performing a write to this row, instead of shifting the 
                        //  previously stored value in the register, we store the new input, to be in sync.
                        if (in_row_idx == r && c == 1) begin
                            row_shift_reg[c] <= in;
                        end else begin
                            row_shift_reg[c] <= row_shift_reg[c-1];
                        end
                    end else begin
                        row_shift_reg[c] <= row_shift_reg[c];
                    end
                end
            end
        end

        // Assign the output to the end of the shift-register
        assign outputs[r] = row_shift_reg[r];
    end
endgenerate;

endmodule