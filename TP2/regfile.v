`timescale 1ns / 1ps

// regfile.v - 32 registros de 8 bits (x0 = 0)
module regfile #(
    parameter DATA_W = 8,
    parameter NREGS  = 32
)(
    input  wire                clk,
    // Puertos de lectura
    input  wire [4:0]          raddr1,
    input  wire [4:0]          raddr2,
    output wire [DATA_W-1:0]  rdata1,
    output wire [DATA_W-1:0]  rdata2,
    // Puerto de escritura
    input  wire                we,
    input  wire [4:0]          waddr,
    input  wire [DATA_W-1:0]  wdata
);
    reg [DATA_W-1:0] regs [0:NREGS-1];

    // Escritura en el banco de registros (ignora escrituras a x0)
    always @(posedge clk) begin
        if (we && (waddr != 5'd0))
            regs[waddr] <= wdata;
    end

    // Lectura del banco de registros (combinacional)
    // El registro x0 siempre devuelve 0
    assign rdata1 = (raddr1 == 5'd0) ? {DATA_W{1'b0}} : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? {DATA_W{1'b0}} : regs[raddr2];

endmodule
