module interface #(
    parameter NB_DATA = 8,
    parameter START_FSM = 8'hFF
) (
    input wire clk, reset,

    // UART RX
    input wire [NB_DATA-1:0] data_rx,
    input wire empty_rx,
    output reg rd

    // UART TX
    input wire tx_full,
    output reg wr_tx,
    output reg [NB_DATA-1:0] data_tx,

    // ALU
    input wire [NB_DATA-1:0] alu_result,
    input wire alu_valid,
    output reg alu_start,
    output reg [NB_DATA-3:0] alu_op,
    output reg [NB_DATA-1:0] alu_a,
    output reg [NB_DATA-1:0] alu_b
);

    // FSM States
    localparam WAIT = 6'b000001,
    localparam GET_A = 6'b000010,
    localparam GET_B = 6'b000100,
    localparam GET_OP = 6'b001000,
    localparam START = 6'b010000,
    localparam SEND = 6'b100000;

    reg [5:0] state, next_state;

    // Data registers
    reg [NB_DATA-1:0] reg_a, reg_b;
    reg [NB_DATA-3:0] reg_op;
    reg [NB_DATA-1:0] reg_result;

    // FSM Sequential Logic
    always @(posedge clk) begin
        if (reset) begin
            state <= WAIT;
            reg_a <= '0;
            reg_b <= '0;
            reg_op <= '0;
            reg_result <= '0;
        end else begin
            state <= next_state;

            // Register data when reading from UART
            // Only capture the specific data for the current state
            if (state == GET_A && rd && !empty_rx)
                reg_a <= data_rx;
            if (state == GET_B && rd && !empty_rx)
                reg_b <= data_rx;
            if (state == GET_OP && rd && !empty_rx)
                reg_op <= data_rx[NB_DATA-3:0];

            // Register ALU result
            if (alu_valid) begin
                reg_result <= alu_result;
            end
        end
    end

    // FSM Combinational Logic (Next State)
    always @(*) begin
        next_state = state;
        case (state)
            WAIT:   if (data_rx == START_FSM && !empty_rx)  next_state = GET_A;
            GET_A:  if (!empty_rx)                          next_state = GET_B;
            GET_B:  if (!empty_rx)                          next_state = GET_OP;
            GET_OP: if (!empty_rx)                          next_state = START;
            START:  if (alu_valid)                          next_state = SEND;
            SEND:   if (!tx_full)                           next_state = WAIT;
            default: next_state = WAIT;
        endcase
    end

    // FSM Combinational Logic (Outputs)
    always @(*) begin
        // Default values
        rd          = 1'b0;
        wr_tx       = 1'b0;
        data_tx     = '0;
        alu_start   = 1'b0;
        alu_op      = reg_op;
        alu_a       = reg_a;
        alu_b       = reg_b;

        case (state)
            WAIT:   rd          = !empty_rx;
            GET_A:  rd          = !empty_rx;
            GET_B:  rd          = !empty_rx;
            GET_OP: rd          = !empty_rx;
            START:  alu_start   = 1'b1;
            SEND: begin
                wr_tx   = !tx_full;
                data_tx = reg_result;
            end
        endcase
    end

endmodule