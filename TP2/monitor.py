import serial

PORT = "/dev/ttyUSB1"
BAUD = 9600

with serial.Serial(PORT, BAUD, timeout=0.1) as ser:
    print(f"Escuchando en {PORT} a {BAUD} bps...")
    while True:
        data = ser.read(ser.in_waiting or 1)
        if data:
            print("RX:", [hex(b) for b in data])
