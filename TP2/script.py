#!/usr/bin/env python3
"""
Controlador UART para ALU en FPGA
Permite ejecutar operaciones aritméticas y lógicas en tiempo real
"""

import serial
import time
import sys

class ALUController:
    # Mapeo de operaciones a códigos binarios (6 bits menos significativos)
    OPERATIONS = {
        'add': 0x20,  # 100000
        'sub': 0x22,  # 100010
        'and': 0x24,  # 100100
        'or':  0x25,  # 100101
        'xor': 0x26,  # 100110
        'nor': 0x27,  # 100111
        'srl': 0x02,  # 000010 - Shift Right Logical
        'sra': 0x03,  # 000011 - Shift Right Arithmetic
    }
    
    def __init__(self, port='/dev/ttyUSB0', baudrate=9600, timeout=2):
        """
        Inicializa la conexión serial con la FPGA
        
        Args:
            port: Puerto serial (ej: '/dev/ttyUSB0' en Linux, 'COM3' en Windows)
            baudrate: Velocidad de comunicación
            timeout: Timeout en segundos para lectura
        """
        try:
            self.ser = serial.Serial(port, baudrate, timeout=timeout)
            time.sleep(2)  # Esperar estabilización de la conexión
            print(f"✓ Conectado a {port} @ {baudrate} baud")
            print(f"✓ Operaciones disponibles: {', '.join(self.OPERATIONS.keys())}")
            print("-" * 60)
        except serial.SerialException as e:
            print(f"✗ Error al abrir puerto serial: {e}")
            sys.exit(1)
    
    def execute_operation(self, operation, operand_a, operand_b):
        """
        Ejecuta una operación en la ALU de la FPGA
        
        Args:
            operation: Nombre de la operación (ej: 'add', 'sub', etc.)
            operand_a: Primer operando (0-255)
            operand_b: Segundo operando (0-255, o 0-3 para shifts)
            
        Returns:
            Resultado de la operación o None si hay error
        """
        # Validar operación
        if operation not in self.OPERATIONS:
            print(f"✗ Operación '{operation}' no válida")
            return None
        
        # Para operaciones de shift, validar rango 0-3 y convertir a bits [7:6]
        if operation in ['srl', 'sra']:
            if not (0 <= operand_b <= 3):
                print(f"✗ Cantidad de desplazamiento debe ser 0-3")
                return None
            # Convertir cantidad de shift a los bits [7:6]
            # 0 -> 0b00000000, 1 -> 0b01000000, 2 -> 0b10000000, 3 -> 0b11000000
            operand_b = operand_b << 6
        
        # Validar operandos
        if not (0 <= operand_a <= 255 and 0 <= operand_b <= 255):
            print(f"✗ Operandos fuera de rango (0-255)")
            return None
        
        # Obtener código de operación
        opcode = self.OPERATIONS[operation]
        
        # Enviar 3 bytes: [operación, operando_a, operando_b]
        try:
            self.ser.write(bytes([opcode, operand_a, operand_b]))
            self.ser.flush()
            
            # Leer resultado (1 byte)
            result = self.ser.read(1)
            
            if len(result) == 1:
                return result[0]
            else:
                print("✗ Timeout: no se recibió respuesta de la FPGA")
                return None
                
        except serial.SerialException as e:
            print(f"✗ Error de comunicación: {e}")
            return None
    
    def parse_and_execute(self, command):
        """
        Parsea un comando tipo 'add 10 15' y lo ejecuta
        
        Args:
            command: String con formato "operacion operando1 operando2"
        """
        parts = command.strip().lower().split()
        
        if len(parts) != 3:
            print("✗ Formato inválido. Uso: <operacion> <operando1> <operando2>")
            print("  Ejemplo: add 10 15")
            return
        
        operation = parts[0]
        
        try:
            operand_a = int(parts[1])
            operand_b = int(parts[2])
        except ValueError:
            print("✗ Los operandos deben ser números enteros")
            return
        
        # Ejecutar operación
        print(f"→ Ejecutando: {operation.upper()} {operand_a} {operand_b}")
        result = self.execute_operation(operation, operand_a, operand_b)
        
        if result is not None:
            # Mostrar resultado según la operación
            if operation in ['add', 'sub']:
                print(f"← Resultado: {result} (decimal) = 0x{result:02X} (hex)")
            elif operation in ['and', 'or', 'xor', 'nor']:
                print(f"← Resultado: {result} (decimal) = 0b{result:08b} (binario) = 0x{result:02X} (hex)")
            elif operation in ['srl', 'sra']:
                shift_amount = operand_b >> 6  # Los 2 bits más significativos (valor real enviado)
                # Reconstruir el valor original antes de la conversión
                original_shift = result.bit_length() - 1 if result else 0
                print(f"← Resultado: {result} (decimal) = 0b{result:08b} (binario)")
                print(f"   (Valor {operand_a} desplazado {shift_amount} posiciones a la derecha)")
            
            print("-" * 60)
    
    def interactive_mode(self):
        """
        Modo interactivo: permite ingresar comandos continuamente
        """
        print("\n" + "="*60)
        print("MODO INTERACTIVO - Controlador ALU UART")
        print("="*60)
        print("Ingrese comandos en formato: <operacion> <op1> <op2>")
        print("Ejemplos:")
        print("  add 25 30    → Suma 25 + 30")
        print("  sub 100 45   → Resta 100 - 45")
        print("  and 0xFF 0x0F → AND bit a bit")
        print("  xor 170 85   → XOR bit a bit")
        print("\nEscriba 'help' para ver operaciones, 'quit' para salir")
        print("="*60 + "\n")
        
        while True:
            try:
                command = input("ALU> ").strip()
                
                if not command:
                    continue
                
                if command.lower() == 'quit' or command.lower() == 'exit':
                    print("Cerrando conexión...")
                    break
                
                if command.lower() == 'help':
                    self.show_help()
                    continue
                
                # Ejecutar comando
                self.parse_and_execute(command)
                
            except KeyboardInterrupt:
                print("\n\nInterrumpido por usuario. Cerrando...")
                break
            except Exception as e:
                print(f"✗ Error: {e}")
    
    def show_help(self):
        """Muestra ayuda con todas las operaciones disponibles"""
        print("\n" + "="*60)
        print("OPERACIONES DISPONIBLES")
        print("="*60)
        print("ADD  - Suma:                    add 10 20")
        print("SUB  - Resta:                   sub 50 30")
        print("AND  - AND lógico:              and 255 15")
        print("OR   - OR lógico:               or 128 64")
        print("XOR  - XOR lógico:              xor 170 85")
        print("NOR  - NOR lógico:              nor 15 240")
        print("SRL  - Shift Right Logical:     srl 128 2  (desplaza 2 posiciones)")
        print("SRA  - Shift Right Arithmetic:  sra 128 3  (desplaza 3 posiciones)")
        print("\nNota: Operandos válidos de 0 a 255")
        print("      Para SRL/SRA: segundo operando de 0 a 3 (cantidad de bits)")
        print("="*60 + "\n")
    
    def close(self):
        """Cierra la conexión serial"""
        if self.ser.is_open:
            self.ser.close()
            print("✓ Conexión cerrada")

    def batch_test(self):
        """Ejecuta un conjunto de pruebas automáticas"""
        print("\n" + "="*60)
        print("EJECUTANDO PRUEBAS AUTOMÁTICAS")
        print("="*60 + "\n")
        
        tests = [
            ("add", 10, 15),
            ("add", 100, 155),
            ("sub", 50, 20),
            ("sub", 200, 150),
            ("and", 0xFF, 0x0F),
            ("or", 0xF0, 0x0F),
            ("xor", 170, 85),
            ("nor", 0, 255),
            ("srl", 128, 1),  # 128 >> 1 = 64
            ("srl", 15, 2),   # 15 >> 2 = 3
            ("sra", 128, 3),  # 128 >> 3 = 16 (lógico, sin signo en 8 bits)
        ]
        
        for op, a, b in tests:
            print(f"Test: {op.upper()} {a} {b}")
            result = self.execute_operation(op, a, b)
            if result is not None:
                print(f"  → Resultado: {result}")
            print()
            time.sleep(0.5)
        
        print("="*60 + "\n")


def main():
    """Función principal"""
    # Configuración del puerto (ajustar según tu sistema)
    # Linux/Mac: '/dev/ttyUSB0' o '/dev/ttyUSB1'
    # Windows: 'COM3', 'COM4', etc.
    
    PORT = '/dev/ttyUSB1'  # ← CAMBIAR SEGÚN TU SISTEMA
    BAUDRATE = 9600
    
    try:
        # Crear controlador
        alu = ALUController(port=PORT, baudrate=BAUDRATE)
        
        # Modo interactivo
        alu.interactive_mode()
        
        # Cerrar conexión
        alu.close()
        
    except Exception as e:
        print(f"Error fatal: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()