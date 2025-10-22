#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import serial
import serial.tools.list_ports
import threading
import time
import sys

# === FUNCIÓN AUXILIAR ===
def list_serial_ports():
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("⚠️  No se encontraron puertos seriales.")
        sys.exit(1)
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

# === CONFIGURACIÓN ===
BAUD = 9600
PORT = list_serial_ports()
print(f"\nAbriendo {PORT} a {BAUD} baud...")

ser = serial.Serial(PORT, BAUD, timeout=0.05)
time.sleep(2)

# === HILO PARA LEER CONTINUAMENTE ===
def serial_reader():
    print("\n[MONITOR UART] Esperando datos de la FPGA...\n")
    while True:
        data = ser.read(ser.in_waiting or 1)
        if data:
            print("RX:", [f"0x{b:02X}" for b in data])
        time.sleep(0.05)

thread = threading.Thread(target=serial_reader, daemon=True)
thread.start()

# === ENVÍO DE COMANDOS ===
HEADER = 0xFF  # Debe coincidir con tu START_FSM
while True:
    try:
        # Leer entrada del usuario
        line = input("\nIngrese A, B, OP (ej: 3 2 0x20) o 'q' para salir: ").strip()
        if line.lower() in {"q", "quit", "exit"}:
            break

        parts = line.split()
        if len(parts) != 3:
            print("⚠️  Formato inválido. Ejemplo: 3 2 0x20")
            continue

        A = int(parts[0], 0)
        B = int(parts[1], 0)
        OP = int(parts[2], 0)

        frame = bytes([HEADER, A & 0xFF, B & 0xFF, OP & 0xFF])
        ser.write(frame)
        print(f"TX: {[f'0x{x:02X}' for x in frame]}")

    except (KeyboardInterrupt, EOFError):
        break
    except ValueError:
        print("⚠️  Entrada inválida. Use números (dec o hex).")

print("\nCerrando puerto...")
ser.close()
print("Listo.")
