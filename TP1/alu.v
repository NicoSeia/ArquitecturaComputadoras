module alu (
    parameter NB_DATA = 8;
)
(
    // Inputs
    input [NB_DATA - 1:0]   i_data,
    input                   i_enable_1,
    input                   i_enable_2,
    input                   i_enable_3,
    input                   i_clk,
    input                   i_reset,

    // Outputs
    output [NB_DATA - 1:0]  o_data,
    output                  o_carry,
    output                  o_zero,
);

    // Local parameters
    localparam DATA_1       = [NB_DATA - 1:0];
    localparam DATA_2       = [NB_DATA - 1:0];
    localparam DATA_3       = [NB_DATA - 3:0];
    localparam ALU_RESULT   = [NB_DATA - 1:0];
    localparam ALU_OP_CARRY = [NB_DATA : 0];

    // Data assignments
    always @(*) begin
        if (i_enable_1) begin
            DATA_1 = i_data;
        end else if (i_enable_2) begin
            DATA_2 = i_data;
        end else if (i_enable_3) begin
            DATA_3 = i_data[NB_DATA - 1 : 2];
        end
    end

    // ALU operations
    always @(posedge i_clk) begin
        if (i_reset) begin
            ALU_RESULT <= 8'b0;
            DATA_1 <= 8'b0;
            DATA_2 <= 8'b0;
            DATA_3 <= 6'b0;
            o_carry <= 1'b0;
            o_zero <= 1'b0;
        end
        case (DATA_3)
            6'b100000: begin
                ALU_OP_CARRY <= DATA_1 + DATA_2;                            // ADD
                ALU_RESULT   <= ALU_OP_CARRY[NB_DATA - 1:0];
                o_carry <= ALU_OP_CARRY[NB_DATA];
            end
            6'b100010: begin
                ALU_OP_CARRY <= {1'b0, DATA_1} - {1'b0, DATA_2};            // SUB
                ALU_RESULT   <= ALU_OP_CARRY[NB_DATA - 1:0];
                o_carry      <= ~ALU_OP_CARRY[NB_DATA];
            end
            6'b100100: begin
                ALU_RESULT <= DATA_1 & DATA_2;                              // AND
                o_carry <= 1'b0;
            end
            6'b100101: begin
                ALU_RESULT <= DATA_1 | DATA_2;                              // OR
                o_carry <= 1'b0;
            end
            6'b100111: begin
                ALU_RESULT <= ~(DATA_1 | DATA_2);                           // NOR
                o_carry <= 1'b0;
            end
            6'b100110: begin
                ALU_RESULT <= DATA_1 ^ DATA_2;                              // XOR
                o_carry <= 1'b0;
            end
            6'b000010: begin
                ALU_RESULT <= DATA_1 >> DATA_2[NB_DATA - 1: NB_DATA - 2];   // SRL
                o_carry <= 1'b0;
            end
            6'b000011: begin
                ALU_RESULT <= DATA_1 >>> DATA_2[NB_DATA - 1: NB_DATA - 2];  // SRA
                o_carry <= 1'b0;
            end
            default: {o_carry, o_zero, ALU_RESULT} <= {1'b0, 1'b0, 8'b0};
        endcase
        o_zero <= (ALU_RESULT == 8'b0) ? 1'b1 : 1'b0;
    end
endmodule