`timescale 1ns / 1ps

module alu #(
    parameter NB_DATA = 8
)
(
    // Inputs
    input wire [NB_DATA - 1:0]   data_1,
    input wire [NB_DATA - 1:0]   data_2,
    input wire [NB_DATA - 3:0]   data_3,

    // Outputs
    output reg [NB_DATA - 1:0]  o_data,
    output reg                  o_carry,
    output reg                  o_zero
);

    reg [NB_DATA - 1:0] alu_result;
    reg [NB_DATA : 0]   alu_op_carry;

    // ALU operations
    always @(*) begin
        alu_result   = {NB_DATA{1'b0}};
        alu_op_carry = {(NB_DATA+1){1'b0}};
        o_carry      = 1'b0;
        o_zero       = 1'b0;
        case (data_3)
            6'b100000: begin
                alu_op_carry = data_1 + data_2;                            // ADD
                alu_result   = alu_op_carry[NB_DATA - 1:0];
                o_carry      = alu_op_carry[NB_DATA];
            end
            6'b100010: begin
                alu_op_carry = {1'b0, data_1} - {1'b0, data_2};            // SUB
                alu_result   = alu_op_carry[NB_DATA - 1:0];
                o_carry      = alu_op_carry[NB_DATA];
            end
            6'b100100: begin
                alu_result = data_1 & data_2;                              // AND
                o_carry = 1'b0;
            end
            6'b100101: begin
                alu_result = data_1 | data_2;                              // OR
                o_carry = 1'b0;
            end
            6'b100111: begin
                alu_result = ~(data_1 | data_2);                           // NOR
                o_carry = 1'b0;
            end
            6'b100110: begin
                alu_result = data_1 ^ data_2;                              // XOR
                o_carry = 1'b0;
            end
            6'b000010: begin
                alu_result = data_1 >> data_2[NB_DATA - 1: NB_DATA - 2];   // SRL
                o_carry = 1'b0;
            end
            6'b000011: begin
                alu_result = $signed(data_1) >>> data_2[NB_DATA - 1: NB_DATA - 2];  // SRA
                o_carry = 1'b0;
            end
            default: {o_carry, o_zero, alu_result} = {1'b0, 1'b0, 8'b0};
        endcase
        o_data = alu_result;
        o_zero = (alu_result == 8'b0) ? 1'b1 : 1'b0;
    end
endmodule