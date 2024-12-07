import GEMM_pkg::*;

module SA #(
    parameter SA_SIZE = 8,


    // This module uses INT-N weights weights and activations
    parameter WEIGHT_SIZE = 8,
    parameter ACTIVATION_SIZE = 8
) (
    input logic resetn,
    input logic clk,

    // All weights are loaded at once when cmd = CMD_WRITE_WEIGHTS
    input logic[WEIGHT_SIZE-1:0] weight_inputs[SA_SIZE][SA_SIZE],

    input logic[ACTIVATION_SIZE-1:0] inputs[SA_SIZE],
    output logic[ACTIVATION_SIZE-1:0] outputs[SA_SIZE],

    input command_t cmd
);
    // Weights for each processing element.
    //    Access as weights_reg[r][c]
    logic[WEIGHT_SIZE-1:0] weights_reg[SA_SIZE][SA_SIZE];

    // Accumulator registers storing the output of each PE.
    // Note that there are only SA_SIZE-1 rows of accumulators, as the first accumulator (input to first PE) is always 0.
    //    Access as accs_reg[r][c]
    logic[ACTIVATION_SIZE-1:0] accs_reg[SA_SIZE-1][SA_SIZE];

    // Registers that hold the input of each PE (which is passed to the right).
    // Note that there are only SA_SIZE-1 rows of input registers, as the input to the first PE comes from the SA module input inputs.
    //    Access as pe_inputs_reg[r][c]
    logic[ACTIVATION_SIZE-1:0] pe_inputs_reg[SA_SIZE][SA_SIZE-1];

    // The computation should only be advanced if the command is CMD_STREAM
    logic should_advance_computation;
    assign should_advance_computation = (cmd == CMD_STREAM);

    //////////////////////////////////////////////////////////////////////////
    //                       PROCESSING ELEMENTS
    //////////////////////////////////////////////////////////////////////////

    // Instantiate each processing element
    genvar r, c;
    generate
        for (r = 0; r < SA_SIZE; r = r + 1) begin: R_GEN
            for (c = 0; c < SA_SIZE; c = c + 1) begin: C_GEN

                // PE INPUT
                logic[ACTIVATION_SIZE-1:0] pe_in;

                // If this is the first column, the input to the PE is the input to the SA module
                // Otherwise, the input to the PE is the output of the PE to the left
                assign pe_in = (c == 0) ? inputs[r] : pe_inputs_reg[r][c-1];

                // If should_advance_computation, advance the input to the right (if there's a next PE to the right)
                if (c < SA_SIZE-1) begin
                    always_ff @(posedge clk) begin
                        if (~resetn) begin
                            pe_inputs_reg[r][c] <= '0;
                        end else begin
                            if (should_advance_computation) begin
                                pe_inputs_reg[r][c] <= pe_in;
                            end else begin
                                pe_inputs_reg[r][c] <= pe_inputs_reg[r][c];
                            end
                        end
                    end
                end

                // PE ACCUMULATOR
                logic[ACTIVATION_SIZE-1:0] pe_acc;

                // If this is the first row, the accumulator is 0
                // Otherwise, the accumulator is the output of the PE above
                assign pe_acc = (r == 0) ? '0 : accs_reg[r-1][c];

                // PE OUTPUT
                logic[ACTIVATION_SIZE-1:0] pe_out;

                // If this is the last row, then the output of the accumulator is the output of the SA module
                if (r == SA_SIZE-1) begin
                    assign outputs[c] = pe_out;
                end else begin
                    // Otherwise, the output of the PE is stored in accs_reg for the next row to use
                    always_ff @(posedge clk) begin
                        if (~resetn) begin
                            accs_reg[r][c] <= '0;
                        end else begin
                            if (should_advance_computation) begin
                                accs_reg[r][c] <= pe_out;
                            end else begin
                                accs_reg[r][c] <= accs_reg[r][c];
                            end
                        end
                    end
                end

                PE #(
                    .WEIGHT_SIZE(WEIGHT_SIZE),
                    .ACTIVATION_SIZE(ACTIVATION_SIZE)
                ) u_PE (
                    .resetn(resetn),
                    .clk(clk),
                    .in(pe_in),
                    .acc(pe_acc),
                    .w(weights_reg[r][c]),
                    .out(pe_out)
                );

                //////////////////////////////////////////////////////////////////////////
                //                     WEIGHTS REGISTERS
                //////////////////////////////////////////////////////////////////////////

                always_ff @(posedge clk) begin
                    if (~resetn) begin
                        weights_reg[r][c] <= '0;
                    end else begin
                        weights_reg[r][c] <= weights_reg[r][c];
                        // If cmd is CMD_WRITE_WEIGHTS, then load all weights
                        if (cmd == CMD_WRITE_WEIGHTS) begin
                            weights_reg[r][c] <= weight_inputs[r][c];
                        end
                    end
                end

            end
        end
    endgenerate

endmodule