`timescale 1ns / 1ps

// instruction_memory.v - Memoria para almacenar el programa a ejecutar
module instruction_memory #(
    parameter MEM_DEPTH = 64 // 64 instrucciones de 32 bits
)(
    input  wire clk,
    input  wire wr_en,
    input  wire [31:0] addr,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);
    reg [31:0] mem [0:MEM_DEPTH-1];

    // Puerto de lectura (asincrono)
    assign data_out = mem[addr[($clog2(MEM_DEPTH)+1):2]]; // Direccionamiento por palabra

    // Puerto de escritura (sincrono)
    // Nota: simplificado para carga secuencial desde la FSM de control.
    // En un sistema real, esto seria mas complejo.
    always @(posedge clk) begin
        if (wr_en) begin
            // La FSM de carga controla que byte se escribe
            // Se asume que la direccion no cambia durante los 4 ciclos de carga
            case (addr[1:0])
                2'b00: mem[addr[($clog2(MEM_DEPTH)+1):2]][7:0]   <= data_in[7:0];
                2'b01: mem[addr[($clog2(MEM_DEPTH)+1):2]][15:8]  <= data_in[7:0];
                2'b10: mem[addr[($clog2(MEM_DEPTH)+1):2]][23:16] <= data_in[7:0];
                2'b11: mem[addr[($clog2(MEM_DEPTH)+1):2]][31:24] <= data_in[7:0];
            endcase
        end
    end

endmodule
