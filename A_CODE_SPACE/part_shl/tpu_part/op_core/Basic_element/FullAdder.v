//======================================================================
// File Name    : FullAdder.v
// Module Name  : FullAdder
// Author       : Hzt
// Version      : 1.0
// Modified     : 2025/02/24 22:00
// Description  : Full Adder
//======================================================================
`timescale 1ns/1ps

//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module FullAdder(
    input  a,    
    input  b,    
    input  cin,  
    output sum,  
    output cout  
);
    assign sum = a ^ b ^ cin;
    
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule
