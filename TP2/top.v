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

    // ================================
    // Señales internas
    // ================================
    
    // Baud rate generator
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
    
    // Señales ALU
    wire [NB_DATA-3:0]  alu_op;
    wire [NB_DATA-1:0]  alu_a;
    wire [NB_DATA-1:0]  alu_b;
    wire [NB_DATA-1:0]  alu_result;
    wire                alu_carry;
    wire                alu_zero;
    
    // ================================
    // Instancias de módulos
    // ================================
    
    // Generador de baud rate
    baud_rate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD_RATE)
    ) baud_gen_inst (
        .clk(clk),
        .reset(reset),
        .tick(s_tick)
    );
    
    // Receptor UART
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
    
    // FIFO de recepción
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
    
    // Controlador de interface (FSM)
    interface #(
        .NB_DATA(NB_DATA)
    ) interface_inst (
        .clk(clk),
        .reset(reset),
        // Conexión FIFO RX
        .rx_empty(fifo_empty),
        .rx_data(fifo_r_data),
        .rx_rd(fifo_rd),
        // Conexión UART TX
        .tx_done_tick(tx_done_tick),
        .tx_start(tx_start),
        .tx_data(tx_data_in),
        // Conexión ALU
        .alu_op(alu_op),
        .alu_a(alu_a),
        .alu_b(alu_b),
        .alu_result(alu_result)
    );
    
    // ALU (Unidad Aritmético-Lógica)
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
    
    // Transmisor UART
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