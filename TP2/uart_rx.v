module uart_rx #(
    parameter NB_DATA = 8,
    parameter S_TICK = 651
) (
    input wire clk,
    input wire reset,
    input wire rx, s_tick,
    output reg rx_done_tick,
    output reg [NB_DATA-1:0] data_out
);

    reg [1:0]           state_reg, state_next;
    reg [2:0]           n_data_bits_reg, n_data_bits_next;
    reg [9:0]           s_tick_reg, s_tick_next;            // tick counter
    reg [NB_DATA-1:0]   data_reg, data_next;                // data register

    localparam [1:0]
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11;

    always @(posedge clk) begin
        if (reset) begin
            state_reg       <= IDLE;
            n_data_bits_reg <= 0;
            s_tick_reg      <= 0;
            data_reg        <= 0;
        end else begin
            state_reg       <= state_next;
            n_data_bits_reg <= n_data_bits_next;
            s_tick_reg      <= s_tick_next;
            data_reg        <= data_next;
        end
    end

    // next state logic
    always @(*) begin
        state_next       = state_reg;
        rx_done_tick     = 1'b0;
        data_next        = data_reg;
        n_data_bits_next = n_data_bits_reg;
        s_tick_next      = s_tick_reg;

        case (state_reg)
            IDLE: begin
                if (~rx) begin                     // start bit detected
                    state_next  = START;
                    s_tick_next = 0;
                end
            end

            START: begin
                if (s_tick) begin
                    if (s_tick_reg == (S_TICK-1)/2) begin
                        s_tick_next      = 0;
                        n_data_bits_next = 0;
                        state_next       = DATA;
                    end else begin
                        state_next  = IDLE;   // false start, back to idle
                    end
                end else begin
                    s_tick_next = s_tick_reg + 1;
                end
            end

            DATA: begin
                if (s_tick) begin
                    if (s_tick_reg == S_TICK-1) begin
                        s_tick_next = 0;
                        data_next   = {rx, data_reg[NB_DATA-1:1]}; // LSB first
                        if (n_data_bits_reg == NB_DATA-1) begin
                            state_next = STOP;
                        end else begin
                            n_data_bits_next = n_data_bits_reg + 1;
                        end
                    end else begin
                        s_tick_next = s_tick_reg + 1;
                    end
                end
            end

            STOP: begin
                if (s_tick) begin
                    if (s_tick_reg == S_TICK-1) begin
                        state_next   = IDLE;
                        rx_done_tick = 1'b1;
                        data_next    = data_reg;
                    end else begin
                        s_tick_next = s_tick_reg + 1;
                    end
                end
            end
        endcase
    end


endmodule