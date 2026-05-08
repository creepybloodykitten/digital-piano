import math

# Параметры MIF
DEPTH = 1024 
WIDTH = 16   
MAX_VAL = 32767

def generate_piano_mif(filename):
    with open(filename, "w") as f:
        f.write(f"WIDTH={WIDTH};\nDEPTH={DEPTH};\n")
        f.write("ADDRESS_RADIX=DEC;\nDATA_RADIX=DEC;\n")
        f.write("CONTENT BEGIN\n")

        for i in range(DEPTH):
            x = 2 * math.pi * i / DEPTH
            # Струна пианино имеет очень много гармоник. 
            # Первые 3-4 — самые мощные, дальше идут затухающие.
            val = (
                1.00 * math.sin(x) +                     # Основной тон
                0.60 * math.sin(2 * x + 0.2) +           # 2-я гармоника
                0.40 * math.sin(3 * x + 0.4) +           # 3-я гармоника
                0.30 * math.sin(4 * x + 0.1) +           # 4-я гармоника
                0.20 * math.sin(5 * x + 0.8) +           # 5-я гармоника
                0.15 * math.sin(6 * x + 0.3) +           # 6-я гармоника
                0.10 * math.sin(7 * x + 0.9) +           # 7-я гармоника
                0.08 * math.sin(8 * x + 0.5)             # 8-я гармоника
            )
            
            # Нормализация (чтобы сумма не вылетела за пределы 16 бит)
            val = val / 3.0
            
            res = int(val * MAX_VAL)
            f.write(f"    {i} : {res};\n")

        f.write("END;\n")

generate_piano_mif("piano_rich.mif")
print("MIF файл piano_rich.mif создан!")