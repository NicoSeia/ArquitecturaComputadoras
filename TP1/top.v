`include "alu.v"

module top #(
    parameter NB_DATA = 8,
    parameter NB_LEDS = 8
) (
    input i_clk,
    input i_reset,
    input [NB_DATA - 1:0] i_data,
    input i_enable_1,
    input i_enable_2,
    input i_enable_3,
    output [NB_DATA - 1:0] o_data,
    output o_carry,
    output o_zero
    output [NB_LEDS - 1:0] o_led_data,
    output o_led_carry,
    output o_led_zero
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
        .o_data(o_data),
        .o_carry(o_carry),
        .o_zero(o_zero)
    );

    assign o_led_data = o_data;
    assign o_led_carry = o_carry;
    assign o_led_zero = o_zero;
endmodule