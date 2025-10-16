module rx_fifo #(
    parameter NB_DATA = 8
) (
    input wire clk,
    input wire reset,

    // UART RX side
    input wire wr,
    input wire [NB_DATA-1:0] data_in,

    // Interface side
    input wire rd,
    output wire [NB_DATA-1:0] data_out,
    output wire empty
);

    reg [NB_DATA-1:0]   buffer_reg;
    reg                 full_reg;

    assign data_out = buffer_reg;
    assign empty = ~full_reg;

    always @(posedge clk) begin
        if (reset) begin
            full_reg <= 1'b0;
            buffer_reg <= '0;
        end else if (wr) begin
            full_reg <= 1'b1;
            buffer_reg <= data_in;
        end else if (rd && full_reg) begin
            full_reg <= 1'b0;
        end
    end

endmodule