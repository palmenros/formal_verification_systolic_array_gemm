import GEMM_pkg::*;

module FV_GEMM #(
    parameter SA_SIZE = 2,
    parameter INPUT_SIZE = 2,
    parameter WEIGHT_ACTIVATION_SIZE = 8
) (
    input logic clk,
    input logic resetn
);

`ifdef FORMAL

// Default clocking and reset for all properties
default clocking cb @(posedge clk); endclocking
default disable iff (!resetn);

`endif

//////////////////////////////////////////////////////////////////////////
//  GEMM module instantiation
//////////////////////////////////////////////////////////////////////////

// Inputs to GEMM module
logic[WEIGHT_ACTIVATION_SIZE-1:0] weight_inputs[SA_SIZE][SA_SIZE];
logic[WEIGHT_ACTIVATION_SIZE-1:0] activation_inputs[SA_SIZE];
command_t cmd;

// Outputs from GEMM module
logic[WEIGHT_ACTIVATION_SIZE-1:0] activation_outputs[SA_SIZE];
logic output_valid;

// Instantiate the GEMM module
GEMM #(
    .SA_SIZE(SA_SIZE),
    .WEIGHT_ACTIVATION_SIZE(WEIGHT_ACTIVATION_SIZE)
) u_GEMM (
    .resetn(resetn),
    .clk(clk),
    .weight_inputs(weight_inputs),
    .activation_inputs(activation_inputs),
    .activation_outputs(activation_outputs),
    .cmd(cmd),
    .output_valid(output_valid)
);

//////////////////////////////////////////////////////////////////////////
//  GEMM module instantiation
//////////////////////////////////////////////////////////////////////////

// Non-initialized variables that will be fed into the GEMM and reference model.
// As they are non initialized, the FV tools will prove that the properties
//  hold for every possible value.
(* anyconst *) logic [WEIGHT_ACTIVATION_SIZE-1:0] weights[SA_SIZE][SA_SIZE];
(* anyconst *) logic [WEIGHT_ACTIVATION_SIZE-1:0] inputs[INPUT_SIZE][SA_SIZE];


assign weight_inputs = weights;

//////////////////////////////////////////////////////////////////////////
//  Reference model
//////////////////////////////////////////////////////////////////////////

logic [WEIGHT_ACTIVATION_SIZE-1:0] reference_outputs[INPUT_SIZE][SA_SIZE];

// Golden model for reference model matrix multiplication
function automatic logic[WEIGHT_ACTIVATION_SIZE-1:0] compute_output_element(
    input int row,
    input int col
);
    logic[WEIGHT_ACTIVATION_SIZE-1:0] sum;
    sum = 0;
    for (int k = 0; k < SA_SIZE; k++) begin
        sum += inputs[row][k] * weights[k][col];
    end
    return sum;
endfunction

// Compute reference outputs
always_ff @(posedge clk) begin
    for (int i = 0; i < INPUT_SIZE; i++) begin
        for (int j = 0; j < SA_SIZE; j++) begin
            reference_outputs[i][j] <= compute_output_element(i, j);
        end
    end
end

logic [WEIGHT_ACTIVATION_SIZE-1:0] actual_sa_outputs[INPUT_SIZE][SA_SIZE];
logic all_outputs_stored;

// Output row counter
int output_row_idx;

always_ff @(posedge clk) begin
    if (!resetn) begin
        output_row_idx <= 0;
        all_outputs_stored <= 1'b0;
        actual_sa_outputs <= '{default: '0};
    end else begin
        if (output_valid && cmd == CMD_STREAM && !all_outputs_stored) begin
            for (int c = 0; c < SA_SIZE; c++) begin
                actual_sa_outputs[output_row_idx][c] <= activation_outputs[c];
            end

            if (output_row_idx == INPUT_SIZE - 1) begin
                all_outputs_stored <= 1'b1;
            end
            output_row_idx <= output_row_idx + 1;
        end
    end
end

///////////////////////////////////////////////////////////////////////////
//  DRIVER FSM.
//
//  Loads data into the GEMM Systolic Array. Note that the FV tool will
//  check all possible weight / input data combinations, but the access
//  pattern will be fixed by the driver (sequence of loading weights,
//  streaming inputs, etc.)
///////////////////////////////////////////////////////////////////////////

// Input row counter
logic [$clog2(INPUT_SIZE)-1:0] input_row_idx, next_input_row_idx;

typedef enum logic [2:0] {
    S_INITIAL,
    S_LOAD_WEIGHTS,
    S_STREAM_INPUTS,
    S_STREAM_UNTIL_ALL_OUTPUTS_RECEIVED,
    S_DONE
} state_t;

state_t state, next_state;


always_ff @(posedge clk) begin
    if (!resetn) begin
        state <= S_INITIAL;
        input_row_idx <= '0;
    end else begin
        state <= next_state;
        input_row_idx <= next_input_row_idx;
    end
end

