module midi_decoder (
    input clk,
    input rx_ready,
    input [7:0] rx_data,
    
    output reg [7:0] out_note,
    output reg [7:0] out_velocity,
    output reg       out_on,  
    output reg       out_trig 
);

    reg [1:0] state = 0; 
    reg [7:0] running_status = 0;
    reg [7:0] note_temp;

    always @(posedge clk) begin
        out_trig <= 0;
        
        if (rx_ready) begin
            if (rx_data[7]) begin
                // ИСПРАВЛЕНО: реагируем на статус-байт только если это Note ON (0x9_) или Note OFF (0x8_).
                // Все остальные сообщения (системные, CC, Active Sensing 0xFE) отфильтровываются.
                if (rx_data[7:4] == 4'h9 || rx_data[7:4] == 4'h8) begin
                    running_status <= rx_data;
                    state <= 1; // Переходим к ожиданию первого байта данных (Ноты)
                end
            end 
            else begin
                // Пришел Data Byte
                case (state)
                    0: begin
                        // Сработал Running Status (статус не передавался повторно)
                        if (running_status[7:4] == 4'h9 || running_status[7:4] == 4'h8) begin
                            note_temp <= rx_data;
                            state <= 2; // Ожидаем Velocity
                        end
                    end
                    1: begin 
                        // Обычный прием ноты после Status Byte
                        note_temp <= rx_data;
                        state <= 2;
                    end
                    2: begin 
                        // Пришел Velocity
                        out_note <= note_temp;
                        out_velocity <= rx_data;
                        
                        // Если это команда Note ON (0x9_) и Velocity > 0
                        if ((running_status[7:4] == 4'h9) && (rx_data > 0)) begin
                            out_on <= 1;
                        end else begin
                            // Команда Note OFF (0x8_) ИЛИ Note ON с Velocity == 0
                            out_on <= 0;
                        end
                        
                        out_trig <= 1;
                        state <= 0; // Сброс состояния для ожидания следующих данных
                    end
                    default: state <= 0;
                endcase
            end
        end
    end
endmodule