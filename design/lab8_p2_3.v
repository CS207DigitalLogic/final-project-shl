`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/12 11:32:23
// Design Name: 
// Module Name: lab8_p2_3
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module lab8_p2_3(
    input [4:0] x_in,
    input clk,
    input rst_n,
    output reg y_out,
    output reg [2:0] state,
    output reg [2:0] next_state
);
parameter S0 = 3'b000,  
          S1 = 3'b001,    
          S2 = 3'b010,  
          S3 = 3'b011,  
          S4 = 3'b100;  

reg [2:0] ones_count;

always @(*) begin
    ones_count = x_in[0] + x_in[1] + x_in[2] + x_in[3] + x_in[4];
end
always @(posedge clk or negedge rst_n) begin
    if (~rst_n)
        state <= S0;
    else
        state <= next_state;
end

always @(*) begin
    case (state)
        S0: next_state = (ones_count % 5 == 0) ? S0 :
                         (ones_count % 5 == 1) ? S1 :
                         (ones_count % 5 == 2) ? S2 :
                         (ones_count % 5 == 3) ? S3 : S4;
        S1: next_state = ((ones_count + 1) % 5 == 0) ? S0 :
                         ((ones_count + 1) % 5 == 1) ? S1 :
                         ((ones_count + 1) % 5 == 2) ? S2 :
                         ((ones_count + 1) % 5 == 3) ? S3 : S4;
        S2: next_state = ((ones_count + 2) % 5 == 0) ? S0 :
                         ((ones_count + 2) % 5 == 1) ? S1 :
                         ((ones_count + 2) % 5 == 2) ? S2 :
                         ((ones_count + 2) % 5 == 3) ? S3 : S4;
        S3: next_state = ((ones_count + 3) % 5 == 0) ? S0 :
                         ((ones_count + 3) % 5 == 1) ? S1 :
                         ((ones_count + 3) % 5 == 2) ? S2 :
                         ((ones_count + 3) % 5 == 3) ? S3 : S4;
        S4: next_state = ((ones_count + 4) % 5 == 0) ? S0 :
                         ((ones_count + 4) % 5 == 1) ? S1 :
                         ((ones_count + 4) % 5 == 2) ? S2 :
                         ((ones_count + 4) % 5 == 3) ? S3 : S4;
        default: next_state = S0;
    endcase
end

// 
always @(*) begin
    y_out = (state == S0);  
end

endmodule