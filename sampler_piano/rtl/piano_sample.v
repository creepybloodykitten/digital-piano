module piano_sample(
	output wire      LEDG0,
	output wire      LEDG1,
	input  wire      KEY,

	//////////// CLOCK //////////
	//input 		          		CLOCK_125_p,
	input 		          		CLOCK_50_B5B,
	// input 		          		CLOCK_50_B6A,
	// input 		          		CLOCK_50_B7A,
	// input 		          		CLOCK_50_B8A,

	//////////// Audio //////////
	//input 		          		AUD_ADCDAT,
	output  		          		AUD_ADCLRCK,
	output  		          		AUD_BCLK,
	output		          		AUD_DACDAT,
	output  		          		AUD_DACLRCK,
	output		          		AUD_XCK,

	//////////// I2C for Audio/HDMI-TX/Si5338/HSMC //////////
	output		          		I2C_SCL,
	inout 		          		I2C_SDA,

	//////////// SDCARD //////////
	// output		          		SD_CLK,
	// inout 		          		SD_CMD,
	// inout 		     [3:0]		SD_DAT,

	//////////// Uart to USB //////////
	input 		          		UART_RX,
	// output		          		UART_TX,

	//////////// SRAM //////////
	// output		    [17:0]		SRAM_A,
	// output		          		SRAM_CE_n,
	// inout 		    [15:0]		SRAM_D,
	// output		          		SRAM_LB_n,
	// output		          		SRAM_OE_n,
	// output		          		SRAM_UB_n,
	// output		          		SRAM_WE_n,

	//////////// LPDDR2 //////////
	output		     [9:0]		DDR2LP_CA,
	output		          		DDR2LP_CK_n,
	output		          		DDR2LP_CK_p,
	output		     [1:0]		DDR2LP_CKE,
	output		     [1:0]		DDR2LP_CS_n,
	output		     [3:0]		DDR2LP_DM,
	inout 		    [31:0]		DDR2LP_DQ,
	inout 		     [3:0]		DDR2LP_DQS_n,
	inout 		     [3:0]		DDR2LP_DQS_p,
	input 		          		DDR2LP_OCT_RZQ
);

	// =======================================================
    // I2C Конфигурация аудиокодека

	// Кодеку нужно, чтобы ADC и DAC LRCK были одинаковыми
	assign AUD_ADCLRCK = AUD_DACLRCK;
	wire rst_n = KEY;
	//init config
	I2C_AV_Config cfg_inst (
		.iCLK    (CLOCK_50_B5B), 
		.iRST_N  (rst_n),
		.I2C_SCLK(I2C_SCL),
		.I2C_SDAT(I2C_SDA)
	);

	// Переключатель режимов: 0 - загрузка по UART, 1 - игра
    wire mode_play; 
	assign LEDG1 = mode_play;  

	// =======================================================
    // UART Приемник 
	wire [7:0] rx_byte;
    wire rx_ready;

    uart_rx #(.CLK(50000000)) rx_inst (
        .clk(CLOCK_50_B5B),
        .reset_n(1'b1),
        .rx_pin(UART_RX), 
        .rx_data(rx_byte),
        .flag_byte_ready(rx_ready),
        .mode_play(mode_play)
    );

	// =======================================================
    // MIDI Декодер
	wire [7:0] midi_note, midi_vel;
    wire midi_on, midi_trig;

    midi_decoder m_dec (
        .clk(CLOCK_50_B5B),
        .rx_ready(rx_ready),
        .rx_data(rx_byte),
        .out_note(midi_note),
        .out_velocity(midi_vel),
        .out_on(midi_on),
        .out_trig(midi_trig)
    );

	// =======================================================
    // Загрузчик сэмплов по UART

    wire [24:0] loader_addr;
    wire [127:0] loader_data;
    wire [15:0]  loader_byteenable;
    wire        loader_write;
    wire        loader_waitreq;
    wire        ram_clk; // Высокоскоростной клок памяти

    uart_to_ram_loader loader_inst (
        .clk            (ram_clk),
        .reset_n        (rst_n),
        .rx_data        (rx_byte),
        .rx_ready       (rx_ready & ~mode_play), // Принимаем байты только в режиме загрузки
        
        .avm_address    (loader_addr),
        .avm_writedata  (loader_data),
        .avm_byteenable (loader_byteenable),
        .avm_write      (loader_write),
        .avm_waitrequest(loader_waitreq & ~mode_play),
        
        .mode_play      (mode_play) // Сигнал готовности уходит на светодиод и переключает шину
    );

    // =======================================================
    // Читатель сэмплов для 10 параллельных голосов

	wire [24:0]  fetcher_addr;       
    wire         fetcher_read;
    wire [127:0] fetcher_readdata;   
    wire         fetcher_readdatavalid;
    wire         fetcher_waitreq;
    wire         fetcher_stuck;
    wire         fetcher_has_data; 

    wire [31:0] voice_addr [0:9];
    wire [15:0] voice_data [0:9];

    memory_fetcher fetcher_inst (
        .clk                  (ram_clk),
        .rst_n                (rst_n & mode_play),
        .lrck                 (AUD_DACLRCK),

        // К LPDDR2
        .avm_address          (fetcher_addr),
        .avm_read             (fetcher_read),
        .avm_waitrequest      (fetcher_waitreq & mode_play),
        .avm_readdata         (fetcher_readdata),
        .avm_readdatavalid    (fetcher_readdatavalid),

        .fetcher_stuck        (fetcher_stuck),
        .fetcher_has_data     (fetcher_has_data), 

        // К голосам
        .voice_addr_0(voice_addr[0]), .voice_data_0(voice_data[0]),
        .voice_addr_1(voice_addr[1]), .voice_data_1(voice_data[1]),
        .voice_addr_2(voice_addr[2]), .voice_data_2(voice_data[2]),
        .voice_addr_3(voice_addr[3]), .voice_data_3(voice_data[3]),
        .voice_addr_4(voice_addr[4]), .voice_data_4(voice_data[4]),
        .voice_addr_5(voice_addr[5]), .voice_data_5(voice_data[5]),
        .voice_addr_6(voice_addr[6]), .voice_data_6(voice_data[6]),
        .voice_addr_7(voice_addr[7]), .voice_data_7(voice_data[7]),
        .voice_addr_8(voice_addr[8]), .voice_data_8(voice_data[8]),
        .voice_addr_9(voice_addr[9]), .voice_data_9(voice_data[9])
    );

    // =======================================================
    // МУЛЬТИПЛЕКСОР ШИНЫ ПАМЯТИ

    wire [24:0]  avl_address    = (mode_play) ? fetcher_addr : loader_addr;
    wire [127:0] avl_writedata  = (mode_play) ? 128'd0       : loader_data;
    wire [15:0]  avl_byteenable = (mode_play) ? 16'hFFFF     : loader_byteenable;
    wire         avl_write      = (mode_play) ? 1'b0         : loader_write;
    wire         avl_read       = (mode_play) ? fetcher_read : 1'b0;
    
    wire        avl_waitrequest_n; // Провод для инверсного сигнала от Qsys
    wire        avl_waitrequest = ~avl_waitrequest_n; // Инвертируем: 0 (занят) превращается в 1 (занят)
    
    assign      loader_waitreq  = avl_waitrequest;
    assign      fetcher_waitreq = avl_waitrequest;


	// =======================================================
    // Qsys Система Контроллера LPDDR2

 	wire mem_init_done;
    wire mem_cal_success;
    
    //assign LEDG0 = mem_cal_success; 
    assign LEDG0 = (mode_play) ? (fetcher_has_data & ~fetcher_stuck) : mem_cal_success;
 
    
    wire memory_mem_cke_wire;
    wire memory_mem_cs_n_wire;
    
    assign DDR2LP_CKE  = {1'b0, memory_mem_cke_wire};
    assign DDR2LP_CS_n = {1'b1, memory_mem_cs_n_wire}; 

    lpddr2_qsys u0 (
        .clk_clk                             (CLOCK_50_B5B),
        .reset_reset_n                       (rst_n),
        
        // Пины к памяти
        .memory_mem_ca                       (DDR2LP_CA),
        .memory_mem_ck                       (DDR2LP_CK_p),
        .memory_mem_ck_n                     (DDR2LP_CK_n),
        .memory_mem_cke                      (memory_mem_cke_wire),
        .memory_mem_cs_n                     (memory_mem_cs_n_wire),
        .memory_mem_dm                       (DDR2LP_DM),
        .memory_mem_dq                       (DDR2LP_DQ),
        .memory_mem_dqs                      (DDR2LP_DQS_p),
        .memory_mem_dqs_n                    (DDR2LP_DQS_n),
        
        .oct_rzqin                           (DDR2LP_OCT_RZQ),
        
        // Шина данных
        .mem_if_lpddr2_emif_0_avl_address    (avl_address),
        .mem_if_lpddr2_emif_0_avl_write      (avl_write),
        .mem_if_lpddr2_emif_0_avl_writedata  (avl_writedata),
        .mem_if_lpddr2_emif_0_avl_byteenable (avl_byteenable),
        .mem_if_lpddr2_emif_0_avl_waitrequest_n(avl_waitrequest_n), 
        .mem_if_lpddr2_emif_0_avl_read       (avl_read),
        .mem_if_lpddr2_emif_0_avl_readdata   (fetcher_readdata),
        .mem_if_lpddr2_emif_0_avl_readdatavalid(fetcher_readdatavalid),
        .mem_if_lpddr2_emif_0_avl_beginbursttransfer(1'b0),
        .mem_if_lpddr2_emif_0_avl_burstcount(3'b001),
        
        .mem_if_lpddr2_emif_0_afi_clk_clk    (ram_clk),
        
        .mem_if_lpddr2_emif_0_status_local_init_done  (mem_init_done),
        .mem_if_lpddr2_emif_0_status_local_cal_success(mem_cal_success),
        .mem_if_lpddr2_emif_0_status_local_cal_fail   ()
    );

	// =======================================================
	// Синтезатор (Играет готовые сэмплы из памяти)

    Simple_I2S_Tone audio_inst (
        .clk_50              (CLOCK_50_B5B),
        .ram_clk             (ram_clk),
        
        // Аудио выходы кодека
        .aud_xck             (AUD_XCK),
        .aud_bclk            (AUD_BCLK),
        .aud_lrck            (AUD_DACLRCK),
        .aud_dat             (AUD_DACDAT),

        // Связь с декодированным MIDI
        .midi_note           (midi_note),
        .midi_vel            (midi_vel),
        .midi_on             (midi_on),
        .midi_trig           (midi_trig),

        // Связь с памятью для каждого голоса
        .voice_addr_0(voice_addr[0]), .voice_data_0(voice_data[0]),
        .voice_addr_1(voice_addr[1]), .voice_data_1(voice_data[1]),
        .voice_addr_2(voice_addr[2]), .voice_data_2(voice_data[2]),
        .voice_addr_3(voice_addr[3]), .voice_data_3(voice_data[3]),
        .voice_addr_4(voice_addr[4]), .voice_data_4(voice_data[4]),
        .voice_addr_5(voice_addr[5]), .voice_data_5(voice_data[5]),
        .voice_addr_6(voice_addr[6]), .voice_data_6(voice_data[6]),
        .voice_addr_7(voice_addr[7]), .voice_data_7(voice_data[7]),
        .voice_addr_8(voice_addr[8]), .voice_data_8(voice_data[8]),
        .voice_addr_9(voice_addr[9]), .voice_data_9(voice_data[9])
    );

endmodule
