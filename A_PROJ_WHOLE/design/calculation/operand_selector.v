`timescale 1ns / 1ps
//==============================================================================
// operand_selector.v
// 运算数选择模块
// 功能: 实现运算数选择的交互流程
// 流程:
//   1. 用户输入维度 m (行数)，按确认
//   2. 用户输入维度 n (列数)，按确认
//   3. 显示该维度的所有矩阵及编号
//   4. 用户输入矩阵编号，按确认
//   5. 显示选中的矩阵
//==============================================================================

module operand_selector #(
    parameter MAX_MATRICES = 7,
    parameter PTR_WIDTH = 3
)(
    input wire clk,
    input wire rst_n,
    
    //--------------------------------------------------------------------------
    // 控制接口
    //--------------------------------------------------------------------------
    input wire        start,              // 开始选择 (单周期脉冲)
    input wire        confirm,            // 确认按钮 (单周期脉冲)
    input wire [2:0]  row_input,          // 行数输入 (来自拨码开关)
    input wire [2:0]  col_input,          // 列数输入 (来自拨码开关)
    input wire [2:0]  matrix_select,      // 矩阵编号选择 (来自拨码开关)
    input wire [PTR_WIDTH:0] mat_count,   // 当前存储的矩阵数量
    
    //--------------------------------------------------------------------------
    // 矩阵存储接口
    //--------------------------------------------------------------------------
    output reg [PTR_WIDTH-1:0] read_id,   // 读取的矩阵 ID
    output reg [4:0]  read_addr,          // 读取地址
    input wire [2:0]  dim_row,            // 矩阵行数
    input wire [2:0]  dim_col,            // 矩阵列数
    input wire [3:0]  read_data,          // 读取数据
    
    //--------------------------------------------------------------------------
    // UART TX 接口
    //--------------------------------------------------------------------------
    output reg [7:0]  tx_data,
    output reg        tx_start,
    input wire        tx_busy,
    
    //--------------------------------------------------------------------------
    // 状态输出
    //--------------------------------------------------------------------------
    output reg        busy,               // 正在选择
    output reg        done,               // 选择完成
    output reg        error,              // 错误 (没有找到匹配的矩阵)
    output reg [PTR_WIDTH-1:0] selected_id, // 选中的矩阵 ID
    output reg [2:0]  selected_row,       // 选中矩阵的行数
    output reg [2:0]  selected_col        // 选中矩阵的列数
);

    //==========================================================================
    // ASCII 字符定义
    //==========================================================================
    localparam ASCII_0     = 8'h30;
    localparam ASCII_SPACE = 8'h20;
    localparam ASCII_CR    = 8'h0D;
    localparam ASCII_LF    = 8'h0A;
    localparam ASCII_COLON = 8'h3A;
    localparam ASCII_LBRK  = 8'h5B;
    localparam ASCII_RBRK  = 8'h5D;
    localparam ASCII_x     = 8'h78;

    //==========================================================================
    // 状态机定义
    //==========================================================================
    localparam S_IDLE         = 4'd0;
    localparam S_WAIT_CONFIRM = 4'd1;   // 等待用户确认维度
    localparam S_SCAN_START   = 4'd2;   // 开始扫描匹配的矩阵
    localparam S_SCAN_WAIT    = 4'd3;   // 等待读取
    localparam S_SCAN_CHECK   = 4'd4;   // 检查是否匹配
    localparam S_SCAN_NEXT    = 4'd5;   // 下一个矩阵
    localparam S_SHOW_LIST    = 4'd6;   // 显示匹配的矩阵列表
    localparam S_WAIT_SELECT  = 4'd7;   // 等待用户选择
    localparam S_VALIDATE     = 4'd8;   // 验证选择
    localparam S_SHOW_MATRIX  = 4'd9;   // 显示选中的矩阵
    localparam S_SEND_DATA    = 4'd10;  // 发送矩阵数据
    localparam S_DONE         = 4'd11;
    localparam S_ERROR        = 4'd12;

    reg [3:0] state;
    reg wait_tx;

    //==========================================================================
    // 内部变量
    //==========================================================================
    reg [2:0] target_row, target_col;     // 用户指定的维度
    reg [PTR_WIDTH-1:0] scan_idx;         // 扫描索引
    
    // 匹配矩阵列表 (最多存储8个匹配)
    reg [PTR_WIDTH-1:0] match_ids [0:7];  // 匹配的矩阵 ID
    reg [3:0] match_count;                // 匹配数量
    reg [3:0] match_idx;                  // 当前显示/处理的匹配索引
    
    // 显示相关
    reg [3:0] send_step;
    reg [2:0] current_row, current_col;
    reg [2:0] show_rows, show_cols;
    
    integer i;

    //==========================================================================
    // 主状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            read_id <= 0;
            read_addr <= 0;
            tx_data <= 0;
            tx_start <= 0;
            busy <= 0;
            done <= 0;
            error <= 0;
            selected_id <= 0;
            selected_row <= 0;
            selected_col <= 0;
            wait_tx <= 0;
            target_row <= 0;
            target_col <= 0;
            scan_idx <= 0;
            match_count <= 0;
            match_idx <= 0;
            send_step <= 0;
            current_row <= 0;
            current_col <= 0;
            show_rows <= 0;
            show_cols <= 0;
            for (i = 0; i < 8; i = i + 1) match_ids[i] <= 0;
        end else begin
            tx_start <= 0;
            done <= 0;

            case (state)
                //--------------------------------------------------------------
                // 空闲状态
                //--------------------------------------------------------------
                S_IDLE: begin
                    busy <= 0;
                    error <= 0;
                    if (start) begin
                        busy <= 1;
                        match_count <= 0;
                        state <= S_WAIT_CONFIRM;
                    end
                end

                //--------------------------------------------------------------
                // 等待用户确认维度 (同时读取行数和列数)
                //--------------------------------------------------------------
                S_WAIT_CONFIRM: begin
                    if (confirm) begin
                        target_row <= row_input;
                        target_col <= col_input;
                        scan_idx <= 0;
                        match_count <= 0;
                        state <= S_SCAN_START;
                    end
                end

                //--------------------------------------------------------------
                // 开始扫描
                //--------------------------------------------------------------
                S_SCAN_START: begin
                    read_id <= scan_idx;
                    state <= S_SCAN_WAIT;
                end

                //--------------------------------------------------------------
                // 等待读取稳定
                //--------------------------------------------------------------
                S_SCAN_WAIT: begin
                    state <= S_SCAN_CHECK;
                end

                //--------------------------------------------------------------
                // 检查是否匹配
                //--------------------------------------------------------------
                S_SCAN_CHECK: begin
                    if (dim_row == target_row && dim_col == target_col) begin
                        // 找到匹配的矩阵
                        if (match_count < 8) begin
                            match_ids[match_count] <= scan_idx;
                            match_count <= match_count + 1;
                        end
                    end
                    state <= S_SCAN_NEXT;
                end

                //--------------------------------------------------------------
                // 下一个矩阵
                //--------------------------------------------------------------
                S_SCAN_NEXT: begin
                    if (scan_idx + 1 < mat_count) begin
                        scan_idx <= scan_idx + 1;
                        state <= S_SCAN_START;
                    end else begin
                        // 扫描完成
                        if (match_count == 0) begin
                            state <= S_ERROR;
                        end else begin
                            match_idx <= 0;
                            send_step <= 0;
                            state <= S_SHOW_LIST;
                        end
                    end
                end

                //--------------------------------------------------------------
                // 显示匹配的矩阵列表
                // 格式: 编号\r\n矩阵内容\r\n...
                //--------------------------------------------------------------
                S_SHOW_LIST: begin
                    if (match_idx < match_count) begin
                        // 设置当前要显示的矩阵
                        read_id <= match_ids[match_idx];
                        read_addr <= 0;
                        current_row <= 0;
                        current_col <= 0;
                        send_step <= 0;
                        wait_tx <= 0;
                        state <= S_SEND_DATA;
                    end else begin
                        // 所有匹配矩阵已显示
                        state <= S_WAIT_SELECT;
                    end
                end

                //--------------------------------------------------------------
                // 发送矩阵数据
                //--------------------------------------------------------------
                S_SEND_DATA: begin
                    if (!tx_busy && !wait_tx) begin
                        case (send_step)
                            // 发送编号
                            4'd0: begin
                                tx_data <= ASCII_0 + {4'b0, match_idx[3:0]} + 8'd1; // 编号从1开始
                                tx_start <= 1;
                                wait_tx <= 1;
                                send_step <= 4'd1;
                            end
                            4'd1: begin
                                tx_data <= ASCII_CR;
                                tx_start <= 1;
                                wait_tx <= 1;
                                send_step <= 4'd2;
                            end
                            4'd2: begin
                                tx_data <= ASCII_LF;
                                tx_start <= 1;
                                wait_tx <= 1;
                                send_step <= 4'd3;
                                // 加载矩阵维度
                                show_rows <= dim_row;
                                show_cols <= dim_col;
                            end
                            // 发送矩阵内容
                            4'd3: begin
                                // 读取当前格子
                                read_addr <= current_row * 5 + current_col;
                                send_step <= 4'd4;
                            end
                            4'd4: begin
                                // 等待数据稳定
                                send_step <= 4'd5;
                            end
                            4'd5: begin
                                // 发送数据
                                tx_data <= ASCII_0 + {4'b0, read_data};
                                tx_start <= 1;
                                wait_tx <= 1;
                                send_step <= 4'd6;
                            end
                            4'd6: begin
                                // 发送分隔符
                                if (current_col + 1 < show_cols) begin
                                    tx_data <= ASCII_SPACE;
                                    tx_start <= 1;
                                    wait_tx <= 1;
                                    current_col <= current_col + 1;
                                    send_step <= 4'd3;
                                end else begin
                                    // 行结束
                                    tx_data <= ASCII_CR;
                                    tx_start <= 1;
                                    wait_tx <= 1;
                                    send_step <= 4'd7;
                                end
                            end
                            4'd7: begin
                                tx_data <= ASCII_LF;
                                tx_start <= 1;
                                wait_tx <= 1;
                                if (current_row + 1 < show_rows) begin
                                    current_row <= current_row + 1;
                                    current_col <= 0;
                                    send_step <= 4'd3;
                                end else begin
                                    // 矩阵显示完成，显示下一个
                                    match_idx <= match_idx + 1;
                                    state <= S_SHOW_LIST;
                                end
                            end
                        endcase
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 0;
                end

                //--------------------------------------------------------------
                // 等待用户选择
                //--------------------------------------------------------------
                S_WAIT_SELECT: begin
                    if (confirm) begin
                        state <= S_VALIDATE;
                    end
                end

                //--------------------------------------------------------------
                // 验证选择
                //--------------------------------------------------------------
                S_VALIDATE: begin
                    // matrix_select 是用户输入的编号 (1-based)
                    if (matrix_select >= 1 && matrix_select <= match_count) begin
                        selected_id <= match_ids[matrix_select - 1];
                        selected_row <= target_row;
                        selected_col <= target_col;
                        
                        // 显示选中的矩阵
                        read_id <= match_ids[matrix_select - 1];
                        match_idx <= matrix_select - 1;
                        current_row <= 0;
                        current_col <= 0;
                        send_step <= 0;
                        state <= S_SHOW_MATRIX;
                    end else begin
                        state <= S_ERROR;
                    end
                end

                //--------------------------------------------------------------
                // 显示选中的矩阵 (重用 S_SEND_DATA 的部分逻辑)
                //--------------------------------------------------------------
                S_SHOW_MATRIX: begin
                    if (!tx_busy && !wait_tx) begin
                        case (send_step)
                            4'd0: begin
                                show_rows <= dim_row;
                                show_cols <= dim_col;
                                read_addr <= 0;
                                send_step <= 4'd1;
                            end
                            4'd1: begin
                                send_step <= 4'd2;
                            end
                            4'd2: begin
                                tx_data <= ASCII_0 + {4'b0, read_data};
                                tx_start <= 1;
                                wait_tx <= 1;
                                send_step <= 4'd3;
                            end
                            4'd3: begin
                                if (current_col + 1 < show_cols) begin
                                    tx_data <= ASCII_SPACE;
                                    tx_start <= 1;
                                    wait_tx <= 1;
                                    current_col <= current_col + 1;
                                    read_addr <= current_row * 5 + (current_col + 1);
                                    send_step <= 4'd1;
                                end else begin
                                    tx_data <= ASCII_CR;
                                    tx_start <= 1;
                                    wait_tx <= 1;
                                    send_step <= 4'd4;
                                end
                            end
                            4'd4: begin
                                tx_data <= ASCII_LF;
                                tx_start <= 1;
                                wait_tx <= 1;
                                if (current_row + 1 < show_rows) begin
                                    current_row <= current_row + 1;
                                    current_col <= 0;
                                    read_addr <= (current_row + 1) * 5;
                                    send_step <= 4'd1;
                                end else begin
                                    state <= S_DONE;
                                end
                            end
                        endcase
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 0;
                end

                //--------------------------------------------------------------
                // 完成
                //--------------------------------------------------------------
                S_DONE: begin
                    done <= 1;
                    busy <= 0;
                    state <= S_IDLE;
                end

                //--------------------------------------------------------------
                // 错误
                //--------------------------------------------------------------
                S_ERROR: begin
                    error <= 1;
                    busy <= 0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
