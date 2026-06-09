import wave
import struct
import os

# Автоопределение корневой папки проекта
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if os.path.exists(os.path.join(SCRIPT_DIR, 'generated_samples')):
    PROJECT_DIR = SCRIPT_DIR
else:
    PROJECT_DIR = os.path.dirname(SCRIPT_DIR)

# Настройка путей в проекте
INPUT_DIR = os.path.join(PROJECT_DIR, 'generated_samples')
OUTPUT_DIR = os.path.join(PROJECT_DIR, 'raw_samples')
OUTPUT_RAW = os.path.join(OUTPUT_DIR, 'samples.raw')

# Строгий порядок объединения нот для верного соответствия индексам в Verilog
NOTES = [
    "00_note48", "01_note49", "02_note50", "03_note51", "04_note52", 
    "05_note53", "06_note54", "07_note55", "08_note56", "09_note57", 
    "10_note58", "11_note59", "12_note60", "13_note61", "14_note62", 
    "15_note63", "16_note64", "17_note65", "18_note66", "19_note67", 
    "20_note68", "21_note69", "22_note70", "23_note71", "24_note72"
]

# Слой громкости. Можете изменить на v12 или другой, если захотите пересобрать пианино
VELOCITY = "" 

MAX_SECONDS = 3.0    # Длина каждого сэмпла

def process_audio():
    if not os.path.exists(INPUT_DIR):
        print(f"Ошибка! Папка с оригиналами не найдена по пути: {INPUT_DIR}")
        print("Пожалуйста, создайте папку 'original_samples' и положите туда 9 WAV файлов.")
        return

    # Создаем папку назначения, если её нет
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    combined_raw_data = bytearray()

    print(f"Поиск исходных файлов в: {INPUT_DIR}")
    print(f"Результат будет сохранен в: {OUTPUT_RAW}\n")

    for i, note in enumerate(NOTES):
        filename = f"{note}{VELOCITY}.wav"
        input_filepath = os.path.join(INPUT_DIR, filename)

        if not os.path.exists(input_filepath):
            print(f"Ошибка! Файл не найден: {filename}")
            print(f"Пожалуйста, убедитесь, что в {INPUT_DIR} есть все 9 нужных файлов.")
            return

        print(f"[{i}] Обработка {filename}...")

        with wave.open(input_filepath, 'rb') as wav_in:
            n_channels = wav_in.getnchannels()
            sampwidth = wav_in.getsampwidth()
            framerate = wav_in.getframerate()
            n_frames = wav_in.getnframes()
            
            if sampwidth != 2:
                print(f"Ошибка: Скрипт работает только с 16-битными файлами! ({filename})")
                return
                
            # Рассчитываем целевую длину одного сэмпла (3.0 сек * 44100 Гц = 132300)
            # Округляем до ближайшей кратности 8 для ровного заполнения 128-битной шины (132304 отсчета)
            target_samples = int(framerate * MAX_SECONDS)
            if target_samples % 8 != 0:
                target_samples += 8 - (target_samples % 8)
                
            frames_to_read = min(n_frames, target_samples)
            raw_data = wav_in.readframes(frames_to_read)
            
            # Стерео -> Моно (Берем только левый канал, как в вашем исходном скрипте)
            if n_channels == 2:
                shorts = struct.unpack(f"<{frames_to_read * 2}h", raw_data)
                mono_shorts = shorts[0::2] 
                processed_bytes = struct.pack(f"<{frames_to_read}h", *mono_shorts)
            else:
                processed_bytes = raw_data

            # Добавляем паддинг нулевыми байтами в конец, если реальный файл короче 3.0 секунд
            current_bytes = len(processed_bytes)
            target_bytes = target_samples * 2
            if current_bytes < target_bytes:
                padding_size = target_bytes - current_bytes
                processed_bytes += b'\x00' * padding_size

            # Накапливаем данные в общий массив для RAW
            combined_raw_data.extend(processed_bytes)

    # Сохраняем один объединенный RAW файл для прошивки
    with open(OUTPUT_RAW, 'wb') as raw_out:
        raw_out.write(combined_raw_data)

    print(f"\nУспешно обработано и объединено!")
    print(f"Файл для ПЛИС: {OUTPUT_RAW}")
    print(f"Размер: {len(combined_raw_data)} байт ({len(combined_raw_data)//2} сэмплов)")

if __name__ == "__main__":
    process_audio()