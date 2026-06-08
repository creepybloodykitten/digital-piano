module note_to_freq_and_sample (
    input  wire [6:0] note,
    output reg  [4:0] sample_index, // ИЗМЕНЕНО: теперь [4:0] вместо [3:0]
    output reg  [15:0] step          
);
    always @(*) begin
        step = 16'd4096; // Шаг ВСЕГДА 1.0 (оригинальная скорость воспроизведения)
        
        if (note < 48) begin
            sample_index = 5'd0;    // Ограничение снизу (играет C3)
        end else if (note > 72) begin
            sample_index = 5'd24;   // Ограничение сверху (играет C5)
        end else begin
            // Прямая адресация: 48 (C3) -> 0, 49 (C#3) -> 1 ... 72 (C5) -> 24
            sample_index = note - 7'd48; 
        end
    end
endmodule