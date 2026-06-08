module note_to_freq_and_sample (
    input  wire [6:0] note,
    output reg  [3:0] sample_index, // Индекс сэмпла от 0 до 8
    output reg  [15:0] step          // Шаг чтения в формате 12.12
);
    always @(*) begin
        sample_index = 0;
        step = 16'd0;
        
        if (note < 48) begin
            sample_index = 0;
            step = 16'd4096; // Ограничение снизу (играет C3)
        end else if (note > 72) begin
            sample_index = 8;
            step = 16'd4096; // Ограничение сверху (играет C5)
        end else begin
            case (note)
                48: begin sample_index = 0; step = 16'd4096; end // C3 (оригинал)
                49: begin sample_index = 0; step = 16'd4339; end // C#3 (+1 полутон)
                50: begin sample_index = 1; step = 16'd3866; end // D3 (-1 полутон)
                51: begin sample_index = 1; step = 16'd4096; end // D#3 (оригинал)
                52: begin sample_index = 1; step = 16'd4339; end // E3 (+1 полутон)
                53: begin sample_index = 2; step = 16'd3866; end // F3 (-1 полутон)
                54: begin sample_index = 2; step = 16'd4096; end // F#3 (оригинал)
                55: begin sample_index = 2; step = 16'd4339; end // G3 (+1 полутон)
                56: begin sample_index = 3; step = 16'd3866; end // G#3 (-1 полутон)
                57: begin sample_index = 3; step = 16'd4096; end // A3 (оригинал)
                58: begin sample_index = 3; step = 16'd4339; end // A#3 (+1 полутон)
                59: begin sample_index = 4; step = 16'd3866; end // B3 (-1 полутон)
                60: begin sample_index = 4; step = 16'd4096; end // C4 (оригинал)
                61: begin sample_index = 4; step = 16'd4339; end // C#4 (+1 полутон)
                62: begin sample_index = 5; step = 16'd3866; end // D4 (-1 полутон)
                63: begin sample_index = 5; step = 16'd4096; end // D#4 (оригинал)
                64: begin sample_index = 5; step = 16'd4339; end // E4 (+1 полутон)
                65: begin sample_index = 6; step = 16'd3866; end // F4 (-1 полутон)
                66: begin sample_index = 6; step = 16'd4096; end // F#4 (оригинал)
                67: begin sample_index = 6; step = 16'd4339; end // G4 (+1 полутон)
                68: begin sample_index = 7; step = 16'd3866; end // G#4 (-1 полутон)
                69: begin sample_index = 7; step = 16'd4096; end // A4 (оригинал)
                70: begin sample_index = 7; step = 16'd4339; end // A#4 (+1 полутон)
                71: begin sample_index = 8; step = 16'd3866; end // B4 (-1 полутон)
                72: begin sample_index = 8; step = 16'd4096; end // C5 (оригинал)
                default: begin sample_index = 0; step = 16'd0; end
            endcase
        end
    end
endmodule