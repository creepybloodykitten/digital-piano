module Simple_I2S_Tone(
    input  wire clk_50,
    input  wire ram_clk,
    
    output wire aud_xck,
    output wire aud_bclk,
    output wire aud_lrck,
    output wire aud_dat,

    // Входы MIDI
    input  wire [7:0]  midi_note,
    input  wire [7:0]  midi_vel,
    input  wire        midi_on,
    input  wire        midi_trig,

    // Порты памяти для 10 голосов
    output wire [31:0] voice_addr_0, input wire [15:0] voice_data_0,
    output wire [31:0] voice_addr_1, input wire [15:0] voice_data_1,
    output wire [31:0] voice_addr_2, input wire [15:0] voice_data_2,
    output wire [31:0] voice_addr_3, input wire [15:0] voice_data_3,
    output wire [31:0] voice_addr_4, input wire [15:0] voice_data_4,
    output wire [31:0] voice_addr_5, input wire [15:0] voice_data_5,
    output wire [31:0] voice_addr_6, input wire [15:0] voice_data_6,
    output wire [31:0] voice_addr_7, input wire [15:0] voice_data_7,
    output wire [31:0] voice_addr_8, input wire [15:0] voice_data_8,
    output wire [31:0] voice_addr_9, input wire [15:0] voice_data_9
);

    reg [9:0] audio_cnt = 0;
    always @(posedge clk_50) audio_cnt <= audio_cnt + 1'b1;

    assign aud_xck  = audio_cnt[1]; 
    assign aud_bclk = audio_cnt[3]; 
    assign aud_lrck = audio_cnt[9]; 

    // Глобальный декодер частоты и сэмплов (1 на весь проект!)
    wire [3:0] current_midi_sample_index;
    wire [15:0] current_midi_step;

    note_to_freq_and_sample n2f_inst (
        .note(midi_note),
        .sample_index(current_midi_sample_index),
        .step(current_midi_step)
    );

    // Массивы регистров для хранения состояния 10 голосов
    reg [3:0]  v_sample_index [0:9];
    reg [15:0] v_step         [0:9];
    reg [6:0]  v_note         [0:9];
    reg [7:0]  v_vel          [0:9];
    reg        v_on           [0:9];

    integer i;
    reg allocated;

    // Инициализация при старте
    integer k_init;
    initial begin
        for (k_init = 0; k_init < 10; k_init = k_init + 1) begin
            v_sample_index[k_init] = 0;
            v_step[k_init] = 0;
            v_note[k_init] = 0;
            v_vel[k_init] = 0;
            v_on[k_init] = 0;
        end
    end

    always @(posedge clk_50) begin
        if (midi_trig) begin
            if (midi_on) begin
                allocated = 0;
                for (i = 0; i < 10; i = i + 1) begin
                    if (!v_on[i] && !allocated) begin
                        v_on[i]           <= 1'b1;
                        v_note[i]         <= midi_note[6:0];
                        v_sample_index[i] <= current_midi_sample_index;
                        v_step[i]         <= current_midi_step;
                        v_vel[i]          <= midi_vel;
                        allocated = 1;
                    end
                end
                if (!allocated) begin
                    v_on[0]           <= 1'b1;
                    v_note[0]         <= midi_note[6:0];
                    v_sample_index[0] <= current_midi_sample_index;
                    v_step[0]         <= current_midi_step;
                    v_vel[0]          <= midi_vel;
                end
            end else begin
                // При Note OFF находим голос, играющий эту ноту, и тушим его
                for (i = 0; i < 10; i = i + 1) begin
                    if (v_on[i] && (v_note[i] == midi_note[6:0])) begin
                        v_on[i] <= 1'b0;
                    end
                end
            end
        end
    end

    wire signed [15:0] v_out [0:9];

    // Описание 10 параллельных голосов
    genvar g;
    generate
        for (g = 0; g < 10; g = g + 1) begin : voices
            // Прокидываем провода памяти к конкретным портам голосов
            wire [31:0] v_addr;
            wire [15:0] v_data;
            
            if (g == 0) begin assign voice_addr_0 = v_addr; assign v_data = voice_data_0; end
            if (g == 1) begin assign voice_addr_1 = v_addr; assign v_data = voice_data_1; end
            if (g == 2) begin assign voice_addr_2 = v_addr; assign v_data = voice_data_2; end
            if (g == 3) begin assign voice_addr_3 = v_addr; assign v_data = voice_data_3; end
            if (g == 4) begin assign voice_addr_4 = v_addr; assign v_data = voice_data_4; end
            if (g == 5) begin assign voice_addr_5 = v_addr; assign v_data = voice_data_5; end
            if (g == 6) begin assign voice_addr_6 = v_addr; assign v_data = voice_data_6; end
            if (g == 7) begin assign voice_addr_7 = v_addr; assign v_data = voice_data_7; end
            if (g == 8) begin assign voice_addr_8 = v_addr; assign v_data = voice_data_8; end
            if (g == 9) begin assign voice_addr_9 = v_addr; assign v_data = voice_data_9; end

            piano_voice voice_inst (
                .clk_lrck(aud_lrck),
                .ram_clk(ram_clk),
                .step(v_step[g]),                 // Из сохраненных регистров голоса
                .sample_index(v_sample_index[g]), // Из сохраненных регистров голоса
                .velocity(v_vel[g]),
                .key_pressed(v_on[g]),
                .audio_out(v_out[g]),
                
                .voice_ram_addr(v_addr),
                .voice_ram_data(v_data)
            );
        end
    endgenerate

    // Смешивание (Микшер)
    wire signed [19:0] mix_sum;
    assign mix_sum = $signed(v_out[0]) + $signed(v_out[1]) + 
                     $signed(v_out[2]) + $signed(v_out[3]) + 
                     $signed(v_out[4]) + $signed(v_out[5]) + 
                     $signed(v_out[6]) + $signed(v_out[7]) + 
                     $signed(v_out[8]) + $signed(v_out[9]);

    wire signed [19:0] mix_scaled = mix_sum >>> 1; 

    wire [15:0] final_audio = (mix_scaled > 20'sd32767)  ? 16'sd32767 :
                              (mix_scaled < -20'sd32768) ? -16'sd32768 :
                              mix_scaled[15:0];

    // Отправка в I2S кодек
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