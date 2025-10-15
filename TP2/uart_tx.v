module uart_tx #(
    parameter NB_DATA = 8,
    parameter S_TICK = 651
) (
    input wire clk, reset,
    input wire tx,                     // arranque de transmisión
    input wire s_tick,                 // tick
    input wire [NB_DATA-1:0] data_in,  // dato paralelo a enviar
    output reg tx_done_tick,           // pulso cuando termina
    output wire tx_serial              // línea serial (idle=1)
);
    reg [1:0]           state_reg, state_next;
    reg [2:0]           n_data_bits_reg, n_data_bits_next;
    reg [9:0]           s_tick_reg, s_tick_next;            // tick counter
    reg [NB_DATA-1:0]   data_reg, data_next;                // data register
    reg tx_reg, tx_next;        // línea tx filtrada (salida registrada)

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
            tx_reg          <= 1'b1;
        end else begin
            state_reg       <= state_next;
            n_data_bits_reg <= n_data_bits_next;
            s_tick_reg      <= s_tick_next;
            data_reg        <= data_next;
            tx_reg          <= tx_next;
        end
    end

    always @(*) begin
        state_next       = state_reg;
        tx_done_tick     = 1'b0;
        data_next        = data_reg;
        n_data_bits_next = n_data_bits_reg;
        s_tick_next      = s_tick_reg;
        tx_next          = tx_reg;

        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;
                if (tx) begin                     // start bit detected
                    state_next  = START;
                    s_tick_next = 0;
                    data_next   = data_in;
                end
            end

            START: begin
                tx_next = 1'b0;
                if (s_tick) begin
                    if (s_tick_reg == (S_TICK-1) begin
                        s_tick_next      = 0;
                        n_data_bits_next = 0;
                        state_next       = DATA;
                    end
                end else begin
                    s_tick_next = s_tick_reg + 1;
                end
            end

            DATA: begin
                tx_next = data_reg[0];
                if (s_tick) begin
                    if (s_tick_reg == S_TICK-1) begin
                        s_tick_next = 0;
                        data_next = data_reg >> 1; // Shift Right next LSB
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
                tx_next = 1'b1;
                if (s_tick) begin
                    if (s_tick_reg == S_TICK-1) begin
                        state_next   = IDLE;
                        tx_done_tick = 1'b1;
                    end else begin
                        s_tick_next = s_tick_reg + 1;
                    end
                end
            end
        endcase
    end
    assign tx_serial = tx_reg;
endmodule