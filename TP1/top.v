
module top #(
    parameter NB_DATA = 8,
    parameter NB_LEDS = 8
) (
    input wire i_clk,
    input wire i_reset,
    input wire [NB_DATA - 1:0] i_data,
    input wire i_enable_1,
    input wire i_enable_2,
    input wire i_enable_3,

    output wire [NB_LEDS - 1:0] o_led_data,
    output wire o_led_carry,
    output wire o_led_zero
);

    reg [NB_DATA - 1:0] data_1;
    reg [NB_DATA - 1:0] data_2;
    reg [NB_DATA - 3:0] data_3;

        // Data assignments
    always @(posedge i_clk) begin
        if (i_reset) begin
            data_1 <= {NB_DATA{1'b0}};
            data_2 <= {NB_DATA{1'b0}};
            data_3 <= {(NB_DATA-2){1'b0}};
        end else begin
            if (i_enable_1) begin
                data_1 <= i_data;
            end else if (i_enable_2) begin
                data_2 <= i_data;
            end else if (i_enable_3) begin
                data_3 <= i_data[NB_DATA - 1 : 2];
            end
        end
    end

    // ALU instance
    alu #(
        .NB_DATA(NB_DATA)
    ) alu_inst (
        .data_1(data_1),
        .data_2(data_2),
        .data_3(data_3),
        .o_data(o_led_data),
        .o_carry(o_led_carry),
        .o_zero(o_led_zero)
    );

endmodule