`timescale 1ns / 1ps

module tb_alu_resta_complemento2();
    // Parámetros
    parameter NB_DATA = 8;
    parameter NB_LEDS = 8;
    parameter CLK_PERIOD = 10;
    
    // Señales
    reg i_clk;
    reg i_reset;
    reg [NB_DATA-1:0] i_data;
    reg i_enable_1;
    reg i_enable_2;
    reg i_enable_3;
    
    wire [NB_LEDS-1:0] o_led_data;
    wire o_led_carry;
    wire o_led_zero;
    
    // Instancia del módulo
    top #(
        .NB_DATA(NB_DATA),
        .NB_LEDS(NB_LEDS)
    ) dut (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_data(i_data),
        .i_enable_1(i_enable_1),
        .i_enable_2(i_enable_2),
        .i_enable_3(i_enable_3),
        .o_led_data(o_led_data),
        .o_led_carry(o_led_carry),
        .o_led_zero(o_led_zero)
    );
    
    // Generar reloj
    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD/2) i_clk = ~i_clk;
    end
    
    // Tarea para cargar operación
    task load_operation(input [7:0] data1, input [7:0] data2, input [5:0] operation);
        begin
            @(posedge i_clk);
            i_enable_1 = 1; i_enable_2 = 0; i_enable_3 = 0;
            i_data = data1;
            @(posedge i_clk);
            i_enable_1 = 0;
            
            @(posedge i_clk);
            i_enable_2 = 1;
            i_data = data2;
            @(posedge i_clk);
            i_enable_2 = 0;
            
            @(posedge i_clk);
            i_enable_3 = 1;
            i_data = {operation, 2'b00};
            @(posedge i_clk);
            i_enable_3 = 0;
            
            @(posedge i_clk);
            @(posedge i_clk);
        end
    endtask
    
    // Tarea para debug completo de resta con complemento a 2
    task debug_resta_c2(input [7:0] data1, input [7:0] data2, input [47:0] test_name);
        reg [8:0] complemento_data2;
        reg [8:0] suma_manual;
        begin
            $display("=== DEBUG: %s ===", test_name);
            $display("Operación: %d - %d", data1, data2);
            
            // Calcular manualmente el complemento a 2
            complemento_data2 = (~{1'b0, data2}) + 1'b1;
            suma_manual = {1'b0, data1} + complemento_data2;
            
            $display("Cálculo manual paso a paso:");
            $display("  data_1 extendido: 9'b%b (%d)", {1'b0, data1}, {1'b0, data1});
            $display("  data_2 extendido: 9'b%b (%d)", {1'b0, data2}, {1'b0, data2});
            $display("  ~data_2_ext: 9'b%b (%d)", ~{1'b0, data2}, ~{1'b0, data2});
            $display("  ~data_2_ext + 1: 9'b%b (%d)", complemento_data2, complemento_data2);
            $display("  Suma final: %d + %d = %d", {1'b0, data1}, complemento_data2, suma_manual);
            $display("  Resultado manual: 9'b%b", suma_manual);
            $display("    - Carry bit [8]: %b", suma_manual[8]);
            $display("    - Resultado [7:0]: %d", suma_manual[7:0]);
            
            // Realizar operación en el ALU
            load_operation(data1, data2, 6'b100010);
            
            // Mostrar resultados del ALU
            $display("Resultados del ALU:");
            $display("  data_1: %d", dut.alu_inst.data_1);
            $display("  data_2: %d", dut.alu_inst.data_2);
            $display("  alu_op_carry: 9'b%b (%d)", dut.alu_inst.alu_op_carry, dut.alu_inst.alu_op_carry);
            $display("  alu_op_carry[8]: %b", dut.alu_inst.alu_op_carry[8]);
            $display("  alu_op_carry[7:0]: %d", dut.alu_inst.alu_op_carry[7:0]);
            
            // Salidas finales
            $display("Salidas finales:");
            $display("  o_data: %d", o_led_data);
            $display("  o_carry: %b (directo de alu_op_carry[8])", o_led_carry);
            $display("  o_zero: %b", o_led_zero);
            
            // Verificación
            $display("Verificación:");
            if (suma_manual == dut.alu_inst.alu_op_carry) begin
                $display("  ✓ Cálculo manual coincide con ALU");
            end else begin
                $display("  ✗ ERROR: Cálculo manual ≠ ALU");
            end
            
            // Interpretación del resultado
            if (data1 >= data2) begin
                $display("  Interpretación: %d >= %d → resultado positivo", data1, data2);
            end else begin
                $display("  Interpretación: %d < %d → resultado negativo (complemento a 2)", data1, data2);
                $display("  Valor en complemento a 2: %d", $signed(o_led_data));
            end
            
            // Análisis del carry
            $display("Análisis del carry:");
            if (o_led_carry) begin
                $display("  o_carry = 1 → Hubo carry en la suma A + (~B + 1)");
                if (data1 >= data2) begin
                    $display("  → Resta sin underflow (resultado válido)");
                end else begin
                    $display("  → Resta con underflow, pero carry=1 por la aritmética del complemento a 2");
                end
            end else begin
                $display("  o_carry = 0 → No hubo carry en la suma A + (~B + 1)");
                if (data1 < data2) begin
                    $display("  → Indica underflow en resta tradicional");
                end
            end
            
            $display("------------------------------------------------");
        end
    endtask
    
    // Test principal
    initial begin
        $display("=== TEST RESTA CON COMPLEMENTO A 2 EXPLÍCITO ===");
        $display("Nueva implementación: A + (~B + 1) SIN negar carry\n");
        
        // Reset
        i_reset = 1;
        i_enable_1 = 0; i_enable_2 = 0; i_enable_3 = 0; i_data = 0;
        #30; i_reset = 0; #20;
        
        // Test 1: Resta sin underflow
        debug_resta_c2(8'd50, 8'd20, "50 - 20 = 30");
        
        // Test 2: Resta con underflow
        debug_resta_c2(8'd10, 8'd20, "10 - 20 = -10");
        
        // Test 3: Caso límite - restar 1 de 0
        debug_resta_c2(8'd0, 8'd1, "0 - 1 = -1");
        
        // Test 4: Resta que da cero
        debug_resta_c2(8'd25, 8'd25, "25 - 25 = 0");
        
        // Test 5: Restar número grande
        debug_resta_c2(8'd100, 8'd150, "100 - 150 = -50");
        
        // Test 6: Caso máximo
        debug_resta_c2(8'd255, 8'd1, "255 - 1 = 254");
        
        $display("=== FIN TEST RESTA COMPLEMENTO A 2 ===");
        #100;
        $finish;
    end

endmodule