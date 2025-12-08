//==============================================================================================================
// File Name    : uart_rx.v
// Module Name  : uart_rx
// Author       : Huang JiaWei & Su Zhenyu
// Version      : 0.5
// Modified     : 2025/02/26 10:00
// Description  : uart rx module
// Function List:
//===============================================================================================================
//`define SIMULATION

`timescale 1ns / 1ps

`ifdef SIMULATION

`define UD #1

module uart_rx # (
        // clock frequency
        parameter  CLK_FREQ  = 50_000_000,   // clk frequency, Unit : Hz
        // UART format
        parameter  BPS_NUM   = 16'd434,
        parameter  BAUD_RATE = 115200,       // Unit : Hz
        parameter  PARITY    = "NONE"        // "NONE", "ODD", or "EVEN"
    //  设置波特率为4800时，  bit位宽时钟周期个数:50MHz set 10417  40MHz set 8333
    //  设置波特率为9600时，  bit位宽时钟周期个数:50MHz set 5208   40MHz set 4167
    //  设置波特率为115200时，bit位宽时钟周期个数:50MHz set 434    40MHz set 347
    )
    (
        //input ports
        input             clk,
        input             rstn,        // reset
        input             uart_rx,
        
        //output ports
        output reg [7:0]  rx_data,
        output reg        rx_en = 1'b0,
        output            rx_busy
    );

        localparam BPS_MID = BPS_NUM >> 1;

        // uart rx state machine's state
        localparam  IDLE         = 3'h0;    //空闲状态，等待开始信号到来.
        localparam  RECEIV_START = 3'h1;    //接收Uart开始信号，低电平一个波特周期.
        localparam  RECEIV_DATA  = 3'h2;    //接收Uart传输数据信号，此工程定义传输8bit，每个波特周期中间位置取值，8个周期后跳转到stop状态.
        localparam  RECEIV_STOP  = 3'h3;    //停止状态数据线是高电平，与空闲状态是一致的按照协议标准需要等待一个停止位周期再做状态跳转.
        localparam  RECEIV_END   = 3'h4;    //结束中转状态.

        //==========================================================================
        //wire and reg in the module
        //==========================================================================
        reg    [2:0]        rx_state=0;       //current state of tx state machine. 当前状态
        reg    [2:0]        rx_state_n=0;     //next state of tx state machine.    下一个状态
        reg    [7:0]        rx_data_reg;      //                                   接收数据缓冲寄存器
        reg                 uart_rx_1d;       //save uart_rx one cycle.            保存uart_rx一个时钟周期
        reg                 uart_rx_2d;       //save uart_rx one cycle.保存uart_rx 前两个时钟周期
        wire                start;            //active when start a byte receive.  检测到start信号标志
        reg    [15:0]       clk_div_cnt;      //count for division the clock.      波特周期计数器

        //==========================================================================
        //logic
        //==========================================================================
        
        //some control single.
        always @ (posedge clk) 
        begin
            uart_rx_1d <= `UD uart_rx;
            uart_rx_2d <= `UD  uart_rx_1d;
        end

        // assign start     = (!uart_rx) && (uart_rx_1d);
        assign start     = (!uart_rx) && (uart_rx_1d || uart_rx_2d);

        assign rx_busy = (rx_state == IDLE) ? 1'b0 : 1'b1;


        //division the clock to satisfy baud rate.波特周期计数器
        always @ (posedge clk)
        begin
            if (~rstn) 
                clk_div_cnt   <= `UD 16'h0;
            else if(rx_state == IDLE || clk_div_cnt == BPS_NUM)
                clk_div_cnt   <= `UD 16'h0;
            else
                clk_div_cnt   <= `UD clk_div_cnt + 16'h1;
        end
        
        // receive bit data numbers 
        //在接收数据状态中，接收的bit位计数，每一个波特周期计数加1
        reg    [2:0]      rx_bit_cnt=0;    //the bits number has transmited.
        always @ (posedge clk)
        begin
            if (~rstn) 
                rx_bit_cnt <= `UD 3'h0;
            else if(rx_state == IDLE)
                rx_bit_cnt <= `UD 3'h0;
            else if((rx_bit_cnt == 3'h7) && (clk_div_cnt == BPS_NUM))
                rx_bit_cnt <= `UD 3'h0;
            else if((rx_state == RECEIV_DATA) && (clk_div_cnt == BPS_NUM))
                rx_bit_cnt <= `UD rx_bit_cnt + 3'h1;
            else 
                rx_bit_cnt <= `UD rx_bit_cnt;
        end

    //==========================================================================
    //receive state machine
    //==========================================================================
        //状态机状态跳转
        always @(posedge clk)
        begin
            if (~rstn) 
                rx_state <= IDLE;
            else 
                rx_state <= rx_state_n;
        end
        
        //状态机状态跳转条件及跳转规律
        always @ (*)
        begin
        case(rx_state)
            IDLE       :  
            begin
                if(start)                                     //监测到start信号到来，下一状态跳转到start状态
                    rx_state_n = RECEIV_START;
                else
                    rx_state_n = rx_state;
            end
            RECEIV_START    :  
            begin
                if(clk_div_cnt == BPS_NUM)                     //已完成接收start标志信号
                    rx_state_n = RECEIV_DATA;
                else
                    rx_state_n = rx_state;
            end
            RECEIV_DATA    :  
            begin
                if(rx_bit_cnt == 3'h7 && clk_div_cnt == BPS_NUM) //已完成8bit数据的传输
                    rx_state_n = RECEIV_STOP;
                else
                    rx_state_n = rx_state;
            end
            RECEIV_STOP    :  
            begin
                if(clk_div_cnt == BPS_NUM)                       //已完成接收stop标志信号
                    rx_state_n = RECEIV_END;
                else
                    rx_state_n = rx_state;
                //   rx_state_n = RECEIV_END;
            end
            RECEIV_END    :  
            begin
                if(!uart_rx_1d)                                  //数据线重新被拉低，表示新数据传输又发送start标志信号，需要跳转到start状态
                    rx_state_n = RECEIV_START;
                else                                             //没有其他状况出现时，回到空闲状态，等待start信号的到来
                    rx_state_n = IDLE;
                //   rx_state_n = IDLE;
            end
            default    :  rx_state_n = IDLE;
        endcase
        end
        
        // 状态机输出
        always @ (posedge clk)
        begin
            if (~rstn) begin 
                rx_en <= `UD 1'b0;
                rx_data_reg <= `UD 8'h0;
            end else 
            case(rx_state)
                IDLE         ,
                RECEIV_START :                               //在空闲和start状态时将接收数据缓冲寄存器和数据使能置位；
                begin
                    rx_en <= `UD 1'b0;
                    rx_data_reg <= `UD 8'h0;
                end
                RECEIV_DATA  :  
                begin
                    // if(clk_div_cnt == BPS_NUM[15:1])        //在一个波特周期的中间位置取数据线上传输的数据；
                    if (clk_div_cnt == BPS_MID)
                        rx_data_reg  <= `UD {uart_rx , rx_data_reg[7:1]};  //以循环右移的方式将uart_rx数据填入缓冲寄存器的最高位（Uart传输低位在前，最后一个bit刚好是最高位）
                end
                RECEIV_STOP  : 
                begin
                    rx_en   <= `UD 1'b1;                    // 输出使能信号，表示最新的数据输出有效
                    rx_data <= `UD rx_data_reg;             // 将缓冲寄存器的值赋值给输出寄存器
                end
                RECEIV_END    :  
                begin
                    rx_data_reg <= `UD 8'h0;
                end
                default:    rx_en <= `UD 1'b0;
            endcase
        end

    endmodule

`else 

module uart_rx #(
        // clock frequency
        parameter  CLK_FREQ  = 50_000_000,   // clk frequency, Unit : Hz
        // UART format
        parameter  BPS_NUM   = 16'd434,
        parameter  BAUD_RATE = 115200,       // Unit : Hz
        parameter  PARITY    = "NONE"        // "NONE", "ODD", or "EVEN"
    )
    (
        //input ports
        input             clk     ,
        input             rstn    ,        // reset
        input             uart_rx ,
        
        //output ports
        output [7:0]      rx_data ,
        output            rx_en   ,
        output            rx_busy
    );


    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Generate fractional precise upper limit for counter
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    localparam  BAUD_CYCLES      = ( (CLK_FREQ*10*2 + BAUD_RATE) / (BAUD_RATE*2) ) / 10 ;
    localparam  BAUD_CYCLES_FRAC = ( (CLK_FREQ*10*2 + BAUD_RATE) / (BAUD_RATE*2) ) % 10 ;

    localparam           HALF_BAUD_CYCLES =  BAUD_CYCLES    / 2;
    localparam  THREE_QUARTER_BAUD_CYCLES = (BAUD_CYCLES*3) / 4;

    localparam [9:0] ADDITION_CYCLES = (BAUD_CYCLES_FRAC == 0) ? 10'b0000000000 :
                                    (BAUD_CYCLES_FRAC == 1) ? 10'b0000010000 :
                                    (BAUD_CYCLES_FRAC == 2) ? 10'b0010000100 :
                                    (BAUD_CYCLES_FRAC == 3) ? 10'b0010010010 :
                                    (BAUD_CYCLES_FRAC == 4) ? 10'b0101001010 :
                                    (BAUD_CYCLES_FRAC == 5) ? 10'b0101010101 :
                                    (BAUD_CYCLES_FRAC == 6) ? 10'b1010110101 :
                                    (BAUD_CYCLES_FRAC == 7) ? 10'b1101101101 :
                                    (BAUD_CYCLES_FRAC == 8) ? 10'b1101111011 :
                                    /*BAUD_CYCLES_FRAC == 9)*/ 10'b1111101111 ;

    wire [31:0] cycles [9:0];

    assign cycles[0] = BAUD_CYCLES + (ADDITION_CYCLES[0] ? 1 : 0);
    assign cycles[1] = BAUD_CYCLES + (ADDITION_CYCLES[1] ? 1 : 0);
    assign cycles[2] = BAUD_CYCLES + (ADDITION_CYCLES[2] ? 1 : 0);
    assign cycles[3] = BAUD_CYCLES + (ADDITION_CYCLES[3] ? 1 : 0);
    assign cycles[4] = BAUD_CYCLES + (ADDITION_CYCLES[4] ? 1 : 0);
    assign cycles[5] = BAUD_CYCLES + (ADDITION_CYCLES[5] ? 1 : 0);
    assign cycles[6] = BAUD_CYCLES + (ADDITION_CYCLES[6] ? 1 : 0);
    assign cycles[7] = BAUD_CYCLES + (ADDITION_CYCLES[7] ? 1 : 0);
    assign cycles[8] = BAUD_CYCLES + (ADDITION_CYCLES[8] ? 1 : 0);
    assign cycles[9] = BAUD_CYCLES + (ADDITION_CYCLES[9] ? 1 : 0);



    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Input beat
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    reg        rx_d1 = 1'b0;

    always @ (posedge clk)
        if (~rstn)
            rx_d1 <= 1'b0;
        else
            rx_d1 <= uart_rx;



    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    // count continuous '1'
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    reg [31:0] count1 = 0;

    always @ (posedge clk)
        if (~rstn) begin
            count1 <= 0;
        end else begin
            if (rx_d1)
                count1 <= (count1 < 'hFFFFFFFF) ? (count1 + 1) : count1;
            else
                count1 <= 0;
        end



    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    // main FSM
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    localparam [ 3:0] TOTAL_BITS_MINUS1 = (PARITY == "ODD" || PARITY == "EVEN") ? 4'd9 : 4'd8;

    localparam [ 1:0] S_IDLE     = 2'd0 ,
                    S_RX       = 2'd1 ,
                    S_STOP_BIT = 2'd2 ;

    reg        [ 1:0] state   = S_IDLE;
    reg        [ 8:0] rxbits  = 9'b0;
    reg        [ 3:0] rxcnt   = 4'd0;
    reg        [31:0] cycle   = 1;
    reg        [32:0] countp  = 33'h1_0000_0000;       // countp>=0x100000000 means '1' is majority       , countp<0x100000000 means '0' is majority
    wire              rxbit   = countp[32];            // countp>=0x100000000 corresponds to countp[32]==1, countp<0x100000000 corresponds to countp[32]==0

    wire [ 7:0] rbyte   = (PARITY == "ODD" ) ? rxbits[7:0] : 
                        (PARITY == "EVEN") ? rxbits[7:0] : 
                        /*(PARITY == "NONE")*/ rxbits[8:1] ;

    wire parity_correct = (PARITY == "ODD" ) ? ((~(^(rbyte))) == rxbits[8]) : 
                        (PARITY == "EVEN") ? (  (^(rbyte))  == rxbits[8]) : 
                        /*(PARITY == "NONE")*/      1'b1                    ;


    always @ (posedge clk)
        if (~rstn) begin
            state    <= S_IDLE;
            rxbits   <= 9'b0;
            rxcnt    <= 4'd0;
            cycle    <= 1;
            countp   <= 33'h1_0000_0000;
        end else begin
            case (state)
                S_IDLE : begin
                    if ((count1 >= THREE_QUARTER_BAUD_CYCLES) && (rx_d1 == 1'b0))  // receive a '0' which is followed by continuous '1' for half baud cycles
                        state <= S_RX;
                    rxcnt  <= 4'd0;
                    cycle  <= 2;                                                   // we've already receive a '0', so here cycle  = 2
                    countp <= (33'h1_0000_0000 - 33'd1);                           // we've already receive a '0', so here countp = initial_value - 1
                end
                
                S_RX :
                    if ( cycle < cycles[rxcnt] ) begin                             // cycle loop from 1 to cycles[rxcnt]
                        cycle  <= cycle + 1;
                        countp <= rx_d1 ? (countp + 33'd1) : (countp - 33'd1);
                    end else begin
                        cycle  <= 1;                                               // reset counter
                        countp <= 33'h1_0000_0000;                                 // reset counter
                        
                        if ( rxcnt < TOTAL_BITS_MINUS1 ) begin                     // rxcnt loop from 0 to TOTAL_BITS_MINUS1
                            rxcnt <= rxcnt + 4'd1;
                            if ((rxcnt == 4'd0) && (rxbit == 1'b1))                // except start bit, but get '1'
                                state <= S_IDLE;                                   // RX failed, back to IDLE
                        end else begin
                            rxcnt <= 4'd0;
                            state <= S_STOP_BIT;
                        end
                        
                        rxbits <= {rxbit, rxbits[8:1]};                            // put current rxbit to MSB of rxbits, and right shift other bits
                    end
                
                default :  // S_STOP_BIT
                    if ( cycle < THREE_QUARTER_BAUD_CYCLES) begin                  // cycle loop from 1 to THREE_QUARTER_BAUD_CYCLES
                        cycle <= cycle + 1;
                    end else begin
                        cycle <= 1;                                                // reset counter
                        state <= S_IDLE;                                           // back to IDLE
                    end
            endcase
        end



    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    // RX result byte
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    reg       f_tvalid = 1'b0;
    reg [7:0] f_tdata  = 8'h0;

    always @ (posedge clk)
        if (~rstn) begin
            f_tvalid <= 1'b0;
            f_tdata  <= 8'h0;
        end else begin
            if (state == S_IDLE) begin
                f_tvalid <= 1'b0;
            end 
            else if (state == S_RX) begin
                f_tvalid <= 1'b0;
                f_tdata  <= 8'h0;
            end 
            else if (state == S_STOP_BIT) begin
                if ( cycle < THREE_QUARTER_BAUD_CYCLES) begin
                end else begin
                    if ((count1 >= HALF_BAUD_CYCLES) && parity_correct) begin  // stop bit have enough '1', and parity correct
                        f_tvalid <= 1'b1;
                        f_tdata  <= rbyte;                                     // received a correct byte, output it
                    end
                end
            end
        end


    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Adapter
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------
    assign rx_en   = f_tvalid;
    assign rx_data = f_tdata;
    assign rx_busy = (state == S_IDLE) ? 1'b0 : 1'b1;

    endmodule

`endif 