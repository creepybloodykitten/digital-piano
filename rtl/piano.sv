//top-level
module piano(
    input  wire CLOCK_50_B5B, // 50МГц
    input  wire [3:0] KEY,    // Кнопка KEY0 для сброса, остальные для управления 

    // I2C
    output wire I2C_SCL,
    inout  wire I2C_SDAT,

    // Аудио пины
    output wire AUD_XCK,      // Master Clock кодека
    output wire AUD_BCLK,     // Bit Clock
    output wire AUD_DACLRCK,  // Left/Right Clock
    output wire AUD_DACDAT,   // Данные
    output wire AUD_ADCLRCK,   // сигнал синхронизации для каналов ацп
	 
	 input  wire uart_rx_pin
);

    // Кодеку нужно, чтобы ADC и DAC LRCK были одинаковыми
    assign AUD_ADCLRCK = AUD_DACLRCK;
    wire rst_n = KEY[0];

	 //init config
	 I2C_AV_Config cfg_inst (
		  .iCLK    (CLOCK_50_B5B), 
		  .iRST_N  (rst_n),
		  .I2C_SCLK(I2C_SCL),
		  .I2C_SDAT(I2C_SDAT)
	 );

    // Модуль генерации звука (I2S)
    Simple_I2S_Tone audio_inst (
        .clk_50  (CLOCK_50_B5B),
		  .keys    (KEY[3:1]),
        .aud_xck (AUD_XCK),
        .aud_bclk(AUD_BCLK),
        .aud_lrck(AUD_DACLRCK),
        .aud_dat (AUD_DACDAT),
		  .rx_pin(uart_rx_pin)
    );

endmodule

