//======================================================================
// File Name    : booth_encoder.v
// Module Name  : booth_encoder
// Author       : Hzt
// Version      : 1.0
// Modified     : 2025/02/24 11:00
// Description  : To get the partial product
//======================================================================
`timescale 1ns/1ps

//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module booth_encoder #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,      // multiplicand
    input  wire [2:0]       b_seg,  // Multipliers in groups of three(b[i+1], b[i], b[i-1])
    output reg  [WIDTH+1:0] pp    // partial product with signal bit
);

//--------------------------------------------------------------------------
// Combinational Always Block (Use blocking assignment)
//--------------------------------------------------------------------------
wire [WIDTH+1:0] a_ext = {{2{a[7]}}, a};
always @(*) begin
    case (b_seg)
        3'b000:         pp = 0;                // +0
        3'b001:         pp = a_ext;                // +a
        3'b010:         pp = a_ext;                // +a    
        3'b011:         pp = a_ext << 1;           // +2a
        3'b100:         pp = (~a_ext + 1) << 1;    // -2a
        3'b101:         pp = ~a_ext + 1;           // -a
        3'b110:         pp = ~a_ext + 1;           // -a
        3'b111:         pp = 0;                // 0
        default:        pp = 0;
    endcase
end

endmodule
