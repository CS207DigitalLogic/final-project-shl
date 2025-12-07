//======================================================================
// File Name    : pp_generate.v
// Module Name  : pp_generate
// Author       : Hzt
// Version      : 1.0
// Modified     : 2025/03/2 22:00
// Description  : To generate the partial products
//======================================================================
module pp_generate24 #(
    parameter WIDTH = 24,              // input bit
    parameter WIDTHX2 = 48
)
(
	input [23:0] A,
	input [11:0] neg,
	input [11:0] zero,
	input [11:0] two,

	output reg [WIDTH+3:0] pp1,
    output reg [WIDTH+4:0] pp2,
    output reg [WIDTH+4:0] pp3,
    output reg [WIDTH+4:0] pp4,
    output reg [WIDTH+4:0] pp5,
    output reg [WIDTH+4:0] pp6,
    output reg [WIDTH+4:0] pp7,
    output reg [WIDTH+4:0] pp8,
    output reg [WIDTH+4:0] pp9,
    output reg [WIDTH+4:0] pp10,
    output reg [WIDTH+4:0] pp11,
    output reg [WIDTH+4:0] pp12,
    output reg [WIDTH+1:0] pp13

);

//--------------------------------------------------------------------------
// Internal Signal Declaration
//--------------------------------------------------------------------------
//first step |X2?  second step |zero?  third step |invert?
wire [WIDTH:0] A_X2[11:0];
wire [WIDTH:0] A_zero[11:0];
wire [WIDTH:0] A_inv[11:0];
wire [11:0] S;

//--------------------------------------------------------------------------
// generate the 8bit pp
//--------------------------------------------------------------------------
genvar i;
generate
    for (i =0 ;i < 12 ;i=i+1 ) begin
        assign A_X2[i] = (two[i] == 1'b1) ? {A,1'b0} : {1'b0,A};
        assign A_zero[i] = (zero[i] == 1'b1) ? 25'd0 : A_X2[i];
        assign A_inv[i] = (neg[i] == 1'b1) ? ~A_zero[i] : A_zero[i];//the +1 is put in the next stage
        assign S[i] = neg[i];
    end
endgenerate

//--------------------------------------------------------------------------
// extend signal bit
//--------------------------------------------------------------------------
always @(*) begin
    pp1 = {~S[0], S[0], S[0], A_inv[0]};
    pp2 = {1'b1, ~S[1], A_inv[1], 1'b0, S[0]};
    pp3 = {1'b1, ~S[2], A_inv[2], 1'b0, S[1]};
    pp4 = {1'b1, ~S[3], A_inv[3], 1'b0, S[2]};
    pp5 = {1'b1, ~S[4], A_inv[4], 1'b0, S[3]};
    pp6 = {1'b1, ~S[5], A_inv[5], 1'b0, S[4]};
    pp7 = {1'b1, ~S[6], A_inv[6], 1'b0, S[5]};
    pp8 = {1'b1, ~S[7], A_inv[7], 1'b0, S[6]};
    pp9 = {1'b1, ~S[8], A_inv[8], 1'b0, S[7]};
    pp10 = {1'b1, ~S[9], A_inv[9], 1'b0, S[8]};
    pp11 = {1'b1, ~S[10], A_inv[10], 1'b0, S[9]};
    pp12 = {1'b1, ~S[11], A_inv[11], 1'b0, S[10]};
    if (neg[11]==1) begin
    pp13 = {A, 1'b0, S[11]};
    end

    else begin
    pp13 = {24'd0, 1'b0, S[11]};
    end

end

		
endmodule