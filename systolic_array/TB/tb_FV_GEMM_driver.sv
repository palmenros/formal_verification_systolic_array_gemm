module tb_FV_GEMM_driver;
    // Parameters
    localparam SA_SIZE = 4;
    localparam INPUT_SIZE = 5;
    localparam WEIGHT_ACTIVATION_SIZE = 8;

    localparam clk_period = 10;


    // Clock
    logic clk;

    always begin
        clk = 0;
        #(clk_period/2);
        clk = 1;
        #(clk_period/2);
    end

    // Reset signal
    logic resetn;

    // Instantiate the FV_GEMM module
    FV_GEMM #(
        .SA_SIZE(SA_SIZE),
        .INPUT_SIZE(INPUT_SIZE),
        .WEIGHT_ACTIVATION_SIZE(WEIGHT_ACTIVATION_SIZE)
    ) u_FV_GEMM (
        .resetn(resetn),
        .clk(clk)
    );

    logic mismatch;

    initial begin
        // Initialize data with random values
        for (int i = 0; i < SA_SIZE; i++) begin
            for (int j = 0; j < SA_SIZE; j++) begin
                u_FV_GEMM.weights[i][j] = $urandom_range(0, (1 << WEIGHT_ACTIVATION_SIZE) - 1);
            end
        end

        for (int i = 0; i < INPUT_SIZE; i++) begin
            for (int j = 0; j < SA_SIZE; j++) begin
                u_FV_GEMM.inputs[i][j] = $urandom_range(0, (1 << WEIGHT_ACTIVATION_SIZE) - 1);
            end
        end

        // Assert and de-assert reset
        resetn = 0;
        #(2*clk_period);
        resetn = 1;

        // Wait for completion
        wait(u_FV_GEMM.state == u_FV_GEMM.S_DONE);

        // Display results
        $display("Simulation completed!");
        $display("Weights Matrix:");
        for (int i = 0; i < SA_SIZE; i++) begin
            for (int j = 0; j < SA_SIZE; j++) begin
                $write("%4d ", u_FV_GEMM.weights[i][j]);
            end
            $display("");
        end

        $display("\nInput Matrix:");
        for (int i = 0; i < INPUT_SIZE; i++) begin
            for (int j = 0; j < SA_SIZE; j++) begin
                $write("%4d ", u_FV_GEMM.inputs[i][j]);
            end
            $display("");
        end

        $display("\nReference Output Matrix:");
        for (int i = 0; i < INPUT_SIZE; i++) begin
            for (int j = 0; j < SA_SIZE; j++) begin
                $write("%4d ", u_FV_GEMM.reference_outputs[i][j]);
            end
            $display("");
        end

        $display("\nActual Output Matrix:");
        for (int i = 0; i < INPUT_SIZE; i++) begin
            for (int j = 0; j < SA_SIZE; j++) begin
                $write("%4d ", u_FV_GEMM.actual_sa_outputs[i][j]);
            end
            $display("");
        end

        mismatch = 0;

        // Check if outputs match
        for (int i = 0; i < INPUT_SIZE; i++) begin
            for (int j = 0; j < SA_SIZE; j++) begin
                if (u_FV_GEMM.reference_outputs[i][j] != u_FV_GEMM.actual_sa_outputs[i][j]) begin
                    $display("ERROR: Mismatch at [%0d][%0d]: Reference=%0d, Actual=%0d", 
                        i, j, 
                        u_FV_GEMM.reference_outputs[i][j], 
                        u_FV_GEMM.actual_sa_outputs[i][j]);
                    mismatch = 1;
                end
            end
        end

        if (!mismatch) begin
            $display("SUCCESS: All outputs match reference model!");
        end

        $finish;
    end
        
endmodule