always_comb begin
    activation_inputs = '{default: '0};

    if (state == S_STREAM_INPUTS) begin
        assert property (input_row_idx < INPUT_SIZE);

        for(int c = 0; c < SA_SIZE; ++c) begin
            activation_inputs[c] = inputs[input_row_idx][c];
        end
    end
end

always_comb begin
    next_state = state;
    cmd = CMD_NONE;
    next_input_row_idx = input_row_idx;

    case (state)
        S_INITIAL: begin
            next_state = S_LOAD_WEIGHTS;
        end

        S_LOAD_WEIGHTS: begin
            cmd = CMD_WRITE_WEIGHTS;
            next_state = S_STREAM_INPUTS;
        end

        S_STREAM_INPUTS: begin
            cmd = CMD_STREAM;
            next_input_row_idx = input_row_idx + 1;

            // Move to next state after streaming all inputs
            if (input_row_idx == INPUT_SIZE - 1) begin
                next_state = S_STREAM_UNTIL_ALL_OUTPUTS_RECEIVED;
            end
        end

        S_STREAM_UNTIL_ALL_OUTPUTS_RECEIVED: begin
            cmd = CMD_STREAM;

            // Wait until all outputs have been captured
            if (all_outputs_stored) begin
                next_state = S_DONE;
            end
        end

        S_DONE: begin
            cmd = CMD_NONE;
        end
    endcase
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

// Go through all states of the driver state machine
cover property (
    state == S_INITIAL ##1 state == S_LOAD_WEIGHTS ##1
    state == S_STREAM_INPUTS ##[1:INPUT_SIZE]
    state == S_STREAM_UNTIL_ALL_OUTPUTS_RECEIVED ##[1:$]
    state == S_DONE);

// Go through some non-zero interesting inputs
cover property (
    weights[0][0] == 1 && weights[0][1] == 2 && //weights[0][2] == 1 && weights[0][3] == 2 &&
    weights[1][0] == 3 && weights[1][1] == 1 && //weights[1][2] == 3 && weights[1][3] == 1 &&
    // weights[2][0] == 1 && weights[2][1] == 4 && weights[2][2] == 1 && weights[2][3] == 4 &&
    // weights[3][0] == 5 && weights[3][1] == 1 && weights[3][2] == 5 && weights[3][3] == 1 &&

    inputs[0][0] == 1 && inputs[0][1] == 2 && //inputs[0][2] == 3 && inputs[0][3] == 4 &&
    inputs[1][0] == 5 && inputs[1][1] == 6 && //inputs[1][2] == 7 && inputs[1][3] == 8 &&
    // inputs[2][0] == 9 && inputs[2][1] == 10 && inputs[2][2] == 11 && inputs[2][3] == 12 &&
    // inputs[3][0] == 13 && inputs[3][1] == 14 && inputs[3][2] == 15 && inputs[3][3] == 16 &&
    // inputs[4][0] == 17 && inputs[4][1] == 18 && inputs[4][2] == 19 && inputs[4][3] == 20 &&

    all_outputs_stored
);

// Cover property stating the final outputs, the tool will figure out
//   two matrices that multiply to that value
cover property (
    actual_sa_outputs[0][0] == 3 && actual_sa_outputs[0][1] == 2 && actual_sa_outputs[0][2] == 1 && actual_sa_outputs[0][3] == 0 &&
    actual_sa_outputs[1][0] == 5 && actual_sa_outputs[1][1] == 6 && actual_sa_outputs[1][2] == 7 && actual_sa_outputs[1][3] == 9 &&
    all_outputs_stored
);

///////////////////////////////////////////////
//  SYSTOLIC ARRAY ASSERTIONS
///////////////////////////////////////////////

// Systolic array activation outputs match when streamed out of the systolic array
// TODO: This property is extremely slow to check. Try to make it faster through intermediate assumptions.
// NOTE: After trying autotune, some of the engines that work best are:
// smtbmc bitwuzla
// smtbmc boolector
// smtbmc --nopresat boolector
logic match;
always_comb begin
    match = 1'b1;
    for (int i = 0; i < SA_SIZE; i++) begin
        match = match && (activation_outputs[i] == reference_outputs[output_row_idx][i]);
    end
end

property streaming_outputs_match;
    (output_valid && output_row_idx < INPUT_SIZE) |-> match;
endproperty
assert property(streaming_outputs_match);

// Actual output should be equal to reference output after everything is finished
// TODO: This property takes too long for my laptop to prove. That's why I've commented it out.
// always_comb begin
//     if (resetn && all_outputs_stored) begin
//         for (int i = 0; i < INPUT_SIZE; i++) begin
//             for (int j = 0; j < SA_SIZE; j++) begin
//                 assert (actual_sa_outputs[i][j] == reference_outputs[i][j]) else
//                     $error("Output mismatch at [%0d][%0d]: actual=%0d, expected=%0d",
//                            i, j, actual_sa_outputs[i][j], reference_outputs[i][j]);
//             end
//         end
//     end
// end

// TODO: Add liveness property about systolic array finishing


// TODO: Define more formal properties


`endif

endmodule
