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
    output reg  [NB_DATA-1:0]    tx_data
);

    // Estados de la máquina
    localparam [2:0]
        IDLE      = 3'b000,
        READ_OP   = 3'b001,
        READ_A    = 3'b010,
        READ_B    = 3'b011,
        COMPUTE   = 3'b100,
        SEND      = 3'b101,
        WAIT_TX   = 3'b110;
    
    // Registros de estado
    reg [2:0] state_reg, state_next;
    
    // Registros para almacenar los operandos y operación
    reg [NB_DATA-3:0] op_reg, op_next;
    reg [NB_DATA-1:0] operand_a_reg, operand_a_next;
    reg [NB_DATA-1:0] operand_b_reg, operand_b_next;
    reg [NB_DATA-1:0] result_reg, result_next;
    
    // Señales de la ALU
    wire [NB_DATA-1:0] alu_result;
    wire               alu_carry;
    wire               alu_zero;
    
    // Instancia de la ALU
    alu #(
        .NB_DATA(NB_DATA)
    ) alu_inst (
        .data_1(operand_a_reg),
        .data_2(operand_b_reg),
        .data_3(op_reg),
        .o_data(alu_result),
        .o_carry(alu_carry),
        .o_zero(alu_zero)
    );
    
    // Registro de estado
    always @(posedge clk) begin
        if (reset) begin
            state_reg     <= IDLE;
            op_reg        <= 0;
            operand_a_reg <= 0;
            operand_b_reg <= 0;
            result_reg    <= 0;
        end else begin
            state_reg     <= state_next;
            op_reg        <= op_next;
            operand_a_reg <= operand_a_next;
            operand_b_reg <= operand_b_next;
            result_reg    <= result_next;
        end
    end
    
    // Lógica combinacional
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
        
        case (state_reg)
            IDLE: begin
                if (!rx_empty) begin
                    state_next = READ_OP;
                end
            end
            
            READ_OP: begin
                if (!rx_empty) begin
                    op_next    = rx_data[NB_DATA-3:0];
                    rx_rd      = 1'b1;
                    state_next = READ_A;
                end
            end
            
            READ_A: begin
                if (!rx_empty) begin
                    operand_a_next = rx_data;
                    rx_rd          = 1'b1;
                    state_next     = READ_B;
                end
            end
            
            READ_B: begin
                if (!rx_empty) begin
                    operand_b_next = rx_data;
                    rx_rd          = 1'b1;
                    state_next     = COMPUTE;
                end
            end
            
            COMPUTE: begin
                result_next = alu_result;
                state_next  = SEND;
            end
            
            SEND: begin
                tx_data    = result_reg;
                tx_start   = 1'b1;
                state_next = WAIT_TX;
            end
            
            WAIT_TX: begin
                if (tx_done_tick) begin
                    state_next = IDLE;
                end
            end
            
            default: begin
                state_next = IDLE;
            end
        endcase
    end

endmodule