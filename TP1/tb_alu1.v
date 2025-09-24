`timescale 1ns / 1ps

module tb_alu();
    // Parámetros
    parameter NB_DATA = 8;
    parameter NB_LEDS = 8;
    parameter CLK_PERIOD = 10; // 10ns = 100MHz
    
    // Señales del testbench
    reg i_clk;
    reg i_reset;
    reg [NB_DATA-1:0] i_data;
    reg i_enable_1;
    reg i_enable_2;
    reg i_enable_3;
    
    wire [NB_LEDS-1:0] o_led_data;
    wire o_led_carry;
    wire o_led_zero;
    
    // Instancia del módulo top
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
    
    // Generación del reloj
    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD/2) i_clk = ~i_clk;
    end
    
    // Proceso de reset
    task reset_system;
        begin
            i_reset = 1;
            i_enable_1 = 0;
            i_enable_2 = 0;
            i_enable_3 = 0;
            i_data = 0;
            #(CLK_PERIOD * 2);
            i_reset = 0;
            #(CLK_PERIOD);
        end
    endtask
    
    // Tarea para cargar datos en los registros
    task load_data(input [7:0] data1, input [7:0] data2, input [5:0] operation);
        begin
            // Cargar data_1
            @(posedge i_clk);
            i_enable_1 = 1;
            i_enable_2 = 0;
            i_enable_3 = 0;
            i_data = data1;
            @(posedge i_clk);
            i_enable_1 = 0;
            
            // Cargar data_2
            @(posedge i_clk);
            i_enable_1 = 0;
            i_enable_2 = 1;
            i_enable_3 = 0;
            i_data = data2;
            @(posedge i_clk);
            i_enable_2 = 0;
            
            // Cargar operación (data_3)
            @(posedge i_clk);
            i_enable_1 = 0;
            i_enable_2 = 0;
            i_enable_3 = 1;
            i_data = {operation, 2'b00}; // Los 6 bits de operación van en los MSB
            @(posedge i_clk);
            i_enable_3 = 0;
            
            // Esperar un ciclo para que se procese la operación
            @(posedge i_clk);
        end
    endtask
    
    // Tarea para mostrar resultados
    task display_result(input [7:0] expected_result, input expected_carry, input expected_zero, input [47:0] operation_name);
        begin
            $display("=== %s ===", operation_name);
            $display("Resultado: %d (0x%02h) - Esperado: %d (0x%02h) - %s", 
                     o_led_data, o_led_data, expected_result, expected_result,
                     (o_led_data == expected_result) ? "PASS" : "FAIL");
            $display("Carry: %b - Esperado: %b - %s", 
                     o_led_carry, expected_carry,
                     (o_led_carry == expected_carry) ? "PASS" : "FAIL");
            $display("Zero: %b - Esperado: %b - %s", 
                     o_led_zero, expected_zero,
                     (o_led_zero == expected_zero) ? "PASS" : "FAIL");
            $display("----------------------------------------");
        end
    endtask
    
    // Proceso principal de test
    initial begin
        $display("=== INICIANDO TESTBENCH ALU ===");
        $display("Tiempo: %t", $time);
        
        // Inicialización
        reset_system();
        
        // TEST 1: Suma sin carry (15 + 10 = 25)
        $display("\nTEST 1: Suma 15 + 10 = 25");
        load_data(8'd15, 8'd10, 6'b100000); // ADD operation
        display_result(8'd25, 1'b0, 1'b0, "SUMA 15 + 10");
        
        // TEST 2: Suma con carry (200 + 100 = 300, pero 300 > 255)
        $display("\nTEST 2: Suma con overflow 200 + 100");
        load_data(8'd200, 8'd100, 6'b100000); // ADD operation
        display_result(8'd44, 1'b1, 1'b0, "SUMA 200 + 100 (con carry)"); // 300 - 256 = 44
        
        // TEST 3: Suma que resulta en cero (128 + 128 = 256, que es 0 en 8 bits)
        $display("\nTEST 3: Suma que resulta en cero 128 + 128");
        load_data(8'd128, 8'd128, 6'b100000); // ADD operation
        display_result(8'd0, 1'b1, 1'b1, "SUMA 128 + 128 (resultado cero con carry)");
        
        // TEST 4: AND básico (0xAA & 0x55 = 0x00)
        $display("\nTEST 4: AND 0xAA & 0x55");
        load_data(8'hAA, 8'h55, 6'b100100); // AND operation
        display_result(8'h00, 1'b0, 1'b1, "AND 0xAA & 0x55");
        
        // TEST 5: AND con resultado no cero (0xFF & 0x0F = 0x0F)
        $display("\nTEST 5: AND 0xFF & 0x0F");
        load_data(8'hFF, 8'h0F, 6'b100100); // AND operation
        display_result(8'h0F, 1'b0, 1'b0, "AND 0xFF & 0x0F");
        
        // TEST 6: AND con todos unos (0xFF & 0xFF = 0xFF)
        $display("\nTEST 6: AND 0xFF & 0xFF");
        load_data(8'hFF, 8'hFF, 6'b100100); // AND operation
        display_result(8'hFF, 1'b0, 1'b0, "AND 0xFF & 0xFF");
        
        // Finalización
        #(CLK_PERIOD * 10);
        $display("\n=== TESTBENCH COMPLETADO ===");
        $display("Tiempo final: %t", $time);
        $finish;
    end
    
    // Monitor para observar cambios en las señales
    initial begin
        $monitor("Tiempo: %t | Reset: %b | Data: %d | En1: %b En2: %b En3: %b | Resultado: %d | Carry: %b | Zero: %b", 
                 $time, i_reset, i_data, i_enable_1, i_enable_2, i_enable_3, o_led_data, o_led_carry, o_led_zero);
    end
    
    // Generar archivo VCD para visualización
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, tb_alu);
    end

endmodule