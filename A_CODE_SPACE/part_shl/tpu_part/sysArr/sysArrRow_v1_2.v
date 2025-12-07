//==============================================================================================================
// File Name    : sysArrRow_v1_2.v
// Module Name  : sysArrRow_v1_2
// Author       : Su Zhenyu
// Version      : 1.0
// Modified     : 2025/03/10 22:00
// Description  : aline pes to create a row version 1
// Function List:
//  1.load the weight
//  2.calculate the macc
//  3.passby the weight\data\active\wwrite
//===============================================================================================================
    `timescale 1ns / 1ps
//===============================================================================================================
//-----------------------------------------------DIFINE EABLE FUNCTIONS------------------------------------------
//===============================================================================================================
    //`define DEBUGGER_WR_WIG
    //`define DEBUGGER_WR_DAT

//===============================================================================================================
//-----------------------------------------------MODULE DEFINE FUNCTIONS-----------------------------------------
//===============================================================================================================

module sysArrRow_v1_2#(
    parameter INT_OR_FPU  = 0  , // 0:INT  1:FPU
    parameter MATRIX_COL  = 16 ,
    parameter WBUFF_WIDTH = 8  , // weight 1 byte
    parameter DBUFF_WIDTH = 8    // data   1 byte
)(
    clk      ,
    rst_n    ,
    active   ,
    activeout,
    wwrite   , 
    wwriteout,
    datain   ,
    dataout  ,
    win      ,
    wout     ,
    sumin    ,
    maccout
);
    //-----------------------------------------------------------------
    //                       PARAMETER
    //-----------------------------------------------------------------
        parameter MACC_SUM_WIDTH = INT_OR_FPU ? 32: WBUFF_WIDTH + DBUFF_WIDTH;
    //-----------------------------------------------------------------
    //                        Input & Output
    //-----------------------------------------------------------------
        //------------------Sys singal------------------//
        input                                clk  ;
        input                                rst_n;
        //----------------Active singal-----------------//
        input                                active   ;
        output [MATRIX_COL-1:0 ]             activeout;
        //----------------Wwrite singal-----------------//
        input  [MATRIX_COL-1:0 ]             wwrite   ;
        output [MATRIX_COL-1:0 ]             wwriteout;
        //------------------Data singal-----------------//
        input  [DBUFF_WIDTH-1:0]             datain ;
        output [DBUFF_WIDTH-1:0]             dataout;
        //-----------------Wight singal-----------------//
        input  [MATRIX_COL*WBUFF_WIDTH-1:0]  win    ;
        output [MATRIX_COL*WBUFF_WIDTH-1:0]  wout   ;
        //------------------Macc singal-----------------//
        input  [MATRIX_COL*MACC_SUM_WIDTH-1:0] sumin   ;
        output [MATRIX_COL*MACC_SUM_WIDTH-1:0] maccout ;
    
    
    
    
    //-----------------------------------------------------------------
    //          Interconnects (PE - PE Connections)
    //-----------------------------------------------------------------
        wire [MATRIX_COL-1:0]                           activeout_inter;
        wire [(MATRIX_COL*DBUFF_WIDTH-DBUFF_WIDTH)-1:0] dataout_inter  ;

        assign activeout = activeout_inter;
    //-----------------------------------------------------------------
    //               Generate the PEs in the row
    //-----------------------------------------------------------------
        genvar i;
        generate
            for (i = 0; i < MATRIX_COL; i = i + 1) begin : genblk1
                if (i == 0) begin
                    // The first PE in the row has different inputs
                    pe_v1_2#(
                        .INT_OR_FPU  (INT_OR_FPU ),
                        .WBUFF_WIDTH (WBUFF_WIDTH),
                        .DBUFF_WIDTH (DBUFF_WIDTH)
                    ) first_pe_inst(
                        .clk         (clk       ),
                        .rst_n       (rst_n     ),
                        .active      (active    ),
                        .datain      (datain    ),
                        .win         (win[WBUFF_WIDTH-1:0]     ),
                        .sumin       (sumin[MACC_SUM_WIDTH-1:0]),
                        .wwrite      (wwrite[0] ),
                        .maccout     (maccout[MACC_SUM_WIDTH-1:0]   ),
                        .dataout     (dataout_inter[DBUFF_WIDTH-1:0]),
                        .wout        (wout[WBUFF_WIDTH-1:0]),
                        .wwriteout   (wwriteout[0]),
                        .activeout   (activeout_inter[i])
                    );
                end // if (i == 0)
                else if (i == MATRIX_COL - 1) begin
                    // The last PE in the row has different outputs
                    pe_v1_2#(
                        .INT_OR_FPU  (INT_OR_FPU ),
                        .WBUFF_WIDTH (WBUFF_WIDTH),
                        .DBUFF_WIDTH (DBUFF_WIDTH)
                    ) last_pe_inst(
                        .clk         (clk        ),
                        .rst_n       (rst_n      ),
                        .active      (activeout_inter[i-1]),
                        .datain      (dataout_inter[(i*DBUFF_WIDTH)-1:(i-1)*DBUFF_WIDTH]),
                        .win         (win[((i+1)*WBUFF_WIDTH)-1:(i*WBUFF_WIDTH)]),
                        .sumin       (sumin[((i+1)*MACC_SUM_WIDTH)-1:(i*MACC_SUM_WIDTH)]),
                        .wwrite      (wwrite[MATRIX_COL-1]),
                        .maccout     (maccout[((i+1)*MACC_SUM_WIDTH)-1:(i*MACC_SUM_WIDTH)]),
                        .dataout     (dataout    ),
                        .wout        (wout[((i+1)*WBUFF_WIDTH)-1:(i*WBUFF_WIDTH)]),
                        .wwriteout   (wwriteout[MATRIX_COL-1]),
                        .activeout   (activeout_inter[i])
                    );
                end // else if (i == MATRIX_COL - 1)
                else begin
                    pe_v1_2#(
                        .INT_OR_FPU  (INT_OR_FPU ),
                        .WBUFF_WIDTH (WBUFF_WIDTH),
                        .DBUFF_WIDTH (DBUFF_WIDTH)
                    ) pe_inst(
                        .clk         (clk        ),
                        .rst_n       (rst_n      ),
                        .active      (activeout_inter[i-1]),
                        .datain      (dataout_inter[(i*DBUFF_WIDTH)-1:(i-1)*DBUFF_WIDTH]),
                        .win         (win[((i+1)*WBUFF_WIDTH)-1:(i*WBUFF_WIDTH)]),
                        .sumin       (sumin[((i+1)*MACC_SUM_WIDTH)-1:(i*MACC_SUM_WIDTH)]),
                        .wwrite      (wwrite[i]  ),
                        .maccout     (maccout[((i+1)*MACC_SUM_WIDTH)-1:(i*MACC_SUM_WIDTH)]),
                        .dataout     (dataout_inter[((i+1)*DBUFF_WIDTH)-1:(i*DBUFF_WIDTH)]),
                        .wout        (wout[((i+1)*WBUFF_WIDTH)-1:(i*WBUFF_WIDTH)]),
                        .wwriteout   (wwriteout[i]      ),
                        .activeout   (activeout_inter[i])
                    );
                end // else
            end // for (i = 0; i < MATRIX_COL; i = i + 1)
        endgenerate
endmodule // sysArrRow
