
module piano_voice (
    input  wire clk_lrck,      // 44.1 kHz
    input  wire ram_clk,       // Частота памяти
    input  wire [15:0] step,   // Шаг чтения в формате 12.12
    input  wire [4:0]  sample_index, 
    input  wire [7:0] velocity, 
    input  wire key_pressed,   
    output wire signed [15:0] audio_out,

    output reg [31:0] voice_ram_addr,
    input  wire [15:0] voice_ram_data
);

    // Автомат состояний огибающей (ADSR)
    localparam ST_IDLE    = 2'd0;
    localparam ST_ATTACK  = 2'd1;
    localparam ST_SUSTAIN = 2'd2;
    localparam ST_RELEASE = 2'd3;

    reg [1:0]  env_state = ST_IDLE;
    reg [15:0] envelope = 0;
    reg [15:0] target_vol = 0;
    
    reg [31:0] sample_ptr = 0; 
    reg [5:0]  decay_div = 0;

    reg last_key;
    always @(posedge clk_lrck) last_key <= key_pressed;
    wire key_just_pressed = key_pressed & ~last_key;
    
    // Расширяем velocity до 16 бит для формулы
    wire [15:0] vel_16 = {8'b0, velocity};

    always @(posedge clk_lrck) begin
        decay_div <= decay_div + 1'b1;

        // --- УПРАВЛЕНИЕ СОСТОЯНИЯМИ ---
        if (key_just_pressed) begin
            // Твоя формула логарифмической/квадратичной громкости от Velocity
            target_vol <= 16'd5000 + (vel_16 * vel_16 * 16'd3);
            env_state <= ST_ATTACK;
            sample_ptr <= 0; // Начинаем сэмпл заново
            // Важно: мы НЕ сбрасываем envelope в 0 моментально, чтобы избежать щелчка при краже голоса
        end 
        else if (!key_pressed && (env_state == ST_ATTACK || env_state == ST_SUSTAIN)) begin
            // Кнопку отпустили — переходим к плавному затуханию
            env_state <= ST_RELEASE;
        end
        else if (sample_ptr[31:12] >= 32'd130000) begin
            // ЗАЩИТА: Сэмпл скоро кончится (132304 макс). Начинаем плавно затухать заранее!
            env_state <= ST_RELEASE;
        end

        // --- ДВИЖЕНИЕ УКАЗАТЕЛЯ СЭМПЛА ---
        if (env_state != ST_IDLE) begin
            sample_ptr <= sample_ptr + step;
        end

        // --- ЛОГИКА ОГИБАЮЩЕЙ (ENVELOPE) ---
        case (env_state)
            ST_IDLE: begin
                envelope <= 0;
            end
            
            ST_ATTACK: begin
                // Плавная атака (прибавляем по 400). Избавляет от щелчка в начале ноты!
                // Это займет около 3-5 миллисекунд, ухо не заметит задержки, но щелчок пропадет.
                if (envelope + 16'd400 < target_vol) begin
                    envelope <= envelope + 16'd400;
                end else begin
                    envelope <= target_vol;
                    env_state <= ST_SUSTAIN;
                end
            end
            
            ST_SUSTAIN: begin
                // Медленное естественное затухание пока клавиша зажата
                if (decay_div == 0) begin
                    if (envelope > 16'd2) envelope <= envelope - 16'd2;
                end
            end
            
            ST_RELEASE: begin
                // Плавный хвост при отпускании (отпускаем педаль/клавишу)
                // Отнимаем по 15 единиц: полное затухание займет около 100-150 мс
                if (envelope > 16'd15) begin
                    envelope <= envelope - 16'd15;
                end else begin
                    envelope <= 0;
                    env_state <= ST_IDLE; // Звук полностью стих, отключаем голос
                end
            end
        endcase
    end

    // Вычисление адреса ОЗУ
    always @(*) begin
        voice_ram_addr = (sample_index * 32'd132304) + sample_ptr[31:12]; 
    end

    // --- ДИНАМИЧЕСКИЙ ФИЛЬТР (LPF) ---
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

    // --- УСИЛИТЕЛЬ (VCA) ---
    wire signed [16:0] env_signed = $signed({1'b0, envelope});
    wire signed [32:0] mixed_audio = $signed(filtered_wave) * env_signed;
    assign audio_out = mixed_audio[31:16];

endmodule


// module piano_voice (
//     input  wire clk_lrck,      // 44.1 kHz
//     input  wire ram_clk,       // Частота памяти
//     input  wire [15:0] step,   // Шаг чтения в формате 12.12
//     input  wire [4:0]  sample_index, 
//     input  wire [7:0] velocity, 
//     input  wire key_pressed,   
//     output wire signed [15:0] audio_out,

//     // Интерфейс чтения памяти для этого конкретного голоса
//     output reg [31:0] voice_ram_addr,
//     input  wire [15:0] voice_ram_data
// );

//     // Автомат состояний огибающей (ADSR)
//     localparam ST_IDLE    = 2'd0;
//     localparam ST_ATTACK  = 2'd1;
//     localparam ST_SUSTAIN = 2'd2;
//     localparam ST_RELEASE = 2'd3;

//     reg [1:0]  env_state = ST_IDLE;
//     reg [15:0] envelope = 0;
//     reg [15:0] target_vol = 0;
    
//     reg [31:0] sample_ptr = 0; 
//     reg [5:0]  decay_div = 0;

//     reg last_key;
//     always @(posedge clk_lrck) last_key <= key_pressed;
//     wire key_just_pressed = key_pressed & ~last_key;

//     wire [15:0] vel_16 = {8'b0, velocity};

//     always @(posedge clk_lrck) begin
//         decay_div <= decay_div + 1'b1;

//         // --- УПРАВЛЕНИЕ СОСТОЯНИЯМИ ---
//         if (key_just_pressed) begin
//             target_vol <= 16'd10000 + ((vel_16 * vel_16 * 110) >>> 5); // Громкая огибающая
//             env_state <= ST_ATTACK;
//             sample_ptr <= 0; 
//         end 
//         else if (!key_pressed && (env_state == ST_ATTACK || env_state == ST_SUSTAIN)) begin
//             env_state <= ST_RELEASE;
//         end
//         else if (sample_ptr[31:12] >= 32'd130000) begin
//             env_state <= ST_RELEASE; // Защита от выхода за границы сэмпла
//         end

//         // --- ДВИЖЕНИЕ УКАЗАТЕЛЯ СЭМПЛА ---
//         if (env_state != ST_IDLE) begin
//             sample_ptr <= sample_ptr + step;
//         end

//         // --- ЛОГИКА ОГИБАЮЩЕЙ (ENVELOPE) ---
//         case (env_state)
//             ST_IDLE: begin
//                 envelope <= 0;
//             end
            
//             ST_ATTACK: begin
//                 if (envelope + 16'd400 < target_vol) begin
//                     envelope <= envelope + 16'd400;
//                 end else begin
//                     envelope <= target_vol;
//                     env_state <= ST_SUSTAIN;
//                 end
//             end
            
//             ST_SUSTAIN: begin
//                 if (decay_div == 0) begin
//                     if (envelope > 16'd2) envelope <= envelope - 16'd2;
//                 end
//             end
            
//             ST_RELEASE: begin
//                 if (envelope > 16'd15) begin
//                     envelope <= envelope - 16'd15;
//                 end else begin
//                     envelope <= 0;
//                     env_state <= ST_IDLE; 
//                 end
//             end
//         endcase
//     end

//     // Вычисление адреса ОЗУ
//     always @(*) begin
//         voice_ram_addr = (sample_index * 32'd132304) + sample_ptr[31:12]; 
//     end

//     // --- ДИНАМИЧЕСКИЙ ФИЛЬТР (LPF) ---
//     reg signed [23:0] lpf_reg = 0;
//     wire signed [23:0] lpf_input = $signed({voice_ram_data, 8'b0}); 
//     wire [3:0] k = (envelope > 16'hC000) ? 4'd1 :  
//                    (envelope > 16'h8000) ? 4'd2 :  
//                    (envelope > 16'h4000) ? 4'd3 :  
//                                            4'd4; 

//     always @(posedge clk_lrck) begin
//         lpf_reg <= lpf_reg + $signed((lpf_input - lpf_reg) >>> k);
//     end
//     wire signed [15:0] filtered_wave = lpf_reg[23:8];

//     // --- УСИЛИТЕЛЬ (VCA) ---
//     wire signed [16:0] env_signed = $signed({1'b0, envelope});
//     wire signed [32:0] mixed_audio = $signed(filtered_wave) * env_signed;
//     assign audio_out = mixed_audio[31:16];

// endmodule