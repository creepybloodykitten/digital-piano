module uart_to_ram_loader (
    input  wire         clk,             // 175 MHz (ram_clk)
    input  wire         reset_n,
    
    input  wire [7:0]   rx_data,
    input  wire         rx_ready,        // Приходит из 50 MHz
    
    output reg [24:0]   avm_address,     
    output reg [127:0]  avm_writedata,   
    output reg [15:0]   avm_byteenable,  
    output reg          avm_write,
    input  wire         avm_waitrequest,
    
    output reg          mode_play = 0    
);

    reg [31:0] total_samples_to_load = 32'hFFFFFFFF;
    reg [31:0] samples_loaded_counter = 0;

    reg [7:0] byte_buf [0:14];
    reg [3:0] byte_cnt;
    
    reg [1:0] state;
    localparam STATE_GET_LEN  = 2'd0;
    localparam STATE_GET_DATA = 2'd1;
    localparam STATE_WRITE    = 2'd2;

    reg rx_ready_s1, rx_ready_s2, rx_ready_s3;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rx_ready_s1 <= 0;
            rx_ready_s2 <= 0;
            rx_ready_s3 <= 0;
        end else begin
            rx_ready_s1 <= rx_ready;
            rx_ready_s2 <= rx_ready_s1;
            rx_ready_s3 <= rx_ready_s2;
        end
    end
    wire rx_ready_pulse = rx_ready_s2 & ~rx_ready_s3; 

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            avm_address            <= 0;
            avm_write              <= 0;
            avm_byteenable         <= 16'hFFFF;
            byte_cnt               <= 0;
            samples_loaded_counter <= 0;
            mode_play              <= 0;
            total_samples_to_load  <= 32'hFFFFFFFF;
            state                  <= STATE_GET_LEN;
        end else begin
            case (state)
                STATE_GET_LEN: begin 
                    if (rx_ready_pulse) begin 
                        if (byte_cnt == 0) byte_buf[0] <= rx_data;
                        if (byte_cnt == 1) byte_buf[1] <= rx_data;
                        if (byte_cnt == 2) byte_buf[2] <= rx_data;
                        if (byte_cnt == 3) begin
                            total_samples_to_load <= {rx_data, byte_buf[2], byte_buf[1], byte_buf[0]};
                            byte_cnt <= 0;
                            state <= STATE_GET_DATA;
                        end else begin
                            byte_cnt <= byte_cnt + 1;
                        end
                    end
                end

                STATE_GET_DATA: begin 
                    avm_write <= 0; // Гарантируем отсутствие ложных записей во время накопления данных
                    if (rx_ready_pulse) begin 
                        if (byte_cnt == 15) begin
                            avm_writedata <= {
                                rx_data,     byte_buf[14], byte_buf[13], byte_buf[12],
                                byte_buf[11], byte_buf[10], byte_buf[9],  byte_buf[8],
                                byte_buf[7],  byte_buf[6],  byte_buf[5],  byte_buf[4],
                                byte_buf[3],  byte_buf[2],  byte_buf[1],  byte_buf[0]
                            };
                            avm_write <= 1; // <-- Выставляем сигнал записи заранее!
                            state <= STATE_WRITE;
                            byte_cnt <= 0;
                        end else begin
                            byte_buf[byte_cnt] <= rx_data;
                            byte_cnt <= byte_cnt + 1;
                        end
                    end
                end

                STATE_WRITE: begin 
                    if (!avm_waitrequest) begin
                        avm_write <= 0; // <-- Сбрасываем запись только после её подтверждения
                        avm_address <= avm_address + 1; 
                        samples_loaded_counter <= samples_loaded_counter + 8; 
                        
                        if (samples_loaded_counter + 8 >= total_samples_to_load) begin
                            mode_play <= 1;
                            state <= STATE_GET_LEN;
                        end else begin
                            state <= STATE_GET_DATA;
                        end
                    end
                end
            endcase
        end
    end
endmodule