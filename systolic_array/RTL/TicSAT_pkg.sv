package TicSAT_pkg;

    typedef enum logic [1:0] {
        // Write weights into the systolic array
        CMD_WRITE_WEIGHTS  = 2'b00,

        // Load inputs into the FIFOs (shift registers), but do not perform any computation yet (not all inputs are loaded)
        CMD_QUEUE = 2'b01,

        // Perform a computation in the systolic array (and shift all values)
        CMD_STREAM = 2'b10,

        // Do nothing
        CMD_NONE = 2'b11
    } command_t;

endpackage // TicSAT_pkg