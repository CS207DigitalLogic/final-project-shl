//======================================================================
// File Name    : int_Mul_pure_logic_v1.v
// Module Name  : int_Mul_pure_logic_v1
// Author       : Hzt
// Version      : 2.0
// Modified     : 2025/03/4 19:00
// Description  : The core module of multiplier with no clock
//======================================================================
`timescale 1ns/1ps

//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module int_Mul_pure_logic_v1 #(
    parameter WIDTH = 8,              // input bit
    parameter WIDTHX2 = 16,
    parameter PRECISION = 8           //4 or 8 to support the int4/int8
) (
    input  wire         clk,          // clk
    input  wire         rst,          // the negative is valid
    // input  wire         valid_in,     // input valid signal
    input  wire [7:0]   a,            // input a(the true width is PRECISION)
    input  wire [7:0]   b,            // input b(the true width is PRECISION)
    output reg  [15:0]  result       // the width is determined by the PRECISION
    // output reg          overflow,     // over signal
    // output reg          valid_out     // output valid signal
);

//--------------------------------------------------------------------------
// Internal Signal Declaration
//--------------------------------------------------------------------------

wire [WIDTH-1:0]    a_ext;
wire [WIDTH:0]    b_ext;
wire [WIDTH+1:0]  partial_products [3:0];//The max of it = PRECISION/2
wire [WIDTHX2-1:0]  final_result;

wire  [WIDTHX2-1:0]  Sum, Carry;


//--------------------------------------------------------------------------
// Data preprocess (signal bit extend) 
//--------------------------------------------------------------------------
assign a_ext = (PRECISION == 4) ? {{4{a[3]}}, a[3:0]} : a;
assign b_ext = (PRECISION == 4) ? {{4{b[3]}}, b[3:0], 1'b0} : {b, 1'b0};

//--------------------------------------------------------------------------
//Using booth_encoder to get the partial product
//--------------------------------------------------------------------------
    booth_encoder #(
        .WIDTH        (8)
    ) utt1 (
        .a            (a_ext),
        .b_seg        (b_ext[2:0]),
        .pp           (partial_products[0])
    );

    booth_encoder #(
        .WIDTH        (8)
    ) utt2 (
        .a            (a_ext),
        .b_seg        (b_ext[4:2]),
        .pp           (partial_products[1])
    );

    booth_encoder #(
        .WIDTH        (8)
    ) utt3 (
        .a            (a_ext),
        .b_seg        (b_ext[6:4]),
        .pp           (partial_products[2])
    );

    booth_encoder #(
        .WIDTH        (8)
    ) utt4 (
        .a            (a_ext),
        .b_seg        (b_ext[8:6]),
        .pp           (partial_products[3])
    );

//--------------------------------------------------------------------------
// partial product add
//--------------------------------------------------------------------------
    wallace_tree_modify
    utt5 (
        .a            (partial_products[0]),
        .b            (partial_products[1]),
        .c            (partial_products[2]),
        .d            (partial_products[3]),
        .sum          (Sum),
        .carry        (Carry)
    );


//--------------------------------------------------------------------------
//Final result calculate
//--------------------------------------------------------------------------
assign final_result = Sum + Carry ;

always @(*) begin
    if (PRECISION == 4) begin
        result = final_result[7:0];
    end
    else begin
        result = final_result[15:0];
    end
end

// always @(*) begin
//     valid_out = valid_pipe[2];
// end

endmodule
