import serial
import struct
import os
import time

# === НАСТРОЙКИ ===
COM_PORT = 'COM5'      # ВПИШИ СВОЙ COM-ПОРТ
BAUD_RATE = 921600     
# =================

# Автоматически находим папку, в которой лежит этот скрипт (python_scripts)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
sample_file_path = os.path.join(PROJECT_DIR, "raw_samples", "samples.raw")

# Если такого файла нет, проверим альтернативное имя "piano_c4.raw"
if not os.path.exists(sample_file_path):
    alt_path = os.path.join(SCRIPT_DIR, "piano_c4.raw")
    if os.path.exists(alt_path):
        sample_file_path = alt_path
    else:
        print(f"Ошибка! Файл не найден ни по одному из путей:")
        print(f" 1) {sample_file_path}")
        print(f" 2) {alt_path}")
        print("Пожалуйста, запусти сначала скрипт форматирования wav_to_raw.py")
        exit(1)

file_size = os.path.getsize(sample_file_path)

# Вычисляем количество 16-битных сэмплов (размер файла / 2 байта)
total_samples = file_size // 2

try:
    print(f"Файл для отправки: {sample_file_path}")
    print(f"Размер: {file_size} байт ({total_samples} сэмплов)")
    print(f"Подключаюсь к {COM_PORT}...")
    
    # Открываем порт UART платы
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    time.sleep(1) # Небольшая пауза для инициализации порта компьютера

    print(f"Отправляем заголовок с размером: {total_samples} сэмплов...")
    # Шлем 32-битное беззнаковое целое число в формате Little Endian (4 байта)
    header = struct.pack("<I", total_samples)
    ser.write(header)

    print("Загружаем аудиоданные...")
    bytes_sent = 0
    start_time = time.time()
    
    with open(sample_file_path, "rb") as f:
        while True:
            chunk = f.read(1024)
            if not chunk:
                break
            ser.write(chunk)
            bytes_sent += len(chunk)
            
            # Прогресс-бар в консоли
            progress = (bytes_sent / file_size) * 100
            print(f"\rПрогресс отправки: {progress:.1f}%", end="")

    elapsed = time.time() - start_time

    ser.flush() 
    time.sleep(0.5) 
    
    print(f"\nЗагрузка завершена за {elapsed:.1f} сек! На плате должен загореться светодиод LEDG1.")
    ser.close()

except Exception as e:
    print(f"\nОшибка при отправке по UART: {e}")