`timescale 1ns / 1ps

// procesador_top.v - Conecta la Control Unit y el Datapath
module procesador_top #(
    parameter DATA_W = 8,
    parameter NB_OP  = 6
)(
    input  wire clk, reset,

    // --- Interfaz con FIFOs UART ---
    input  wire [DATA_W-1:0] rx_data,   // Dato desde FIFO RX
    input  wire              rx_empty,  // FIFO RX esta vacio?
    output wire              rx_rd,     // Pulso de lectura para FIFO RX

    input  wire              tx_full,   // FIFO TX esta lleno?
    output wire              tx_wr,     // Pulso de escritura para FIFO TX
    output wire [DATA_W-1:0] tx_data    // Dato hacia FIFO TX
);

    // --- Senales de Control (Cerebro -> Musculos) ---
    wire            pc_write;
    wire            rf_we;
    wire [1:0]      alu_a_sel;
    wire            alu_b_sel;
    wire [NB_OP-1:0] alu_op;
    wire            mem_wr;
    wire [1:0]      wb_sel;

    // --- Senales de Estado (Musculos -> Cerebro) ---
    wire [31:0] instr_out;

    // --- Instanciacion de los modulos principales ---

    // 1. La Unidad de Control (El Cerebro)
    control_unit #(
        .DATA_W(DATA_W),
        .NB_OP(NB_OP)
    ) cu_i (
        .clk(clk), .reset(reset),
        .instr_in(instr_out),        // Recibe la instruccion actual desde el datapath

        // Senales de control generadas
        .pc_write(pc_write),
        .rf_we(rf_we),
        .alu_a_sel(alu_a_sel),
        .alu_b_sel(alu_b_sel),
        .alu_op(alu_op),
        .mem_wr(mem_wr),
        .wb_sel(wb_sel),

        // Comunicacion con UART para cargar programa
        .rx_data(rx_data),
        .rx_empty(rx_empty),
        .rx_rd(rx_rd),
        .tx_full(tx_full),
        .tx_wr(tx_wr)
    );

    // 2. El Datapath (Los Musculos)
    datapath #(
        .DATA_W(DATA_W),
        .NB_OP(NB_OP)
    ) dp_i (
        .clk(clk), .reset(reset),

        // Senales de control recibidas
        .pc_write(pc_write),
        .rf_we(rf_we),
        .alu_a_sel(alu_a_sel),
        .alu_b_sel(alu_b_sel),
        .alu_op(alu_op),
        .mem_wr(mem_wr),
        .wb_sel(wb_sel),

        // Salidas hacia el exterior
        .instr_out(instr_out),       // Instruccion actual para la Control Unit
        .tx_data(tx_data)            // Resultado final para el FIFO TX
    );

endmodule
