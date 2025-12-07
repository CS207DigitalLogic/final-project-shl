//======================================================================
// File Name    : wallace12to2.v
// Module Name  : wallace12to2
// Author       : Hzt
// Version      : 1.0
// Modified     : 2025/03/3 11:00
// Description  : wallace compute
//======================================================================
`timescale 1ns/1ps

//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module wallace12to2 #(
    parameter WIDTH = 24,              // input bit
    parameter WIDTHX2 = 48
)
(
    input  wire [WIDTH+3:0] pp1,  // 4 partial product
    input  wire [WIDTH+4:0] pp2,
    input  wire [WIDTH+4:0] pp3,
    input  wire [WIDTH+4:0] pp4,
    input  wire [WIDTH+4:0] pp5,
    input  wire [WIDTH+4:0] pp6,
    input  wire [WIDTH+4:0] pp7,
    input  wire [WIDTH+4:0] pp8,
    input  wire [WIDTH+4:0] pp9,
    input  wire [WIDTH+4:0] pp10,
    input  wire [WIDTH+4:0] pp11,
    input  wire [WIDTH+4:0] pp12,
    input  wire [WIDTH+1:0] pp13,

    output reg [47:0] sum,
    output reg [47:0] carry
);

wire [47:0] s1, c1;

//--------------------------------------------------------------------------
// First Stage
//--------------------------------------------------------------------------
wire [28:0] Fir1_S, Fir1_C;
wire [28:0] Fir2_S, Fir2_C;
wire [28:0] Fir3_S, Fir3_C;
wire [28:0] Fir4_S, Fir4_C;


HalfAdder	fir1ha1( pp1[0], pp2[0], Fir1_S[0], Fir1_C[0] );
HalfAdder	fir1ha2( pp1[1], pp2[1], Fir1_S[1], Fir1_C[1] );
FullAdder	fir1fa1( pp1[2], pp2[2], pp3[0], Fir1_S[2], Fir1_C[2] );
FullAdder	fir1fa2( pp1[3], pp2[3], pp3[1], Fir1_S[3], Fir1_C[3] );
FullAdder	fir1fa3( pp1[4], pp2[4], pp3[2], Fir1_S[4], Fir1_C[4] );
FullAdder	fir1fa4( pp1[5], pp2[5], pp3[3], Fir1_S[5], Fir1_C[5] );
FullAdder	fir1fa5( pp1[6], pp2[6], pp3[4], Fir1_S[6], Fir1_C[6] );
FullAdder	fir1fa6( pp1[7], pp2[7], pp3[5], Fir1_S[7], Fir1_C[7] );
FullAdder	fir1fa7( pp1[8], pp2[8], pp3[6], Fir1_S[8], Fir1_C[8] );
FullAdder	fir1fa8( pp1[9], pp2[9], pp3[7], Fir1_S[9], Fir1_C[9] );
FullAdder	fir1fa9( pp1[10], pp2[10], pp3[8], Fir1_S[10], Fir1_C[10] );
FullAdder	fir1fa10( pp1[11], pp2[11], pp3[9], Fir1_S[11], Fir1_C[11] );
FullAdder	fir1fa11( pp1[12], pp2[12], pp3[10], Fir1_S[12], Fir1_C[12] );
FullAdder	fir1fa12( pp1[13], pp2[13], pp3[11], Fir1_S[13], Fir1_C[13] );
FullAdder	fir1fa13( pp1[14], pp2[14], pp3[12], Fir1_S[14], Fir1_C[14] );
FullAdder	fir1fa14( pp1[15], pp2[15], pp3[13], Fir1_S[15], Fir1_C[15] );
FullAdder	fir1fa15( pp1[16], pp2[16], pp3[14], Fir1_S[16], Fir1_C[16] );
FullAdder	fir1fa16( pp1[17], pp2[17], pp3[15], Fir1_S[17], Fir1_C[17] );
FullAdder	fir1fa17( pp1[18], pp2[18], pp3[16], Fir1_S[18], Fir1_C[18] );
FullAdder	fir1fa18( pp1[19], pp2[19], pp3[17], Fir1_S[19], Fir1_C[19] );
FullAdder	fir1fa19( pp1[20], pp2[20], pp3[18], Fir1_S[20], Fir1_C[20] );
FullAdder	fir1fa20( pp1[21], pp2[21], pp3[19], Fir1_S[21], Fir1_C[21] );
FullAdder	fir1fa21( pp1[22], pp2[22], pp3[20], Fir1_S[22], Fir1_C[22] );
FullAdder	fir1fa22( pp1[23], pp2[23], pp3[21], Fir1_S[23], Fir1_C[23] );
FullAdder	fir1fa23( pp1[24], pp2[24], pp3[22], Fir1_S[24], Fir1_C[24] );
FullAdder	fir1fa24( pp1[25], pp2[25], pp3[23], Fir1_S[25], Fir1_C[25] );
FullAdder	fir1fa25( pp1[26], pp2[26], pp3[24], Fir1_S[26], Fir1_C[26] );
FullAdder	fir1fa26( pp1[27], pp2[27], pp3[25], Fir1_S[27], Fir1_C[27] );
HalfAdder	fir1ha3(  pp2[28], pp3[26], Fir1_S[28], Fir1_C[28] );

HalfAdder	fir2ha1( pp4[2], pp5[0], Fir2_S[0], Fir2_C[0] );
HalfAdder	fir2ha2( pp4[3], pp5[1], Fir2_S[1], Fir2_C[1] );
FullAdder	fir2fa1( pp4[4], pp5[2], pp6[0], Fir2_S[2], Fir2_C[2] );
FullAdder	fir2fa2( pp4[5], pp5[3], pp6[1], Fir2_S[3], Fir2_C[3] );
FullAdder	fir2fa3( pp4[6], pp5[4], pp6[2], Fir2_S[4], Fir2_C[4] );
FullAdder	fir2fa4( pp4[7], pp5[5], pp6[3], Fir2_S[5], Fir2_C[5] );
FullAdder	fir2fa5( pp4[8], pp5[6], pp6[4], Fir2_S[6], Fir2_C[6] );
FullAdder	fir2fa6( pp4[9], pp5[7], pp6[5], Fir2_S[7], Fir2_C[7] );
FullAdder	fir2fa7( pp4[10], pp5[8], pp6[6], Fir2_S[8], Fir2_C[8] );
FullAdder	fir2fa8( pp4[11], pp5[9], pp6[7], Fir2_S[9], Fir2_C[9] );
FullAdder	fir2fa9( pp4[12], pp5[10], pp6[8], Fir2_S[10], Fir2_C[10] );
FullAdder	fir2fa10( pp4[13], pp5[11], pp6[9], Fir2_S[11], Fir2_C[11] );
FullAdder	fir2fa11( pp4[14], pp5[12], pp6[10], Fir2_S[12], Fir2_C[12] );
FullAdder	fir2fa12( pp4[15], pp5[13], pp6[11], Fir2_S[13], Fir2_C[13] );
FullAdder	fir2fa13( pp4[16], pp5[14], pp6[12], Fir2_S[14], Fir2_C[14] );
FullAdder	fir2fa14( pp4[17], pp5[15], pp6[13], Fir2_S[15], Fir2_C[15] );
FullAdder	fir2fa15( pp4[18], pp5[16], pp6[14], Fir2_S[16], Fir2_C[16] );
FullAdder	fir2fa16( pp4[19], pp5[17], pp6[15], Fir2_S[17], Fir2_C[17] );
FullAdder	fir2fa17( pp4[20], pp5[18], pp6[16], Fir2_S[18], Fir2_C[18] );
FullAdder	fir2fa18( pp4[21], pp5[19], pp6[17], Fir2_S[19], Fir2_C[19] );
FullAdder	fir2fa19( pp4[22], pp5[20], pp6[18], Fir2_S[20], Fir2_C[20] );
FullAdder	fir2fa20( pp4[23], pp5[21], pp6[19], Fir2_S[21], Fir2_C[21] );
FullAdder	fir2fa21( pp4[24], pp5[22], pp6[20], Fir2_S[22], Fir2_C[22] );
FullAdder	fir2fa22( pp4[25], pp5[23], pp6[21], Fir2_S[23], Fir2_C[23] );
FullAdder	fir2fa23( pp4[26], pp5[24], pp6[22], Fir2_S[24], Fir2_C[24] );
FullAdder	fir2fa24( pp4[27], pp5[25], pp6[23], Fir2_S[25], Fir2_C[25] );
FullAdder	fir2fa25( pp4[28], pp5[26], pp6[24], Fir2_S[26], Fir2_C[26] );
HalfAdder	fir2ha3( pp5[27], pp6[25], Fir2_S[27], Fir2_C[27] );
HalfAdder	fir2ha4( pp5[28], pp6[26], Fir2_S[28], Fir2_C[28] );

HalfAdder	fir3ha1( pp7[2], pp8[0], Fir3_S[0], Fir3_C[0] );
HalfAdder	fir3ha2( pp7[3], pp8[1], Fir3_S[1], Fir3_C[1] );
FullAdder	fir3fa1( pp7[4], pp8[2], pp9[0], Fir3_S[2], Fir3_C[2] );
FullAdder	fir3fa2( pp7[5], pp8[3], pp9[1], Fir3_S[3], Fir3_C[3] );
FullAdder	fir3fa3( pp7[6], pp8[4], pp9[2], Fir3_S[4], Fir3_C[4] );
FullAdder	fir3fa4( pp7[7], pp8[5], pp9[3], Fir3_S[5], Fir3_C[5] );
FullAdder	fir3fa5( pp7[8], pp8[6], pp9[4], Fir3_S[6], Fir3_C[6] );
FullAdder	fir3fa6( pp7[9], pp8[7], pp9[5], Fir3_S[7], Fir3_C[7] );
FullAdder	fir3fa7( pp7[10], pp8[8], pp9[6], Fir3_S[8], Fir3_C[8] );
FullAdder	fir3fa8( pp7[11], pp8[9], pp9[7], Fir3_S[9], Fir3_C[9] );
FullAdder	fir3fa9( pp7[12], pp8[10], pp9[8], Fir3_S[10], Fir3_C[10] );
FullAdder	fir3fa10( pp7[13], pp8[11], pp9[9], Fir3_S[11], Fir3_C[11] );
FullAdder	fir3fa11( pp7[14], pp8[12], pp9[10], Fir3_S[12], Fir3_C[12] );
FullAdder	fir3fa12( pp7[15], pp8[13], pp9[11], Fir3_S[13], Fir3_C[13] );
FullAdder	fir3fa13( pp7[16], pp8[14], pp9[12], Fir3_S[14], Fir3_C[14] );
FullAdder	fir3fa14( pp7[17], pp8[15], pp9[13], Fir3_S[15], Fir3_C[15] );
FullAdder	fir3fa15( pp7[18], pp8[16], pp9[14], Fir3_S[16], Fir3_C[16] );
FullAdder	fir3fa16( pp7[19], pp8[17], pp9[15], Fir3_S[17], Fir3_C[17] );
FullAdder	fir3fa17( pp7[20], pp8[18], pp9[16], Fir3_S[18], Fir3_C[18] );
FullAdder	fir3fa18( pp7[21], pp8[19], pp9[17], Fir3_S[19], Fir3_C[19] );
FullAdder	fir3fa19( pp7[22], pp8[20], pp9[18], Fir3_S[20], Fir3_C[20] );
FullAdder	fir3fa20( pp7[23], pp8[21], pp9[19], Fir3_S[21], Fir3_C[21] );
FullAdder	fir3fa21( pp7[24], pp8[22], pp9[20], Fir3_S[22], Fir3_C[22] );
FullAdder	fir3fa22( pp7[25], pp8[23], pp9[21], Fir3_S[23], Fir3_C[23] );
FullAdder	fir3fa23( pp7[26], pp8[24], pp9[22], Fir3_S[24], Fir3_C[24] );
FullAdder	fir3fa24( pp7[27], pp8[25], pp9[23], Fir3_S[25], Fir3_C[25] );
FullAdder	fir3fa25( pp7[28], pp8[26], pp9[24], Fir3_S[26], Fir3_C[26] );
HalfAdder	fir3ha3( pp8[27], pp9[25], Fir3_S[27], Fir3_C[27] );
HalfAdder	fir3ha4( pp8[28], pp9[26], Fir3_S[28], Fir3_C[28] );

HalfAdder	fir4ha1( pp10[2], pp11[0], Fir4_S[0], Fir4_C[0] );
HalfAdder	fir4ha2( pp10[3], pp11[1], Fir4_S[1], Fir4_C[1] );
FullAdder	fir4fa1( pp10[4], pp11[2], pp12[0], Fir4_S[2], Fir4_C[2] );
FullAdder	fir4fa2( pp10[5], pp11[3], pp12[1], Fir4_S[3], Fir4_C[3] );
FullAdder	fir4fa3( pp10[6], pp11[4], pp12[2], Fir4_S[4], Fir4_C[4] );
FullAdder	fir4fa4( pp10[7], pp11[5], pp12[3], Fir4_S[5], Fir4_C[5] );
FullAdder	fir4fa5( pp10[8], pp11[6], pp12[4], Fir4_S[6], Fir4_C[6] );
FullAdder	fir4fa6( pp10[9], pp11[7], pp12[5], Fir4_S[7], Fir4_C[7] );
FullAdder	fir4fa7( pp10[10], pp11[8], pp12[6], Fir4_S[8], Fir4_C[8] );
FullAdder	fir4fa8( pp10[11], pp11[9], pp12[7], Fir4_S[9], Fir4_C[9] );
FullAdder	fir4fa9( pp10[12], pp11[10], pp12[8], Fir4_S[10], Fir4_C[10] );
FullAdder	fir4fa10( pp10[13], pp11[11], pp12[9], Fir4_S[11], Fir4_C[11] );
FullAdder	fir4fa11( pp10[14], pp11[12], pp12[10], Fir4_S[12], Fir4_C[12] );
FullAdder	fir4fa12( pp10[15], pp11[13], pp12[11], Fir4_S[13], Fir4_C[13] );
FullAdder	fir4fa13( pp10[16], pp11[14], pp12[12], Fir4_S[14], Fir4_C[14] );
FullAdder	fir4fa14( pp10[17], pp11[15], pp12[13], Fir4_S[15], Fir4_C[15] );
FullAdder	fir4fa15( pp10[18], pp11[16], pp12[14], Fir4_S[16], Fir4_C[16] );
FullAdder	fir4fa16( pp10[19], pp11[17], pp12[15], Fir4_S[17], Fir4_C[17] );
FullAdder	fir4fa17( pp10[20], pp11[18], pp12[16], Fir4_S[18], Fir4_C[18] );
FullAdder	fir4fa18( pp10[21], pp11[19], pp12[17], Fir4_S[19], Fir4_C[19] );
FullAdder	fir4fa19( pp10[22], pp11[20], pp12[18], Fir4_S[20], Fir4_C[20] );
FullAdder	fir4fa20( pp10[23], pp11[21], pp12[19], Fir4_S[21], Fir4_C[21] );
FullAdder	fir4fa21( pp10[24], pp11[22], pp12[20], Fir4_S[22], Fir4_C[22] );
FullAdder	fir4fa22( pp10[25], pp11[23], pp12[21], Fir4_S[23], Fir4_C[23] );
FullAdder	fir4fa23( pp10[26], pp11[24], pp12[22], Fir4_S[24], Fir4_C[24] );
FullAdder	fir4fa24( pp10[27], pp11[25], pp12[23], Fir4_S[25], Fir4_C[25] );
FullAdder	fir4fa25( pp10[28], pp11[26], pp12[24], Fir4_S[26], Fir4_C[26] );
HalfAdder	fir4ha3( pp11[27], pp12[25], Fir4_S[27], Fir4_C[27] );
HalfAdder	fir4ha4( pp11[28], pp12[26], Fir4_S[28], Fir4_C[28] );

//--------------------------------------------------------------------------
// Second Stage
//--------------------------------------------------------------------------
wire [29:0] Sec1_S, Sec1_C;
wire [31:0] Sec2_S, Sec2_C;
wire [28:0] Sec3_S, Sec3_C;

HalfAdder   sec1ha1( Fir1_S[1], Fir1_C[0], Sec1_S[0], Sec1_C[0] );
HalfAdder   sec1ha2( Fir1_S[2], Fir1_C[1], Sec1_S[1], Sec1_C[1] );
HalfAdder   sec1ha3( Fir1_S[3], Fir1_C[2], Sec1_S[2], Sec1_C[2] );
FullAdder   sec1fa1( Fir1_S[4], Fir1_C[3], pp4[0], Sec1_S[3], Sec1_C[3] );
FullAdder   sec1fa2( Fir1_S[5], Fir1_C[4], pp4[1], Sec1_S[4], Sec1_C[4] );
FullAdder   sec1fa3( Fir1_S[6], Fir1_C[5], Fir2_S[0], Sec1_S[5], Sec1_C[5] );
FullAdder   sec1fa4( Fir1_S[7], Fir1_C[6], Fir2_S[1], Sec1_S[6], Sec1_C[6] );
FullAdder   sec1fa5( Fir1_S[8], Fir1_C[7], Fir2_S[2], Sec1_S[7], Sec1_C[7] );
FullAdder   sec1fa6( Fir1_S[9], Fir1_C[8], Fir2_S[3], Sec1_S[8], Sec1_C[8] );
FullAdder   sec1fa7( Fir1_S[10], Fir1_C[9], Fir2_S[4], Sec1_S[9], Sec1_C[9] );
FullAdder   sec1fa8( Fir1_S[11], Fir1_C[10], Fir2_S[5], Sec1_S[10], Sec1_C[10] );
FullAdder   sec1fa9( Fir1_S[12], Fir1_C[11], Fir2_S[6], Sec1_S[11], Sec1_C[11] );
FullAdder   sec1fa10( Fir1_S[13], Fir1_C[12], Fir2_S[7], Sec1_S[12], Sec1_C[12] );
FullAdder   sec1fa11( Fir1_S[14], Fir1_C[13], Fir2_S[8], Sec1_S[13], Sec1_C[13] );
FullAdder   sec1fa12( Fir1_S[15], Fir1_C[14], Fir2_S[9], Sec1_S[14], Sec1_C[14] );
FullAdder   sec1fa13( Fir1_S[16], Fir1_C[15], Fir2_S[10], Sec1_S[15], Sec1_C[15] );
FullAdder   sec1fa14( Fir1_S[17], Fir1_C[16], Fir2_S[11], Sec1_S[16], Sec1_C[16] );
FullAdder   sec1fa15( Fir1_S[18], Fir1_C[17], Fir2_S[12], Sec1_S[17], Sec1_C[17] );
FullAdder   sec1fa16( Fir1_S[19], Fir1_C[18], Fir2_S[13], Sec1_S[18], Sec1_C[18] );
FullAdder   sec1fa17( Fir1_S[20], Fir1_C[19], Fir2_S[14], Sec1_S[19], Sec1_C[19] );
FullAdder   sec1fa18( Fir1_S[21], Fir1_C[20], Fir2_S[15], Sec1_S[20], Sec1_C[20] );
FullAdder   sec1fa19( Fir1_S[22], Fir1_C[21], Fir2_S[16], Sec1_S[21], Sec1_C[21] );
FullAdder   sec1fa20( Fir1_S[23], Fir1_C[22], Fir2_S[17], Sec1_S[22], Sec1_C[22] );
FullAdder   sec1fa21( Fir1_S[24], Fir1_C[23], Fir2_S[18], Sec1_S[23], Sec1_C[23] );
FullAdder   sec1fa22( Fir1_S[25], Fir1_C[24], Fir2_S[19], Sec1_S[24], Sec1_C[24] );
FullAdder   sec1fa23( Fir1_S[26], Fir1_C[25], Fir2_S[20], Sec1_S[25], Sec1_C[25] );
FullAdder   sec1fa24( Fir1_S[27], Fir1_C[26], Fir2_S[21], Sec1_S[26], Sec1_C[26] );
FullAdder   sec1fa25( Fir1_S[28], Fir1_C[27], Fir2_S[22], Sec1_S[27], Sec1_C[27] );
FullAdder   sec1fa26( pp3[27], Fir1_C[28], Fir2_S[23], Sec1_S[28], Sec1_C[28] );
HalfAdder   sec1ha4(  pp3[28], Fir2_S[24], Sec1_S[29], Sec1_C[29] );

HalfAdder   sec2ha1( Fir2_C[3], pp7[0], Sec2_S[0], Sec2_C[0] );
HalfAdder   sec2ha2( Fir2_C[4], pp7[1], Sec2_S[1], Sec2_C[1] );
HalfAdder   sec2ha3( Fir2_C[5], Fir3_S[0], Sec2_S[2], Sec2_C[2] );
FullAdder   sec2fa1( Fir2_C[6], Fir3_S[1], Fir3_C[0], Sec2_S[3], Sec2_C[3] );
FullAdder   sec2fa2( Fir2_C[7], Fir3_S[2], Fir3_C[1], Sec2_S[4], Sec2_C[4] );
FullAdder   sec2fa3( Fir2_C[8], Fir3_S[3], Fir3_C[2], Sec2_S[5], Sec2_C[5] );
FullAdder   sec2fa4( Fir2_C[9], Fir3_S[4], Fir3_C[3], Sec2_S[6], Sec2_C[6] );
FullAdder   sec2fa5( Fir2_C[10], Fir3_S[5], Fir3_C[4], Sec2_S[7], Sec2_C[7] );
FullAdder   sec2fa6( Fir2_C[11], Fir3_S[6], Fir3_C[5], Sec2_S[8], Sec2_C[8] );
FullAdder   sec2fa7( Fir2_C[12], Fir3_S[7], Fir3_C[6], Sec2_S[9], Sec2_C[9] );
FullAdder   sec2fa8( Fir2_C[13], Fir3_S[8], Fir3_C[7], Sec2_S[10], Sec2_C[10] );
FullAdder   sec2fa9( Fir2_C[14], Fir3_S[9], Fir3_C[8], Sec2_S[11], Sec2_C[11] );
FullAdder   sec2fa10( Fir2_C[15], Fir3_S[10], Fir3_C[9], Sec2_S[12], Sec2_C[12] );
FullAdder   sec2fa11( Fir2_C[16], Fir3_S[11], Fir3_C[10], Sec2_S[13], Sec2_C[13] );
FullAdder   sec2fa12( Fir2_C[17], Fir3_S[12], Fir3_C[11], Sec2_S[14], Sec2_C[14] );
FullAdder   sec2fa13( Fir2_C[18], Fir3_S[13], Fir3_C[12], Sec2_S[15], Sec2_C[15] );
FullAdder   sec2fa14( Fir2_C[19], Fir3_S[14], Fir3_C[13], Sec2_S[16], Sec2_C[16] );
FullAdder   sec2fa15( Fir2_C[20], Fir3_S[15], Fir3_C[14], Sec2_S[17], Sec2_C[17] );
FullAdder   sec2fa16( Fir2_C[21], Fir3_S[16], Fir3_C[15], Sec2_S[18], Sec2_C[18] );
FullAdder   sec2fa17( Fir2_C[22], Fir3_S[17], Fir3_C[16], Sec2_S[19], Sec2_C[19] );
FullAdder   sec2fa18( Fir2_C[23], Fir3_S[18], Fir3_C[17], Sec2_S[20], Sec2_C[20] );
FullAdder   sec2fa19( Fir2_C[24], Fir3_S[19], Fir3_C[18], Sec2_S[21], Sec2_C[21] );
FullAdder   sec2fa20( Fir2_C[25], Fir3_S[20], Fir3_C[19], Sec2_S[22], Sec2_C[22] );
FullAdder   sec2fa21( Fir2_C[26], Fir3_S[21], Fir3_C[20], Sec2_S[23], Sec2_C[23] );
FullAdder   sec2fa22( Fir2_C[27], Fir3_S[22], Fir3_C[21], Sec2_S[24], Sec2_C[24] );
FullAdder   sec2fa23( Fir2_C[28], Fir3_S[23], Fir3_C[22], Sec2_S[25], Sec2_C[25] );
FullAdder   sec2fa24( pp6[28], Fir3_S[24], Fir3_C[23], Sec2_S[26], Sec2_C[26] );
HalfAdder   sec2ha4( Fir3_S[25],Fir3_C[24], Sec2_S[27], Sec2_C[27] );
HalfAdder   sec2ha5( Fir3_S[26],Fir3_C[25], Sec2_S[28], Sec2_C[28] );
HalfAdder   sec2ha6( Fir3_S[27],Fir3_C[26], Sec2_S[29], Sec2_C[29] );
HalfAdder   sec2ha7( Fir3_S[28],Fir3_C[27], Sec2_S[30], Sec2_C[30] );
HalfAdder   sec2ha8( pp9[27], Fir3_C[28], Sec2_S[31], Sec2_C[31] );

HalfAdder   sec3ha1( Fir4_S[1], Fir4_C[0], Sec3_S[0], Sec3_C[0] );
HalfAdder   sec3ha2( Fir4_S[2], Fir4_C[1], Sec3_S[1], Sec3_C[1] );
HalfAdder   sec3ha3( Fir4_S[3], Fir4_C[2], Sec3_S[2], Sec3_C[2] );
FullAdder   sec3fa1( Fir4_S[4], Fir4_C[3], pp13[0], Sec3_S[3], Sec3_C[3] );
FullAdder   sec3fa2( Fir4_S[5], Fir4_C[4], pp13[1], Sec3_S[4], Sec3_C[4] );
FullAdder   sec3fa3( Fir4_S[6], Fir4_C[5], pp13[2], Sec3_S[5], Sec3_C[5] );
FullAdder   sec3fa4( Fir4_S[7], Fir4_C[6], pp13[3], Sec3_S[6], Sec3_C[6] );
FullAdder   sec3fa5( Fir4_S[8], Fir4_C[7], pp13[4], Sec3_S[7], Sec3_C[7] );
FullAdder   sec3fa6( Fir4_S[9], Fir4_C[8], pp13[5], Sec3_S[8], Sec3_C[8] );
FullAdder   sec3fa7( Fir4_S[10], Fir4_C[9], pp13[6], Sec3_S[9], Sec3_C[9] );
FullAdder   sec3fa8( Fir4_S[11], Fir4_C[10], pp13[7], Sec3_S[10], Sec3_C[10] );
FullAdder   sec3fa9( Fir4_S[12], Fir4_C[11], pp13[8], Sec3_S[11], Sec3_C[11] );
FullAdder   sec3fa10( Fir4_S[13], Fir4_C[12], pp13[9], Sec3_S[12], Sec3_C[12] );
FullAdder   sec3fa11( Fir4_S[14], Fir4_C[13], pp13[10], Sec3_S[13], Sec3_C[13] );
FullAdder   sec3fa12( Fir4_S[15], Fir4_C[14], pp13[11], Sec3_S[14], Sec3_C[14] );
FullAdder   sec3fa13( Fir4_S[16], Fir4_C[15], pp13[12], Sec3_S[15], Sec3_C[15] );
FullAdder   sec3fa14( Fir4_S[17], Fir4_C[16], pp13[13], Sec3_S[16], Sec3_C[16] );
FullAdder   sec3fa15( Fir4_S[18], Fir4_C[17], pp13[14], Sec3_S[17], Sec3_C[17] );
FullAdder   sec3fa16( Fir4_S[19], Fir4_C[18], pp13[15], Sec3_S[18], Sec3_C[18] );
FullAdder   sec3fa17( Fir4_S[20], Fir4_C[19], pp13[16], Sec3_S[19], Sec3_C[19] );
FullAdder   sec3fa18( Fir4_S[21], Fir4_C[20], pp13[17], Sec3_S[20], Sec3_C[20] );
FullAdder   sec3fa19( Fir4_S[22], Fir4_C[21], pp13[18], Sec3_S[21], Sec3_C[21] );
FullAdder   sec3fa20( Fir4_S[23], Fir4_C[22], pp13[19], Sec3_S[22], Sec3_C[22] );
FullAdder   sec3fa21( Fir4_S[24], Fir4_C[23], pp13[20], Sec3_S[23], Sec3_C[23] );  
FullAdder   sec3fa22( Fir4_S[25], Fir4_C[24], pp13[21], Sec3_S[24], Sec3_C[24] );
FullAdder   sec3fa23( Fir4_S[26], Fir4_C[25], pp13[22], Sec3_S[25], Sec3_C[25] );
FullAdder   sec3fa24( Fir4_S[27], Fir4_C[26], pp13[23], Sec3_S[26], Sec3_C[26] );
FullAdder   sec3fa25( Fir4_S[28], Fir4_C[27], pp13[24], Sec3_S[27], Sec3_C[27] );
FullAdder   sec3fa26( pp12[27], Fir4_C[28], pp13[25], Sec3_S[28], Sec3_C[28] );



//--------------------------------------------------------------------------
// Third Stage
//--------------------------------------------------------------------------
wire [33:0] Thi1_S, Thi1_C;
wire [31:0] Thi2_S, Thi2_C;

HalfAdder   thi1ha1( Sec1_S[1], Sec1_C[0], Thi1_S[0], Thi1_C[0] );
HalfAdder   thi1ha2( Sec1_S[2], Sec1_C[1], Thi1_S[1], Thi1_C[1] );
HalfAdder   thi1ha3( Sec1_S[3], Sec1_C[2], Thi1_S[2], Thi1_C[2] );
HalfAdder   thi1ha4( Sec1_S[4], Sec1_C[3], Thi1_S[3], Thi1_C[3] );
HalfAdder   thi1ha5( Sec1_S[5], Sec1_C[4], Thi1_S[4], Thi1_C[4] );
FullAdder   thi1fa1( Sec1_S[6], Sec1_C[5], Fir2_C[0], Thi1_S[5], Thi1_C[5] );
FullAdder   thi1fa2( Sec1_S[7], Sec1_C[6], Fir2_C[1], Thi1_S[6], Thi1_C[6] );
FullAdder   thi1fa3( Sec1_S[8], Sec1_C[7], Fir2_C[2], Thi1_S[7], Thi1_C[7] );
FullAdder   thi1fa4( Sec1_S[9], Sec1_C[8], Sec2_S[0], Thi1_S[8], Thi1_C[8] );
FullAdder   thi1fa5( Sec1_S[10], Sec1_C[9], Sec2_S[1], Thi1_S[9], Thi1_C[9] );
FullAdder   thi1fa6( Sec1_S[11], Sec1_C[10], Sec2_S[2], Thi1_S[10], Thi1_C[10] );
FullAdder   thi1fa7( Sec1_S[12], Sec1_C[11], Sec2_S[3], Thi1_S[11], Thi1_C[11] );
FullAdder   thi1fa8( Sec1_S[13], Sec1_C[12], Sec2_S[4], Thi1_S[12], Thi1_C[12] );
FullAdder   thi1fa9( Sec1_S[14], Sec1_C[13], Sec2_S[5], Thi1_S[13], Thi1_C[13] );
FullAdder   thi1fa10( Sec1_S[15], Sec1_C[14], Sec2_S[6], Thi1_S[14], Thi1_C[14] );
FullAdder   thi1fa11( Sec1_S[16], Sec1_C[15], Sec2_S[7], Thi1_S[15], Thi1_C[15] );
FullAdder   thi1fa12( Sec1_S[17], Sec1_C[16], Sec2_S[8], Thi1_S[16], Thi1_C[16] );
FullAdder   thi1fa13( Sec1_S[18], Sec1_C[17], Sec2_S[9], Thi1_S[17], Thi1_C[17] );
FullAdder   thi1fa14( Sec1_S[19], Sec1_C[18], Sec2_S[10], Thi1_S[18], Thi1_C[18] );
FullAdder   thi1fa15( Sec1_S[20], Sec1_C[19], Sec2_S[11], Thi1_S[19], Thi1_C[19] );
FullAdder   thi1fa16( Sec1_S[21], Sec1_C[20], Sec2_S[12], Thi1_S[20], Thi1_C[20] );
FullAdder   thi1fa17( Sec1_S[22], Sec1_C[21], Sec2_S[13], Thi1_S[21], Thi1_C[21] );
FullAdder   thi1fa18( Sec1_S[23], Sec1_C[22], Sec2_S[14], Thi1_S[22], Thi1_C[22] ); 
FullAdder   thi1fa19( Sec1_S[24], Sec1_C[23], Sec2_S[15], Thi1_S[23], Thi1_C[23] );
FullAdder   thi1fa20( Sec1_S[25], Sec1_C[24], Sec2_S[16], Thi1_S[24], Thi1_C[24] );
FullAdder   thi1fa21( Sec1_S[26], Sec1_C[25], Sec2_S[17], Thi1_S[25], Thi1_C[25] );
FullAdder   thi1fa22( Sec1_S[27], Sec1_C[26], Sec2_S[18], Thi1_S[26], Thi1_C[26] );
FullAdder   thi1fa23( Sec1_S[28], Sec1_C[27], Sec2_S[19], Thi1_S[27], Thi1_C[27] );
FullAdder   thi1fa24( Sec1_S[29], Sec1_C[28], Sec2_S[20], Thi1_S[28], Thi1_C[28] );
FullAdder   thi1fa25( Fir2_S[25], Sec1_C[29], Sec2_S[21], Thi1_S[29], Thi1_C[29] );
HalfAdder   thi1ha6( Fir2_S[26], Sec2_S[22], Thi1_S[30], Thi1_C[30] );
HalfAdder   thi1ha7( Fir2_S[27], Sec2_S[23], Thi1_S[31], Thi1_C[31] );
HalfAdder   thi1ha8( Fir2_S[28], Sec2_S[24], Thi1_S[32], Thi1_C[32] );
HalfAdder   thi1ha9( pp6[27], Sec2_S[25], Thi1_S[33], Thi1_C[33] );

HalfAdder   thi2ha1( Sec2_C[5], pp10[0], Thi2_S[0], Thi2_C[0] );
HalfAdder   thi2ha2( Sec2_C[6], pp10[1], Thi2_S[1], Thi2_C[1] );
HalfAdder   thi2ha3( Sec2_C[7], Fir4_S[0], Thi2_S[2], Thi2_C[2] );
HalfAdder   thi2ha4( Sec2_C[8], Sec3_S[0], Thi2_S[3], Thi2_C[3] );
FullAdder   thi2fa1( Sec2_C[9], Sec3_S[1], Sec3_C[0], Thi2_S[4], Thi2_C[4] );
FullAdder   thi2fa2( Sec2_C[10], Sec3_S[2], Sec3_C[1], Thi2_S[5], Thi2_C[5] );
FullAdder   thi2fa3( Sec2_C[11], Sec3_S[3], Sec3_C[2], Thi2_S[6], Thi2_C[6] );
FullAdder   thi2fa4( Sec2_C[12], Sec3_S[4], Sec3_C[3], Thi2_S[7], Thi2_C[7] );
FullAdder   thi2fa5( Sec2_C[13], Sec3_S[5], Sec3_C[4], Thi2_S[8], Thi2_C[8] );
FullAdder   thi2fa6( Sec2_C[14], Sec3_S[6], Sec3_C[5], Thi2_S[9], Thi2_C[9] );
FullAdder   thi2fa7( Sec2_C[15], Sec3_S[7], Sec3_C[6], Thi2_S[10], Thi2_C[10] );
FullAdder   thi2fa8( Sec2_C[16], Sec3_S[8], Sec3_C[7], Thi2_S[11], Thi2_C[11] );
FullAdder   thi2fa9( Sec2_C[17], Sec3_S[9], Sec3_C[8], Thi2_S[12], Thi2_C[12] );
FullAdder   thi2fa10( Sec2_C[18], Sec3_S[10], Sec3_C[9], Thi2_S[13], Thi2_C[13] );
FullAdder   thi2fa11( Sec2_C[19], Sec3_S[11], Sec3_C[10], Thi2_S[14], Thi2_C[14] );
FullAdder   thi2fa12( Sec2_C[20], Sec3_S[12], Sec3_C[11], Thi2_S[15], Thi2_C[15] );
FullAdder   thi2fa13( Sec2_C[21], Sec3_S[13], Sec3_C[12], Thi2_S[16], Thi2_C[16] );
FullAdder   thi2fa14( Sec2_C[22], Sec3_S[14], Sec3_C[13], Thi2_S[17], Thi2_C[17] );
FullAdder   thi2fa15( Sec2_C[23], Sec3_S[15], Sec3_C[14], Thi2_S[18], Thi2_C[18] );
FullAdder   thi2fa16( Sec2_C[24], Sec3_S[16], Sec3_C[15], Thi2_S[19], Thi2_C[19] );
FullAdder   thi2fa17( Sec2_C[25], Sec3_S[17], Sec3_C[16], Thi2_S[20], Thi2_C[20] );
FullAdder   thi2fa18( Sec2_C[26], Sec3_S[18], Sec3_C[17], Thi2_S[21], Thi2_C[21] );
FullAdder   thi2fa19( Sec2_C[27], Sec3_S[19], Sec3_C[18], Thi2_S[22], Thi2_C[22] );
FullAdder   thi2fa20( Sec2_C[28], Sec3_S[20], Sec3_C[19], Thi2_S[23], Thi2_C[23] );
FullAdder   thi2fa21( Sec2_C[29], Sec3_S[21], Sec3_C[20], Thi2_S[24], Thi2_C[24] );
FullAdder   thi2fa22( Sec2_C[30], Sec3_S[22], Sec3_C[21], Thi2_S[25], Thi2_C[25] );
FullAdder   thi2fa23( Sec2_C[31], Sec3_S[23], Sec3_C[22], Thi2_S[26], Thi2_C[26] );
HalfAdder   thi2ha5( Sec3_S[24], Sec3_C[23], Thi2_S[27], Thi2_C[27] );
HalfAdder   thi2ha6( Sec3_S[25], Sec3_C[24], Thi2_S[28], Thi2_C[28] );
HalfAdder   thi2ha7( Sec3_S[26], Sec3_C[25], Thi2_S[29], Thi2_C[29] );
HalfAdder   thi2ha8( Sec3_S[27], Sec3_C[26], Thi2_S[30], Thi2_C[30] );
HalfAdder   thi2ha9( Sec3_S[28], Sec3_C[27], Thi2_S[31], Thi2_C[31] );

//--------------------------------------------------------------------------
// Fourth Stage
//--------------------------------------------------------------------------
wire [39:0] Fou_S, Fou_C;

HalfAdder   fouha1( Thi1_S[1], Thi1_C[0], Fou_S[0], Fou_C[0] );
HalfAdder   fouha2( Thi1_S[2], Thi1_C[1], Fou_S[1], Fou_C[1] ); 
HalfAdder   fouha3( Thi1_S[3], Thi1_C[2], Fou_S[2], Fou_C[2] );
HalfAdder   fouha4( Thi1_S[4], Thi1_C[3], Fou_S[3], Fou_C[3] );
HalfAdder   fouha5( Thi1_S[5], Thi1_C[4], Fou_S[4], Fou_C[4] );
HalfAdder   fouha6( Thi1_S[6], Thi1_C[5], Fou_S[5], Fou_C[5] );
HalfAdder   fouha7( Thi1_S[7], Thi1_C[6], Fou_S[6], Fou_C[6] );
HalfAdder   fouha8( Thi1_S[8], Thi1_C[7], Fou_S[7], Fou_C[7] );
FullAdder   foufa1( Thi1_S[9], Thi1_C[8], Sec2_C[0], Fou_S[8], Fou_C[8] );
FullAdder   foufa2( Thi1_S[10], Thi1_C[9], Sec2_C[1], Fou_S[9], Fou_C[9] );
FullAdder   foufa3( Thi1_S[11], Thi1_C[10], Sec2_C[2], Fou_S[10], Fou_C[10] );
FullAdder   foufa4( Thi1_S[12], Thi1_C[11], Sec2_C[3], Fou_S[11], Fou_C[11] );
FullAdder   foufa5( Thi1_S[13], Thi1_C[12], Sec2_C[4], Fou_S[12], Fou_C[12] );
FullAdder   foufa6( Thi1_S[14], Thi1_C[13], Thi2_S[0], Fou_S[13], Fou_C[13] );
FullAdder   foufa7( Thi1_S[15], Thi1_C[14], Thi2_S[1], Fou_S[14], Fou_C[14] );
FullAdder   foufa8( Thi1_S[16], Thi1_C[15], Thi2_S[2], Fou_S[15], Fou_C[15] );
FullAdder   foufa9( Thi1_S[17], Thi1_C[16], Thi2_S[3], Fou_S[16], Fou_C[16] );
FullAdder   foufa10( Thi1_S[18], Thi1_C[17], Thi2_S[4], Fou_S[17], Fou_C[17] );
FullAdder   foufa11( Thi1_S[19], Thi1_C[18], Thi2_S[5], Fou_S[18], Fou_C[18] );
FullAdder   foufa12( Thi1_S[20], Thi1_C[19], Thi2_S[6], Fou_S[19], Fou_C[19] );
FullAdder   foufa13( Thi1_S[21], Thi1_C[20], Thi2_S[7], Fou_S[20], Fou_C[20] );
FullAdder   foufa14( Thi1_S[22], Thi1_C[21], Thi2_S[8], Fou_S[21], Fou_C[21] );
FullAdder   foufa15( Thi1_S[23], Thi1_C[22], Thi2_S[9], Fou_S[22], Fou_C[22] );
FullAdder   foufa16( Thi1_S[24], Thi1_C[23], Thi2_S[10], Fou_S[23], Fou_C[23] );
FullAdder   foufa17( Thi1_S[25], Thi1_C[24], Thi2_S[11], Fou_S[24], Fou_C[24] );
FullAdder   foufa18( Thi1_S[26], Thi1_C[25], Thi2_S[12], Fou_S[25], Fou_C[25] );
FullAdder   foufa19( Thi1_S[27], Thi1_C[26], Thi2_S[13], Fou_S[26], Fou_C[26] );
FullAdder   foufa20( Thi1_S[28], Thi1_C[27], Thi2_S[14], Fou_S[27], Fou_C[27] );
FullAdder   foufa21( Thi1_S[29], Thi1_C[28], Thi2_S[15], Fou_S[28], Fou_C[28] );
FullAdder   foufa22( Thi1_S[30], Thi1_C[29], Thi2_S[16], Fou_S[29], Fou_C[29] );
FullAdder   foufa23( Thi1_S[31], Thi1_C[30], Thi2_S[17], Fou_S[30], Fou_C[30] );
FullAdder   foufa24( Thi1_S[32], Thi1_C[31], Thi2_S[18], Fou_S[31], Fou_C[31] );
FullAdder   foufa25( Thi1_S[33], Thi1_C[32], Thi2_S[19], Fou_S[32], Fou_C[32] );
FullAdder   foufa26( Sec2_S[26], Thi1_C[33], Thi2_S[20], Fou_S[33], Fou_C[33] );
HalfAdder   fouha9( Sec2_S[27], Thi2_S[21], Fou_S[34], Fou_C[34] );
HalfAdder   fouha10( Sec2_S[28], Thi2_S[22], Fou_S[35], Fou_C[35] );
HalfAdder   fouha11( Sec2_S[29], Thi2_S[23], Fou_S[36], Fou_C[36] );
HalfAdder   fouha12( Sec2_S[30], Thi2_S[24], Fou_S[37], Fou_C[37] );
HalfAdder   fouha13( Sec2_S[31], Thi2_S[25], Fou_S[38], Fou_C[38] );
HalfAdder   fouha14( pp9[28], Thi2_S[26], Fou_S[39], Fou_C[39] );

//--------------------------------------------------------------------------
// Fifth Stage
//--------------------------------------------------------------------------
wire [30:0] Fif_S, Fif_C;

FullAdder   fiffa1( Fou_S[14], Fou_C[13], Thi2_C[0], Fif_S[0], Fif_C[0] );
FullAdder   fiffa2( Fou_S[15], Fou_C[14], Thi2_C[1], Fif_S[1], Fif_C[1] );  
FullAdder   fiffa3( Fou_S[16], Fou_C[15], Thi2_C[2], Fif_S[2], Fif_C[2] );
FullAdder   fiffa4( Fou_S[17], Fou_C[16], Thi2_C[3], Fif_S[3], Fif_C[3] );
FullAdder   fiffa5( Fou_S[18], Fou_C[17], Thi2_C[4], Fif_S[4], Fif_C[4] );
FullAdder   fiffa6( Fou_S[19], Fou_C[18], Thi2_C[5], Fif_S[5], Fif_C[5] );
FullAdder   fiffa7( Fou_S[20], Fou_C[19], Thi2_C[6], Fif_S[6], Fif_C[6] );
FullAdder   fiffa8( Fou_S[21], Fou_C[20], Thi2_C[7], Fif_S[7], Fif_C[7] );
FullAdder   fiffa9( Fou_S[22], Fou_C[21], Thi2_C[8], Fif_S[8], Fif_C[8] );
FullAdder   fiffa10( Fou_S[23], Fou_C[22], Thi2_C[9], Fif_S[9], Fif_C[9] );
FullAdder   fiffa11( Fou_S[24], Fou_C[23], Thi2_C[10], Fif_S[10], Fif_C[10] );
FullAdder   fiffa12( Fou_S[25], Fou_C[24], Thi2_C[11], Fif_S[11], Fif_C[11] );
FullAdder   fiffa13( Fou_S[26], Fou_C[25], Thi2_C[12], Fif_S[12], Fif_C[12] );
FullAdder   fiffa14( Fou_S[27], Fou_C[26], Thi2_C[13], Fif_S[13], Fif_C[13] );
FullAdder   fiffa15( Fou_S[28], Fou_C[27], Thi2_C[14], Fif_S[14], Fif_C[14] );
FullAdder   fiffa16( Fou_S[29], Fou_C[28], Thi2_C[15], Fif_S[15], Fif_C[15] );
FullAdder   fiffa17( Fou_S[30], Fou_C[29], Thi2_C[16], Fif_S[16], Fif_C[16] );
FullAdder   fiffa18( Fou_S[31], Fou_C[30], Thi2_C[17], Fif_S[17], Fif_C[17] );
FullAdder   fiffa19( Fou_S[32], Fou_C[31], Thi2_C[18], Fif_S[18], Fif_C[18] );
FullAdder   fiffa20( Fou_S[33], Fou_C[32], Thi2_C[19], Fif_S[19], Fif_C[19] );
FullAdder   fiffa21( Fou_S[34], Fou_C[33], Thi2_C[20], Fif_S[20], Fif_C[20] );
FullAdder   fiffa22( Fou_S[35], Fou_C[34], Thi2_C[21], Fif_S[21], Fif_C[21] );
FullAdder   fiffa23( Fou_S[36], Fou_C[35], Thi2_C[22], Fif_S[22], Fif_C[22] );
FullAdder   fiffa24( Fou_S[37], Fou_C[36], Thi2_C[23], Fif_S[23], Fif_C[23] );
FullAdder   fiffa25( Fou_S[38], Fou_C[37], Thi2_C[24], Fif_S[24], Fif_C[24] );
FullAdder   fiffa26( Fou_S[39], Fou_C[38], Thi2_C[25], Fif_S[25], Fif_C[25] );
FullAdder   fiffa27( Thi2_S[27], Fou_C[39], Thi2_C[26], Fif_S[26], Fif_C[26] );
HalfAdder   fifha1( Thi2_S[28], Thi2_C[27], Fif_S[27], Fif_C[27] ); 
HalfAdder   fifha2( Thi2_S[29], Thi2_C[28], Fif_S[28], Fif_C[28] );
HalfAdder   fifha3( Thi2_S[30], Thi2_C[29], Fif_S[29], Fif_C[29] );
HalfAdder   fifha4( Thi2_S[31], Thi2_C[30], Fif_S[30], Fif_C[30] );



assign s1={ Fif_S[30:0], Fou_S[13:0], Thi1_S[0], Sec1_S[0], Fir1_S[0] }; 
assign c1={ Fif_C[29:0], 1'b0, Fou_C[12:0], 4'd0};

always @(*) begin
    sum = s1;
    carry = c1;
end

endmodule