`timescale 1ns / 1ps

module interface #(
    parameter NB_DATA = 8
)(
    input  wire                  clk,
    input  wire                  reset,
    
    // Conexión con UART RX (desde FIFO)
    input  wire                  rx_empty,
    input  wire [NB_DATA-1:0]    rx_data,
    output reg                   rx_rd,
    
    // Conexión con UART TX (hacia TX)
    input  wire                  tx_done_tick,
    output reg                   tx_start,
    output reg  [NB_DATA-1:0]    tx_data,

    // Conexión con ALU
    output reg  [NB_DATA-3:0]    alu_op,
    output reg  [NB_DATA-1:0]    alu_a,
    output reg  [NB_DATA-1:0]    alu_b,
    input  wire [NB_DATA-1:0]    alu_result
);

    // ========================================
    // Estados en ONE-HOT encoding
    // ========================================
    localparam [6:0]
        IDLE      = 7'b0000001,  // bit 0
        READ_OP   = 7'b0000010,  // bit 1
        READ_A    = 7'b0000100,  // bit 2
        READ_B    = 7'b0001000,  // bit 3
        COMPUTE   = 7'b0010000,  // bit 4
        SEND      = 7'b0100000,  // bit 5
        WAIT_TX   = 7'b1000000;  // bit 6
    
    // Registros de estado (7 bits para one-hot)
    reg [6:0] state_reg, state_next;
    
    // Registros para almacenar los operandos y operación
    reg [NB_DATA-3:0] op_reg, op_next;
    reg [NB_DATA-1:0] operand_a_reg, operand_a_next;
    reg [NB_DATA-1:0] operand_b_reg, operand_b_next;
    reg [NB_DATA-1:0] result_reg, result_next;
    
    // ========================================
    // Asignación continua de salidas a ALU
    // ========================================
    always @(*) begin
        alu_op = op_reg;
        alu_a  = operand_a_reg;
        alu_b  = operand_b_reg;
    end
    
    // ========================================
    // Registro de estado (secuencial)
    // ========================================
    always @(posedge clk) begin
        if (reset) begin
            state_reg     <= IDLE;
            op_reg        <= {(NB_DATA-2){1'b0}};
            operand_a_reg <= {NB_DATA{1'b0}};
            operand_b_reg <= {NB_DATA{1'b0}};
            result_reg    <= {NB_DATA{1'b0}};
        end else begin
            state_reg     <= state_next;
            op_reg        <= op_next;
            operand_a_reg <= operand_a_next;
            operand_b_reg <= operand_b_next;
            result_reg    <= result_next;
        end
    end
    
    // ========================================
    // Lógica combinacional (next state + outputs)
    // Con one-hot, usamos case(1'b1)
    // ========================================
    always @(*) begin
        // Valores por defecto
        state_next     = state_reg;
        op_next        = op_reg;
        operand_a_next = operand_a_reg;
        operand_b_next = operand_b_reg;
        result_next    = result_reg;
        rx_rd          = 1'b0;
        tx_start       = 1'b0;
        tx_data        = result_reg;
        
        // ========================================
        // FSM con one-hot: case(1'b1) busca el bit activo
        // ========================================
        case (1'b1)
            // =====================================
            // IDLE: Esperar datos en FIFO
            // =====================================
            state_reg[0]: begin  // IDLE
                if (!rx_empty) begin
                    state_next = READ_OP;
                end
            end
            
            // =====================================
            // READ_OP: Leer código de operación
            // =====================================
            state_reg[1]: begin  // READ_OP
                if (!rx_empty) begin
                    op_next    = rx_data[NB_DATA-3:0];
                    rx_rd      = 1'b1;
                    state_next = READ_A;
                end
            end
            
            // =====================================
            // READ_A: Leer operando A
            // =====================================
            state_reg[2]: begin  // READ_A
                if (!rx_empty) begin
                    operand_a_next = rx_data;
                    rx_rd          = 1'b1;
                    state_next     = READ_B;
                end
            end
            
            // =====================================
            // READ_B: Leer operando B
            // =====================================
            state_reg[3]: begin  // READ_B
                if (!rx_empty) begin
                    operand_b_next = rx_data;
                    rx_rd          = 1'b1;
                    state_next     = COMPUTE;
                end
            end
            
            // =====================================
            // COMPUTE: Calcular resultado (ALU combinacional)
            // =====================================
            state_reg[4]: begin  // COMPUTE
                result_next = alu_result;
                state_next  = SEND;
            end
            
            // =====================================
            // SEND: Iniciar transmisión
            // =====================================
            state_reg[5]: begin  // SEND
                tx_data    = result_reg;
                tx_start   = 1'b1;
                state_next = WAIT_TX;
            end
            
            // =====================================
            // WAIT_TX: Esperar fin de transmisión
            // =====================================
            state_reg[6]: begin  // WAIT_TX
                if (tx_done_tick) begin
                    state_next = IDLE;
                end
            end
            
            // =====================================
            // DEFAULT: Estado inválido, volver a IDLE
            // =====================================
            default: begin
                state_next = IDLE;
            end
        endcase
    end

endmodule