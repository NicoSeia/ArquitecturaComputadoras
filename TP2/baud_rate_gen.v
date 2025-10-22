module baud_rate_gen #(
    parameter CLK_FREQ = 100000000,  // 100 MHz
    parameter BAUD = 9600
)(
    input wire clk,
    input wire reset,
    output reg tick
);

    localparam integer N = CLK_FREQ / (BAUD * 16);
    reg [$clog2(DIVISOR)-1:0] count_reg;                            // Modular.

    always @(posedge clk) begin
        if (reset) begin
            count <= 0;
            tick <= 0;
        end else begin
            if (count == N-1) begin
                count <= 0;
                tick <= 1;   // genera pulso de 1 ciclo
            end else begin
                count <= count + 1;
                tick <= 0;
            end
        end
    end

endmodule