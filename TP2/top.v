`timescale 1ns / 1ps

// top.v - Modulo principal que integra el procesador RISC-V con los perifericos UART y FIFOs.
module top #(
    parameter DATA_W      = 8,
    parameter CLK_FREQ    = 100000000,
    parameter BAUD        = 9600
) (
    input wire clk,
    input wire reset,
    input wire rx_serial,
    output wire tx_serial
);

    // --- Senales de interconexion ---

    // Generador de Baud Rate
    wire s_tick;

    // UART RX -> FIFO RX
    wire rx_done_tick;
    wire [DATA_W-1:0] rx_data_out;

    // FIFO RX -> Procesador
    wire [DATA_W-1:0] fifo_rx_data;
    wire              fifo_rx_empty;
    wire              fifo_rx_rd; // Senal de lectura desde el procesador hacia el FIFO

    // Procesador -> FIFO TX
    wire              fifo_tx_wr;   // Senal de escritura desde el procesador hacia el FIFO
    wire [DATA_W-1:0] fifo_tx_data;
    wire              fifo_tx_full;

    // --- Instanciacion de Perifericos ---

    // 1. Generador de Baud Rate para los modulos UART
    baud_rate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) baud_gen_i (
        .clk(clk),
        .reset(reset),
        .tick(s_tick)
    );

    // 2. Receptor UART
    uart_rx #(
        .DBIT(DATA_W)
    ) uart_rx_i (
        .clk(clk),
        .reset(reset),
        .rx(rx_serial),
        .sample_tick(s_tick),
        .rx_done_tick(rx_done_tick),
        .dout(rx_data_out)
    );

    // 3. FIFO para el receptor (buffer de entrada para el procesador)
    // Usamos el FIFO robusto con punteros. Profundidad de 16 palabras.
    fifo #(
        .W(DATA_W),
        .N(16)
    ) fifo_rx_i (
        .clk(clk),
        .reset(reset),
        .wr(rx_done_tick),     // Escribe cuando el UART RX termina de recibir un byte
        .rd(fifo_rx_rd),       // El procesador controla cuando lee
        .w_data(rx_data_out),
        .r_data(fifo_rx_data), // El dato leido va al procesador
        .full(),               // No necesitamos la senal 'full' del FIFO RX
        .empty(fifo_rx_empty)  // El procesador necesita saber si esta vacio
    );

    // 5. FIFO para el transmisor (buffer de salida para el procesador)
    fifo #(
        .W(DATA_W),
        .N(16)
    ) fifo_tx_i (
        .clk(clk),
        .reset(reset),
        .wr(fifo_tx_wr),       // El procesador controla cuando escribe
        .rd(tx_wr_enable),     // El UART TX controla cuando lee
        .w_data(fifo_tx_data), // El dato a escribir viene del procesador
        .r_data(tx_data_out),
        .full(fifo_tx_full),   // El procesador necesita saber si esta lleno
        .empty(fifo_tx_empty)
    );

    // El UART TX solo debe intentar leer del FIFO si este no esta vacio
    wire tx_wr_enable = !fifo_tx_empty;

    // 6. Transmisor UART
    uart_tx #(
        .DBIT(DATA_W)
    ) uart_tx_i (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_wr_enable), // Inicia transmision si hay algo que enviar
        .sample_tick(s_tick),
        .din(tx_data_out),       // Dato leido del FIFO TX
        .tx_done_tick(),
        .tx(tx_serial)
    );

    // --- Instanciacion del Nucleo de Procesamiento ---

    // 4. Procesador RISC-V Pipelined
    procesador_top #(
        .DATA_W(DATA_W)
        // NB_OP se infiere del default
    ) procesador_i (
        .clk(clk),
        .reset(reset),

        // Conexiones al FIFO RX
        .rx_data(fifo_rx_data),
        .rx_empty(fifo_rx_empty),
        .rx_rd(fifo_rx_rd),

        // Conexiones al FIFO TX
        .tx_full(fifo_tx_full),
        .tx_wr(fifo_tx_wr),
        .tx_data(fifo_tx_data)
    );

endmodule
