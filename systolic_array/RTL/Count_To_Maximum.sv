module Count_To_Maximum #(
    parameter MAX_COUNT = 8
) (
    input logic clk,
    input logic resetn,

    input logic clear,
    input logic increment_counter,

    output logic is_counter_at_max
);
    logic [$clog2(MAX_COUNT):0] count;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            count <= '0;
            is_counter_at_max  <= 1'b0;
        end else if (clear) begin
            count <= '0;
            is_counter_at_max   <= 1'b0;
        end else if (increment_counter && (count != MAX_COUNT)) begin
            count <= count + 1'b1;
            if (count == MAX_COUNT - 1) begin
                is_counter_at_max <= 1'b1;
            end
        end
    end

endmodule
