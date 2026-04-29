module Simple_I2S_Tone(
    input  wire clk_50,
    input  wire [2:0] keys, 
    output wire aud_xck,
    output wire aud_bclk,
    output wire aud_lrck,
    output wire aud_dat
);
    // clock devider
    reg [9:0] audio_cnt = 0;
    always @(posedge clk_50) audio_cnt <= audio_cnt + 1'b1;

    assign aud_xck  = audio_cnt[1]; 
    assign aud_bclk = audio_cnt[3]; 
    assign aud_lrck = audio_cnt[9]; 

    // voices
    wire signed [15:0] voice_do_out;
    wire signed [15:0] voice_re_out;
    wire signed [15:0] voice_mi_out;


    piano_voice voice_do (
        .clk_lrck(aud_lrck),
        .freq(16'd350),
        .key_pressed(~keys[0]),
        .audio_out(voice_do_out)
    );

    piano_voice voice_re (
        .clk_lrck(aud_lrck),
        .freq(16'd393),
        .key_pressed(~keys[1]),
        .audio_out(voice_re_out)
    );

    piano_voice voice_mi (
        .clk_lrck(aud_lrck),
        .freq(16'd442),
        .key_pressed(~keys[2]),
        .audio_out(voice_mi_out)
    );

    // mixer for 3 voices
    // why 18 bit 
    reg signed [17:0] sum;
    always @(posedge aud_lrck) begin
        sum <= voice_do_out + voice_re_out + voice_mi_out;
    end

    //to prevent overflow now just make sound quieter
    wire [15:0] final_audio = sum[17:2]; // Делим на 4 (сдвиг на 2 бита)

    // Передача по I2S (твоя рабочая логика)
    reg [15:0] shift_reg;
    always @(negedge aud_bclk) begin
        if (audio_cnt[8:4] == 5'd0) begin 
            shift_reg <= final_audio;
        end else begin
            shift_reg <= {shift_reg[14:0], 1'b0};
        end
    end

    assign aud_dat = shift_reg[15];

endmodule