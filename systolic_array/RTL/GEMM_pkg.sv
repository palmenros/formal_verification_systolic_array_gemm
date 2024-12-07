package GEMM_pkg;

    typedef enum logic [1:0] {
        // Write all weights into the systolic array at once
        CMD_WRITE_WEIGHTS  = 2'b00,

        // Perform a computation in the systolic array (and shift all values)
        CMD_STREAM = 2'b01,

        // Do nothing
        CMD_NONE = 2'b10
    } command_t;

endpackage // GEMM_pkg