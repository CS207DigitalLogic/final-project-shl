//==============================================================================
// dimension_displayer.v
// 维度筛选显示模块
// 功能：根据指定的维度筛选矩阵，显示该维度下所有矩阵的完整内容
// 
// 交互流程：
// 1. 用户输入行数m，按确认键
// 2. 用户输入列数n，按确认键  
// 3. 系统通过UART显示所有m×n矩阵及其编号
//
// 输出格式示例：
// 1
// 1 2 3
// 4 5 6
// 2
// 1 1 1
// 7 8 9
//==============================================================================
module dimension_displayer #(
    parameter MAX_MATRICES = 4,       // 最大矩阵数量
    parameter MAX_DIM      = 5,       // 最大维度
    parameter MSG_LEN      = 256      // 最大消息长度 (需要容纳完整矩阵数据)
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // 矩阵存储信息
    input  wire [2:0]  mat_count,                         // 已存储矩阵数量 (0-4)
    input  wire [2:0]  mat_rows [0:MAX_MATRICES-1],       // 各矩阵行数
    input  wire [2:0]  mat_cols [0:MAX_MATRICES-1],       // 各矩阵列数
    input  wire [3:0]  mat_data [0:MAX_MATRICES-1][0:24], // 矩阵数据 (4个矩阵，每个25元素)
    
    // 查询条件
    input  wire [2:0]  query_row,                         // 查询行数
    input  wire [2:0]  query_col,                         // 查询列数
    
    // 控制信号
    input  wire        start,                              // 开始筛选并显示
    output reg         done,                               // 显示完成
    output reg         busy,                               // 忙标志
    
    // 筛选结果
    output reg  [2:0]  match_count,                        // 匹配的矩阵数量
    output reg  [MAX_MATRICES-1:0] match_mask,            // 匹配掩码 (哪些矩阵符合维度)
    
    // UART发送接口
    output reg  [7:0]  tx_data,                           // 发送数据
    output reg         tx_start,                          // 发送请求
    input  wire        tx_busy                            // 发送忙信号
);

    //--------------------------------------------------------------------------
    // 状态定义
    //--------------------------------------------------------------------------
    localparam IDLE          = 4'd0;
    localparam SCAN          = 4'd1;   // 扫描匹配
    localparam SEND_MAT_IDX  = 4'd2;   // 发送矩阵编号
    localparam SEND_NEWLINE1 = 4'd3;   // 发送编号后换行
    localparam SEND_ELEMENT  = 4'd4;   // 发送矩阵元素
    localparam SEND_SPACE    = 4'd5;   // 发送空格
    localparam SEND_NEWLINE2 = 4'd6;   // 发送行末换行
    localparam NEXT_ELEMENT  = 4'd7;   // 下一个元素
    localparam NEXT_MATRIX   = 4'd8;   // 下一个矩阵
    localparam FINISH        = 4'd9;   // 完成
    
    reg [3:0] state;
    reg [2:0] scan_idx;              // 扫描索引
    reg [2:0] curr_mat_idx;          // 当前显示的矩阵索引
    reg [2:0] elem_row, elem_col;    // 当前元素的行列
    reg [2:0] temp_count;            // 临时计数
    reg [3:0] current_digit;         // 当前要发送的数字
    
    // ASCII转换
    function [7:0] digit_to_ascii;
        input [3:0] digit;
        begin
            digit_to_ascii = 8'h30 + digit; // '0' = 0x30
        end
    endfunction
    
    //--------------------------------------------------------------------------
    // 主状态机
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            scan_idx     <= 3'd0;
            curr_mat_idx <= 3'd0;
            elem_row     <= 3'd0;
            elem_col     <= 3'd0;
            done         <= 1'b0;
            busy         <= 1'b0;
            match_count  <= 3'd0;
            match_mask   <= {MAX_MATRICES{1'b0}};
            temp_count   <= 3'd0;
            tx_data      <= 8'd0;
            tx_start     <= 1'b0;
        end else begin
            tx_start <= 1'b0; // 默认不发送
            
            case (state)
                // 空闲状态
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy         <= 1'b1;
                        scan_idx     <= 3'd0;
                        curr_mat_idx <= 3'd0;
                        match_count  <= 3'd0;
                        match_mask   <= {MAX_MATRICES{1'b0}};
                        temp_count   <= 3'd0;
                        state        <= SCAN;
                    end
                end
                
                // 扫描所有矩阵，找出维度匹配的
                SCAN: begin
                    if (scan_idx < mat_count) begin
                        if (mat_rows[scan_idx] == query_row && 
                            mat_cols[scan_idx] == query_col) begin
                            match_mask[scan_idx] <= 1'b1;
                            temp_count <= temp_count + 1;
                        end
                        scan_idx <= scan_idx + 1;
                    end else begin
                        match_count  <= temp_count;
                        curr_mat_idx <= 3'd0;
                        if (temp_count > 0) begin
                            // 找到第一个匹配的矩阵
                            state <= SEND_MAT_IDX;
                        end else begin
                            // 没有匹配的矩阵
                            state <= FINISH;
                        end
                    end
                end
                
                // 发送矩阵编号 (1-based)
                SEND_MAT_IDX: begin
                    if (!tx_busy) begin
                        // 跳过不匹配的矩阵
                        if (curr_mat_idx < MAX_MATRICES && match_mask[curr_mat_idx]) begin
                            tx_data  <= digit_to_ascii(curr_mat_idx + 1);
                            tx_start <= 1'b1;
                            state    <= SEND_NEWLINE1;
                        end else if (curr_mat_idx < MAX_MATRICES) begin
                            curr_mat_idx <= curr_mat_idx + 1;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                // 发送编号后的换行
                SEND_NEWLINE1: begin
                    if (!tx_busy) begin
                        tx_data  <= 8'h0A; // '\n'
                        tx_start <= 1'b1;
                        elem_row <= 3'd0;
                        elem_col <= 3'd0;
                        state    <= SEND_ELEMENT;
                    end
                end
                
                // 发送矩阵元素
                SEND_ELEMENT: begin
                    if (!tx_busy) begin
                        // 计算一维索引: row * 5 + col
                        current_digit <= mat_data[curr_mat_idx][elem_row * 5 + elem_col];
                        tx_data  <= digit_to_ascii(mat_data[curr_mat_idx][elem_row * 5 + elem_col]);
                        tx_start <= 1'b1;
                        state    <= NEXT_ELEMENT;
                    end
                end
                
                // 决定下一步：空格、换行或下一个矩阵
                NEXT_ELEMENT: begin
                    if (!tx_busy) begin
                        if (elem_col < query_col - 1) begin
                            // 同一行还有元素，发送空格
                            state <= SEND_SPACE;
                        end else begin
                            // 一行结束，发送换行
                            state <= SEND_NEWLINE2;
                        end
                    end
                end
                
                // 发送空格分隔符
                SEND_SPACE: begin
                    if (!tx_busy) begin
                        tx_data  <= 8'h20; // ' '
                        tx_start <= 1'b1;
                        elem_col <= elem_col + 1;
                        state    <= SEND_ELEMENT;
                    end
                end
                
                // 发送行末换行
                SEND_NEWLINE2: begin
                    if (!tx_busy) begin
                        tx_data  <= 8'h0A; // '\n'
                        tx_start <= 1'b1;
                        elem_col <= 3'd0;
                        
                        if (elem_row < query_row - 1) begin
                            // 还有更多行
                            elem_row <= elem_row + 1;
                            state    <= SEND_ELEMENT;
                        end else begin
                            // 当前矩阵显示完毕
                            state <= NEXT_MATRIX;
                        end
                    end
                end
                
                // 切换到下一个匹配的矩阵
                NEXT_MATRIX: begin
                    if (!tx_busy) begin
                        curr_mat_idx <= curr_mat_idx + 1;
                        if (curr_mat_idx + 1 < MAX_MATRICES) begin
                            state <= SEND_MAT_IDX;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                // 完成
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
