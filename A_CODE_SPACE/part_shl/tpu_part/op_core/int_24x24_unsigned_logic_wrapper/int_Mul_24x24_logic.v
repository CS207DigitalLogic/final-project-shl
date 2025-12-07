//======================================================================
// File Name    : int_Mul_24.v
// Module Name  : int_multiplier_24
// Author       : Hzt
// Version      : 1.0
// Modified     : 2025/03/5 13:40
// Description  : The Top module of multiplier with pure logic
//======================================================================
`timescale 1ns/1ps

//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module int_multiplier_24 #(
    parameter WIDTH = 24,              // input bit
    parameter WIDTHX2 = 48,
    parameter PRECISION = 24           //24 or 11 to support the 24bit /  11bit
) (
    input  wire               clk,          // clk
    input  wire               rst,          // the negative is valid
    input  wire [WIDTH-1:0]   a,            // input a(the true width is PRECISION)
    input  wire [WIDTH-1:0]   b,            // input b(the true width is PRECISION)
    output reg  [WIDTHX2-1:0] result       // the width is determined by the PRECISION
);

//--------------------------------------------------------------------------
// Internal Signal Declaration
//--------------------------------------------------------------------------



wire [WIDTH+3:0]         pp1;
wire [WIDTH+4:0]         pp2, pp3, pp4, pp5, pp6, pp7, pp8, pp9, pp10, pp11, pp12;
wire [WIDTH+1:0]         pp13;
wire [WIDTHX2-1:0]       final_result;
wire [11:0]              neg;
wire [11:0]              zero;
wire [11:0]              two;

wire  [WIDTHX2-1:0]  Sum, Carry;

//--------------------------------------------------------------------------
// a and b extend to 24bit if input is 11bit
//--------------------------------------------------------------------------
wire [WIDTH-1:0]   a_ext;
wire [WIDTH-1:0]   b_ext;
assign a_ext = (PRECISION == 11) ? {13'd0, a[10:0]} : a;
assign b_ext = (PRECISION == 11) ? {13'd0, b[10:0]} : b;


//--------------------------------------------------------------------------
//Using booth_encoder to control signal
//--------------------------------------------------------------------------
genvar i;
generate
    for (i = 0; i<12 ; i = i+1 ) begin
        if (i == 0) begin
            booth_encoder_24x24 u_booth_enci(
                .code ({b_ext[1:0],1'b0}),
                .neg  (neg[i]    ),
                .zero (zero[i]   ),
                .two  (two[i]	 )
            );
        end
        else begin
            booth_encoder_24x24 u_booth_enci(
                .code (b_ext[i+i+1 : i+i-1]),
                .neg  (neg[i]    ),
                .zero (zero[i]   ),
                .two  (two[i]	 )
            );
        end
    end
endgenerate


//--------------------------------------------------------------------------
// Using pp_generate to generate the partial products
//--------------------------------------------------------------------------
  pp_generate24#(
    .WIDTH   (WIDTH),
    .WIDTHX2 (WIDTHX2)
  )
  u_pp(
    .A    (a_ext),
    .neg  (neg),
    .zero (zero),
    .two  (two),
    
    .pp1  (pp1),
    .pp2  (pp2),
    .pp3  (pp3),
    .pp4  (pp4),
    .pp5  (pp5),
    .pp6  (pp6),
    .pp7  (pp7),
    .pp8  (pp8),
    .pp9  (pp9),
    .pp10 (pp10),
    .pp11 (pp11),
    .pp12 (pp12),
    .pp13 (pp13)
  );

//--------------------------------------------------------------------------
// partial product add
//--------------------------------------------------------------------------
    wallace12to2#(
        .WIDTH(WIDTH),
        .WIDTHX2 (WIDTHX2)
    )
    utt (
        .pp1            (pp1),
        .pp2            (pp2),
        .pp3            (pp3),
        .pp4            (pp4),
        .pp5            (pp5),
        .pp6            (pp6),
        .pp7            (pp7),
        .pp8            (pp8),
        .pp9            (pp9),
        .pp10            (pp10),
        .pp11           (pp11),
        .pp12            (pp12),
        .pp13            (pp13),

        .sum          (Sum),
        .carry        (Carry)
    );

//--------------------------------------------------------------------------
//Final result calculate
//--------------------------------------------------------------------------
assign final_result = Sum + Carry;

always @(*) begin
    if (PRECISION == 11) begin
        result = final_result[21:0];
    end
    else begin
        result = final_result[47:0];
    end
end



endmodule
