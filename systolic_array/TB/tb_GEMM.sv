`timescale 1ns/1ns

import GEMM_pkg::*;

module tb_GEMM;

localparam int SA_SIZE = 4;
localparam int INPUT_SIZE = 5;

localparam ACTIVATION_SIZE = 8;

// The first valid output will appear at (2*SA_SIZE-1). Then, to read the whole
//  resulting matrix, we need to flush INPUT_SIZE times.

localparam int FIRST_OUTPUT_CYCLE = 2*SA_SIZE - 1;
localparam int NUM_OUTPUTS_TO_FLUSH = FIRST_OUTPUT_CYCLE + INPUT_SIZE;

// Bidimensional weight-matrix

logic[7:0] weights[SA_SIZE][SA_SIZE];

// logic[7:0] weights[SA_SIZE][SA_SIZE] = '{
//     '{1, 0, 0, 0},
//     '{0, 2, 0, 0},
//     '{0, 0, 3, 0},
//     '{0, 0, 0, 4}
// };

// Input matrix to multiply with the weights
logic[7:0] input_matrix[INPUT_SIZE][SA_SIZE];

// logic[7:0] input_matrix[INPUT_SIZE][SA_SIZE] = '{
//   '{ 1,  2,  3,  4},
//   '{ 5,  6,  7,  8},
//   '{ 9, 10, 11, 12},
//   '{13, 14, 15, 16},
//   '{17, 18, 19, 20}
// };

logic[7:0] output_matrix[INPUT_SIZE][SA_SIZE];

task dump_weight_matrix;
    $display("W=np.array([");

    for (int r = 0; r <= SA_SIZE - 1; r = r + 1) begin
        $write("    [");
        for (int c = 0; c <= SA_SIZE - 1; c = c + 1) begin
            $write("%4d", weights[r][c]);
            if (c != SA_SIZE - 1) begin
                $write(", ");
            end
        end
        $display("],");
    end

    $display("], np.uint8)");
endtask

task dump_input_matrix;
    $display("I=np.array([");

    for (int r = 0; r <= INPUT_SIZE - 1; r = r + 1) begin
        $write("    [");
        for (int c = 0; c <= SA_SIZE - 1; c = c + 1) begin
            $write("%4d", input_matrix[r][c]);
            if (c != SA_SIZE - 1) begin
                $write(", ");
            end
        end
        $display("],");
    end

    $display("], np.uint8)");
endtask;

task dump_computed_output_matrix;
    $display("O_computed=np.array([");

    for (int r = 0; r <= INPUT_SIZE - 1; r = r + 1) begin
        $write("    [");
        for (int c = 0; c <= SA_SIZE - 1; c = c + 1) begin
            $write("%4d", output_matrix[r][c]);
            if (c != SA_SIZE - 1) begin
                $write(", ");
            end
        end
        $display("],");
    end

    $display("], np.uint8)");
endtask;

logic resetn;
logic clk;

parameter clk_period = 10;

// Clock
always begin
    clk = 0;
    #(clk_period/2);
    clk = 1;
    #(clk_period/2);
end

logic[ACTIVATION_SIZE-1:0] in[SA_SIZE];
logic[ACTIVATION_SIZE-1:0] out[SA_SIZE];

command_t cmd;

GEMM #(
    .SA_SIZE            (SA_SIZE)
) u_GEMM (
    .resetn             (resetn),
    .clk                (clk),
    .weight_inputs(weights),
    .activation_inputs(in),
    .activation_outputs(out),
    .cmd                (cmd)
);

// Task to load the weights
task load_weights;
    cmd = CMD_WRITE_WEIGHTS;
    #clk_period;
    cmd = CMD_NONE;
endtask

task automatic print_vector(input logic[7:0] x[]);
    int i;
    int size;
    begin
        size = $size(x);  // Get the size of the array
        $write("[");
        for (i = 0; i < size; i++) begin
            $write("%d", x[i]);
            if (i != size - 1) begin
                $write(", ");
            end
        end
        $display("]");
    end
endtask

// Task to load the input matrix
task load_input;
    for (int r = 0; r < INPUT_SIZE; r = r + 1) begin
        for (int c = 0; c < SA_SIZE; c = c + 1) begin
            in[c] = input_matrix[r][c];
        end

        cmd = CMD_STREAM;
        #clk_period;

        for (int c = 0; c < SA_SIZE; c = c + 1) begin
            if (r >= FIRST_OUTPUT_CYCLE) begin
                output_matrix[r-FIRST_OUTPUT_CYCLE][c] = out[c];
            end
        end

        // Print the buffer as an output
        $write("Output row %d: ", r);
        print_vector(out);
    end

    cmd = CMD_NONE;
endtask

// Task to flush the outputs by inputting 0s into the SA
task flush_outputs;
    int NUM_TO_FLUSH = 20;

    for (int r = INPUT_SIZE; r < NUM_OUTPUTS_TO_FLUSH; r = r + 1) begin

        // Load 0s into the systolic array
        for (int c = 0; c < SA_SIZE; c = c + 1) begin
            in[c] = '0;
        end

        cmd = CMD_STREAM;
        #clk_period;

        for (int c = 0; c < SA_SIZE; c = c + 1) begin
            if (r >= FIRST_OUTPUT_CYCLE) begin
                output_matrix[r-FIRST_OUTPUT_CYCLE][c] = out[c];
            end
        end

        // Print the buffer as an output
        $write("Output row %d: ", r);
        print_vector(out);
    end
    cmd = CMD_NONE;
endtask

initial begin

    // Randomize weights and input matrix
    std::randomize(weights);
    std::randomize(input_matrix);

    // Assert and de-assert reset
    resetn = 0;
    #(4*clk_period);
    cmd = CMD_NONE;
    resetn = 1;
    #(2*clk_period);

    load_weights;
    load_input;
    flush_outputs;

    // Dump weights and matrix as numpy code to be able to verify
    $display("-------------------");
    $display("   BEGIN NUMPY");
    $display("-------------------");

    $display("\nimport numpy as np");
    dump_weight_matrix;
    dump_input_matrix;
    dump_computed_output_matrix;
    $display("O_actual = I @ W");
    $display("print(O_actual)");
    $display("print('\\nTEST PASSED' if (O_actual == O_computed).all() else '\\nTEST FAILED')\n");

    $display("-------------------");
    $display("    END NUMPY");
    $display("-------------------");

    $finish;
end

endmodule
