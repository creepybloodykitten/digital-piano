import librosa
import soundfile as sf
import numpy as np
import os

# === НАСТРОЙКИ ===
SR = 44100              
TARGET_LEN = 132304     

# Автоопределение корневой папки проекта (выходим из python_scripts в корень)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if os.path.exists(os.path.join(SCRIPT_DIR, 'original_samples')):
    PROJECT_DIR = SCRIPT_DIR
else:
    PROJECT_DIR = os.path.dirname(SCRIPT_DIR)

INPUT_DIR = os.path.join(PROJECT_DIR, 'original_samples')
OUT_DIR = os.path.join(PROJECT_DIR, 'generated_samples')

# Создаем папку для готовых сэмплов, если она еще не создана
os.makedirs(OUT_DIR, exist_ok=True)

# Словарь ваших исходных 9 файлов (Ключ - это номер MIDI-ноты)
base_notes = {
    48: "C3v8.wav",
    51: "D#3v8.wav",   
    54: "F#3v8.wav",   
    57: "A3v8.wav",
    60: "C4v8.wav",
    63: "D#4v8.wav",   
    66: "F#4v8.wav",   
    69: "A4v8.wav",
    72: "C5v8.wav"
}

if not os.path.exists(INPUT_DIR):
    print(f"Ошибка! Папка с оригинальными файлами не найдена по пути: {INPUT_DIR}")
    print("Пожалуйста, проверьте структуру папок вашего проекта.")
    exit(1)

# Функция для поиска ближайшего оригинального сэмпла
def find_nearest_base_note(target_note):
    nearest_note = min(base_notes.keys(), key=lambda k: abs(k - target_note))
    return nearest_note, base_notes[nearest_note]

print("Начинаю генерацию 25 нот...")

# Генерируем хроматическую гамму от C3 (48) до C5 (72)
for note in range(48, 73):
    # 1. Находим, из какого базового файла будем делать эту ноту
    base_midi, filename = find_nearest_base_note(note)
    semitones_shift = note - base_midi
    
    # Формируем полный путь к исходному файлу
    file_path = os.path.join(INPUT_DIR, filename)
    
    # 2. Загружаем базовый файл
    # sr=SR гарантирует, что файл прочитается в 44.1 кГц
    y, sr = librosa.load(file_path, sr=SR, mono=True)
    
    # 3. Делаем идеальный сдвиг тона (Pitch Shift), если нужно
    if semitones_shift != 0:
        print(f"Нота {note}: Создаю из {filename} (сдвиг на {semitones_shift} полутонов)...")
        y_shifted = librosa.effects.pitch_shift(y, sr=sr, n_steps=semitones_shift)
    else:
        print(f"Нота {note}: Использую оригинал {filename} без изменений...")
        y_shifted = y

    # 4. ПОДГОНЯЕМ РОВНО ПОД РАЗМЕР В VERILOG (132304 сэмпла)
    current_len = len(y_shifted)
    if current_len < TARGET_LEN:
        # Если файл короче, добиваем тишиной (нулями) в конце
        padding = TARGET_LEN - current_len
        y_final = np.pad(y_shifted, (0, padding), 'constant')
    else:
        # Если файл длиннее, просто обрезаем хвост (затухание)
        y_final = y_shifted[:TARGET_LEN]

    # 5. Сохраняем готовый файл
    index = note - 48
    out_name = f"{index:02d}_note{note}.wav"
    out_path = os.path.join(OUT_DIR, out_name)
    
    # Формат 'PCM_16' обязателен для вашего I2S кодека!
    sf.write(out_path, y_final, sr, subtype='PCM_16')

print("\nУспешно! Все 25 файлов лежат в папке:", OUT_DIR)
print("Теперь их можно склеить и отправлять по UART.")