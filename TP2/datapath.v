`timescale 1ns / 1ps

// datapath.v - Componentes hardware del procesador (PC, memorias, registros, ALU, muxes)
module datapath #(
    parameter DATA_W = 8,
    parameter NB_OP  = 6
)(
    input  wire clk, reset,

    // --- Senales de Control ---
    input  wire            pc_write,
    input  wire            rf_we,
    input  wire [1:0]      alu_a_sel,
    input  wire            alu_b_sel,
    input  wire [NB_OP-1:0] alu_op,
    input  wire            mem_wr,
    input  wire [1:0]      wb_sel,

    // --- Salidas ---
    output wire [31:0] instr_out,     // Instruccion para la Control Unit
    output wire [DATA_W-1:0] tx_data  // Resultado para el UART TX
);

    // ======================== ETAPA IF: INSTRUCTION FETCH ========================
    reg  [31:0] pc_reg, pc_next;
    wire [31:0] instr_if;

    instruction_memory imem_i (
        .clk(clk),
        .wr_en(mem_wr), // Habilitado por la FSM de carga
        .addr(pc_reg),
        .data_in(32'b0), // La FSM de control se encarga de los datos
        .data_out(instr_if)
    );

    always @(posedge clk) begin
        if (reset) pc_reg <= 32'b0;
        else if (pc_write) pc_reg <= pc_next;
    end
    assign pc_next = pc_reg + 4; // Avanza a la siguiente instruccion

    // ======================== PIPELINE REGISTER: IF/ID =========================
    reg [31:0] if_id_instr;
    always @(posedge clk) if (reset) if_id_instr <= 32'b0; else if_id_instr <= instr_if;

    // ======================== ETAPA ID: DECODE & REG FETCH =====================
    assign instr_out = if_id_instr; // La instruccion sale a la Control Unit
    wire [4:0] rs1_addr = if_id_instr[19:15];
    wire [4:0] rs2_addr = if_id_instr[24:20];
    wire [4:0] rd_addr_id = if_id_instr[11:7];
    wire [31:0] imm_ext;

    // Extension de signo para inmediatos
    assign imm_ext = {{20{if_id_instr[31]}}, if_id_instr[31:20]};

    wire [DATA_W-1:0] rf_rdata1, rf_rdata2;
    wire [DATA_W-1:0] wb_data_wb; // Dato que viene de la etapa WB

    regfile #(
        .DATA_W(DATA_W)
    ) rf_i (
        .clk(clk),
        .raddr1(rs1_addr), .rdata1(rf_rdata1),
        .raddr2(rs2_addr), .rdata2(rf_rdata2),
        .we(rf_we_wb), // Viene de la etapa WB
        .waddr(rd_addr_wb),
        .wdata(wb_data_wb)
    );

    // ======================== PIPELINE REGISTER: ID/EX =========================
    reg [DATA_W-1:0] id_ex_rdata1, id_ex_rdata2;
    reg [31:0]       id_ex_imm;
    reg [4:0]        id_ex_rd_addr;
    // Pasa las senales de control a traves del pipeline
    reg              id_ex_rf_we;
    reg              id_ex_alu_b_sel;
    reg [NB_OP-1:0]  id_ex_alu_op;


    always @(posedge clk) begin
        if(reset) begin
            id_ex_rdata1 <= {DATA_W{1'b0}};
            id_ex_rdata2 <= {DATA_W{1'b0}};
            id_ex_imm <= 32'b0;
            id_ex_rd_addr <= 5'b0;
            id_ex_rf_we <= 1'b0;
            id_ex_alu_b_sel <= 1'b0;
            id_ex_alu_op <= {NB_OP{1'b0}};
        end else begin
            id_ex_rdata1 <= rf_rdata1;
            id_ex_rdata2 <= rf_rdata2;
            id_ex_imm <= imm_ext;
            id_ex_rd_addr <= rd_addr_id;
            // Pipelining de senales de control
            id_ex_rf_we <= rf_we;
            id_ex_alu_b_sel <= alu_b_sel;
            id_ex_alu_op <= alu_op;
        end
    end

    // ======================== ETAPA EX: EXECUTE ================================
    wire [DATA_W-1:0] alu_b_operand;
    wire [DATA_W-1:0] alu_result;

    // Mux para seleccionar el segundo operando de la ALU: registro o inmediato
    assign alu_b_operand = id_ex_alu_b_sel ? id_ex_imm[DATA_W-1:0] : id_ex_rdata2;

    // ALU (modelada de forma combinacional)
    always @* begin
        case(id_ex_alu_op)
            `ALU_ADD: alu_result = id_ex_rdata1 + alu_b_operand;
            `ALU_SUB: alu_result = id_ex_rdata1 - alu_b_operand;
            `ALU_AND: alu_result = id_ex_rdata1 & alu_b_operand;
            `ALU_OR:  alu_result = id_ex_rdata1 | alu_b_operand;
            `ALU_XOR: alu_result = id_ex_rdata1 ^ alu_b_operand;
            `ALU_SRA: alu_result = $signed(id_ex_rdata1) >>> 1;
            `ALU_SRL: alu_result = id_ex_rdata1 >> 1;
            `ALU_LUI: alu_result = id_ex_imm[DATA_W-1:0];
            default: alu_result = id_ex_rdata1 + alu_b_operand;
        endcase
    end

    // ======================== PIPELINE REGISTER: EX/WB =========================
    reg [DATA_W-1:0] ex_wb_alu_result;
    reg [4:0]        ex_wb_rd_addr;
    reg              ex_wb_rf_we;

    always @(posedge clk) begin
        if (reset) begin
            ex_wb_alu_result <= {DATA_W{1'b0}};
            ex_wb_rd_addr <= 5'b0;
            ex_wb_rf_we <= 1'b0;
        end else begin
            ex_wb_alu_result <= alu_result;
            ex_wb_rd_addr <= id_ex_rd_addr;
            ex_wb_rf_we <= id_ex_rf_we;
        end
    end

    // ======================== ETAPA WB: WRITE BACK =============================
    wire [4:0]        rd_addr_wb = ex_wb_rd_addr;
    wire              rf_we_wb = ex_wb_rf_we;
    assign wb_data_wb = ex_wb_alu_result;

    // La salida para el UART es el dato que se esta escribiendo en ese momento
    assign tx_data = wb_data_wb;

endmodule
