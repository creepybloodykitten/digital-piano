// module uart_rx #(
//     parameter CLK = 50_000_000,
//     parameter BAUD_RATE =115200
    
// ) (
//     input logic clk, 
//     input logic reset_n,
//     input logic rx_pin,
//     output logic [7:0] rx_data,
//     output logic flag_byte_ready
// );
//     //we can understand how many ticks(time) wait for 1 bit receive
//     localparam ticks_for_bit = CLK / BAUD_RATE;
//     localparam mid_ticks= ticks_for_bit/2;

//     typedef enum logic [2:0]
//     {
//         IDLE,
//         START_BIT,
//         DATA_BITS,
//         STOP_BIT
//     } state_t;

//     state_t state;

//     logic [10:0] timer_bit;//wait ticks_for_time for 1 bit
//     logic [2:0] bit_index;
//     logic [7:0] data_reg;

//     logic reset_flag;

//     //async reset
//     logic rx_sync1,rx_sync2; //double check for input signal
//     always_ff @(posedge clk or negedge reset_n ) begin : sync 
//         if (!reset_n) begin
//             rx_sync1 <=1'b1; //default level = high
//             rx_sync2 <=1'b1;

//         end else begin
//             rx_sync1 <= rx_pin;
//             rx_sync2 <= rx_sync1;
            
//         end
//     end

//     //work with rx_sync2 - input stable signal
//     always_ff @( posedge clk or negedge reset_n  ) begin : main
//         if (!reset_n ) begin
//             state<= IDLE;
//             bit_index       <='0;
//             data_reg	       <='0;
//             timer_bit 		 <='0; 
//             rx_data   		 <='0;
//             flag_byte_ready <=1'b0;

//         end else begin
//             flag_byte_ready <=1'b0;
//             case (state)
//                 //in idle just monitor for input signal changing
//                 IDLE : begin
//                     timer_bit <= '0;
//                     bit_index <= '0;
//                     //by protocol active signal - negative
//                     if (rx_sync2== 1'b0) begin 
//                         state <= START_BIT;
//                     end
//                 end
                
//                 //in start we should verify start bit in mid of signal time and then check every bit after whole time of signal period
//                 START_BIT : begin

//                     if(timer_bit==mid_ticks) begin 
//                         if (rx_sync2 == 1'b0) begin
//                             timer_bit <= '0;
//                             state <= DATA_BITS;
//                         end else begin
//                             state <= IDLE; //false positive
//                         end

//                     end else begin
//                         timer_bit <= timer_bit + 1'b1;
//                     end
//                 end
// 					//так как стартовый бит проверял в середине то теперь всегда имеется смещение и проверка по ней
//                 DATA_BITS: begin
//                     if (timer_bit< ticks_for_bit - 1) begin
//                         timer_bit <= timer_bit + 1;
//                     end else begin
//                         timer_bit <='0;
//                         data_reg[bit_index] <= rx_sync2;

//                         if (bit_index<7) begin
//                             bit_index <= bit_index + 1;
//                         end else begin
//                             bit_index <= '0;
//                             state <= STOP_BIT;
//                         end
//                     end
//                 end

//                 //stop bit==1 so just verify it
//                 STOP_BIT: begin
//                     if (timer_bit< ticks_for_bit - 1) begin
//                         timer_bit <= timer_bit + 1;
//                     end else begin
//                         timer_bit <= '0;  
//                         if (rx_sync2==1'b1) begin 
//                             flag_byte_ready<=1'b1; 
//                             state<= IDLE;
// 									 rx_data <= data_reg; 
//                         end else begin

//                             state<= IDLE;
//                         end
//                     end
                
//                 end
//                 default: state <= IDLE;
//             endcase

//         end
        
//     end

// endmodule

module uart_rx #(
    parameter CLK = 50_000_000
) (
    input logic clk, 
    input logic reset_n,
    input logic rx_pin,
    input logic mode_play, // 0 = Режим загрузки (921600), 1 = Режим игры (115200) [3]
    output logic [7:0] rx_data,
    output logic flag_byte_ready
);

    // Динамический расчет таймингов UART в зависимости от режима работы ПЛИС [3]
    logic [10:0] ticks_for_bit;
    logic [10:0] mid_ticks;

    always_comb begin
        if (mode_play) begin
            // Режим игры: 115200 бод (50 000 000 / 115200 = 434 такта на 1 бит) [3]
            ticks_for_bit = 11'd434; 
            mid_ticks     = 11'd217;
        end else begin
            // Режим загрузки: 921600 бод (50 000 000 / 921600 = 54 такта на 1 бит) [3]
            ticks_for_bit = 11'd54;  
            mid_ticks     = 11'd27;
        end
    end

    typedef enum logic [2:0]
    {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    } state_t;

    state_t state;

    logic [10:0] timer_bit; // Счетчик тиков тактовой частоты
    logic [2:0] bit_index;
    logic [7:0] data_reg;

    // Сдвиговый регистр для защиты от метастабильности (CDC входного пина) [3]
    logic rx_sync1, rx_sync2; 
    always_ff @(posedge clk or negedge reset_n) begin : sync 
        if (!reset_n) begin
            rx_sync1 <= 1'b1; // Линия UART по умолчанию в высоком состоянии (1)
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_pin;
            rx_sync2 <= rx_sync1;
        end
    end

    // Автомат состояний приемника UART [3]
    always_ff @(posedge clk or negedge reset_n) begin : main
        if (!reset_n) begin
            state           <= IDLE;
            bit_index       <= '0;
            data_reg        <= '0;
            timer_bit       <= '0; 
            rx_data         <= '0;
            flag_byte_ready <= 1'b0;
        end else begin
            flag_byte_ready <= 1'b0;
            case (state)
                IDLE : begin
                    timer_bit <= '0;
                    bit_index <= '0;
                    if (rx_sync2 == 1'b0) begin 
                        state <= START_BIT; // Обнаружили спад (старт-бит) [3]
                    end
                end
                
                START_BIT : begin
                    if (timer_bit == mid_ticks) begin 
                        if (rx_sync2 == 1'b0) begin
                            timer_bit <= '0;
                            state     <= DATA_BITS; // Старт-бит валидный, переходим к приему данных [3]
                        end else begin
                            state <= IDLE; // Ложный старт (помеха на линии) [3]
                        end
                    end else begin
                        timer_bit <= timer_bit + 1'b1;
                    end
                end

                DATA_BITS: begin
                    if (timer_bit < ticks_for_bit - 1) begin
                        timer_bit <= timer_bit + 1'b1;
                    end else begin
                        timer_bit <= '0;
                        data_reg[bit_index] <= rx_sync2; // Захватываем бит [3]

                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= '0;
                            state     <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    if (timer_bit < ticks_for_bit - 1) begin
                        timer_bit <= timer_bit + 1'b1;
                    end else begin
                        timer_bit <= '0;  
                        if (rx_sync2 == 1'b1) begin 
                            flag_byte_ready <= 1'b1; 
                            rx_data         <= data_reg; // Байт успешно принят! [3]
                        end
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule