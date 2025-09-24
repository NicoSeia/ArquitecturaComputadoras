
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
    alu #(
        .NB_DATA(NB_DATA)
    ) alu_inst (
        .i_data(i_data),
        .i_enable_1(i_enable_1),
        .i_enable_2(i_enable_2),
        .i_enable_3(i_enable_3),
        .i_clk(i_clk),
        .i_reset(i_reset),
        .o_data(o_led_data),
        .o_carry(o_led_carry),
        .o_zero(o_led_zero)
    );

endmodule