`timescale 1ns / 1ps
//==============================================================================
// calc_result_display.v
// 计算结果 UART 展示模块
// 功能: 将矩阵计算结果通过 UART 以 ASCII 格式发送到电脑显示
// 格式示例 (2x3 结果矩阵):
//   Result:[2x3]
//   10 15 20
//   25 30 35
//==============================================================================

module calc_result_display #(
    parameter MAX_DIM = 5,
    parameter RESULT_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    
    // 控制信号
    input wire start_display,           // 开始发送 (单周期脉冲)
    input wire [2:0] result_rows,       // 结果矩阵行数
    input wire [2:0] result_cols,       // 结果矩阵列数
    input wire [2:0] op_type,           // 操作类型: 000=转置, 001=加法, 010=标量乘, 011=矩阵乘
    
    // 矩阵数据接口 (直接连接到计算模块的结果)
    output reg [4:0] result_read_addr,  // 读取地址 (0~24)
    input wire [RESULT_WIDTH-1:0] read_data,  // 读取的数据
    
    // UART TX 接口
    output reg [7:0] tx_data,           // 发送的字节
    output reg tx_start,                // 发送请求
    input wire tx_busy,                 // 发送忙信号
    
    // 状态输出
    output reg busy,                    // 正在发送
    output reg done                     // 发送完成
);

    //==========================================================================
    // ASCII 字符定义
    //==========================================================================
    localparam ASCII_0     = 8'h30;  // '0'
    localparam ASCII_SPACE = 8'h20;  // ' '
    localparam ASCII_CR    = 8'h0D;  // '\r'
    localparam ASCII_LF    = 8'h0A;  // '\n'
    localparam ASCII_R     = 8'h52;  // 'R'
    localparam ASCII_E     = 8'h45;  // 'E'
    localparam ASCII_S     = 8'h53;  // 'S'
    localparam ASCII_U     = 8'h55;  // 'U'
    localparam ASCII_L     = 8'h4C;  // 'L'
    localparam ASCII_T     = 8'h54;  // 'T'
    localparam ASCII_COLON = 8'h3A;  // ':'
    localparam ASCII_LBRK  = 8'h5B;  // '['
    localparam ASCII_RBRK  = 8'h5D;  // ']'
    localparam ASCII_X     = 8'h78;  // 'x'

    //==========================================================================
    // 状态定义
    //==========================================================================
    localparam S_IDLE        = 4'd0;
    localparam S_SEND_TITLE  = 4'd1;  // 发送 "Result:"
    localparam S_WAIT_TITLE  = 4'd2;  // 等待 UART 发送完成
    localparam S_SEND_DIM    = 4'd3;  // 发送维度 "[rows x cols]"
    localparam S_WAIT_DIM    = 4'd4;  // 等待
    localparam S_SEND_LF     = 4'd5;  // 发送换行
    localparam S_WAIT_LF     = 4'd6;  // 等待
    localparam S_READ_WAIT   = 4'd7;  // 等待读取数据
    localparam S_SEND_DATA   = 4'd8;  // 发送数据
    localparam S_WAIT_DATA   = 4'd9;  // 等待数据发送
    localparam S_SEND_SEP    = 4'd10; // 发送空格或换行
    localparam S_WAIT_SEP    = 4'd11; // 等待分隔符发送
    localparam S_DONE        = 4'd12;

    reg [3:0] state;
    reg [2:0] row_idx, col_idx;       // 当前行、列索引
    reg [3:0] step_idx;               // 步骤索引 (用于发送标题和维度)
    reg [RESULT_WIDTH-1:0] current_data;
    reg [2:0] digit_idx;              // 当前发送的数字位置
    reg [2:0] saved_rows, saved_cols; // 保存的维度
    
    // 用于多位数显示
    reg [3:0] digit_count;
    reg [3:0] digits_0, digits_1, digits_2, digits_3, digits_4;
    
    // 数字分解 (组合逻辑)
    always @(*) begin
        // 计算位数
        if (current_data >= 16'd10000) digit_count = 4'd5;
        else if (current_data >= 16'd1000) digit_count = 4'd4;
        else if (current_data >= 16'd100) digit_count = 4'd3;
        else if (current_data >= 16'd10) digit_count = 4'd2;
        else digit_count = 4'd1;
        
        // 分解各位数字
        digits_0 = current_data % 10;
        digits_1 = (current_data / 10) % 10;
        digits_2 = (current_data / 100) % 10;
        digits_3 = (current_data / 1000) % 10;
        digits_4 = (current_data / 10000) % 10;
    end
    
    // 获取指定位置的数字 (从高位开始)
    function [3:0] get_digit;
        input [2:0] idx;
        input [3:0] count;
        begin
            case (count - 1 - idx)
                3'd0: get_digit = digits_0;
                3'd1: get_digit = digits_1;
                3'd2: get_digit = digits_2;
                3'd3: get_digit = digits_3;
                3'd4: get_digit = digits_4;
                default: get_digit = 4'd0;
            endcase
        end
    endfunction

    //==========================================================================
    // 状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
            result_read_addr <= 5'd0;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            step_idx <= 4'd0;
            current_data <= 0;
            digit_idx <= 3'd0;
            saved_rows <= 3'd0;
            saved_cols <= 3'd0;
        end else begin
            // 默认值
            done <= 1'b0;
            tx_start <= 1'b0;
            
            case (state)
                //--------------------------------------------------------------
                // 空闲状态
                //--------------------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start_display) begin
                        busy <= 1'b1;
                        row_idx <= 3'd0;
                        col_idx <= 3'd0;
                        step_idx <= 4'd0;
                        saved_rows <= result_rows;
                        saved_cols <= result_cols;
                        state <= S_SEND_TITLE;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送标题 "Result:"
                //--------------------------------------------------------------
                S_SEND_TITLE: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        case (step_idx)
                            4'd0: tx_data <= ASCII_R;
                            4'd1: tx_data <= ASCII_E;
                            4'd2: tx_data <= ASCII_S;
                            4'd3: tx_data <= ASCII_U;
                            4'd4: tx_data <= ASCII_L;
                            4'd5: tx_data <= ASCII_T;
                            4'd6: tx_data <= ASCII_COLON;
                            default: tx_data <= ASCII_SPACE;
                        endcase
                        state <= S_WAIT_TITLE;
                    end
                end
                
                S_WAIT_TITLE: begin
                    if (!tx_busy) begin
                        if (step_idx == 4'd6) begin
                            step_idx <= 4'd0;
                            state <= S_SEND_DIM;
                        end else begin
                            step_idx <= step_idx + 1'b1;
                            state <= S_SEND_TITLE;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送维度 "[rows x cols]"
                //--------------------------------------------------------------
                S_SEND_DIM: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        case (step_idx)
                            4'd0: tx_data <= ASCII_LBRK;                    // '['
                            4'd1: tx_data <= ASCII_0 + {5'd0, saved_rows};  // 行数
                            4'd2: tx_data <= ASCII_X;                       // 'x'
                            4'd3: tx_data <= ASCII_0 + {5'd0, saved_cols};  // 列数
                            4'd4: tx_data <= ASCII_RBRK;                    // ']'
                            default: tx_data <= ASCII_SPACE;
                        endcase
                        state <= S_WAIT_DIM;
                    end
                end
                
                S_WAIT_DIM: begin
                    if (!tx_busy) begin
                        if (step_idx == 4'd4) begin
                            step_idx <= 4'd0;
                            state <= S_SEND_LF;
                        end else begin
                            step_idx <= step_idx + 1'b1;
                            state <= S_SEND_DIM;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送换行
                //--------------------------------------------------------------
                S_SEND_LF: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        tx_data <= ASCII_LF;
                        state <= S_WAIT_LF;
                    end
                end
                
                S_WAIT_LF: begin
                    if (!tx_busy) begin
                        // 检查是否有数据要发送
                        if (saved_rows == 0 || saved_cols == 0) begin
                            state <= S_DONE;
                        end else begin
                            result_read_addr <= {2'd0, row_idx} * 5 + {2'd0, col_idx};
                            state <= S_READ_WAIT;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 等待读取数据 (需要一个周期让数据稳定)
                //--------------------------------------------------------------
                S_READ_WAIT: begin
                    current_data <= read_data;
                    digit_idx <= 3'd0;
                    state <= S_SEND_DATA;
                end
                
                //--------------------------------------------------------------
                // 发送数据
                //--------------------------------------------------------------
                S_SEND_DATA: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        // 从高位到低位发送
                        tx_data <= ASCII_0 + {4'd0, get_digit(digit_idx, digit_count)};
                        state <= S_WAIT_DATA;
                    end
                end
                
                S_WAIT_DATA: begin
                    if (!tx_busy) begin
                        if ({1'b0, digit_idx} + 1 < {1'b0, digit_count}) begin
                            digit_idx <= digit_idx + 1'b1;
                            state <= S_SEND_DATA;
                        end else begin
                            state <= S_SEND_SEP;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送分隔符 (空格或换行)
                //--------------------------------------------------------------
                S_SEND_SEP: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        if (col_idx + 1 < saved_cols) begin
                            // 行内: 发送空格
                            tx_data <= ASCII_SPACE;
                        end else begin
                            // 行末: 发送换行
                            tx_data <= ASCII_LF;
                        end
                        state <= S_WAIT_SEP;
                    end
                end
                
                S_WAIT_SEP: begin
                    if (!tx_busy) begin
                        if (col_idx + 1 < saved_cols) begin
                            // 同一行继续
                            col_idx <= col_idx + 1'b1;
                            result_read_addr <= {2'd0, row_idx} * 5 + ({2'd0, col_idx} + 1);
                            state <= S_READ_WAIT;
                        end else begin
                            // 行结束
                            col_idx <= 3'd0;
                            if (row_idx + 1 < saved_rows) begin
                                row_idx <= row_idx + 1'b1;
                                result_read_addr <= ({2'd0, row_idx} + 1) * 5;
                                state <= S_READ_WAIT;
                            end else begin
                                state <= S_DONE;
                            end
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 完成状态
                //--------------------------------------------------------------
                S_DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
