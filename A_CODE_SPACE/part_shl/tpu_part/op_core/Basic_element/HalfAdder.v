//======================================================================
// File Name    : HalfAdder.v
// Module Name  : HalfAdder
// Author       : Hzt
// Version      : 1.0
// Modified     : 2025/02/24 22:00
// Description  : Full Adder
//======================================================================
`timescale 1ns/1ps

//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module HalfAdder(
    input  a,    
    input  b,    
    output sum,  
    output cout  
);
    assign sum  = a ^ b;  
    assign cout = a & b;  
endmodule