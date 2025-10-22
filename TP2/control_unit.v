`timescale 1ns / 1ps

// control_unit.v - FSM de carga y decodificador de control para el pipeline
module control_unit #(
    parameter DATA_W = 8,
    parameter NB_OP  = 6
)(
    input  wire clk, reset,

    // --- Comunicacion con Datapath ---
    input  wire [31:0] instr_in,      // Instruccion desde la etapa ID

    // --- Senales de Control generadas ---
    output reg  pc_write,
    output reg  rf_we,
    output reg [1:0] alu_a_sel,
    output reg  alu_b_sel,
    output reg [NB_OP-1:0] alu_op,
    output reg  mem_wr,
    output reg [1:0] wb_sel,

    // --- Comunicacion con UART ---
    input  wire [DATA_W-1:0] rx_data,
    input  wire              rx_empty,
    output reg               rx_rd,
    input  wire              tx_full,
    output reg               tx_wr
);

    // --- Decodificador de Instruccion ---
    wire [6:0] opcode = instr_in[6:0];
    wire [2:0] funct3 = instr_in[14:12];
    wire [6:0] funct7 = instr_in[31:25];

    wire is_rtype = (opcode == 7'b0110011);
    wire is_itype = (opcode == 7'b0010011);
    wire is_lui   = (opcode == 7'b0110111); // Load Upper Immediate

    // --- FSM para Carga de Programa desde UART ---
    reg [2:0] state, state_n;
    localparam S_IDLE       = 3'd0, // Espera a que el procesador este libre
               S_WAIT_PROG  = 3'd1, // Espera a que lleguen datos por UART
               S_LOAD_B0    = 3'd2, // Carga byte 0 de una instruccion
               S_LOAD_B1    = 3'd3,
               S_LOAD_B2    = 3'd4,
               S_LOAD_B3    = 3'd5,
               S_RUN        = 3'd6; // El procesador esta ejecutando

    always @(posedge clk) begin
        if (reset) state <= S_IDLE;
        else       state <= state_n;
    end

    // Logica de la FSM de carga/ejecucion
    always @* begin
        state_n = state;
        rx_rd = 1'b0;
        mem_wr = 1'b0; // Controla la escritura en la memoria de instrucciones

        case(state)
            S_IDLE:      if (!reset) state_n = S_WAIT_PROG;
            S_WAIT_PROG: if (!rx_empty) state_n = S_LOAD_B0;
            S_LOAD_B0:   begin rx_rd = 1'b1; mem_wr = 1'b1; state_n = S_LOAD_B1; end
            S_LOAD_B1:   begin rx_rd = 1'b1; mem_wr = 1'b1; state_n = S_LOAD_B2; end
            S_LOAD_B2:   begin rx_rd = 1'b1; mem_wr = 1'b1; state_n = S_LOAD_B3; end
            S_LOAD_B3:   begin rx_rd = 1'b1; mem_wr = 1'b1; state_n = S_RUN;   end // Ultimo byte, pasa a RUN
            S_RUN:       begin /* El procesador se encarga */ end
        endcase
    end

    // --- Logica de Control para el Pipeline (activa en estado S_RUN) ---
    localparam ADD = 6'b100000, SUB = 6'b100010, AND = 6'b100100,
               OR  = 6'b100101, XOR = 6'b100110, SRA = 6'b000011,
               SRL = 6'b000010, LUI = 6'b011011;

    always @* begin
        // Valores por defecto
        pc_write  = 1'b0;
        rf_we     = 1'b0;
        alu_a_sel = 2'b00; // rs1
        alu_b_sel = 1'b0;  // rs2
        alu_op    = ADD;
        wb_sel    = 2'b00; // Resultado de la ALU
        tx_wr     = 1'b0;

        if (state == S_RUN) begin
            pc_write = 1'b1; // El PC avanza en cada ciclo en modo RUN

            if (is_rtype) begin
                rf_we = 1'b1;
                case (funct3)
                    3'b000: alu_op = (funct7 == 7'b0100000) ? SUB : ADD;
                    3'b111: alu_op = AND;
                    3'b110: alu_op = OR;
                    3'b100: alu_op = XOR;
                    3'b101: alu_op = (funct7 == 7'b0100000) ? SRA : SRL;
                    default: alu_op = ADD;
                endcase
            end
            else if (is_itype) begin
                rf_we     = 1'b1;
                alu_b_sel = 1'b1; // Selecciona el inmediato como segundo operando
                case (funct3)
                    3'b000: alu_op = ADD;
                    3'b111: alu_op = AND;
                    3'b110: alu_op = OR;
                    3'b100: alu_op = XOR;
                    default: alu_op = ADD;
                endcase
            end
            else if (is_lui) begin
                rf_we     = 1'b1;
                alu_op    = LUI;
                alu_b_sel = 1'b1; // El inmediato se pasa por el operando B
            end

            // Logica simple para transmitir el resultado del registro x10 (a5)
            // En un procesador real, esto seria una instruccion de STORE o similar
            if (instr_in[11:7] == 5'd10 && rf_we && !tx_full) begin
                tx_wr = 1'b1;
            end
        end
    end
endmodule
