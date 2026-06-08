module piano_voice (
    input  wire clk_lrck,      // 44.1 kHz
    input  wire ram_clk,       // Частота памяти
    input  wire [15:0] step,   // Шаг чтения в формате 12.12
    input  wire [4:0]  sample_index, // Индекс сэмпла (0 до 8)
    input  wire [7:0] velocity, 
    input  wire key_pressed,   
    output wire signed [15:0] audio_out,

    // Интерфейс чтения памяти для этого конкретного голоса
    output reg [31:0] voice_ram_addr,
    input  wire [15:0] voice_ram_data
);

    // Дробный указатель сэмпла (20 бит целая часть, 12 бит дробная)
    reg [31:0] sample_ptr; 
    
    reg last_key;
    always @(posedge clk_lrck) last_key <= key_pressed;
    wire key_just_pressed = key_pressed & ~last_key;

    // Считаем дробный указатель
    always @(posedge clk_lrck) begin
        if (key_just_pressed) begin
            sample_ptr <= 0; // Сбрасываем в начало сэмпла
        end else if (key_pressed || envelope > 16'd30) begin
            sample_ptr <= sample_ptr + step; 
        end
    end

    // Вычисляем абсолютный адрес с учетом смещения конкретного сэмпла в ОЗУ
    always @(*) begin
        voice_ram_addr = (sample_index * 32'd132304) + sample_ptr[31:12]; 
    end

    // Огибающая громкости (Envelope) с замедленным затуханием и защитой от выхода за край
    reg [15:0] envelope = 0;
    reg [5:0] decay_div; 
    wire [15:0] decay_step = 16'd5; 

    always @(posedge clk_lrck) begin
        decay_div <= decay_div + 1'b1;
        if (key_just_pressed) begin
            envelope <= 16'd20000 + ({8'b0, velocity} * 16'd250); 
        end 
        // ЗАЩИТА: Заглушаем звук перед физическим концом сэмпла, чтобы избежать воспроизведения мусора ОЗУ
        else if (sample_ptr[31:12] >= 32'd132290) begin
            envelope <= 0; 
        end
        else if (key_pressed) begin
            if (decay_div == 0) begin // Раз в 64 такта LRCK
                if (envelope > decay_step)
                    envelope <= envelope - decay_step;
                else 
                    envelope <= 0;
            end
        end 
        else begin
            if (envelope > 16'd40) envelope <= envelope - 16'd40;
            else envelope <= 0;
        end
    end

    // Динамический фильтр низких частот (LPF)
    reg signed [23:0] lpf_reg = 0;
    wire signed [23:0] lpf_input = $signed({voice_ram_data, 8'b0}); 
    wire [3:0] k = (envelope > 16'hC000) ? 4'd1 :  
                   (envelope > 16'h8000) ? 4'd2 :  
                   (envelope > 16'h4000) ? 4'd3 :  
                                           4'd4; 

    always @(posedge clk_lrck) begin
        lpf_reg <= lpf_reg + $signed((lpf_input - lpf_reg) >>> k);
    end
    wire signed [15:0] filtered_wave = lpf_reg[23:8];

    // Усилитель (VCA)
    wire signed [16:0] env_signed = $signed({1'b0, envelope});
    wire signed [32:0] mixed_audio = $signed(filtered_wave) * env_signed;
    assign audio_out = mixed_audio[31:16];

endmodule