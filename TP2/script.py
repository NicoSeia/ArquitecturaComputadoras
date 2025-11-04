#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Cliente UART para Basys 3 - ALU Estilo Comando.
Uso: <operación> <A> <B>
Ejemplos: 
  add 4 5
  sub 0x0A 0x03
  xor 15 7
"""

import serial
import serial.tools.list_ports
import time
import sys

# ------------------------------------
# Configuración UART (8N1, 9600 baud)
# ------------------------------------
BAUD_RATE = 9600
BYTESIZE = serial.EIGHTBITS
PARITY   = serial.PARITY_NONE
STOPBITS = serial.STOPBITS_ONE
HEADER = 0xFF

# ------------------------------------
# Diccionario de operaciones
# ------------------------------------
OPS = {
    'add': 0b100000,
    'sub': 0b100010,
    'and': 0b100100,
    'or':  0b100101,
    'nor': 0b100111,
    'xor': 0b100110,
    'srl': 0b000010,
    'sra': 0b000011
}

# ------------------------------------
# Funciones auxiliares
# ------------------------------------
def list_serial_ports():
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("⚠️  No se encontraron puertos seriales.")
        exit(1)
    print("\n=== Puertos seriales detectados ===")
    for i, p in enumerate(ports):
        desc = p.description or "Sin descripción"
        print(f"[{i}] {p.device} — {desc}")
    print("===================================")
    while True:
        try:
            sel = int(input(f"Seleccione puerto (0-{len(ports)-1}): "))
            if 0 <= sel < len(ports):
                return ports[sel].device
        except ValueError:
            pass
        print("Entrada inválida. Intente nuevamente.")

def parse_value(val_str):
    """Convierte string a int (soporta decimal y hex)"""
    val_str = val_str.strip()
    if val_str.lower().startswith('0x'):
        return int(val_str, 16)
    return int(val_str)

def send_packet_as_bytes(ser, packet_bytes, delay_s=0.002):
    """Envía cada byte con delay"""
    for b in packet_bytes:
        ser.write(bytes([b]))
        ser.flush()
        time.sleep(delay_s)

def read_result_byte(ser, timeout_s=2.0):
    """Lee 1 byte de resultado"""
    t0 = time.time()
    while time.time() - t0 < timeout_s:
        if ser.in_waiting:
            return ser.read(1)[0]
        time.sleep(0.001)
    return None

def show_help():
    """Muestra ayuda de comandos"""
    print("\n=== COMANDOS DISPONIBLES ===")
    print("Uso: <operación> <A> <B>")
    print("\nOperaciones:")
    for op in OPS.keys():
        print(f"  {op}")
    print("\nEjemplos:")
    print("  add 4 5")
    print("  sub 0x0A 0x03")
    print("  xor 15 7")
    print("\nComandos especiales:")
    print("  help  - Muestra esta ayuda")
    print("  exit  - Salir del programa")
    print("============================\n")

# ------------------------------------
# Programa principal
# ------------------------------------
def main():
    port = list_serial_ports()
    
    print(f"\nConectando a {port} @ {BAUD_RATE} baud (8N1)...\n")
    ser = serial.Serial(
        port,
        BAUD_RATE,
        bytesize=BYTESIZE,
        parity=PARITY,
        stopbits=STOPBITS,
        timeout=0.1
    )
    
    # Desactivar DTR y RTS
    ser.setDTR(False)
    ser.setRTS(False)
    time.sleep(0.2)
    
    print("✅ Conexión establecida")
    show_help()
    
    try:
        while True:
            # Leer comando
            try:
                cmd = input("ALU> ").strip().lower()
            except EOFError:
                break
            
            if not cmd:
                continue
            
            # Procesar comandos especiales
            if cmd == 'exit' or cmd == 'quit':
                break
            elif cmd == 'help':
                show_help()
                continue
            
            # Parsear comando: operación A B
            parts = cmd.split()
            if len(parts) != 3:
                print("❌ Error: Formato incorrecto. Uso: <operación> <A> <B>")
                print("   Escribe 'help' para ver ejemplos\n")
                continue
            
            op_name, a_str, b_str = parts
            
            # Validar operación
            if op_name not in OPS:
                print(f"❌ Error: Operación '{op_name}' no reconocida.")
                print(f"   Operaciones válidas: {', '.join(OPS.keys())}\n")
                continue
            
            # Parsear operandos
            try:
                A = parse_value(a_str)
                B = parse_value(b_str)
                
                if not (0 <= A <= 255 and 0 <= B <= 255):
                    print("❌ Error: Los operandos deben estar entre 0 y 255\n")
                    continue
                    
            except ValueError:
                print("❌ Error: Operandos inválidos. Use números decimales o hex (0x...)\n")
                continue
            
            # Obtener código de operación
            op_code = OPS[op_name]
            
            # Crear y enviar paquete
            packet = bytes([HEADER, A, B, op_code])
            
            print(f"→ Enviando: {op_name.upper()} {A} (0x{A:02X}) {B} (0x{B:02X})")
            send_packet_as_bytes(ser, packet)
            
            # Leer resultado
            result = read_result_byte(ser, timeout_s=2.0)
            
            if result is not None:
                print(f"← Resultado: {result} (0x{result:02X}) [binario: {result:08b}]")
            else:
                print("❌ Error: No se recibió respuesta (timeout)")
            
            print()  # Línea en blanco
            
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupción por teclado (Ctrl+C)")
    finally:
        ser.close()
        print(f"Puerto {port} cerrado.")
        print("¡Hasta luego! 👋\n")


if __name__ == "__main__":
    main()