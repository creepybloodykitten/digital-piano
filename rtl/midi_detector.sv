module midi_decoder (
    input clk,
    input rx_ready,
    input [7:0] rx_data,
    
    output reg [7:0] out_note,
    output reg[7:0] out_velocity,
    output reg       out_on,  
    output reg       out_trig 
);

    reg [2:0] state = 0; 
    reg [7:0] cmd_type;
    reg[7:0] note_temp;

    always @(posedge clk) begin
        out_trig <= 0;
        
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
                        out_note <= note_temp;
                        out_velocity <= rx_data;
                        
                        
                        state <= 3; 
                    end else begin
                        out_on <= 0;
                        out_trig <= 1;
                        state <= 0;
                    end
                end
            endcase
            

        end else if (state == 3) begin
            out_on <= 1;   
            out_trig <= 1;
            state <= 0;    
        end
    end
endmodule