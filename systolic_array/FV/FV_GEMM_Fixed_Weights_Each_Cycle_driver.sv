import GEMM_pkg::*;

module FV_GEMM_Fixed_Weights_Each_Cycle #(
    parameter SA_SIZE = 4,
    parameter INPUT_SIZE = 2,
    parameter WEIGHT_ACTIVATION_SIZE = 8
) (
    input logic clk,
    input logic resetn,

    input logic[WEIGHT_ACTIVATION_SIZE-1:0] inputs[SA_SIZE],
    output logic[WEIGHT_ACTIVATION_SIZE-1:0] out[SA_SIZE]
);

`ifdef FORMAL

// Default clocking and reset for all properties
default clocking cb @(posedge clk); endclocking
default disable iff (!resetn);

`endif

//////////////////////////////////////////////////////////////////////////
//  GEMM module instantiation
//////////////////////////////////////////////////////////////////////////

logic output_valid;

// Instantiate the GEMM module
GEMM_Fixed_Weights_Each_Cycle #(
    .SA_SIZE(SA_SIZE),
    .WEIGHT_ACTIVATION_SIZE(WEIGHT_ACTIVATION_SIZE)
) u_GEMM (
    .resetn(resetn),
    .clk(clk),
    .activation_inputs(inputs),
    .activation_outputs(out),
    .output_valid(output_valid)
);

//////////////////////////////////////////////////////////////////////////
//  Reference model
//////////////////////////////////////////////////////////////////////////

logic[WEIGHT_ACTIVATION_SIZE-1:0] weights[SA_SIZE][SA_SIZE];
assign weights = u_GEMM.u_SA.weights_reg;

// Golden model implementation
function automatic logic golden_model_matrix_vector_multiply_check (
    input logic[WEIGHT_ACTIVATION_SIZE-1:0] input_vector[SA_SIZE],
    input logic[WEIGHT_ACTIVATION_SIZE-1:0] actual_systolic_array_output[SA_SIZE]
);
    logic[WEIGHT_ACTIVATION_SIZE-1:0] expected[SA_SIZE];
    logic does_match;

    // Initialize match flag
    does_match = 1'b1;

    // First compute expected result
    for (int i = 0; i < SA_SIZE; i++) begin
        expected[i] = '0;
        // Compute dot product for each row
        for (int j = 0; j < SA_SIZE; j++) begin
            expected[i] += input_vector[j] * weights[j][i];
        end
    end

    // Now compare expected with actual
    for (int i = 0; i < SA_SIZE; i++) begin
        if (expected[i] != actual_systolic_array_output[i]) begin
            does_match = 1'b0;
        end
    end

    return does_match;
endfunction

//////////////////////////////////////////////////////////////////////////
//  Formal verification properties
//////////////////////////////////////////////////////////////////////////

`ifdef FORMAL

// Assume that we always start at reset
initial assume(!resetn);

///////////////////////////////////////////////
//  COVER PROPERTIES
///////////////////////////////////////////////

if (SA_SIZE == 2) begin

    // Test an interesting vector output
    cover property (
        !output_valid ##1 output_valid &&
        out[0] == 6 && out[1] == 10 &&
        weights[0][0] == 3 && weights[0][1] == 0 &&
        weights[1][0] == 0 && weights[1][1] == 2 &&
        $past(inputs[0], 2*SA_SIZE) == 2 &&
        $past(inputs[1], 2*SA_SIZE) == 5
    );

    // Test an interesting matrix output (two inputs)
    cover property (
        !output_valid ##1 output_valid ##1 output_valid &&

        $past(out[0]) == 6 && $past(out[1]) == 10 &&
        out[0] == 9 && out[1] == 4 &&

        weights[0][0] == 3 && weights[0][1] == 0 &&
        weights[1][0] == 0 && weights[1][1] == 2
    );

end

///////////////////////////////////////////////
//  ASSERTIONS
///////////////////////////////////////////////

// TODO: Use golden_model_matrix_vector_multiply to assert that the output is indeed correct.
// For a given output, the input is 2*SA_SIZE cycles in the past.
assert property (
    output_valid |-> golden_model_matrix_vector_multiply_check($past(inputs, 2*SA_SIZE), out) == 1'b1
);

// Assert that the systolic array finishes in at most 2*SA_SIZE
assert property (
    (!output_valid |-> ##(2*SA_SIZE) output_valid)
);

// TODO: Define more formal properties


`endif

endmodule