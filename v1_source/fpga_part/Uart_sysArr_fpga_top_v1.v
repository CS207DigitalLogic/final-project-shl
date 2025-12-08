//==============================================================================================================
// File Name    : Uart_sysArr_fpga_top_v1.v
// Module Name  : Uart_sysArr_fpga_top_v1
// Author       : Su Zhenyu
// Version      : 1.0
// Modified     : 2025/03/05 16:19
// Description  : The top wrapper prepare for sysArr test by uart on PDS FPGA
// Function List:
//     1. UART for getting data from PC and sending  data to PC
//     2. LED display for showing the BUFF status
//     3. Button for LOAD MATRIX , START CALCULATION ,SENT RESULT
//===============================================================================================================
    
    `timescale 1ns/1ps

//===============================================================================================================
//-----------------------------------------------DIFINE EABLE FUNCTIONS------------------------------------------
//===============================================================================================================

    //-------------------------------------
    //`define VVD or PDS                  //---- Only one of the following DEBUGGER lines can be enabled
    //-------------------------------------
    //`define VVD
    `define PDS

    //-------------------------------------
    //`define DBUGGER                      //---- Only one of the following DEBUGGER lines can be enabled
    //-------------------------------------
        //------------------------
        //`define DEBUGGER_CALCU    // For only [key] ctrl sysArr weight and data load and calculation             [pass]
        //------------------------
            //`define DEBUGGER_WW
            //`define DEBUGGER_DW
            //`define DEBUGGER_CAL
        //------------------------
        //`define DEBUGGER_UART_W    // For [Uart] only ctrl sysArr weight load test                               [pass]
        //------------------------
            //`define DEBUGGER_WW
            //`define DEBUGGER_DW
            //`define DEBUGGER_CAL
        //------------------------
        //`define DEBUGGER_UART_D    // For [Uart] only ctrl sysArr data load test                                 [pass]                        
        //------------------------
            //`define DEBUGGER_WW
            //`define DEBUGGER_DW
            //`define DEBUGGER_CAL
        //------------------------
        //`define DEBUGGER_UART_DW    // For Uart ctrl both sysArr weight load and data load test                    [pass]                                 
        //------------------------
            //`define DEBUGGER_WW
            //`define DEBUGGER_DW
            //`define DEBUGGER_CAL
        //------------------------
        //`define DEBUGGER_UART_TX    // For Uart ctrl both sysArr weight load and data load test                    [pass]                                 
        //------------------------
            //`define DEBUGGER_W_BUFF
            //`define DEBUGGER_R_BUFF
    

