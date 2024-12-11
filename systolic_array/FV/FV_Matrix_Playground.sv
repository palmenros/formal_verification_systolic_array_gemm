module FV_Matrix_Playground #(
    parameter SA_SIZE = 3,
    parameter INPUT_SIZE = 2,
    parameter WEIGHT_ACTIVATION_SIZE = 8
) (
    input logic clk,

    input logic[WEIGHT_ACTIVATION_SIZE-1:0] inputs[SA_SIZE],
    output logic[WEIGHT_ACTIVATION_SIZE-1:0] out[SA_SIZE]
);

`ifdef FORMAL

// Default clocking all properties
default clocking cb @(posedge clk); endclocking

`endif

//////////////////////////////////////////////////////////////////////////
//  Reference model
//////////////////////////////////////////////////////////////////////////

(* anyconst *) logic[WEIGHT_ACTIVATION_SIZE-1:0] weights[SA_SIZE][SA_SIZE];

always_comb begin
    for (int i = 0; i < SA_SIZE; i++) begin
        out[i] = '0;
        // Compute dot product for each row
        for (int j = 0; j < SA_SIZE; j++) begin
            out[i] += inputs[j] * weights[j][i];
        end
    end
end

//////////////////////////////////////////////////////////////////////////
//  Formal verification properties
//////////////////////////////////////////////////////////////////////////

`ifdef FORMAL

///////////////////////////////////////////////
//  COVER PROPERTIES
///////////////////////////////////////////////


///////////////////////////////////////////////
//  Matrix inverse of diagonal matrix
///////////////////////////////////////////////

cover property (
    ##1
    $past(out[0]) == 6 && $past(out[1])  == 10 && $past(out[2]) == 30  &&
    out[0]        == 12 && out[1]        == 30 && out[2]        == 120 &&
    // O = np.array([[6, 10, 30],
    //               [12, 30, 120]], np.uint8)

    weights[0][0] == 3 && weights[0][1] == 0 && weights[0][2] == 0 &&
    weights[1][0] == 0 && weights[1][1] == 2 && weights[1][2] == 0 &&
    weights[2][0] == 0 && weights[2][1] == 0 && weights[2][2] == 5
    // W = np.array([[3, 0, 0],
    //               [0, 2, 0],
    //               [0, 0, 5]], np.uint8)

    // The computed input is is:

    // I=np.array([[0x02, 0x85, 0x06],
    //             [0x04, 0x8f, 0x18]], np.uint8)
);

///////////////////////////////////////////////
//  Full linear system solver
///////////////////////////////////////////////

cover property (
    ##1
    $past(out[0]) == 1 && $past(out[1])  == 2 && $past(out[2]) == 3  &&
    out[0]        == 4 &&  out[1]        == 5 && out[2]        == 6 &&
    // O = np.array([[1, 2, 3],
    //               [4, 5, 6]], np.uint8)

    weights[0][0] == 3 && weights[0][1] == 255 && weights[0][2] == 1 &&
    weights[1][0] == 4 && weights[1][1] == 2 && weights[1][2] == 7   &&
    weights[2][0] == 23 && weights[2][1] == 42 && weights[2][2] == 5
    // W = np.array([[3, 255, 1],
    //               [4,   2, 7],
    //               [23, 42, 5]], np.uint8)

    // The computed input is is:

    // I=np.array([[0x4C, 0x60, 0x6B],
    //             [0xB5, 0x86, 0xBB]], np.uint8)
);

///////////////////////////////////////////////
// LU factoring
///////////////////////////////////////////////

// X = [[1 1  1]
//      [4 3 255]
//      [3 5  3]]

// L = [[1   0   0],
//      [4   1   0],
//      [3  254  1]]

// U = [[1   1   1],
//      [0 255 251],
//      [0   0 246]]

// L * U = X

cover property (
    ##2
    $past(out[0], 2) == 1 && $past(out[1], 2) == 1 && $past(out[2], 2) == 1   &&
    $past(out[0], 1) == 4 && $past(out[1], 1) == 3 && $past(out[2], 1) == 255 &&
    out[0] == 3 && out[1] == 5 && out[2] == 3 &&
    // X = np.array([[1, 1, 1],
    //               [4, 3, 255],
    //               [3, 5, 3]], np.uint8)

    /*     */               /*    */                /*    */
    weights[1][0] == 0  &&  /*    */                /*    */
    weights[2][0] == 0  &&  weights[2][1] == 0 &&   /*    */

    /*     */               $past(inputs[1], 2) == 0 &&  $past(inputs[2], 2) == 0 &&
    /*     */               /*     */                    $past(inputs[2], 1) == 0
    /*     */               /*    */                     /*    */
);

// The computed decomposition is:

// L = np.array([[0x81, 0x00, 0x00],
//               [0x04, 0xDD, 0x00],
//               [0x83, 0x46, 0xD2]], np.uint8)

// U = np.array([[0x81, 0x81, 0x81],
//               [0x00, 0x8B, 0xB7],
//               [0x00, 0x00, 0xC3]], np.uint8)

`endif

endmodule
