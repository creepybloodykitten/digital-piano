module piano_voice(
    input  wire clk_lrck,      // sample frequency clock
    input  wire [15:0] freq,   // note frequency (phase increment)
    input [7:0] velocity, 
    input  wire key_pressed,   // key status
    output wire signed [15:0] audio_out // output of one voice
);
    //  Phase accumulator (unique for each voice)
    reg [31:0] phase_acc = 0;
    always @(posedge clk_lrck) begin
        if (freq == 0) phase_acc <= 0;
        else phase_acc <= phase_acc + {freq, 16'b0};
    end

    // Sine table (unique for each voice)
    wire [9:0] rom_addr = phase_acc[31:22];
    wire signed [15:0] raw_wave;
	 
	 wave_rom rom_inst (
        .address(rom_addr),
        .clock(clk_lrck),
        .q(raw_wave)
    );
	 

    // Envelope (unique for each voice)
    reg [15:0] envelope = 0;
    reg last_key;
    always @(posedge clk_lrck) last_key <= key_pressed;
    wire key_just_pressed = key_pressed & ~last_key;

    reg [2:0] decay_div;
    // Key Tracking: вычисляем скорость затухания в зависимости от высоты ноты
    // freq сдвигается, чтобы получить разумное значение прибавки.
    // Чем выше нота (freq больше), тем больше decay_rate.
    wire [15:0] release_rate = 16'd5 + (freq >> 4); 
    wire [15:0] decay_step   = (envelope >> 14) + (freq >> 7) + 16'd1;
    

    always @(posedge clk_lrck) begin
        decay_div <= decay_div + 1'b1;
        if (key_just_pressed) begin
			envelope <= 16'd5000 + ( {8'b0, velocity} * velocity * 16'd3 ); //log volume with base 
        end 
        else if (key_pressed) begin
            if (decay_div == 0 ) begin
                if (envelope > decay_step)
                    envelope <= envelope - decay_step;
                else 
                    envelope <= 0;
            end
        end 
        else begin
            if (envelope > 16'd30) envelope <= envelope - 16'd30;
            else envelope <= 0;
        end
    end

    //dynamic low-pass filter
    reg signed [23:0] lpf_reg = 0;
	 wire signed [23:0] lpf_input = $signed({raw_wave, 8'b0}); 
    wire[3:0] k = (envelope > 16'hC000) ? 4'd1 :  // strong 
                   (envelope > 16'h8000) ? 4'd2 :  // medium
                   (envelope > 16'h4000) ? 4'd3 :  // weak
                                           4'd4; // very weak

    always @(posedge clk_lrck) begin
        // shift raw_wave for equal lpf_reg
        lpf_reg <= lpf_reg + $signed((lpf_input - lpf_reg) >>> k);
    end
    wire signed [15:0] filtered_wave = lpf_reg[23:8];

    // VCA
    wire signed [16:0] env_signed = $signed({1'b0, envelope});
    wire signed [32:0] mixed_audio = $signed(filtered_wave) * env_signed;
    assign audio_out = mixed_audio[31:16];
endmodule

module note_to_freq (
    input  wire [6:0] note,
    output reg[15:0] freq
);
    always @(*) begin
        case (note)
            48: freq = 16'd176; // До (малая)
            49: freq = 16'd186; 
            50: freq = 16'd197; // Ре
            51: freq = 16'd209; 
            52: freq = 16'd221; // Ми
            53: freq = 16'd234; // Фа
            54: freq = 16'd248; 
            55: freq = 16'd263; // Соль
            56: freq = 16'd279; 
            57: freq = 16'd295; // Ля
            58: freq = 16'd313; 
            59: freq = 16'd331; // Си
            60: freq = 16'd350; // До (первая)
				60: freq = 16'd351; // До (C4)
            61: freq = 16'd372; // До#
            62: freq = 16'd394; // Ре
            63: freq = 16'd418; // Ре#
            64: freq = 16'd442; // Ми
            65: freq = 16'd469; // Фа
            66: freq = 16'd497; // Фа#
            67: freq = 16'd526; // Соль
            68: freq = 16'd557; // Соль#
            69: freq = 16'd591; // Ля (Ля 440 Гц - камертон)
            70: freq = 16'd626; // Ля#
            71: freq = 16'd663; // Си
            72: freq = 16'd702; // До (C5)
            default: freq = 16'd0;
        endcase
    end
endmodule