//===============================================================================================================
//-----------------------------------------------MODULE DEFINE FUNCTIONS-----------------------------------------
//===============================================================================================================

    module Uart_sysArr_fpga_top_v1#(
      //------------ parameter define -------//
        parameter BPS_NUM     = 434, // 16'd434
        parameter MATRIX_COL  = 2  , // 2x2 matrix
        parameter MATRIX_ROW  = 2  , // 2x2 matrix
        parameter WBUFF_WIDTH = 8  , // weight 1 byte
        parameter DBUFF_WIDTH = 8   // data   1 byte
    )(
      //----------Global Clock and Reset ----// i:
        input  wire         clk_50m,         //   50MHz Main Clock
        input  wire         rst_n,           //   Reset Ngetive key[7]

      //--------------UART Signals ----------// i:
        input  wire         uart_rx,         //   UART Receive
                                             // o:
        output wire         uart_tx,         //   UART Transmit

      //---------------FPGA Signals ---------// i:
        input  wire [6:0]   keys,            //   Key Input
                                             // o:
        output wire [7:0]   led              //   LED Output
    );
    //-----------------------------------------------------------------
    //[0]                Wires & Regs & Parameter
    //-----------------------------------------------------------------
      //-----------------------------------------------//
      //                 Parameter Define              //
      //-----------------------------------------------//
        localparam WBUFF_DEPTH = MATRIX_COL*MATRIX_ROW    ; // 2x2 matrix have 4 weights
        localparam DATA_IN_PIPE= 2*MATRIX_COL-1           ; // n*n matrix have 2n-1 output clk
        localparam DBUFF_DEPTH = MATRIX_ROW*DATA_IN_PIPE  ; // n*n matrix have row*2n-1 data(given by uart)
      //-----------------------------------------------//
      //                 Wires & Regs Define           //
      //-----------------------------------------------//
        //------------For UART_RX_TX----------//
          wire [7:0] tx_data;
          wire [7:0] rx_data;
          wire       tx_en;
          wire       rx_en;
          wire       tx_done;
          wire       rx_done;
          wire       tx_busy;
          wire       rx_busy;

          wire [MATRIX_COL*(2*DBUFF_WIDTH)-1:0] macc_out; // aline macout1 and macout2 as 1clk data
          wire [MATRIX_COL-1:0]               active_out; // aline macout1 and macout2 as 1clk data
        //------------For sysArr2x2_v1----------//
          wire active_tpu;
          wire [ 7:0] wout1,wout2;
          wire activeout1,activeout2;
          wire wwriteout1,wwriteout2;
          wire [ 7:0] dataout1,dataout2;
          wire [MATRIX_COL-1:0] wwrite_tpu;
          wire [15:0] win,datain,sumin,maccout1,maccout2;
        //------------For UART_CTRL----------//
          wire [7:0] byte_out;
          wire byte_valid;
        //------------For DBUGGER--------------//
          `ifdef DEBUGGER_UART_TX
            wire [3:0]debugger;
          `endif

    //-----------------------------------------------------------------
    //[1]                      PLL Module
    //-----------------------------------------------------------------
      wire clk_200m; 

      CLK_gen PLL (
        `ifdef VVD
          .clk_in (clk_50m),        //VVD ip: input   50Mhz for UART
          .clk_out(clk_200m)        //VVD ip: output 200Mhz for TPU
        `elsif PDS
          .clkin1 (clk_50m ),       //PDS ip: input   50Mhz for UART
          .clkout0(clk_200m)        //PDS ip: output 200Mhz for TPU
        `endif
      );

    //-----------------------------------------------------------------
    //[2]                    Keydebounce Module
    //-----------------------------------------------------------------
        //------------wires & regs----------//
          wire [6:0] keys_stable ;
        //-----------Module Instance--------//
        KeyDebounce #(
          .CLK_FREQ     (50_000_000 ),      
          .KEY_CNT      (7          ) 
        ) Keys_stable(
          .clk          (clk_50m    ),      // 50MHz Main Clock
          .keys         (keys       ),      // keys negetive vaild
          .keys_stable  (keys_stable)       // stable posedge valid for 1 clk
        );
        //------------keys conect-----------//
          wire wbuff_sel = keys_stable[0] ; // KEY1:  Load wight to fifo
          wire dbuff_sel = keys_stable[1] ; // KEY2:  Load Data  to fifo
          wire wigh_load = keys_stable[2] ; // KEY3:  Start wight preset
          wire data_load = keys_stable[3] ; // KEY4:  Start Calculation
          wire out_load  = keys_stable[4] ; // KEY5:  Load result to uart_tx
                                            // KEY6:  [reserved]
          wire work_load = keys_stable[6] ; // KEY7:  Start uart tx sysArr output
                                            // KEY8： Reset system

    //-----------------------------------------------------------------
    //[3]                        LED logic
    //-----------------------------------------------------------------
      reg led_wbuff_sel ;                   // LED1: wight fifo select
      reg led_dbuff_sel ;                   // LED2: wight fifo full
      assign led[0] = led_wbuff_sel;
      assign led[1] = led_dbuff_sel;
      always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
          led_wbuff_sel <= 0 ;
          led_dbuff_sel <= 0 ;
        end 
        else begin
          //----LED 0:key0 wbuff_sel load to wfifo
          if (wbuff_sel) begin 
            led_wbuff_sel <= ~led_wbuff_sel;
          end

          //----LED 1:key1 wbuff_sel load to dfifo
          if (dbuff_sel) begin 
            led_dbuff_sel <= ~led_dbuff_sel;
          end
        end      
      end  
    
    //-----------------------------------------------------------------
    //[4]                        UART Module
    //-----------------------------------------------------------------
      //------------------------------------------------------------
      // UART RX TX Dataflow_CTRL tx_gen Module
      //------------------------------------------------------------
        //------------UART RX instance----------//
          uart_rx #(
              .BPS_NUM ( BPS_NUM        ) //16'd434
          )
          u_uart_rx (                        
              .clk     ( clk_50m ),//i
              .rstn    ( rst_n   ),//                            
              .uart_rx ( uart_rx ),//     

              .rx_data ( rx_data ),//o                               
              .rx_en   ( rx_en   ),//                      
              .rx_busy ( rx_busy ) //          
          );
        //------------UART TX instance----------//
          uart_tx #(
              .BPS_NUM ( BPS_NUM        ) //16'd434
          )
          u_uart_tx (                        
              .clk     ( clk_50m ),//i
              .rstn    ( rst_n   ),//                            
              .tx_data ( tx_data ),//i
              .tx_pluse( tx_en   ),//i
              .tx_busy ( tx_busy ),//o
              .uart_tx ( uart_tx ) //o
          );
        //------UART Dataflow_CTRL instance-----//
          tpu_uart_ctrl_dataflow #(
              .WBUFF_WIDTH (WBUFF_WIDTH), //parameter         WBUFF_WIDTH = 8
              .WBUFF_DEPTH (WBUFF_DEPTH), //parameter         WBUFF_DEPTH = 4
              .MATRIX_COL  (MATRIX_COL ), //
              .MATRIX_ROW  (MATRIX_ROW ), //
              .DATA_IN_PIPE(DATA_IN_PIPE), //parameter         DATA_IN_PIPE= 3
              .DBUFF_WIDTH (DBUFF_WIDTH), //parameter         DBUFF_WIDTH = 8
              .DBUFF_DEPTH (DBUFF_DEPTH)  //parameter         DBUFF_DEPTH = 6
           ) 
            dataflow_ctrl
           (   
            //---- Uart recive data signals
              .clk_tpu        ( clk_200m       ),//i
              .clk_uart       ( clk_50m        ),//i
              .rst_n          ( rst_n        ),//i
              .uart_rx_data   ( rx_data      ),//i
              .uart_rx_en     ( rx_en        ),//i
            //---- wight buff read and write signals
              .wbuff_sele     ( led[0]       ),//i
              `ifdef DEBUGGER_UART_TX
              `else            
              .wbuff_full     ( led[2]       ),//o
              `endif
            //---- wight dataflow prepare signals
            `ifdef DEBUGGER_UART_D
            `else
              .wight_load     ( wigh_load    ),//i
              .wwrite_tpu     ( wwrite_tpu   ),//o
              .wight_out_row  ( win          ),//o
            `endif
            //---- data buff read and write signals
              .dbuff_sele     ( led[1]       ),//i
              `ifdef DEBUGGER_UART_TX
              `else
              .dbuff_full     ( led[3]       ),//o
              `endif
            //---- data dataflow prepare signals
            `ifdef DEBUGGER_UART_W
            `else
              .data_load      ( data_load    ),//i
              .dwrite_tpu     ( active_tpu   ),//o
              .data_out_col   ( datain       ),//o
            `endif
              
            //---- out buff read and write signals
              `ifdef DEBUGGER_UART_W
              `elsif DEBUGGER_UART_D
              `elsif DEBUGGER_UART_DW
              `elsif DEBUGGER_UART_TX
                     `ifdef DEBUGGER_W_BUFF
                      .obuff_sele     ( {led[0],led[1]}  ),//i
                      .debugger       ( debugger         ),//o
                     `endif
              `else
              .obuff_full     ( led[4]       ),//o
              `endif
              .byte_out       ( byte_out     ),//o
              .byte_valid     ( byte_valid   ),//o
            //---- tpu dataflow signals
              .active_tpu_out ( active_out   ),//i
              .macc_tpu_out   ( macc_out     ),//i
              .uart_tx_load   ( out_load     )
            
          );
          //------UART DataTX_CTRL instance-----//
            uart_tx_ctrl_gen #(
              .DBUFF_DEPTH    ( 2*DBUFF_DEPTH  )
            )
            u_uart_tx_ctrl_gen(
              .clk           (clk_50m        ),
              .rst_n         (rst_n          ),
              .read_data     (byte_out       ),
              .read_en       (byte_valid     ),
              .work_start    (work_load      ),
              .tx_busy       (tx_busy        ),
              .write_max_num (2*DBUFF_DEPTH+1),
              .write_data    (tx_data        ),
              `ifdef DEBUGGER_UART_W
              `elsif DEBUGGER_UART_D
              `elsif DEBUGGER_UART_DW
              `elsif DEBUGGER_UART_TX
              `else
              .buffer_full   (led[5]         ),
              `endif
              .write_en      (tx_en          )
            );
      
    //-----------------------------------------------------------------
    //[5]                       SysArr Module
    //-----------------------------------------------------------------
        
      //-----------Module Instance--------//
       sysArr2x2_v1 SysArr2x2 (
          //-----------debugger-------------//
           `ifdef DEBUGGER_WR_WIG
             .sel_keys  ({keys_stable[4],keys_stable[5]} ),
             .debug     (debug            ), 
           `elsif DEBUGGER_WR_DAT
             .sel_keys  ({keys_stable[4],keys_stable[5]} ),
             .debug     (debug            ),
           `endif

          //-----------clock & reset--------//i:
          .clk       (clk_200m     ),
          .rst_n     (rst_n        ),
          //-----------wight signal---------//i:
          .wwrite    (wwrite_tpu   ),
          .win       (win          ),
                                            //o:
          .wout1     (wout1),
          .wout2     (wout2),
          .wwriteout1(wwriteout1),
          .wwriteout2(wwriteout2),
          //-----------data signal----------//i:
          .active    (active_tpu   ),
          .datain    (datain     ),
                                            //o:
          .sumin     (0          ),
          .maccout1  (maccout1   ),
          .maccout2  (maccout2   ),
          .activeout1(activeout1 ),
          .activeout2(activeout2 ),
          .dataout1  (dataout1   ),
          .dataout2  (dataout2   )
        ); 
        assign active_out[0] = activeout1;
        assign active_out[1] = activeout2; 
        assign macc_out[ 2*DBUFF_WIDTH-1:0] = maccout1;
        assign macc_out[4*DBUFF_WIDTH-1:2*DBUFF_WIDTH] = maccout2;

    //-----------------------------------------------------------------
    //[6]                        DEBUGGER
    //-----------------------------------------------------------------
      //----------------------
      `ifdef DEBUGGER_CALCU  //---------------------------------------
      //---------------------
        //------------pedge detect----------//
        reg wigh_load_d1;
        reg wigh_load_d2;
        reg data_load_d1;
        reg data_load_d2;
        wire wpedge = wigh_load_d1 & ~wigh_load_d2;
        wire dpedge = data_load_d1 & ~data_load_d2;
        always@(posedge clk_200m or negedge rst_n)begin
          if (!rst_n) begin
            wigh_load_d1 <= 1'b0;
            data_load_d1 <= 1'b0;
            wigh_load_d2 <= 1'b0;
            data_load_d2 <= 1'b0;
          end
          else begin
            wigh_load_d1 <= wigh_load;
            data_load_d1 <= data_load;
            wigh_load_d2 <= wigh_load_d1;
            data_load_d2 <= data_load_d1;
          end
        end
        //-------------line up to sysArr----------------//
        reg [1:0]wwrite_tpu_gen;
        assign wwrite_tpu = wwrite_tpu_gen;

        reg [15:0]win_gen;
        assign win = win_gen;

        reg [15:0]datain_gen;
        assign datain = datain_gen;

        reg active_tpu_gen;
        assign active_tpu = active_tpu_gen;
        //------------self test gen wsignals----------//
        reg wtime_2clk_gen;
        always@(posedge clk_200m or negedge rst_n) begin
          if (!rst_n) begin
            wtime_2clk_gen <= 1'b0;
          end
          else begin
            if(wwrite_tpu_gen==2'b11)
              wtime_2clk_gen <= 1'b1;
            else
              wtime_2clk_gen <= 1'b0;
          end
        end

        always@(posedge clk_200m or negedge rst_n)begin
          if(!rst_n)begin
            wwrite_tpu_gen<=2'b0;
          end
          else begin
            if(wpedge)begin
              wwrite_tpu_gen<=2'b11;
            end
            else if(wtime_2clk_gen)begin
              wwrite_tpu_gen<=2'b0;
            end
          end
        end

        always@(posedge clk_200m or negedge rst_n)begin
          if(!rst_n)begin
            win_gen<=2'b0;
          end
          else begin
            if(wpedge&&!wtime_2clk_gen)begin
              win_gen<=16'h0403;
            end
            else if(wwrite_tpu_gen&&!wtime_2clk_gen)begin
              win_gen<=16'h0201;
            end
          end
        end
        //------------self test gen dsignals----------//
        reg dtime_2clk_gen;
        always@(posedge clk_200m or negedge rst_n) begin
          if (!rst_n) begin
            dtime_2clk_gen <= 1'b0;
          end
          else begin
            if(active_tpu_gen)
              dtime_2clk_gen <= 1'b1;
            else
              dtime_2clk_gen <= 1'b0;
          end
        end

        always@(posedge clk_200m or negedge rst_n)begin
          if(!rst_n)begin
            active_tpu_gen<=2'b0;
          end
          else begin
            if(dpedge)begin
              active_tpu_gen<=2'b1;
            end
            else if(dtime_2clk_gen)begin
              active_tpu_gen<=2'b0;
            end
          end
        end

        always@(posedge clk_200m or negedge rst_n)begin
          if(!rst_n)begin
            datain_gen<=16'h0;
          end
          else begin
            if(dpedge&&!dtime_2clk_gen)begin
              datain_gen<=16'h0001;
            end
            else if(active_tpu_gen&&!dtime_2clk_gen)begin
              datain_gen<=16'h0203;
            end
            else if(active_tpu_gen&&dtime_2clk_gen)begin
              datain_gen<=16'h0400;
            end
          end
        end
        //-------collect sysArrout & display ---------//
        reg [7:0]maccout1_save_1;
        reg [7:0]maccout1_save_2;
        reg [7:0]maccout2_save_1;
        reg [7:0]maccout2_save_2;
        reg [5:0]debug;
          assign led[2]=debug[5];
          assign led[3]=debug[4];
          assign led[4]=debug[3];
          assign led[5]=debug[2];
          assign led[6]=debug[1];
          assign led[7]=debug[0];
        always@(posedge clk_200m or negedge rst_n)begin
            if(!rst_n)begin
              maccout1_save_1<=8'h0;
              maccout1_save_2<=8'h0;
              maccout2_save_1<=8'h0;
              maccout2_save_2<=8'h0;
            end
            else begin
              `ifdef DEBUGGER_CAL
                if(activeout1&&!activeout2)begin
                  maccout1_save_1<=maccout1[7:0];
                end
                if(activeout1&&activeout2)begin
                  maccout1_save_2<=maccout1[7:0];
                  maccout2_save_1<=maccout2[7:0];
                end
                if(!activeout1&&activeout2)begin
                  maccout2_save_2<=maccout2[7:0];
                end

              `elsif DEBUGGER_DW
                if(activeout1&&!activeout2)begin
                  maccout1_save_1<=dataout1[7:0];
                end
                if(activeout1&&activeout2)begin
                  maccout1_save_2<=dataout1[7:0];
                  maccout2_save_1<=dataout2[7:0];
                end
                if(!activeout1&&activeout2)begin
                  maccout2_save_2<=dataout2[7:0];
                end
              `endif
            end
        end
        always@(*)begin
          case ({led_wbuff_sel,led_dbuff_sel})
            2'b00:debug=maccout1_save_1;
            2'b01:debug=maccout1_save_2;
            2'b10:debug=maccout2_save_1;
            2'b11:debug=maccout2_save_2;
          endcase
        end
      //----------------------
      `elsif DEBUGGER_UART_W  //---------------------------------------
      //---------------------
        //------------pedge detect----------//
          reg wigh_load_d1;
          reg wigh_load_d2;
          reg data_load_d1;
          reg data_load_d2;
          wire wpedge = wigh_load_d1 & ~wigh_load_d2;
          wire dpedge = data_load_d1 & ~data_load_d2;
          always@(posedge clk_200m or negedge rst_n)begin
            if (!rst_n) begin
              wigh_load_d1 <= 1'b0;
              data_load_d1 <= 1'b0;
              wigh_load_d2 <= 1'b0;
              data_load_d2 <= 1'b0;
            end
            else begin
              wigh_load_d1 <= wigh_load;
              data_load_d1 <= data_load;
              wigh_load_d2 <= wigh_load_d1;
              data_load_d2 <= data_load_d1;
            end
          end
        //-------------line up to sysArr----------------//
          reg [15:0]datain_gen;
          assign datain = datain_gen;

          reg active_tpu_gen;
          assign active_tpu = active_tpu_gen;
        //------------self test gen dsignals----------//
          reg dtime_2clk_gen;
          always@(posedge clk_200m or negedge rst_n) begin
            if (!rst_n) begin
              dtime_2clk_gen <= 1'b0;
            end
            else begin
              if(active_tpu_gen)
                dtime_2clk_gen <= 1'b1;
              else
                dtime_2clk_gen <= 1'b0;
            end
          end

          always@(posedge clk_200m or negedge rst_n)begin
            if(!rst_n)begin
              active_tpu_gen<=2'b0;
            end
            else begin
              if(dpedge)begin
                active_tpu_gen<=2'b1;
              end
              else if(dtime_2clk_gen)begin
                active_tpu_gen<=2'b0;
              end
            end
          end

          always@(posedge clk_200m or negedge rst_n)begin
            if(!rst_n)begin
              datain_gen<=16'h0;
            end
            else begin
              if(dpedge&&!dtime_2clk_gen)begin
                datain_gen<=16'h0001;
              end
              else if(active_tpu_gen&&!dtime_2clk_gen)begin
                datain_gen<=16'h0203;
              end
              else if(active_tpu_gen&&dtime_2clk_gen)begin
                datain_gen<=16'h0400;
              end
            end
          end
        //---------collect sysArrout & display ---------//
          reg [7:0]maccout1_save_1;
          reg [7:0]maccout1_save_2;
          reg [7:0]maccout2_save_1;
          reg [7:0]maccout2_save_2;
          reg [5:0]debug;
            assign led[4]=debug[3];
            assign led[5]=debug[2];
            assign led[6]=debug[1];
            assign led[7]=debug[0];
          always@(posedge clk_200m or negedge rst_n)begin
              if(!rst_n)begin
                maccout1_save_1<=8'h0;
                maccout1_save_2<=8'h0;
                maccout2_save_1<=8'h0;
                maccout2_save_2<=8'h0;
              end
              else begin
                `ifdef DEBUGGER_CAL
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=maccout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=maccout1[7:0];
                    maccout2_save_1<=maccout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=maccout2[7:0];
                  end

                `elsif DEBUGGER_DW
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=dataout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=dataout1[7:0];
                    maccout2_save_1<=dataout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=dataout2[7:0];
                  end
                `elsif DEBUGGER_WW
                  if(wwriteout1&&!wwriteout2)begin
                    maccout1_save_1<=wout1[7:0];
                  end
                  if(wwriteout1&&wwriteout2)begin
                    maccout1_save_2<=wout1[7:0];
                    maccout2_save_1<=wout2[7:0];
                  end
                  if(!wwriteout1&&wwriteout2)begin
                    maccout2_save_2<=wout2[7:0];
                  end
                
                `endif
              end
          end
          always@(*)begin
            case ({led_wbuff_sel,led_dbuff_sel})
              2'b00:debug=maccout1_save_1;
              2'b01:debug=maccout1_save_2;
              2'b10:debug=maccout2_save_1;
              2'b11:debug=maccout2_save_2;
            endcase
          end
       //----------------------
      `elsif DEBUGGER_UART_D  //---------------------------------------
      //---------------------
        //------------pedge detect----------//
          reg wigh_load_d1;
          reg wigh_load_d2;
          reg data_load_d1;
          reg data_load_d2;
          wire wpedge = wigh_load_d1 & ~wigh_load_d2;
          wire dpedge = data_load_d1 & ~data_load_d2;
          always@(posedge clk_200m or negedge rst_n)begin
            if (!rst_n) begin
              wigh_load_d1 <= 1'b0;
              data_load_d1 <= 1'b0;
              wigh_load_d2 <= 1'b0;
              data_load_d2 <= 1'b0;
            end
            else begin
              wigh_load_d1 <= wigh_load;
              data_load_d1 <= data_load;
              wigh_load_d2 <= wigh_load_d1;
              data_load_d2 <= data_load_d1;
            end
          end
        //-------------line up to sysArr----------------//
          reg [1:0]wwrite_tpu_gen;
          assign wwrite_tpu = wwrite_tpu_gen;
        //------------self test gen wsignals----------//
          reg [15:0]win_gen;
          assign win = win_gen;
          reg wtime_2clk_gen;
          always@(posedge clk_200m or negedge rst_n) begin
            if (!rst_n) begin
              wtime_2clk_gen <= 1'b0;
            end
            else begin
              if(wwrite_tpu_gen==2'b11)
                wtime_2clk_gen <= 1'b1;
              else
                wtime_2clk_gen <= 1'b0;
            end
          end

          always@(posedge clk_200m or negedge rst_n)begin
            if(!rst_n)begin
              wwrite_tpu_gen<=2'b0;
            end
            else begin
              if(wpedge)begin
                wwrite_tpu_gen<=2'b11;
              end
              else if(wtime_2clk_gen)begin
                wwrite_tpu_gen<=2'b0;
              end
            end
          end

          always@(posedge clk_200m or negedge rst_n)begin
            if(!rst_n)begin
              win_gen<=2'b0;
            end
            else begin
              if(wpedge&&!wtime_2clk_gen)begin
                win_gen<=16'h0403;
              end
              else if(wwrite_tpu_gen&&!wtime_2clk_gen)begin
                win_gen<=16'h0201;
              end
            end
          end
        //---------collect sysArrout & display ---------//
          reg [7:0]maccout1_save_1;
          reg [7:0]maccout1_save_2;
          reg [7:0]maccout2_save_1;
          reg [7:0]maccout2_save_2;
          reg [5:0]debug;
            assign led[4]=debug[3];
            assign led[5]=debug[2];
            assign led[6]=debug[1];
            assign led[7]=debug[0];
          always@(posedge clk_200m or negedge rst_n)begin
              if(!rst_n)begin
                maccout1_save_1<=8'h0;
                maccout1_save_2<=8'h0;
                maccout2_save_1<=8'h0;
                maccout2_save_2<=8'h0;
              end
              else begin
                `ifdef DEBUGGER_CAL
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=maccout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=maccout1[7:0];
                    maccout2_save_1<=maccout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=maccout2[7:0];
                  end

                `elsif DEBUGGER_DW
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=dataout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=dataout1[7:0];
                    maccout2_save_1<=dataout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=dataout2[7:0];
                  end
                `elsif DEBUGGER_WW
                  if(wwriteout1&&!wwriteout2)begin
                    maccout1_save_1<=wout1[7:0];
                  end
                  if(wwriteout1&&wwriteout2)begin
                    maccout1_save_2<=wout1[7:0];
                    maccout2_save_1<=wout2[7:0];
                  end
                  if(!wwriteout1&&wwriteout2)begin
                    maccout2_save_2<=wout2[7:0];
                  end
                
                `endif
              end
          end
          always@(*)begin
            case ({led_wbuff_sel,led_dbuff_sel})
              2'b00:debug=maccout1_save_1;
              2'b01:debug=maccout1_save_2;
              2'b10:debug=maccout2_save_1;
              2'b11:debug=maccout2_save_2;
            endcase
          end
      //---------------------
        //------------pedge detect----------//
          reg wigh_load_d1;
          reg wigh_load_d2;
          reg data_load_d1;
          reg data_load_d2;
          wire wpedge = wigh_load_d1 & ~wigh_load_d2;
          wire dpedge = data_load_d1 & ~data_load_d2;
          always@(posedge clk_200m or negedge rst_n)begin
            if (!rst_n) begin
              wigh_load_d1 <= 1'b0;
              data_load_d1 <= 1'b0;
              wigh_load_d2 <= 1'b0;
              data_load_d2 <= 1'b0;
            end
            else begin
              wigh_load_d1 <= wigh_load;
              data_load_d1 <= data_load;
              wigh_load_d2 <= wigh_load_d1;
              data_load_d2 <= data_load_d1;
            end
          end
        //-------------line up to sysArr----------------//
          reg [15:0]datain_gen;
          assign datain = datain_gen;

          reg active_tpu_gen;
          assign active_tpu = active_tpu_gen;
        //------------self test gen dsignals----------//
          reg dtime_2clk_gen;
          always@(posedge clk_200m or negedge rst_n) begin
            if (!rst_n) begin
              dtime_2clk_gen <= 1'b0;
            end
            else begin
              if(active_tpu_gen)
                dtime_2clk_gen <= 1'b1;
              else
                dtime_2clk_gen <= 1'b0;
            end
          end

          always@(posedge clk_200m or negedge rst_n)begin
            if(!rst_n)begin
              active_tpu_gen<=2'b0;
            end
            else begin
              if(dpedge)begin
                active_tpu_gen<=2'b1;
              end
              else if(dtime_2clk_gen)begin
                active_tpu_gen<=2'b0;
              end
            end
          end

          always@(posedge clk_200m or negedge rst_n)begin
            if(!rst_n)begin
              datain_gen<=16'h0;
            end
            else begin
              if(dpedge&&!dtime_2clk_gen)begin
                datain_gen<=16'h0001;
              end
              else if(active_tpu_gen&&!dtime_2clk_gen)begin
                datain_gen<=16'h0203;
              end
              else if(active_tpu_gen&&dtime_2clk_gen)begin
                datain_gen<=16'h0400;
              end
            end
          end
        //---------collect sysArrout & display ---------//
          reg [7:0]maccout1_save_1;
          reg [7:0]maccout1_save_2;
          reg [7:0]maccout2_save_1;
          reg [7:0]maccout2_save_2;
          reg [5:0]debug;
            assign led[4]=debug[3];
            assign led[5]=debug[2];
            assign led[6]=debug[1];
            assign led[7]=debug[0];
          always@(posedge clk_200m or negedge rst_n)begin
              if(!rst_n)begin
                maccout1_save_1<=8'h0;
                maccout1_save_2<=8'h0;
                maccout2_save_1<=8'h0;
                maccout2_save_2<=8'h0;
              end
              else begin
                `ifdef DEBUGGER_CAL
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=maccout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=maccout1[7:0];
                    maccout2_save_1<=maccout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=maccout2[7:0];
                  end

                `elsif DEBUGGER_DW
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=dataout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=dataout1[7:0];
                    maccout2_save_1<=dataout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=dataout2[7:0];
                  end
                `elsif DEBUGGER_WW
                  if(wwriteout1&&!wwriteout2)begin
                    maccout1_save_1<=wout1[7:0];
                  end
                  if(wwriteout1&&wwriteout2)begin
                    maccout1_save_2<=wout1[7:0];
                    maccout2_save_1<=wout2[7:0];
                  end
                  if(!wwriteout1&&wwriteout2)begin
                    maccout2_save_2<=wout2[7:0];
                  end
                
                `endif
              end
          end
          always@(*)begin
            case ({led_wbuff_sel,led_dbuff_sel})
              2'b00:debug=maccout1_save_1;
              2'b01:debug=maccout1_save_2;
              2'b10:debug=maccout2_save_1;
              2'b11:debug=maccout2_save_2;
            endcase
          end
       //----------------------
      `elsif DEBUGGER_UART_DW  //---------------------------------------
      //---------------------
        //---------collect sysArrout & display ---------//
          reg [7:0]maccout1_save_1;
          reg [7:0]maccout1_save_2;
          reg [7:0]maccout2_save_1;
          reg [7:0]maccout2_save_2;
          reg [5:0]debug;
            assign led[4]=debug[3];
            assign led[5]=debug[2];
            assign led[6]=debug[1];
            assign led[7]=debug[0];
          always@(posedge clk_200m or negedge rst_n)begin
              if(!rst_n)begin
                maccout1_save_1<=8'h0;
                maccout1_save_2<=8'h0;
                maccout2_save_1<=8'h0;
                maccout2_save_2<=8'h0;
              end
              else begin
                `ifdef DEBUGGER_CAL
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=maccout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=maccout1[7:0];
                    maccout2_save_1<=maccout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=maccout2[7:0];
                  end

                `elsif DEBUGGER_DW
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=dataout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=dataout1[7:0];
                    maccout2_save_1<=dataout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=dataout2[7:0];
                  end
                `elsif DEBUGGER_WW
                  if(wwriteout1&&!wwriteout2)begin
                    maccout1_save_1<=wout1[7:0];
                  end
                  if(wwriteout1&&wwriteout2)begin
                    maccout1_save_2<=wout1[7:0];
                    maccout2_save_1<=wout2[7:0];
                  end
                  if(!wwriteout1&&wwriteout2)begin
                    maccout2_save_2<=wout2[7:0];
                  end
                
                `endif
              end
          end
          always@(*)begin
            case ({led_wbuff_sel,led_dbuff_sel})
              2'b00:debug=maccout1_save_1;
              2'b01:debug=maccout1_save_2;
              2'b10:debug=maccout2_save_1;
              2'b11:debug=maccout2_save_2;
            endcase
          end
      //---------------------
        //------------pedge detect----------//
          reg wigh_load_d1;
          reg wigh_load_d2;
          reg data_load_d1;
          reg data_load_d2;
          wire wpedge = wigh_load_d1 & ~wigh_load_d2;
          wire dpedge = data_load_d1 & ~data_load_d2;
          always@(posedge clk_200m or negedge rst_n)begin
            if (!rst_n) begin
              wigh_load_d1 <= 1'b0;
              data_load_d1 <= 1'b0;
              wigh_load_d2 <= 1'b0;
              data_load_d2 <= 1'b0;
            end
            else begin
              wigh_load_d1 <= wigh_load;
              data_load_d1 <= data_load;
              wigh_load_d2 <= wigh_load_d1;
              data_load_d2 <= data_load_d1;
            end
          end
        //-------------line up to sysArr----------------//
          reg [15:0]datain_gen;
          assign datain = datain_gen;

          reg active_tpu_gen;
          assign active_tpu = active_tpu_gen;
        //------------self test gen dsignals----------//
          reg dtime_2clk_gen;
          always@(posedge clk_200m or negedge rst_n) begin
            if (!rst_n) begin
              dtime_2clk_gen <= 1'b0;
            end
            else begin
              if(active_tpu_gen)
                dtime_2clk_gen <= 1'b1;
              else
                dtime_2clk_gen <= 1'b0;
            end
          end

          always@(posedge clk_200m or negedge rst_n)begin
            if(!rst_n)begin
              active_tpu_gen<=2'b0;
            end
            else begin
              if(dpedge)begin
                active_tpu_gen<=2'b1;
              end
              else if(dtime_2clk_gen)begin
                active_tpu_gen<=2'b0;
              end
            end
          end

          always@(posedge clk_200m or negedge rst_n)begin
            if(!rst_n)begin
              datain_gen<=16'h0;
            end
            else begin
              if(dpedge&&!dtime_2clk_gen)begin
                datain_gen<=16'h0001;
              end
              else if(active_tpu_gen&&!dtime_2clk_gen)begin
                datain_gen<=16'h0203;
              end
              else if(active_tpu_gen&&dtime_2clk_gen)begin
                datain_gen<=16'h0400;
              end
            end
          end
        //---------collect sysArrout & display ---------//
          reg [7:0]maccout1_save_1;
          reg [7:0]maccout1_save_2;
          reg [7:0]maccout2_save_1;
          reg [7:0]maccout2_save_2;
          reg [5:0]debug;
            assign led[4]=debug[3];
            assign led[5]=debug[2];
            assign led[6]=debug[1];
            assign led[7]=debug[0];
          always@(posedge clk_200m or negedge rst_n)begin
              if(!rst_n)begin
                maccout1_save_1<=8'h0;
                maccout1_save_2<=8'h0;
                maccout2_save_1<=8'h0;
                maccout2_save_2<=8'h0;
              end
              else begin
                `ifdef DEBUGGER_CAL
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=maccout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=maccout1[7:0];
                    maccout2_save_1<=maccout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=maccout2[7:0];
                  end

                `elsif DEBUGGER_DW
                  if(activeout1&&!activeout2)begin
                    maccout1_save_1<=dataout1[7:0];
                  end
                  if(activeout1&&activeout2)begin
                    maccout1_save_2<=dataout1[7:0];
                    maccout2_save_1<=dataout2[7:0];
                  end
                  if(!activeout1&&activeout2)begin
                    maccout2_save_2<=dataout2[7:0];
                  end
                `elsif DEBUGGER_WW
                  if(wwriteout1&&!wwriteout2)begin
                    maccout1_save_1<=wout1[7:0];
                  end
                  if(wwriteout1&&wwriteout2)begin
                    maccout1_save_2<=wout1[7:0];
                    maccout2_save_1<=wout2[7:0];
                  end
                  if(!wwriteout1&&wwriteout2)begin
                    maccout2_save_2<=wout2[7:0];
                  end
                
                `endif
              end
          end
          always@(*)begin
            case ({led_wbuff_sel,led_dbuff_sel})
              2'b00:debug=maccout1_save_1;
              2'b01:debug=maccout1_save_2;
              2'b10:debug=maccout2_save_1;
              2'b11:debug=maccout2_save_2;
            endcase
          end
       //----------------------
      `elsif DEBUGGER_UART_TX  //---------------------------------------
      //---------------------
        `ifdef DEBUGGER_W_BUFF
        //---------detect buffer & display ---------//
          assign led[4]=debugger[3];
          assign led[5]=debugger[2];
          assign led[6]=debugger[1];
          assign led[7]=debugger[0];
        `elsif DEBUGGER_R_BUFF
        //---------detect keys two more ---------//
          reg led_sel3 ;                   // LED3: show data_sel bit3
          reg led_sel4 ;                   // LED4: show data_sel bit4
          assign led[2] = led_sel3;
          assign led[3] = led_sel4;
          always @(posedge clk_50m or negedge rst_n) begin
            if (!rst_n) begin
              led_sel3 <= 0 ;
              led_sel4 <= 0 ;
            end 
            else begin
              //----LED 3:key3
              if (keys_stable[2]) begin 
                led_sel3 <= ~led_sel3;
              end

              //----LED 4:key4 
              if (keys_stable[3]) begin 
                led_sel4 <= ~led_sel4;
              end
            end      
          end 
        //---------collect sysArrout & display ---------//
          reg [3:0] byteout_save_1;
          reg [3:0] byteout_save_2;
          reg [3:0] byteout_save_3;
          reg [3:0] byteout_save_4;
          reg [3:0] byteout_save_5;
          reg [3:0] byteout_save_6;
          reg [3:0] byteout_save_7;
          reg [3:0] byteout_save_8;
          reg [3:0] byteout_save_9;
          reg [3:0] byteout_save_10;
          reg [3:0] byteout_save_11;
          reg [3:0] byteout_save_12;
          reg [3:0]debug;
            assign led[4]=debug[3];
            assign led[5]=debug[2];
            assign led[6]=debug[1];
            assign led[7]=debug[0];
          always@(posedge clk_50m or negedge rst_n)begin
              if(!rst_n)begin
                byteout_save_1<=8'h0;
                byteout_save_2<=8'h0;
                byteout_save_3<=8'h0;
                byteout_save_4<=8'h0;
                byteout_save_5<=8'h0;
                byteout_save_6<=8'h0;
                byteout_save_7<=8'h0;
                byteout_save_8<=8'h0;
                byteout_save_9<=8'h0;
                byteout_save_10<=8'h0;
                byteout_save_11<=8'h0;
                byteout_save_12<=8'h0;
              end
              else begin
                if(byte_valid)begin
                  byteout_save_1<=byte_out;
                  byteout_save_2<=byteout_save_1;
                  byteout_save_3<=byteout_save_2;
                  byteout_save_4<=byteout_save_3;
                  byteout_save_5<=byteout_save_4;
                  byteout_save_6<=byteout_save_5;
                  byteout_save_7<=byteout_save_6;
                  byteout_save_8<=byteout_save_7;
                  byteout_save_9<=byteout_save_8;
                  byteout_save_10<=byteout_save_9;
                  byteout_save_11<=byteout_save_10;
                  byteout_save_12<=byteout_save_11;
                end
              end
          end
          always@(*)begin
            case ({led_wbuff_sel,led_dbuff_sel,led_sel3,led_sel4})
              4'b0000:debug=byteout_save_11;
              4'b0001:debug=byteout_save_10;
              4'b0010:debug=byteout_save_9;
              4'b0011:debug=byteout_save_8;
              4'b0100:debug=byteout_save_7;
              4'b0101:debug=byteout_save_6;
              4'b0110:debug=byteout_save_5;
              4'b0111:debug=byteout_save_4;
              4'b1000:debug=byteout_save_3;
              4'b1001:debug=byteout_save_2;
              4'b1010:debug=byteout_save_1;
              4'b1011:debug=byteout_save_12;
              default:debug=4'hF;
            endcase
          end
        `endif
      `endif
      

    endmodule
