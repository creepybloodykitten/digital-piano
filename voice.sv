module piano_voice(
    input  wire clk_lrck,      // sample frequency clock
    input  wire [15:0] freq,   // note frequency (phase increment)
    input  wire key_pressed,   // key status
    output wire signed [15:0] audio_out // output of one voice
);
    //  Phase accumulator (unique for each voice)
    reg [15:0] phase_acc = 0;
    always @(posedge clk_lrck) begin
        if (freq == 0) phase_acc <= 0;
        else phase_acc <= phase_acc + freq;
    end

    // Sine table (unique for each voice)
    wire [4:0] rom_index = phase_acc[15:11];
    reg signed [15:0] sine_wave;
    always @(*) begin
        case(rom_index)
            5'd0 : sine_wave =  16'd0;     5'd1 : sine_wave =  16'd6242;
            5'd2 : sine_wave =  16'd12245; 5'd3 : sine_wave =  16'd17760;
            5'd4 : sine_wave =  16'd22627; 5'd5 : sine_wave =  16'd26607;
            5'd6 : sine_wave =  16'd29560; 5'd7 : sine_wave =  16'd31384;
            5'd8 : sine_wave =  16'd32000; 5'd9 : sine_wave =  16'd31384;
            5'd10: sine_wave =  16'd29560; 5'd11: sine_wave =  16'd26607;
            5'd12: sine_wave =  16'd22627; 5'd13: sine_wave =  16'd17760;
            5'd14: sine_wave =  16'd12245; 5'd15: sine_wave =  16'd6242;
            5'd16: sine_wave =  16'd0;     5'd17: sine_wave = -16'd6242;
            5'd18: sine_wave = -16'd12245; 5'd19: sine_wave = -16'd17760;
            5'd20: sine_wave = -16'd22627; 5'd21: sine_wave = -16'd26607;
            5'd22: sine_wave = -16'd29560; 5'd23: sine_wave = -16'd31384;
            5'd24: sine_wave = -16'd32000; 5'd25: sine_wave = -16'd31384;
            5'd26: sine_wave = -16'd29560; 5'd27: sine_wave = -16'd26607;
            5'd28: sine_wave = -16'd22627; 5'd29: sine_wave = -16'd17760;
            5'd30: sine_wave = -16'd12245; 5'd31: sine_wave = -16'd6242;
            default: sine_wave = 16'd0;
        endcase
    end

    // Envelope (unique for each voice)
    reg [15:0] envelope = 0;
    reg last_key;
    always @(posedge clk_lrck) last_key <= key_pressed;
    wire key_just_pressed = key_pressed & ~last_key;

    reg [2:0] decay_div;
    always @(posedge clk_lrck) begin
        decay_div <= decay_div + 1'b1;
        if (key_just_pressed) begin
            envelope <= 16'hFFFF;
        end 
        else if (key_pressed) begin
            if (decay_div == 0 && envelope > 0)
                envelope <= envelope - (envelope >> 13) - 1'b1;
        end 
        else begin
            if (envelope > 16'd30) envelope <= envelope - 16'd30;
            else envelope <= 0;
        end
    end

    // VCA
    wire signed [16:0] env_signed = {1'b0, envelope};
    wire signed [32:0] mixed_audio = sine_wave * env_signed;
    assign audio_out = mixed_audio[31:16];

endmodule