import GEMM_pkg::*;

module FV_GEMM_Fixed_Weights #(
    parameter SA_SIZE = 2,
    parameter INPUT_SIZE = 2,
    parameter WEIGHT_ACTIVATION_SIZE = 8
) (
    input logic clk,
    input logic resetn,

    input logic[WEIGHT_ACTIVATION_SIZE-1:0] inputs[SA_SIZE],
    output logic[WEIGHT_ACTIVATION_SIZE-1:0] out[SA_SIZE],

    input logic should_advance_computation
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
GEMM_Fixed_Weights #(
    .SA_SIZE(SA_SIZE),
    .WEIGHT_ACTIVATION_SIZE(WEIGHT_ACTIVATION_SIZE)
) u_GEMM (
    .resetn(resetn),
    .clk(clk),
    .activation_inputs(inputs),
    .activation_outputs(out),
    .output_valid(output_valid),
    .should_advance_computation(should_advance_computation)
);

//////////////////////////////////////////////////////////////////////////
//  Reference model
//////////////////////////////////////////////////////////////////////////


logic[WEIGHT_ACTIVATION_SIZE-1:0] weights[SA_SIZE][SA_SIZE];
assign weights = u_GEMM.u_SA.weights_reg;

localparam int MAX_INPUTS = 2;

int should_advance_counter;
logic [WEIGHT_ACTIVATION_SIZE-1:0] input_snapshot[MAX_INPUTS][SA_SIZE];

// Golden model implementation
function automatic logic golden_model_matrix_vector_multiply_check (
    input int input_index,
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
            expected[i] += input_snapshot[input_index][j] * weights[j][i];
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

// Counter for should_advance
always_ff @(posedge clk) begin
    if (!resetn) begin
        should_advance_counter <= 0;

        for(int i = 0; i < MAX_INPUTS; ++i) begin
            for (int c = 0; c < SA_SIZE; ++c) begin
                input_snapshot[i][c] <= '0;
            end
        end
        input_snapshot <= '{default: '0};
    end else begin
        if (should_advance_computation) begin
            should_advance_counter <= should_advance_counter + 1'b1;

            if (should_advance_computation < MAX_INPUTS) begin
                for (int c = 0; c < SA_SIZE; ++c) begin
                    input_snapshot[should_advance_counter][c] <= inputs[c];
                end
            end
        end
    end
end

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

// Use golden_model_matrix_vector_multiply to assert that the output is indeed correct.
// For a given output, the input is 2*SA_SIZE counts of should_advance_counter in the past.
assert property (
    output_valid && (should_advance_counter < 2*SA_SIZE + MAX_INPUTS) |-> (should_advance_counter >= 2*SA_SIZE) && golden_model_matrix_vector_multiply_check(
        should_advance_counter - 2*SA_SIZE,
        out
    ) == 1'b1
);

///////////////////////////////////////////////////////////////////
// Assert that the systolic array finishes in at most 2*SA_SIZE 
///////////////////////////////////////////////////////////////////

// NOTE: This is not supported by SymbiYosys, so instead we need to implement the counter in normal system verilog
// sequence count_should_advance_occurrences;
//   int count = 0;
//   (1, count = 0) ##0 (should_advance_computation, count++) [*0:$] ##0 (count == 2*SA_SIZE);
// endsequence

// Assert that the output is indeed produced on time.
assert property (
    (should_advance_computation && should_advance_counter == 2*SA_SIZE-1) |=> output_valid
);

// Once the output is valid, it should remain being valid
assert property (
    output_valid |-> ##1 output_valid
);

// TODO: Define more formal properties


`endif

endmodule
