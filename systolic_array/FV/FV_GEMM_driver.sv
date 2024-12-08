import GEMM_pkg::*;

module FV_GEMM #(
    parameter SA_SIZE = 4,
    parameter INPUT_SIZE = 5,
    parameter WEIGHT_ACTIVATION_SIZE = 8
) (
    input logic resetn,
    input logic clk
);

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
logic [WEIGHT_ACTIVATION_SIZE-1:0] weights[SA_SIZE][SA_SIZE];
logic [WEIGHT_ACTIVATION_SIZE-1:0] inputs[INPUT_SIZE][SA_SIZE];


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
            end else begin
                output_row_idx <= output_row_idx + 1;
            end;
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
        assert (input_row_idx < INPUT_SIZE);
        activation_inputs = inputs[input_row_idx];
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

// TODO: Define some formal properties

`endif

endmodule
