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


	 reg [6:0] v_note [0:9]; // Какую ноту играет каждый из 10 голосов
    reg [7:0] v_vel  [0:9]; // С какой силой нажали
    reg       v_on   [0:9]; // Нажат ли голос сейчас (1 - звучит, 0 - затухает)

    integer i;
    reg allocated; // Флаг: "нашли свободный голос"

    always @(posedge clk_50) begin
        if (midi_trig) begin
            if (midi_on) begin
                // пришла команда нажать note on
                allocated = 0;
                for (i = 0; i < 10; i = i + 1) begin
                    // Ищем первый свободный голос 
                    if (!v_on[i] && !allocated) begin
                        v_on[i]   <= 1'b1;
                        v_note[i] <= midi_note[6:0];
                        v_vel[i]  <= midi_vel;
                        allocated = 1; // заняли голос, дальше не ищем
                    end
                end
            end else begin
                // пришла команда отпустить note Off
                for (i = 0; i < 10; i = i + 1) begin
                    // ищем голос, который играет ИМЕННО ЭТУ ноту
                    if (v_on[i] && (v_note[i] == midi_note[6:0])) begin
                        v_on[i] <= 1'b0; // начинаем затухание 
                    end
                end
            end
        end
    end


    wire signed [15:0] v_out[0:9]; // выходы звука от каждого голоса

    genvar g;
    generate
        for (g = 0; g < 10; g = g + 1) begin : voices
            wire [15:0] freq_wire;
            
            // связующее звено нота -> частота
            note_to_freq n2f_inst (
                .note(v_note[g]),
                .freq(freq_wire)
            );

           
            piano_voice voice_inst (
                .clk_lrck(aud_lrck),
                .freq(freq_wire),
                .velocity(v_vel[g]),
                .key_pressed(v_on[g]),
                .audio_out(v_out[g])
            );
        end
    endgenerate

	 //--------------
	 //mixer 
    wire signed [19:0] mix_sum;
    
    assign mix_sum = $signed(v_out[0]) + $signed(v_out[1]) + 
                     $signed(v_out[2]) + $signed(v_out[3]) + 
                     $signed(v_out[4]) + $signed(v_out[5]) + 
                     $signed(v_out[6]) + $signed(v_out[7]) + 
                     $signed(v_out[8]) + $signed(v_out[9]);

    // уменьшаем громкость (сдвиг вправо на 3 бита = деление на 8)
    wire signed[19:0] mix_scaled = mix_sum >>> 1; 


    wire [15:0] final_audio = (mix_scaled > 20'sd32767)  ? 16'sd32767 :
                              (mix_scaled < -20'sd32768) ? -16'sd32768 :
                              mix_scaled[15:0];


    // transmit via I2S 
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