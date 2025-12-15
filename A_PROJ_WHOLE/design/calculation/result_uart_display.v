`timescale 1ns / 1ps
//==============================================================================
// result_uart_display.v
// 计算结果 UART 展示模块
// 功能: 将矩阵计算结果通过 UART 以 ASCII 格式发送到电脑
// 格式示例 (2x3 结果矩阵):
//   Result:[2x3]
//   123 456 789
//   12 34 56
//==============================================================================

module result_uart_display (
    input wire clk,
    input wire rst_n,
    
    // 控制信号
    input wire start_display,       // 开始发送 (单周期脉冲)
    
    // 结果矩阵接口
    input wire [2:0] result_rows,   // 结果行数
    input wire [2:0] result_cols,   // 结果列数
    output reg [4:0] read_addr,     // 读取地址 (0~24)
    input wire [15:0] read_data,    // 读取的数据 (16位)
    
    // UART TX 接口
    output reg [7:0] tx_data,       // 发送的字节
    output reg tx_start,            // 发送请求
    input wire tx_busy,             // 发送忙信号
    
    // 状态输出
    output reg busy,                // 正在发送
    output reg done                 // 发送完成
);

    //==========================================================================
    // ASCII 字符定义
    //==========================================================================
    localparam ASCII_0     = 8'h30;  // '0'
    localparam ASCII_SPACE = 8'h20;  // ' '
    localparam ASCII_CR    = 8'h0D;  // '\r'
    localparam ASCII_LF    = 8'h0A;  // '\n'
    localparam ASCII_R     = 8'h52;  // 'R'
    localparam ASCII_e     = 8'h65;  // 'e'
    localparam ASCII_s     = 8'h73;  // 's'
    localparam ASCII_u     = 8'h75;  // 'u'
    localparam ASCII_l     = 8'h6C;  // 'l'
    localparam ASCII_t     = 8'h74;  // 't'
    localparam ASCII_COLON = 8'h3A;  // ':'
    localparam ASCII_LBRK  = 8'h5B;  // '['
    localparam ASCII_RBRK  = 8'h5D;  // ']'
    localparam ASCII_x     = 8'h78;  // 'x'

    //==========================================================================
    // 状态机定义
    //==========================================================================
    localparam S_IDLE       = 4'd0;
    localparam S_SEND_HEADER= 4'd1;   // 发送 "Result:"
    localparam S_SEND_DIM   = 4'd2;   // 发送维度 "[RxC]\r\n"
    localparam S_SET_ADDR   = 4'd3;   // 设置读取地址
    localparam S_LOAD_DATA  = 4'd4;   // 加载数据
    localparam S_SEND_DATA  = 4'd5;   // 发送数据 (多位数字)
    localparam S_SEND_SPACE = 4'd6;   // 发送空格
    localparam S_SEND_CR    = 4'd7;   // 发送回车
    localparam S_SEND_LF    = 4'd8;   // 发送换行
    localparam S_DONE       = 4'd9;

    reg [3:0] state;
    reg [2:0] current_row, current_col;
    reg [2:0] target_rows, target_cols;
    reg [3:0] header_idx;
    reg [3:0] dim_idx;
    reg [15:0] current_value;
    reg [3:0] digit_idx;              // 当前发送的数字位置
    reg [3:0] digit_count;            // 数字总位数
    reg [7:0] digits [0:4];           // 最多5位数字 (16位最大65535)
    reg       wait_tx;

    //==========================================================================
    // 数字分解：将16位数值分解为各位数字
    //==========================================================================
    reg [15:0] temp_value;
    reg [2:0]  digit_cnt;
    integer digit_i;
    
    always @(*) begin
        temp_value = current_value;
        digit_cnt = 0;
        
        // 找出有多少位数字
        if (temp_value >= 10000) digit_cnt = 5;
        else if (temp_value >= 1000) digit_cnt = 4;
        else if (temp_value >= 100) digit_cnt = 3;
        else if (temp_value >= 10) digit_cnt = 2;
        else digit_cnt = 1;
    end

    //==========================================================================
    // 主状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            current_row <= 3'd0;
            current_col <= 3'd0;
            target_rows <= 3'd0;
            target_cols <= 3'd0;
            header_idx <= 4'd0;
            dim_idx <= 4'd0;
            digit_idx <= 4'd0;
            digit_count <= 4'd0;
            current_value <= 16'd0;
            read_addr <= 5'd0;
            tx_data <= 8'd0;
            tx_start <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            wait_tx <= 1'b0;
            for (digit_i = 0; digit_i < 5; digit_i = digit_i + 1) begin
                digits[digit_i] <= 8'd0;
            end
        end else begin
            // 默认值
            tx_start <= 1'b0;
            done <= 1'b0;

            case (state)
                //--------------------------------------------------------------
                // 空闲状态
                //--------------------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start_display) begin
                        busy <= 1'b1;
                        target_rows <= result_rows;
                        target_cols <= result_cols;
                        header_idx <= 4'd0;
                        state <= S_SEND_HEADER;
                        wait_tx <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                // 发送标题: "Result:"
                //--------------------------------------------------------------
                S_SEND_HEADER: begin
                    if (!tx_busy && !wait_tx) begin
                        case (header_idx)
                            4'd0: begin tx_data <= ASCII_R; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 4'd1; end
                            4'd1: begin tx_data <= ASCII_e; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 4'd2; end
                            4'd2: begin tx_data <= ASCII_s; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 4'd3; end
                            4'd3: begin tx_data <= ASCII_u; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 4'd4; end
                            4'd4: begin tx_data <= ASCII_l; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 4'd5; end
                            4'd5: begin tx_data <= ASCII_t; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 4'd6; end
                            4'd6: begin tx_data <= ASCII_COLON; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 4'd7; end
                            4'd7: begin 
                                state <= S_SEND_DIM;
                                dim_idx <= 4'd0;
                            end
                        endcase
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 1'b0;
                end

                //--------------------------------------------------------------
                // 发送维度: "[RxC]\r\n"
                //--------------------------------------------------------------
                S_SEND_DIM: begin
                    if (!tx_busy && !wait_tx) begin
                        case (dim_idx)
                            4'd0: begin tx_data <= ASCII_LBRK; tx_start <= 1'b1; wait_tx <= 1'b1; dim_idx <= 4'd1; end
                            4'd1: begin tx_data <= ASCII_0 + {5'b0, target_rows}; tx_start <= 1'b1; wait_tx <= 1'b1; dim_idx <= 4'd2; end
                            4'd2: begin tx_data <= ASCII_x; tx_start <= 1'b1; wait_tx <= 1'b1; dim_idx <= 4'd3; end
                            4'd3: begin tx_data <= ASCII_0 + {5'b0, target_cols}; tx_start <= 1'b1; wait_tx <= 1'b1; dim_idx <= 4'd4; end
                            4'd4: begin tx_data <= ASCII_RBRK; tx_start <= 1'b1; wait_tx <= 1'b1; dim_idx <= 4'd5; end
                            4'd5: begin tx_data <= ASCII_CR; tx_start <= 1'b1; wait_tx <= 1'b1; dim_idx <= 4'd6; end
                            4'd6: begin tx_data <= ASCII_LF; tx_start <= 1'b1; wait_tx <= 1'b1; dim_idx <= 4'd7; end
                            4'd7: begin
                                current_row <= 3'd0;
                                current_col <= 3'd0;
                                state <= S_SET_ADDR;
                            end
                        endcase
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 1'b0;
                end

                //--------------------------------------------------------------
                // 设置读取地址
                //--------------------------------------------------------------
                S_SET_ADDR: begin
                    read_addr <= current_row * 5 + current_col;
                    state <= S_LOAD_DATA;
                end

                //--------------------------------------------------------------
                // 加载数据并分解为数字
                //--------------------------------------------------------------
                S_LOAD_DATA: begin
                    current_value <= read_data;
                    digit_idx <= 4'd0;
                    
                    // 分解数字 (组合逻辑计算位数，这里存储各位)
                    begin : DIGIT_DECOMPOSE
                        reg [15:0] val;
                        val = read_data;
                        
                        if (val >= 10000) begin
                            digit_count <= 4'd5;
                            digits[0] <= ASCII_0 + val / 10000;
                            digits[1] <= ASCII_0 + (val / 1000) % 10;
                            digits[2] <= ASCII_0 + (val / 100) % 10;
                            digits[3] <= ASCII_0 + (val / 10) % 10;
                            digits[4] <= ASCII_0 + val % 10;
                        end else if (val >= 1000) begin
                            digit_count <= 4'd4;
                            digits[0] <= ASCII_0 + val / 1000;
                            digits[1] <= ASCII_0 + (val / 100) % 10;
                            digits[2] <= ASCII_0 + (val / 10) % 10;
                            digits[3] <= ASCII_0 + val % 10;
                        end else if (val >= 100) begin
                            digit_count <= 4'd3;
                            digits[0] <= ASCII_0 + val / 100;
                            digits[1] <= ASCII_0 + (val / 10) % 10;
                            digits[2] <= ASCII_0 + val % 10;
                        end else if (val >= 10) begin
                            digit_count <= 4'd2;
                            digits[0] <= ASCII_0 + val / 10;
                            digits[1] <= ASCII_0 + val % 10;
                        end else begin
                            digit_count <= 4'd1;
                            digits[0] <= ASCII_0 + val;
                        end
                    end
                    
                    state <= S_SEND_DATA;
                end

                //--------------------------------------------------------------
                // 发送数据的各位数字
                //--------------------------------------------------------------
                S_SEND_DATA: begin
                    if (!tx_busy && !wait_tx) begin
                        if (digit_idx < digit_count) begin
                            tx_data <= digits[digit_idx];
                            tx_start <= 1'b1;
                            wait_tx <= 1'b1;
                            digit_idx <= digit_idx + 1;
                        end else begin
                            // 发送完所有数字
                            if (current_col + 1 < target_cols) begin
                                state <= S_SEND_SPACE;
                            end else begin
                                state <= S_SEND_CR;
                            end
                        end
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 1'b0;
                end

                //--------------------------------------------------------------
                // 发送空格
                //--------------------------------------------------------------
                S_SEND_SPACE: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_SPACE;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        current_col <= current_col + 1;
                        state <= S_SET_ADDR;
                    end
                end

                //--------------------------------------------------------------
                // 发送回车
                //--------------------------------------------------------------
                S_SEND_CR: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_CR;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        state <= S_SEND_LF;
                    end
                end

                //--------------------------------------------------------------
                // 发送换行
                //--------------------------------------------------------------
                S_SEND_LF: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_LF;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        
                        if (current_row + 1 < target_rows) begin
                            current_row <= current_row + 1;
                            current_col <= 3'd0;
                            state <= S_SET_ADDR;
                        end else begin
                            state <= S_DONE;
                        end
                    end
                end

                //--------------------------------------------------------------
                // 完成
                //--------------------------------------------------------------
                S_DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
