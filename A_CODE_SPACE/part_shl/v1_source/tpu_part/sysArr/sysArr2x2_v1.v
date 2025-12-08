//==============================================================================================================
// File Name    : sysArr2x2_v1.v
// Module Name  : sysArr2x2_v1
// Author       : Su Zhenyu
// Version      : 1.0
// Modified     : 2025/03/05 16:00
// Description  : version 1 of syArr2x2
// Function List:
//===============================================================================================================
    `timescale 1ns/1ps
//===============================================================================================================
//-----------------------------------------------DIFINE EABLE FUNCTIONS------------------------------------------
//===============================================================================================================
    //`define DEBUGGER_WR_WIG
    //`define DEBUGGER_WR_DAT
    //`define DEBUGGER_CALCU

//===============================================================================================================
//-----------------------------------------------MODULE DEFINE FUNCTIONS-----------------------------------------
//===============================================================================================================   
  module sysArr2x2_v1(
      //--------------------------------------------//
      //                    DEBUGGER                //
      //--------------------------------------------//
        `ifdef DEBUGGER_WR_WIG                      //
      //--------------------------------------------//i:
            input wire [1:0] sel_keys  ,            //  select keys
                                                    //o:
            output reg [3:0] debug     ,            //  weight write debug 
      //--------------------------------------------//
        `elsif DEBUGGER_WR_DAT                      //
      //--------------------------------------------//i:
            input wire [1:0] sel_keys  ,            //  select keys
                                                    //o:
            output reg [3:0] debug     ,            //  data  write debug
      //--------------------------------------------//
        `elsif DEBUGGER_CALCU                       //
      //--------------------------------------------//i:
                                                    //o:
        `endif
      //------------------ SYS signal -------------//i:
        input clk,
        input rst_n,

      //------------------ Wig signal -------------//i:
        input       [ 1:0] wwrite    ,             //  2 write enable inputs
        input       [15:0] win       ,             //  2 weight inputs
                                                   //o:
        output wire [ 7:0] wout1,                  // 2 weight outputs
        output wire [ 7:0] wout2,                  //
        output wire        wwriteout1,             // 2 weight write outputs
        output wire        wwriteout2,             //

      //------------------ Mac signal -------------//i:
        input              active,                 //
        input       [15:0] datain    ,             // 2 datain inputs
        input       [31:0] sumin     ,             // 2 sumin inputs
                                                   //o:
        output wire [15:0] maccout1  ,             // 2 maccout outputs
        output wire [15:0] maccout2  ,             //
        output wire        activeout1,             // 2 active outputs
        output wire        activeout2,             //
        output wire [ 7:0] dataout1  ,             // 2 dataout outputs
        output wire [ 7:0] dataout2                //

    );  
    //-----------------------------------------------------------------
    //                    DEBUGGER SINGALS DEFINE
    //-----------------------------------------------------------------
        `ifdef DEBUGGER_WR_WIG
            wire [3:0]debug0,debug1,debug2,debug3; 
        `elsif DEBUGGER_WR_DAT
            wire [3:0]debug0,debug1,debug2,debug3;
        `endif
    //-----------------------------------------------------------------
    //                          Interconnects
    //-----------------------------------------------------------------
      //------------------ Wire signal -------------//
        wire [15:0] macc_topLeft, macc_topRight;
        wire activeOutTopLeft, activeOutTopRight, activeOutBotLeft, activeOutBotRight;
        wire [7:0] dataoutTopLeft, dataoutBotLeft, dataoutTopRight, dataoutBotRight;
        wire [7:0] woutTopLeft, woutTopRight;
        wire wwriteoutTopLeft, wwriteoutTopRight;

        wire [15:0] maccoutBotLeft, maccoutBotRight;
        wire [7:0] woutBotLeft, woutBotRight;
        wire wwriteoutBotLeft, wwriteoutBotRight;

        assign maccout1 = maccoutBotLeft;
        assign maccout2 = maccoutBotRight;

        assign wout1 = woutBotLeft;
        assign wout2 = woutBotRight;

        assign wwriteout1 = wwriteoutBotLeft;
        assign wwriteout2 = wwriteoutBotRight;

        assign activeout1 = activeOutBotLeft;
        assign activeout2 = activeOutBotRight;

        assign dataout1 = dataoutTopRight;
        assign dataout2 = dataoutBotRight;

      //------------------ PE instance -------------//
        pe_v1 topLeft(
            `ifdef DEBUGGER_WR_WIG
            .debug(debug0),
            `endif
            .clk      (clk), // done
            .rst_n    (rst_n),
            .active   (active),
            .datain   (datain[7:0]),
            .win      (win[7:0]),
            .sumin    (sumin[15:0]),
            .wwrite   (wwrite[0]),
            .maccout  (macc_topLeft),
            .dataout  (dataoutTopLeft),
            .wout     (woutTopLeft),
            .wwriteout(wwriteoutTopLeft),
            .activeout(activeOutTopLeft)
        );

        pe_v1 topRight(
            `ifdef DEBUGGER_WR_WIG
            .debug(debug1),
            `endif
            .clk      (clk), // done
            .rst_n    (rst_n),
            .active   (activeOutTopLeft),
            .datain   (dataoutTopLeft),
            .win      (win[15:8]),
            .sumin    (sumin[31:16]),
            .wwrite   (wwrite[1]),
            .maccout  (macc_topRight),
            .dataout  (dataoutTopRight),
            .wout     (woutTopRight),
            .wwriteout(wwriteoutTopRight),
            .activeout(activeOutTopRight)
        );

        pe_v1 botLeft(
            `ifdef DEBUGGER_WR_WIG
            .debug(debug2),
            `endif
            .clk      (clk), // done
            .rst_n    (rst_n),
            .active   (activeOutTopLeft),
            .datain   (datain[15:8]),
            .win      (woutTopLeft),
            .sumin    (macc_topLeft),
            .wwrite   (wwriteoutTopLeft),
            .maccout  (maccoutBotLeft),
            .dataout  (dataoutBotLeft),
            .wout     (woutBotLeft),
            .wwriteout(wwriteoutBotLeft),
            .activeout(activeOutBotLeft)
        );

        pe_v1 botRight(
            `ifdef DEBUGGER_WR_WIG
            .debug(debug3),
            `endif
            .clk      (clk), // done
            .rst_n    (rst_n),
            .active   (activeOutBotLeft & activeOutTopRight),
            .datain   (dataoutBotLeft),
            .win      (woutTopRight),
            .sumin    (macc_topRight),
            .wwrite   (wwriteoutTopRight),
            .maccout  (maccoutBotRight),
            .dataout  (dataoutBotRight),
            .wout     (woutBotRight),
            .wwriteout(wwriteoutBotRight),
            .activeout(activeOutBotRight)
        );

    //-----------------------------------------------------------------
    //                      DEBUGGER LOGIC
    //-----------------------------------------------------------------
          //--------------------------------------------//
        `ifdef DEBUGGER_WR_WIG                          //
          //--------------------------------------------//
            //debugger
            reg key1_stable_d1=0;
            reg key1_stable_d2=0;
            reg key2_stable_d1=0;
            reg key2_stable_d2=0;
            reg [1:0]sel=0;
            wire p1=key1_stable_d1&&(!key1_stable_d2);
            wire p2=key2_stable_d1&&(!key2_stable_d2);
            
            always@(posedge clk or negedge rst_n)begin
                if(!rst_n)begin
                    key1_stable_d1 <= 0;
                    key2_stable_d1 <= 0;
                    key1_stable_d2 <= 0;
                    key2_stable_d2 <= 0;
                    sel <=0;
                end
                
                else begin
                    key1_stable_d1 <= sel_keys[1];//keys[4]
                    key2_stable_d1 <= sel_keys[0];//keys[5]
                    key1_stable_d2 <= key1_stable_d1;
                    key2_stable_d2 <= key2_stable_d1;

                    if(p1)begin
                        sel [1] <= ~sel[1];
                    end

                    if(p2)begin
                        sel [0] <= ~sel[0];
                    end
                end
            end

            always@(*)begin
                    case(sel)
                    2'b00:debug=debug0;//PE0 TopLeft
                    2'b01:debug=debug1;//PE1 TopRight
                    2'b10:debug=debug2;//PE2 BotLeft
                    2'b11:debug=debug3;//PE3 BotRight
                    endcase
            end

          //--------------------------------------------//
        `elsif DEBUGGER_CALCU                           //
          //--------------------------------------------//
        

          //--------------------------------------------//
        `elsif DEBUGGER_WR_DAT                          //
          //--------------------------------------------//
           //debugger
            reg key1_stable_d1=0;
            reg key1_stable_d2=0;
            reg key2_stable_d1=0;
            reg key2_stable_d2=0;
            reg [1:0]sel=0;
            wire p1=key1_stable_d1&&(!key1_stable_d2);
            wire p2=key2_stable_d1&&(!key2_stable_d2);
            
            always@(posedge clk or negedge rst_n)begin
                if(!rst_n)begin
                    key1_stable_d1 <= 0;
                    key2_stable_d1 <= 0;
                    key1_stable_d2 <= 0;
                    key2_stable_d2 <= 0;
                    sel <=0;
                end
                
                else begin
                    key1_stable_d1 <= sel_keys[1];//keys[4]
                    key2_stable_d1 <= sel_keys[0];//keys[5]
                    key1_stable_d2 <= key1_stable_d1;
                    key2_stable_d2 <= key2_stable_d1;

                    if(p1)begin
                        sel [1] <= ~sel[1];
                    end

                    if(p2)begin
                        sel [0] <= ~sel[0];
                    end
                end
            end

            always@(*)begin
                    case(sel)
                    2'b00:debug=debug0;//PE0 TopLeft
                    2'b01:debug=debug1;//PE1 TopRight
                    2'b10:debug=debug2;//PE2 BotLeft
                    2'b11:debug=debug3;//PE3 BotRight
                    endcase
            end
        `endif

  endmodule // sysArr2x2_v1