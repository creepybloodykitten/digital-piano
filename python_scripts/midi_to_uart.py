import mido
import serial

# Настройки
SERIAL_PORT = 'COM5'  
BAUD_RATE = 115200    

try:
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.1)
    print(f"Подключено к ПЛИС на {SERIAL_PORT}")
except:
    print(f"Не удалось открыть порт {SERIAL_PORT}")
    exit()

input_names = mido.get_input_names()
if not input_names:
    print("Клавиатура не найдена")
    exit()

print(f"Слушаю {input_names[0]}...")

with mido.open_input(input_names[0]) as inport:
    for msg in inport:
        if msg.type in ['note_on', 'note_off']:
            # MIDI сообщение — это 3 байта
            raw_bytes = msg.bytes()
            #ser.write(raw_bytes) # Шлем их в ПЛИС
            ser.write(bytearray(raw_bytes))
            print(f"Отправлено: {raw_bytes}")