module note_to_freq_and_sample (
    input  wire [6:0] note,
    output reg  [4:0] sample_index, 
    output reg  [15:0] step          
);
    always @(*) begin
        step = 16'd4096; // оригинальная скорость воспроизведения
        
        if (note < 48) begin
            sample_index = 5'd0;    // Ограничение снизу (играет C3)
        end else if (note > 72) begin
            sample_index = 5'd24;   // Ограничение сверху (играет C5)
        end else begin
            // Прямая адресация
            sample_index = note - 7'd48; 
        end
    end
endmodule