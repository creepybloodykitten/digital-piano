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

    wire [15:0] decay_step = key_pressed ? 16'd2 : 16'd20;

    always @(posedge clk_lrck) begin
        decay_div <= decay_div + 1'b1;

        if (key_just_pressed) begin
            target_vol <= 16'd5000 + (vel_16 * vel_16 * 16'd3);
            env_state <= ST_ATTACK;
            sample_ptr <= 32'd0; // Сброс указателя строго в момент нажатия
        end 
        else if (!key_pressed && (env_state == ST_ATTACK || env_state == ST_SUSTAIN)) begin
            env_state <= ST_RELEASE;
        end
        else if (sample_ptr[31:12] >= 32'd100000) begin // Автозатухание начинается на 100000
            env_state <= ST_RELEASE;
        end

        if (env_state != ST_IDLE) begin
            sample_ptr <= sample_ptr + step;
        end else begin
            sample_ptr <= 32'd0; 
        end

        // огибающая
        case (env_state)
            ST_IDLE: begin
                envelope <= 16'd0;
            end
            
            ST_ATTACK: begin
                if (envelope + 16'd400 < target_vol) begin
                    envelope <= envelope + 16'd400;
                end else begin
                    envelope <= target_vol;
                    env_state <= ST_SUSTAIN;
                end
            end
            
            ST_SUSTAIN: begin
                if (decay_div == 0) begin
                    if (envelope > 16'd2) envelope <= envelope - 16'd2;
                end
            end
            
            ST_RELEASE: begin
                // Медленное затухание (step = 2) при зажатой клавише или быстрое (step = 20) при отпускании
                if (envelope > decay_step) begin
                    envelope <= envelope - decay_step;
                end else begin
                    envelope <= 16'd0;
                    env_state <= ST_IDLE;
                end
            end
            
            default: env_state <= ST_IDLE;
        endcase
    end

    // Безопасное ограничение указателя 
    wire [19:0] sample_idx_int = sample_ptr[31:12];
    wire [17:0] local_ptr = (sample_idx_int >= 20'd132303) ? 18'd132303 : sample_idx_int[17:0];

    always @(*) begin
        voice_ram_addr = (sample_index * 32'd132304) + local_ptr; 
    end

    // динамический фильтр (LPF) 
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