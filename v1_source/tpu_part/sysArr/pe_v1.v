//==============================================================================================================
// File Name    : pe_v1.v
// Module Name  : pe_v1
// Author       : Su Zhenyu
// Version      : 1.0
// Modified     : 2025/03/05 16:00
// Description  : basic elements of processing element version 1
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

  module pe_v1(
      //--------------------------------------------//
      //                    DEBUGGER                //
      //--------------------------------------------//
        `ifdef DEBUGGER_WR_WIG                      //
      //--------------------------------------------//i:
                                                    //o:
            output [3:0] debug,                     //  weight write debug
      //--------------------------------------------//
        `elsif DEBUGGER_WR_DAT
      //--------------------------------------------//i:
                                                    //o:
            output [3:0] debug,                     //  data  write debug
        `endif
      //------------------ SYS signal -------------//i:
        input           clk       ,                //  minimum clock frequency 200MHz
        input           rst_n     ,

      //------------------ Wig signal -------------//i:
        input           wwrite    ,                //  weight write enable
        input  [ 7:0]   win       ,                //  weight input
                                                   //o:
        output          wwriteout ,                //  weight write enable pass
        output [ 7:0]   wout      ,                //  weight output

      //------------------ Mac signal -------------//i:
        input           active    ,                //  data write & calculate enable
        input  [ 7:0]   datain    ,                //  data input
        input  [15:0]   sumin     ,                //  macc input
                                                   //o:
        output          activeout ,                //  data write & calculate enable pass
        output [15:0]   maccout   ,                //  macc result 
        output [ 7:0]   dataout                    //  data pass
    );

    //-----------------------------------------------------------------
    //                   Weight Preset & Passby
    //-----------------------------------------------------------------
        reg [7:0] weight       ;
        reg [7:0] weight_pass  ;
        reg       wwrite_pass ;
        assign wout      = weight_pass;
        assign wwriteout = wwrite_pass;
        
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                weight       <= 8'b0;
                weight_pass  <= 8'b0;
                wwrite_pass <= 1'b0;
            end
            else begin
                wwrite_pass <= wwrite;

                if(wwrite)begin
                    weight      <= win  ;
                    weight_pass <= weight;
                end
                else begin
                    weight      <= weight;
                    weight_pass <= 8'b0 ;
                end
            end
        end

    //-----------------------------------------------------------------
    //                     Data flow & Passby
    //-----------------------------------------------------------------
      //---------------------- MACC ------------------//logic
        wire [15:0] mult_result;
        wire [15:0] macc_result;
        assign macc_result = sumin + mult_result;
        int_Mul_pure_logic_v1 mult (
            .a (datain),
            .b (weight),
            .result(mult_result)
        );

      //--------------------- MACC -------------------//sequence
        reg [15:0] macc_pass   ;
        reg  [7:0] data_pass   ;
        reg        active_pass ;
        assign maccout   = macc_pass;
        assign dataout   = data_pass;
        assign activeout = active_pass;
        
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                macc_pass    <= 16'b0;
                data_pass  <=  8'b0;
                active_pass <= 1'b0;
            end
            else begin
                active_pass <= active;

                if(active)begin
                    data_pass   <= datain     ;  
                    macc_pass   <= macc_result;
                end
                else begin
                    data_pass   <= 0  ;  
                    macc_pass   <= 0  ;
                end
            end
        end
        
    //-----------------------------------------------------------------
    //                          DEBUGGER
    //-----------------------------------------------------------------
        `ifdef DEBUGGER_WR_WIG
            assign debug = weight[3:0];
        `elsif DEBUGGER_WR_DAT
            assign debug = data_pass[3:0];
        `endif

  endmodule // pe_v1
