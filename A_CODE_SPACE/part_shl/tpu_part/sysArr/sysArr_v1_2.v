//==============================================================================================================
// File Name    : sysArr_v1_2.v
// Module Name  : sysArr_v1_2
// Author       : Su Zhenyu
// Version      : 1.0
// Modified     : 2025/03/14 22:00
// Description  : aline pes to create a array version 1
// Function List:
//  1.load the weight
//  2.calculate the macc
//  3.passby the weight\data\active\wwrite
// NEW COMMENT :
//  [3.14] try to add FPU and create a enable defination for it
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

module sysArr_v1_2#(
    parameter INT_OR_FPU  = 0  , // 0:INT  1:FPU
    parameter MATRIX_COL  = 16 ,
    parameter MATRIX_ROW  = 16 ,
    parameter WBUFF_WIDTH = 8  , // weight 1 byte
    parameter DBUFF_WIDTH = 8    // data   1 byte
)(
    clk,
    rst_n,
    active    ,
    activeout , 
    wwrite    ,
    wwriteout , //not used
    datain    ,
    dataout   , //not used right side dataout 
    win       ,
    wout      , //not used down side wout
    sumin     , //always 0
    maccout    
);
    //-----------------------------------------------------------------
    //                      Parameter
    //-----------------------------------------------------------------
        parameter MACC_SUM_WIDTH = INT_OR_FPU ? 32: WBUFF_WIDTH + DBUFF_WIDTH;
    //-----------------------------------------------------------------
    //                      Input & Output
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
        input  [DBUFF_WIDTH*MATRIX_ROW-1:0]    datain ;
        output [DBUFF_WIDTH*MATRIX_ROW-1:0]    dataout;
        //------------------Win singal------------------//
        input  [WBUFF_WIDTH*MATRIX_COL-1:0]    win    ;
        output [WBUFF_WIDTH*MATRIX_COL-1:0]    wout   ;
        //------------------Sumin singal----------------//
        input  [MACC_SUM_WIDTH*MATRIX_COL-1:0] sumin  ;
        output [MACC_SUM_WIDTH*MATRIX_COL-1:0] maccout;
    
    //-----------------------------------------------------------------
    //          Interconnects (PE - PE Connections)
    //-----------------------------------------------------------------
        wire [((MATRIX_ROW-1)*MATRIX_COL*MACC_SUM_WIDTH)-1:0] maccout_inter   ;
        wire [((MATRIX_ROW-1)*MATRIX_COL*WBUFF_WIDTH)-1:0]    wout_inter      ;
        wire [((MATRIX_ROW-1)*MATRIX_COL)-1:0]                wwriteout_inter ;
        wire [((MATRIX_ROW-1)*MATRIX_COL)-1:0]                activeout_inter ;
    //-----------------------------------------------------------------
    //               Generate the PEs Array
    //-----------------------------------------------------------------
        genvar i;
        generate
            for (i = 0; i < MATRIX_ROW; i = i + 1) begin : genblk1
                if (i == 0) begin
                    // The first row has different inputs
                    sysArrRow_v1_2 #(
                        .INT_OR_FPU  (INT_OR_FPU ),
                        .MATRIX_COL  (MATRIX_COL ),
                        .WBUFF_WIDTH (WBUFF_WIDTH),
                        .DBUFF_WIDTH (DBUFF_WIDTH)
                    )first_sysArrRow_inst(
                        .clk      (clk   ),
                        .rst_n    (rst_n ),
                        .active   (active),
                        .datain   (datain[((i+1)*DBUFF_WIDTH)-1:(i*DBUFF_WIDTH)]),
                        .win      (win   ),
                        .sumin    ({(MACC_SUM_WIDTH*MATRIX_COL){1'b0}}), // Simulation may throw a warning due to unmatched port sizes here
                        .wwrite   (wwrite),
                        .maccout  (maccout_inter[((i+1)*MACC_SUM_WIDTH*MATRIX_COL)-1:(i*MACC_SUM_WIDTH*MATRIX_COL)]),
                        .wout     (wout_inter[((i+1)*MATRIX_COL*WBUFF_WIDTH)-1:(i*MATRIX_COL*WBUFF_WIDTH)]),
                        .wwriteout(wwriteout_inter[((i+1)*MATRIX_COL)-1:(i*MATRIX_COL)]),
                        .activeout(activeout_inter[((i+1)*MATRIX_COL)-1:(i*MATRIX_COL)]),
                        .dataout  (dataout[((i+1)*DBUFF_WIDTH)-1:(i*DBUFF_WIDTH)])
                    );


                end // if (i == 0)

                else if (i == MATRIX_ROW-1) begin
                    // The last row has different outputs
                    sysArrRow_v1_2 #(
                        .INT_OR_FPU  (INT_OR_FPU ),
                        .MATRIX_COL  (MATRIX_COL ),
                        .WBUFF_WIDTH (WBUFF_WIDTH),
                        .DBUFF_WIDTH (DBUFF_WIDTH)
                    )last_sysArrRow_inst(
                        .clk      (clk     ),
                        .rst_n    (rst_n   ),
                        .active   (activeout_inter[((i-1)*MATRIX_COL)]),
                        .datain   (datain[((i+1)*DBUFF_WIDTH)-1:(i*DBUFF_WIDTH)]),
                        .win      (wout_inter[(i*MATRIX_COL*WBUFF_WIDTH)-1:((i-1)*MATRIX_COL*WBUFF_WIDTH)]),
                        .sumin    (maccout_inter[(i*MACC_SUM_WIDTH*MATRIX_COL)-1:((i-1)*MACC_SUM_WIDTH*MATRIX_COL)]),
                        .wwrite   (wwriteout_inter[(i*MATRIX_COL)-1:((i-1)*MATRIX_COL)]),
                        .maccout  (maccout ),
                        .wout     (wout    ),
                        .wwriteout(wwriteout),
                        .activeout(activeout),
                        .dataout  (dataout[((i+1)*DBUFF_WIDTH)-1:(i*DBUFF_WIDTH)])
                    );



                end // else if (i == width_height-1)

                else begin
                    // intermediate rows have generic inputs/outputs
                    sysArrRow_v1_2 #(
                        .INT_OR_FPU  (INT_OR_FPU ),
                        .MATRIX_COL  (MATRIX_COL ),
                        .WBUFF_WIDTH (WBUFF_WIDTH),
                        .DBUFF_WIDTH (DBUFF_WIDTH)
                    )sysArrRow_inst(
                        .clk      (clk  ),
                        .rst_n    (rst_n),
                        .active   (activeout_inter[((i-1)*MATRIX_COL)]),
                        .datain   (datain[((i+1)*DBUFF_WIDTH)-1:(i*DBUFF_WIDTH)]),
                        .win      (wout_inter[(i*MATRIX_COL*WBUFF_WIDTH)-1:((i-1)*MATRIX_COL*WBUFF_WIDTH)]),
                        .sumin    (maccout_inter[(i*MACC_SUM_WIDTH*MATRIX_COL)-1:((i-1)*MACC_SUM_WIDTH*MATRIX_COL)]),
                        .wwrite   (wwriteout_inter[(i*MATRIX_COL)-1:((i-1)*MATRIX_COL)]),
                        .maccout  (maccout_inter[((i+1)*MACC_SUM_WIDTH*MATRIX_COL)-1:(i*MACC_SUM_WIDTH*MATRIX_COL)]),
                        .wout     (wout_inter[((i+1)*MATRIX_COL*WBUFF_WIDTH)-1:(i*MATRIX_COL*WBUFF_WIDTH)]),
                        .wwriteout(wwriteout_inter[((i+1)*MATRIX_COL)-1:(i*MATRIX_COL)]),
                        .activeout(activeout_inter[((i+1)*MATRIX_COL)-1:(i*MATRIX_COL)]),
                        .dataout  (dataout[((i+1)*DBUFF_WIDTH)-1:(i*WBUFF_WIDTH)])
                    );



                end // else
            end // for (i = 0; i < width_height; i = i + 1)
        endgenerate
endmodule // sysArr
