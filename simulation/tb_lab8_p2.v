`timescale 1ns / 1ps
`include "../Design/lab8_p2.v"
`include "../Design/lab8_p2_3.v"
// tb_lab8_p2.v
module tb_lab8_p2;

reg [4:0] x_in;
reg clk;
reg rst_n;

wire y_out1,y_out2;
wire [2:0] state1,state2;   
wire [2:0] next_state1,next_state2;

lab8_p2 u1 (
    .x_in(x_in),
    .clk(clk),
    .rst_n(rst_n),
    .y_out(y_out1),
    .state(state1),
    .next_state(next_state1)
);

lab8_p2_3 u2 (
    .x_in(x_in),
    .clk(clk),
    .rst_n(rst_n),
    .y_out(y_out2),
    .state(state2),
    .next_state(next_state2)
);
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    x_in = 5'b00000;
    #20;
    
    rst_n = 1;
    #10;
    
    x_in = 5'b11111;
    #10;
    
    x_in = 5'b10101;
    #10;
    
    x_in = 5'b10001;
    #10;
    
    x_in = 5'b00000;
    #10;
    
    x_in = 5'b11110;
    #10;
    
    x_in = 5'b00001;
    #10;
    
    #20;
    $finish;
end

initial begin
    $dumpfile("tb_lab8_p2.vcd");
    $dumpvars(0,tb_lab8_p2);
end

endmodule