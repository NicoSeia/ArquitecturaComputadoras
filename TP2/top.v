`timescale 1ns / 1ps

module top #(
    parameter NB_DATA   = 8,
    parameter CLK_FREQ  = 100000000,
    parameter BAUD      = 9600,
    parameter START_FSM = 8'hFF
) (
    input  wire clk,
    input  wire reset,
    input  wire rx_serial,
    output wire tx_serial
);

    // -------------------------------
    // Señales internas
    // -------------------------------

    // Baud rate generator
    wire s_tick;

    // UART RX
    wire rx_done_tick;
    wire [NB_DATA-1:0] rx_data_out;

    // FIFO -> Interface
    wire [NB_DATA-1:0] fifo_data_out;
    wire fifo_empty;
    wire fifo_rd;
    wire fifo_full;

    // Interface -> UART TX
    wire tx_wr;
    wire [NB_DATA-1:0] tx_data_in;
    wire tx_full;

    // Interface -> ALU
    wire alu_start;
    wire [NB_DATA-3:0] alu_op;
    wire [NB_DATA-1:0] alu_a;
    wire [NB_DATA-1:0] alu_b;

    // ALU -> Interface
    wire [NB_DATA-1:0] alu_result;
    wire alu_valid;
    wire alu_carry;
    wire alu_zero;

    // -------------------------------
    // Señales derivadas
    // -------------------------------
    assign tx_full = 1'b0;  // TX nunca lleno (simplificación)

    // Validación del resultado de la ALU
    reg alu_start_d1;
    always @(posedge clk) begin
        if (reset)
            alu_start_d1 <= 1'b0;
        else
            alu_start_d1 <= alu_start;
    end
    assign alu_valid = alu_start_d1;

    // -------------------------------
    // Instancias
    // -------------------------------

    // Baud rate generator
    baud_rate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) baud_gen_inst (
        .clk(clk),
        .reset(reset),
        .tick(s_tick)
    );

    // UART Receiver
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

    // RX FIFO (multi-word buffer)
    rx_fifo #(
        .B(NB_DATA),
        .W(4)
    ) rx_fifo_inst (
        .clk(clk),
        .reset(reset),
        .wr(rx_done_tick && !fifo_full),  // protege contra overflow
        .rd(fifo_rd),
        .w_data(rx_data_out),
        .r_data(fifo_data_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    // Interface FSM
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

    // ALU
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

    // UART Transmitter
    uart_tx #(
        .NB_DATA(NB_DATA)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .tx(tx_serial),
        .s_tick(s_tick),
        .data_in(tx_data_in),
        .tx_done_tick(), // no usado
        .tx_serial(tx_serial)
    );

endmodule
