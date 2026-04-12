module Simple_I2S_Tone(
    input  wire clk_50,
    input  wire [2:0] keys, 
    
    output wire aud_xck, //(Master Clock / Главный клок чипа)
    output wire aud_bclk, //(Bit Clock) - для синхронизации данных получения и отправки
    output wire aud_lrck, //(Left-Right Clock) переключатель канала, 0 - левый канал, 1 - правый, по сути Sample Rate
    output wire aud_dat // данные
);
    // делители частоты
    reg [9:0] audio_cnt = 0;
    always @(posedge clk_50) audio_cnt <= audio_cnt + 1'b1;

    assign aud_xck  = audio_cnt[1]; 
    assign aud_bclk = audio_cnt[3]; 
    assign aud_lrck = audio_cnt[9]; 

    // блок управления
    wire press_Do = ~keys[0]; 
    wire press_Re = ~keys[1]; 
    wire press_Mi = ~keys[2]; 
    wire any_key_pressed = press_Do | press_Re | press_Mi;

    // когда мы отпускаем кнопку, генератор продолжает вибрировать
    // на той же частоте, пока звук плавно затухает
    reg [15:0] current_freq = 0;
    always @(posedge aud_lrck) begin
        if      (press_Do) current_freq <= 16'd350; 
        else if (press_Re) current_freq <= 16'd393; 
        else if (press_Mi) current_freq <= 16'd442; 
    end

    // аккумулятор фазы
    reg [15:0] phase_acc = 0;
    always @(posedge aud_lrck) begin
        phase_acc <= phase_acc + current_freq;
    end

    // таблица синуса
    wire [4:0] rom_index = phase_acc[15:11];
    reg signed [15:0] sine_wave;
    
    always @(*) begin
        case(rom_index)
            5'd0 : sine_wave =  16'd0;
            5'd1 : sine_wave =  16'd6242;
            5'd2 : sine_wave =  16'd12245;
            5'd3 : sine_wave =  16'd17760;
            5'd4 : sine_wave =  16'd22627;
            5'd5 : sine_wave =  16'd26607;
            5'd6 : sine_wave =  16'd29560;
            5'd7 : sine_wave =  16'd31384;
            5'd8 : sine_wave =  16'd32000; 
            5'd9 : sine_wave =  16'd31384;
            5'd10: sine_wave =  16'd29560;
            5'd11: sine_wave =  16'd26607;
            5'd12: sine_wave =  16'd22627;
            5'd13: sine_wave =  16'd17760;
            5'd14: sine_wave =  16'd12245;
            5'd15: sine_wave =  16'd6242;
            5'd16: sine_wave =  16'd0;    
            5'd17: sine_wave = -16'd6242;
            5'd18: sine_wave = -16'd12245;
            5'd19: sine_wave = -16'd17760;
            5'd20: sine_wave = -16'd22627;
            5'd21: sine_wave = -16'd26607;
            5'd22: sine_wave = -16'd29560;
            5'd23: sine_wave = -16'd31384;
            5'd24: sine_wave = -16'd32000; 
            5'd25: sine_wave = -16'd31384;
            5'd26: sine_wave = -16'd29560;
            5'd27: sine_wave = -16'd26607;
            5'd28: sine_wave = -16'd22627;
            5'd29: sine_wave = -16'd17760;
            5'd30: sine_wave = -16'd12245;
            5'd31: sine_wave = -16'd6242;
            default: sine_wave = 16'd0;
        endcase
    end

    // огибающая (ADSR)
    reg [15:0] envelope = 0; 
    
    reg last_any_key;
    always @(posedge aud_lrck) last_any_key <= any_key_pressed;
    wire key_just_pressed = any_key_pressed & ~last_any_key; 

    // делитель, чтобы звук тянулся дольше
    reg [2:0] decay_div = 0;

    always @(posedge aud_lrck) begin
        decay_div <= decay_div + 1'b1;

        if (key_just_pressed) begin
            envelope <= 16'hFFFF; // удар (максимум)
        end 
        else if (any_key_pressed) begin
            // медленное затухание удержанной струны
            if (decay_div == 0 && envelope > 0) envelope <= envelope - 16'd01; 
        end 
        else begin
            // быстрое затухание после отпускания 
            if (envelope > 16'd30) envelope <= envelope - 16'd30;
            else envelope <= 0;
        end
    end


    // явно делаем громкость 17-битным положительным числом
    wire signed [16:0] env_signed = {1'b0, envelope};
    
    // умножаем 16-битный синус на 17-битную громкость Результат - 33 бита
    wire signed [32:0] mixed_audio = sine_wave * env_signed;
    
    // 16 нужных бит (это эквивалент деления результата на 65536)
    wire [15:0] final_audio = mixed_audio[31:16];

    // передача i2s
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