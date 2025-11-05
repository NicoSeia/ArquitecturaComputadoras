`timescale 1ns / 1ps

module top #(
    parameter NB_DATA   = 8,
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 9600,
    parameter FIFO_W    = 8
)(
    input  wire clk,
    input  wire reset,
    input  wire rx_serial,
    output wire tx_serial
);

    // Señales internas
    wire s_tick;
    
    // Señales UART RX
    wire                rx_done_tick;
    wire [NB_DATA-1:0]  rx_data_out;
    
    // Señales FIFO
    wire                fifo_empty;
    wire                fifo_full;
    wire [NB_DATA-1:0]  fifo_r_data;
    wire                fifo_rd;
    
    // Señales UART TX
    wire                tx_start;
    wire [NB_DATA-1:0]  tx_data_in;
    wire                tx_done_tick;
    
    // Instancia del generador de baud rate
    baud_rate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD_RATE)
    ) baud_gen_inst (
        .clk(clk),
        .reset(reset),
        .tick(s_tick)
    );
    
    // Instancia del receptor UART
    uart_rx #(
        .NB_DATA(NB_DATA),
        .S_TICK(16)
    ) uart_rx_inst (
        .clk(clk),
        .reset(reset),
        .rx(rx_serial),
        .s_tick(s_tick),
        .rx_done_tick(rx_done_tick),
        .data_out(rx_data_out)
    );
    
    // Instancia del FIFO para recepción
    rx_fifo #(
        .B(NB_DATA),
        .W(FIFO_W)
    ) rx_fifo_inst (
        .clk(clk),
        .reset(reset),
        .rd(fifo_rd),
        .wr(rx_done_tick),
        .w_data(rx_data_out),
        .empty(fifo_empty),
        .full(fifo_full),
        .r_data(fifo_r_data)
    );
    
    // Instancia de la interface (controlador)
    interface #(
        .NB_DATA(NB_DATA)
    ) interface_inst (
        .clk(clk),
        .reset(reset),
        .rx_empty(fifo_empty),
        .rx_data(fifo_r_data),
        .rx_rd(fifo_rd),
        .tx_done_tick(tx_done_tick),
        .tx_start(tx_start),
        .tx_data(tx_data_in)
    );
    
    // Instancia del transmisor UART
    uart_tx #(
        .NB_DATA(NB_DATA),
        .S_TICK(16)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .tx(tx_start),
        .s_tick(s_tick),
        .data_in(tx_data_in),
        .tx_done_tick(tx_done_tick),
        .tx_serial(tx_serial)
    );

endmodule