//======================================================================
// File Name    : wallace_tree_4to2_modify.v
// Module Name  : wallace_tree_modify
// Author       : Hzt
// Version      : 1.1
// Modified     : 2025/02/24 22:00
// Description  : wallace compute
//======================================================================
`timescale 1ns/1ps

//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module wallace_tree_modify (
    input  wire [9:0] a,  // 4 partial product
    input  wire [9:0] b,
    input  wire [9:0] c,
    input  wire [9:0] d,
    output reg [15:0] sum,
    output reg [15:0] carry
);

//--------------------------------------------------------------------------
// Internal Signal Declaration
//--------------------------------------------------------------------------
wire [15:0] s1, c1;
wire [13: 0] Fir_S, Fir_C;
wire [12: 0] Sec_S, Sec_C;

//--------------------------------------------------------------------------
// signal bit extend
//--------------------------------------------------------------------------
wire [15:0] pp_a = {{6{a[9]}}, a};
wire [13:0] pp_b = {{4{b[9]}}, b};
wire [11:0] pp_c = {{2{c[9]}}, c};
wire [9:0]  pp_d = d;


//--------------------------------------------------------------------------
// First Stage
//--------------------------------------------------------------------------
HalfAdder	firha1( pp_a[2], pp_b[0], Fir_S[0], Fir_C[0] );
HalfAdder	firha2( pp_a[3], pp_b[1], Fir_S[1], Fir_C[1] );
FullAdder	firfa1( pp_a[4], pp_b[2], pp_c[0], Fir_S[2], Fir_C[2] );
FullAdder	firfa2( pp_a[5], pp_b[3], pp_c[1], Fir_S[3], Fir_C[3] );
FullAdder	firfa3( pp_a[6], pp_b[4], pp_c[2], Fir_S[4], Fir_C[4] );
FullAdder	firfa4( pp_a[7], pp_b[5], pp_c[3], Fir_S[5], Fir_C[5] );
FullAdder	firfa5( pp_a[8], pp_b[6], pp_c[4], Fir_S[6], Fir_C[6] );
FullAdder	firfa6( pp_a[9], pp_b[7], pp_c[5], Fir_S[7], Fir_C[7] );
FullAdder	firfa7( pp_a[10], pp_b[8], pp_c[6], Fir_S[8], Fir_C[8] );
FullAdder	firfa8( pp_a[11], pp_b[9], pp_c[7], Fir_S[9], Fir_C[9] );
FullAdder	firfa9( pp_a[12], pp_b[10], pp_c[8], Fir_S[10], Fir_C[10] );
FullAdder	firfa10( pp_a[13], pp_b[11], pp_c[9], Fir_S[11], Fir_C[11] );
FullAdder	firfa11( pp_a[14], pp_b[12], pp_c[10], Fir_S[12], Fir_C[12] );
FullAdder	firfa12( pp_a[15], pp_b[13], pp_c[11], Fir_S[13], Fir_C[13] );

//--------------------------------------------------------------------------
// Second Stage
//--------------------------------------------------------------------------
HalfAdder	secha1( Fir_S[1], Fir_C[0], Sec_S[0], Sec_C[0] );
HalfAdder	secha2( Fir_S[2], Fir_C[1], Sec_S[1], Sec_C[1] );
HalfAdder	secha3( Fir_S[3], Fir_C[2], Sec_S[2], Sec_C[2] );
FullAdder	secfa1( pp_d[0], Fir_S[4], Fir_C[3], Sec_S[3], Sec_C[3] );
FullAdder	secfa2( pp_d[1], Fir_S[5], Fir_C[4], Sec_S[4], Sec_C[4] );
FullAdder	secfa3( pp_d[2], Fir_S[6], Fir_C[5], Sec_S[5], Sec_C[5] );
FullAdder	secfa4( pp_d[3], Fir_S[7], Fir_C[6], Sec_S[6], Sec_C[6] );
FullAdder	secfa5( pp_d[4], Fir_S[8], Fir_C[7], Sec_S[7], Sec_C[7] );
FullAdder	secfa6( pp_d[5], Fir_S[9], Fir_C[8], Sec_S[8], Sec_C[8] );
FullAdder	secfa7( pp_d[6], Fir_S[10], Fir_C[9], Sec_S[9], Sec_C[9] );
FullAdder	secfa8( pp_d[7], Fir_S[11], Fir_C[10], Sec_S[10], Sec_C[10] );
FullAdder	secfa9( pp_d[8], Fir_S[12], Fir_C[11], Sec_S[11], Sec_C[11] );
FullAdder	secfa10( pp_d[9], Fir_S[13], Fir_C[12], Sec_S[12], Sec_C[12] );


assign s1={ Sec_S, Fir_S[0],a[1],a[0]};
assign c1={Sec_C[11:0], 4'b0};

always @(*) begin
    sum = s1;
    carry = c1;
end

endmodule