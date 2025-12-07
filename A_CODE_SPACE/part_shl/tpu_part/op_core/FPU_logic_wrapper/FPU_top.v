//======================================================================
// File Name    : FPU_top_all.v
// Module Name  : FPU_top_all
// Author       : Hzt
// Version      : 1.0
// Modified     : 2025/03/14 14:00
// Description  : The Top module of FPU to achcieve the AxB+C
//======================================================================
`timescale 1ns/1ps

//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module FPU_top_all #(
        parameter WIDTH = 32,
        parameter PRECISION = 32           //32 or 16 to support the 32bit /  16bit
    )(
        input wire                 clk,
        input wire                 rst,
        input wire [WIDTH-1:0]     A,
        input wire [WIDTH-1:0]     B,
        input wire [WIDTH-1:0]     C,


        output reg [WIDTH-1:0]     Result
    );

//--------------------------------------------------------------------------
// Internal Signal Declaration
//--------------------------------------------------------------------------
    wire [WIDTH-1:0] mediate_result;
    wire [WIDTH-1:0] Result_w;


    FPU_v1_0 #(
        .WIDTH     	( 32     ),
        .PRECISION 	( 32  ))
    u_FPU_new1(
        .clk     	( clk      ),
        .rst     	( rst      ),
        .A       	( A        ),
        .B       	( B        ),
        .Control 	( 1  ),
        .Result  	( mediate_result   )
    );


    FPU_v1_0 #(
        .WIDTH     	( 32     ),
        .PRECISION 	( 32  ))
    u_FPU_new2(
        .clk     	( clk      ),
        .rst     	( rst      ),
        .A       	( mediate_result        ),
        .B       	( C        ),
        .Control 	( 0  ),
        .Result  	( Result_w   )
    );


always @(*) begin
    Result = Result_w;
end


endmodule