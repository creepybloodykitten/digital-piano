// module midi_decoder (
//     input clk,
//     input rx_ready,
//     input [7:0] rx_data,
    
//     output reg [7:0] out_note,
//     output reg [7:0] out_velocity,
//     output reg       out_on,  // 1 - нажать, 0 - отпустить
//     output reg       out_trig // импульс на 1 такт при получении пакета
// );

//     reg [2:0] state = 0;
//     reg [7:0] note_temp;
//     reg is_note_on;

//     always @(posedge clk) begin
//         out_trig <= 0;
//         if (rx_ready) begin
//             case (state)
//                 0: begin
//                     if (rx_data[7:4] == 4'h9) begin      // Note On
//                         is_note_on <= 1;
//                         state <= 1;
//                     end else if (rx_data[7:4] == 4'h8) begin // Note Off
//                         is_note_on <= 0;
//                         state <= 1;
//                     end
//                 end
//                 1: begin // Байт ноты
//                     note_temp <= rx_data;
//                     state <= 2;
//                 end
//                 2: begin // Байт силы
//                     out_note <= note_temp;
//                     // Если Note On пришел с Velocity 0, это тоже Note Off по стандарту
//                     if (is_note_on && rx_data > 0) begin
//                         out_velocity <= rx_data;
//                         out_on <= 1;
//                     end else begin
//                         out_velocity <= 0;
//                         out_on <= 0;
//                     end
//                     out_trig <= 1;
//                     state <= 0;
//                 end
//             endcase
//         end
//     end
// endmodule

module midi_decoder (
    input clk,
    input rx_ready,
    input [7:0] rx_data,
    
    output reg [7:0] out_note,
    output reg[7:0] out_velocity,
    output reg       out_on,  
    output reg       out_trig 
);

    reg [2:0] state = 0; // Увеличили размер регистра состояния до 3 бит
    reg [7:0] cmd_type;
    reg[7:0] note_temp;

    always @(posedge clk) begin
        out_trig <= 0;
        
        // Обработка входящих байтов
        if (rx_ready) begin
            case (state)
                0: begin
                    if (rx_data[7]) begin
                        cmd_type <= rx_data;
                        state <= 1;
                    end
                end
                
                1: begin 
                    note_temp <= rx_data;
                    state <= 2;
                end
                
                2: begin 
                    if ((cmd_type[7:4] == 4'h9) && (rx_data > 0)) begin
                        // NOTE ON: Сначала выставляем ноту и силу!
                        out_note <= note_temp;
                        out_velocity <= rx_data;
                        
                        // Сигнал out_on НЕ ТРОГАЕМ. Переходим в состояние задержки.
                        state <= 3; 
                    end else begin
                        // NOTE OFF: Тут скорость не важна, сразу выключаем
                        out_on <= 0;
                        out_trig <= 1;
                        state <= 0;
                    end
                end
            endcase
            
        // А вот если мы в состоянии задержки (данные уже стабильны):
        end else if (state == 3) begin
            out_on <= 1;   // Даем команду звуковому модулю!
            out_trig <= 1;
            state <= 0;    // Возвращаемся в ожидание
        end
    end
endmodule