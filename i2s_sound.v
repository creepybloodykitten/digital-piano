module Simple_I2S_Tone(
    input  wire clk_50,
    input  wire [2:0] keys, 
    output wire aud_xck,
    output wire aud_bclk,
    output wire aud_lrck,
    output wire aud_dat,
    input  wire rx_pin
);
    // clock devider
    reg [9:0] audio_cnt = 0;
    always @(posedge clk_50) audio_cnt <= audio_cnt + 1'b1;

    assign aud_xck  = audio_cnt[1]; 
    assign aud_bclk = audio_cnt[3]; 
    assign aud_lrck = audio_cnt[9]; 

    wire [7:0] rx_byte;
    wire rx_ready;

    uart_rx #(.CLK(50000000), .BAUD_RATE(115200)) rx_inst (
        .clk(clk_50),
        .reset_n(1'b1),
        .rx_pin(rx_pin), 
        .rx_data(rx_byte),
        .flag_byte_ready(rx_ready)
    );

    wire [7:0] midi_note, midi_vel;
    wire midi_on, midi_trig;

    midi_decoder m_dec (
        .clk(clk_50),
        .rx_ready(rx_ready),
        .rx_data(rx_byte),
        .out_note(midi_note),
        .out_velocity(midi_vel),
        .out_on(midi_on),
        .out_trig(midi_trig)
    );

//    reg [15:0] target_freq;
//    always @(*) begin
//        case (midi_note)
//            48: target_freq = 16'd176;
//            49: target_freq = 16'd186;
//            50: target_freq = 16'd197;
//            51: target_freq = 16'd209;
//            52: target_freq = 16'd221;
//            53: target_freq = 16'd234;
//            54: target_freq = 16'd248;
//            55: target_freq = 16'd263;
//            56: target_freq = 16'd279;
//            57: target_freq = 16'd295;
//            58: target_freq = 16'd313;
//            59: target_freq = 16'd331;
//            default: target_freq = 0;
//        endcase
//    end

    reg [15:0] target_freq;
    always @(*) begin
        case (midi_note)
            48: target_freq = 16'd350;
            50: target_freq = 16'd393;
            52: target_freq = 16'd442;
            default: target_freq = 0;
        endcase
    end


    wire signed [15:0] voice_out;
    piano_voice voice1 (
        .clk_lrck(aud_lrck),
        .freq(target_freq),
        .key_pressed(midi_on),   // MIDI управляет нажатием
        //.velocity(midi_vel),     // MIDI управляет силой
		  .velocity(8'd127),
        .audio_out(voice_out)
    );


    // transmit via I2S 
    reg [15:0] shift_reg;
    always @(negedge aud_bclk) begin
        if (audio_cnt[8:4] == 5'd0) begin 
            shift_reg <= voice_out;
        end else begin
            shift_reg <= {shift_reg[14:0], 1'b0};
        end
    end

    assign aud_dat = shift_reg[15];

endmodule