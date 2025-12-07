//==============================================================================================================
// File Name    : pe_v1_2.v
// Module Name  : pe_v1_2
// Author       : Su Zhenyu
// Version      : 1.2
// Modified     : 2025/03/14 16:00
// Description  : basic elements of processing element version 1
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
    
//===============================================================================================================
//-----------------------------------------------MODULE DEFINE FUNCTIONS-----------------------------------------
//===============================================================================================================

  module pe_v1_2#(
    parameter INT_OR_FPU  = 0  , // 0:INT  1:FPU
    parameter WBUFF_WIDTH = 8  , // weight 1 byte
    parameter DBUFF_WIDTH = 8    // data   1 byte
  )(
    clk      ,
    rst_n    ,
    wwrite   ,
    win      ,  
    wwriteout,
    wout     ,
    active   ,
    datain   ,
    sumin    ,
    activeout,
    maccout  ,
    dataout
    );
    //-----------------------------------------------------------------
    //                       PARAMETER
    //-----------------------------------------------------------------
        localparam MACC_SUM_WIDTH = INT_OR_FPU ? 32: WBUFF_WIDTH + DBUFF_WIDTH;
    //-----------------------------------------------------------------
    //                        Input & Output
    //-----------------------------------------------------------------
      //------------------ SYS signal ------------------------//i:
        input                         clk       ;             //  minimum clock frequency 200MHz
        input                         rst_n     ;
      //------------------ Wig signal ------------------------//i:
        input                         wwrite    ;             //  weight write enable
        input  [WBUFF_WIDTH-1:0]      win       ;             //  weight input
                                                              //o:
        output                        wwriteout ;             //  weight write enable pass
        output [WBUFF_WIDTH-1:0]      wout      ;             //  weight output

      //------------------ Mac signal ------------------------//i:
        input                         active    ;             //  data write & calculate enable
        input  [DBUFF_WIDTH-1:0]      datain    ;             //  data input
        input  [MACC_SUM_WIDTH-1:0]   sumin     ;             //  macc input
                                                              //o:
        output                        activeout ;             //  data write & calculate enable pass
        output [MACC_SUM_WIDTH-1:0]   maccout   ;             //  macc result 
        output [DBUFF_WIDTH-1:0]      dataout   ;             //  data pass
    //-----------------------------------------------------------------
    //                   Weight Preset & Passby
    //-----------------------------------------------------------------
        reg [WBUFF_WIDTH-1:0] weight       ;
        reg [WBUFF_WIDTH-1:0] weight_pass  ;
        reg       wwrite_pass ;
        assign wout      = weight_pass;
        assign wwriteout = wwrite_pass;
        
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                weight       <= {WBUFF_WIDTH{1'b0}};
                weight_pass  <= {WBUFF_WIDTH{1'b0}};
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
                    weight_pass <= {WBUFF_WIDTH{1'b0}} ;
                end
            end
        end

    //-----------------------------------------------------------------
    //                     Data flow & Passby
    //-----------------------------------------------------------------
      //---------------------- MACC ------------------//logic
        
        wire [MACC_SUM_WIDTH-1:0] macc_result;
        
        generate if(INT_OR_FPU)begin
            FPU_top_all macc(
                .A     (datain     ),
                .B     (weight     ),
                .C     (sumin      ),
                .Result(macc_result)
            );
        end 
        else begin
            wire [MACC_SUM_WIDTH-1:0] mult_result;
            // INT
            int_Mul_8x8_logic mult (
                .a (datain),
                .b (weight),
                .result(mult_result)
            );
            // ADD
            assign macc_result = sumin + mult_result;
        end endgenerate
        

      //--------------------- MACC -------------------//sequence
        reg [MACC_SUM_WIDTH-1:0] macc_pass   ;
        reg [DBUFF_WIDTH-1:0]    data_pass   ;
        reg                      active_pass ;
        assign maccout   = macc_pass;
        assign dataout   = data_pass;
        assign activeout = active_pass;
        
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                macc_pass    <= {(MACC_SUM_WIDTH){1'b0}};
                data_pass    <= {DBUFF_WIDTH{1'b0}};
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
        

  endmodule // pe_v1_2
