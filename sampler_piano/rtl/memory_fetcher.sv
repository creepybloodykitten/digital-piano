module memory_fetcher (
    input  wire         clk,             // ram_clk (~150-175 MHz)
    input  wire         rst_n,
    input  wire         lrck,            // Приходит асинхронно из 50 MHz домена

    output reg [24:0]   avm_address,     
    output reg          avm_read,
    input  wire         avm_waitrequest,
    input  wire [127:0] avm_readdata,    
    input  wire         avm_readdatavalid,
    
    output wire         fetcher_stuck,   // Индикатор зависания шины чтения
    output reg          fetcher_has_data,// Диагностика: получили ли ненулевые данные

    // Интерфейс к 10 голосам
    input  wire [31:0]  voice_addr_0, output reg [15:0] voice_data_0,
    input  wire [31:0]  voice_addr_1, output reg [15:0] voice_data_1,
    input  wire [31:0]  voice_addr_2, output reg [15:0] voice_data_2,
    input  wire [31:0]  voice_addr_3, output reg [15:0] voice_data_3,
    input  wire [31:0]  voice_addr_4, output reg [15:0] voice_data_4,
    input  wire [31:0]  voice_addr_5, output reg [15:0] voice_data_5,
    input  wire [31:0]  voice_addr_6, output reg [15:0] voice_data_6,
    input  wire [31:0]  voice_addr_7, output reg [15:0] voice_data_7,
    input  wire [31:0]  voice_addr_8, output reg [15:0] voice_data_8,
    input  wire [31:0]  voice_addr_9, output reg [15:0] voice_data_9
);

    reg [3:0] current_voice;
    reg [1:0] state;
    

    // синхронизация
    reg lrck_sync_0, lrck_sync_1, lrck_sync_2;
    always @(posedge clk) begin 
        lrck_sync_0 <= lrck;
        lrck_sync_1 <= lrck_sync_0;
        lrck_sync_2 <= lrck_sync_1;
    end
    wire start_fetch = lrck_sync_1 & ~lrck_sync_2;


    reg [15:0] stuck_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stuck_counter <= 0;
        end else if (state == 2) begin
            if (stuck_counter < 16'hFFFF)
                stuck_counter <= stuck_counter + 1'b1;
        end else begin
            stuck_counter <= 0;
        end
    end
    assign fetcher_stuck = (stuck_counter > 16'd5000);

    // наличие не нулевых данных
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fetcher_has_data <= 0;
        end else if (avm_readdatavalid && avm_readdata != 128'd0) begin
            fetcher_has_data <= 1; // Защелкиваем единицу, если прочитали не ноль
        end
    end

    // fsm
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            avm_read <= 0;
            avm_address <= 0;
            current_voice <= 0;
        end else begin
            case (state)
                0: begin
                    if (start_fetch) begin
                        current_voice <= 0;
                        avm_read <= 1; 
                        avm_address <= voice_addr_0[27:3]; 
                        state <= 1;
                    end
                end

                1: begin 
                    if (!avm_waitrequest) begin
                        avm_read <= 0; 
                        state <= 2;
                    end
                end

                2: begin 
                    if (avm_readdatavalid) begin
                        reg [2:0] sel;
                        case (current_voice)
                            0: sel = voice_addr_0[2:0];
                            1: sel = voice_addr_1[2:0];
                            2: sel = voice_addr_2[2:0];
                            3: sel = voice_addr_3[2:0];
                            4: sel = voice_addr_4[2:0];
                            5: sel = voice_addr_5[2:0];
                            6: sel = voice_addr_6[2:0];
                            7: sel = voice_addr_7[2:0];
                            8: sel = voice_addr_8[2:0];
                            9: sel = voice_addr_9[2:0];
                            default: sel = 0;
                        endcase

                        case (current_voice)
                            0: voice_data_0 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                            1: voice_data_1 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                            2: voice_data_2 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                            3: voice_data_3 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                            4: voice_data_4 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                            5: voice_data_5 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                            6: voice_data_6 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                            7: voice_data_7 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                            8: voice_data_8 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                            9: voice_data_9 <= (sel == 3'd0) ? avm_readdata[15:0]   : (sel == 3'd1) ? avm_readdata[31:16]  : (sel == 3'd2) ? avm_readdata[47:32]  : (sel == 3'd3) ? avm_readdata[63:48]  : (sel == 3'd4) ? avm_readdata[79:64]  : (sel == 3'd5) ? avm_readdata[95:80]  : (sel == 3'd6) ? avm_readdata[111:96]  : avm_readdata[127:112];
                        endcase

                        if (current_voice == 9) begin
                            state <= 0;
                        end else begin
                            current_voice <= current_voice + 1;
                            avm_read <= 1; 
                            case (current_voice)
                                0: avm_address <= voice_addr_1[27:3];
                                1: avm_address <= voice_addr_2[27:3];
                                2: avm_address <= voice_addr_3[27:3];
                                3: avm_address <= voice_addr_4[27:3];
                                4: avm_address <= voice_addr_5[27:3];
                                5: avm_address <= voice_addr_6[27:3];
                                6: avm_address <= voice_addr_7[27:3];
                                7: avm_address <= voice_addr_8[27:3];
                                8: avm_address <= voice_addr_9[27:3];
                                default: avm_address <= 0;
                            endcase
                            state <= 1;
                        end
                    end
                end
            endcase
        end
    end
endmodule