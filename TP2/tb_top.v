`timescale 1ns / 1ps

module tb_top;

    // Parámetros UART
    localparam CLK_FREQ = 100_000_000; // 100 MHz
    localparam BAUD_RATE = 9600;
    localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE; // en ns

    // Señales del top
    reg clk;
    reg reset;
    reg rx_serial;
    wire tx_serial;

    // Instancia del módulo top
    top uut (
        .clk(clk),
        .reset(reset),
        .rx_serial(rx_serial),
        .tx_serial(tx_serial)
    );

    // Generador de reloj 100 MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // Periodo 10 ns
    end

    // Proceso principal de prueba
    initial begin
        // Inicialización
        $dumpfile("sim.vcd");
        $dumpvars(0, tb_top);

        rx_serial = 1'b1; // Línea UART idle
        reset = 1;
        #200;
        reset = 0;

        // Esperar un poco después del reset
        #(10*BIT_PERIOD);

        // Enviar secuencia: Header (0xA5), DatoA (0x03), DatoB (0x02), Operación (0x01)
        uart_write_byte(8'hFF);
        uart_write_byte(8'h03);
        uart_write_byte(8'h02);
        uart_write_byte(8'h20);

        // Esperar transmisión y respuesta
        #(50*BIT_PERIOD);

        $display("Test finalizado. Revisar señales en la simulación.");
        $finish;
    end

    // Tarea para enviar un byte por UART
    task uart_write_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            rx_serial = 1'b0;
            #(BIT_PERIOD);

            // Data bits (LSB primero)
            for (i = 0; i < 8; i = i + 1) begin
                rx_serial = data[i];
                #(BIT_PERIOD);
            end

            // Stop bit
            rx_serial = 1'b1;
            #(BIT_PERIOD);
        end
    endtask

endmodule
