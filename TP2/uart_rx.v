module uart_rx #(
    parameter NB_DATA = 8,
    parameter S_TICK = 16
) (
    input wire clk,
    input wire reset,
    input wire rx, s_tick,
    output reg rx_done_tick,
    output wire [NB_DATA-1:0] data_out
);

    reg [1:0]           state_reg, state_next;
    reg [2:0]           n_data_bits_reg, n_data_bits_next;
    reg [3:0]           s_tick_reg, s_tick_next;                                // Contador de registros.
    reg [NB_DATA-1:0]   data_reg, data_next;                                    // Registro del dato

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
            state_reg       <= state_next;                                      // Se carga el siguiente
            n_data_bits_reg <= n_data_bits_next;                                // Se carga el indice de datos que vamos.
            s_tick_reg      <= s_tick_next;                                     // Se carga el tick actual.
            data_reg        <= data_next;                                       // Se carga el dato actual.
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
                if (~rx) begin                                                  // Start bit detectado. De 1 a 0.
                    state_next  = START;
                    s_tick_next = 0;
                end
            end

            START: begin
                if (s_tick) begin
                    if (s_tick_reg == (S_TICK-2)/2) begin                       // El tick 7 es el tick que determina el medio del cero.
                        s_tick_next      = 0;                                   // Reseteamos a cero para ir viendo los medios.
                        n_data_bits_next = 0;                                   // Comineza el primer dato.
                        state_next       = DATA;                                // Cambio de estado.
                end else begin
                    s_tick_next = s_tick_reg + 1;                               // Vamos registrando internamente el tick
                end
            end

            DATA: begin
                if (s_tick) begin
                    if (s_tick_reg == S_TICK-1) begin
                        s_tick_next = 0;                                        // Si llegamos a los 15 s_ticks, significa que llegamos al medio del bit.
                        data_next   = {rx, data_reg[NB_DATA-1:1]};              // Se pone el bit rx a la izq y se van desplazando todos a la derecha.
                        if (n_data_bits_reg == NB_DATA-1) begin                 // Si terminaron de cargarse los bits, pasa a STOP.
                            state_next = STOP;                                  // Si tenemos los 8 bits. Entramos al estado de STOP.
                        end else begin
                            n_data_bits_next = n_data_bits_reg + 1;             // Contamos cuantos bits se van cargando
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
                    end else begin
                        s_tick_next = s_tick_reg + 1;
                    end
                end
            end
        endcase
    end
    assign data_out = data_reg;                                                 // Cargamos el dato a la salida.
endmodule