module top #(
    parameter NB_DATA   = 8,
    parameter CLK_FREQ  = 100000000,
    parameter BAUD      = 9600,
    parameter START_FSM = 8'hFF
) (
    input wire clk,
    input wire reset,
    input wire rx_serial,
    output wire tx_serial
);

    // Baud rate generator tick
    wire s_tick;

    // UART RX -> FIFO connections
    wire rx_done_tick;
    wire [NB_DATA-1:0] rx_data_out;

    // FIFO -> Interface connections
    wire [NB_DATA-1:0] fifo_data_out;
    wire fifo_empty;
    wire fifo_rd;

    // Interface -> UART TX connections
    wire tx_wr;
    wire [NB_DATA-1:0] tx_data_in;
    wire tx_full; // Assumed to be always not full for this simple case

    // Interface -> ALU connections
    wire alu_start;
    wire [NB_DATA-3:0] alu_op;
    wire [NB_DATA-1:0] alu_a;
    wire [NB_DATA-1:0] alu_b;

    // ALU -> Interface connections
    wire [NB_DATA-1:0] alu_result;
    wire alu_valid;
    wire alu_carry; // Not used by interface, but ALU provides it
    wire alu_zero;  // Not used by interface, but ALU provides it

    // For simplicity, we assume the TX buffer is never full.
    // In a real system, you might get this from the uart_tx module.
    assign tx_full = 1'b0;

    // The ALU result is valid one cycle after alu_start is asserted.
    // We create a registered version of alu_start to signal validity.
    reg alu_start_d1;
    always @(posedge clk) begin
        if (reset)
            alu_start_d1 <= 1'b0;
        else
            alu_start_d1 <= alu_start;
    end
    assign alu_valid = alu_start_d1;

    // Instantiate Baud Rate Generator
    baud_rate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) baud_gen_inst (
        .clk(clk),
        .reset(reset),
        .tick(s_tick)
    );

    // Instantiate UART Receiver
    uart_rx #(
        .NB_DATA(NB_DATA)
    ) uart_rx_inst (
        .clk(clk),
        .reset(reset),
        .rx(rx_serial),
        .s_tick(s_tick),
        .rx_done_tick(rx_done_tick),
        .data_out(rx_data_out)
    );

    // Instantiate RX FIFO (single-element buffer)
    rx_fifo #(
        .NB_DATA(NB_DATA)
    ) rx_fifo_inst (
        .clk(clk),
        .reset(reset),
        .wr(rx_done_tick),
        .data_in(rx_data_out),
        .rd(fifo_rd),
        .data_out(fifo_data_out),
        .empty(fifo_empty)
    );

    // Instantiate Interface FSM
    interface #(
        .NB_DATA(NB_DATA),
        .START_FSM(START_FSM)
    ) interface_inst (
        .clk(clk),
        .reset(reset),
        .data_rx(fifo_data_out),
        .empty_rx(fifo_empty),
        .rd(fifo_rd),
        .tx_full(tx_full),
        .wr_tx(tx_wr),
        .data_tx(tx_data_in),
        .alu_result(alu_result),
        .alu_valid(alu_valid),
        .alu_start(alu_start),
        .alu_op(alu_op),
        .alu_a(alu_a),
        .alu_b(alu_b)
    );

    // Instantiate ALU
    alu #(
        .NB_DATA(NB_DATA)
    ) alu_inst (
        .data_1(alu_a),
        .data_2(alu_b),
        .data_3(alu_op),
        .o_data(alu_result),
        .o_carry(alu_carry),
        .o_zero(alu_zero)
    );

    // Instantiate UART Transmitter
    uart_tx #(
        .NB_DATA(NB_DATA)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .tx(tx_wr),
        .s_tick(s_tick),
        .data_in(tx_data_in),
        .tx_done_tick(), // Not used
        .tx_serial(tx_serial)
    );

endmodule