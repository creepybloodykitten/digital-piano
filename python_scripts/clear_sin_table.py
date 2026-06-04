import math

DEPTH = 1024 
WIDTH = 16   
MAX_VAL = 32767

def generate_pure_sine(filename):
    with open(filename, "w") as f:
        f.write(f"WIDTH={WIDTH};\nDEPTH={DEPTH};\n")
        f.write("ADDRESS_RADIX=DEC;\nDATA_RADIX=DEC;\n")
        f.write("CONTENT BEGIN\n")

        for i in range(DEPTH):
            x = 2 * math.pi * i / DEPTH
            val = math.sin(x) # Только чистый синус! Никаких гармоник.
            res = int(val * MAX_VAL)
            f.write(f"    {i} : {res};\n")

        f.write("END;\n")

generate_pure_sine("clear_sin.mif")
print("Создан чистый синус clear_sin.mif!")