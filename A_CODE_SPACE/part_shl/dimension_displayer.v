//==============================================================================
// dimension_displayer.v
// 维度筛选显示模块
// 功能：根据指定的维度筛选矩阵并按序号列出
// 输入维度后显示该维度下所有矩阵的序号列表
//==============================================================================
module dimension_displayer #(
    parameter MAX_MATRICES = 4,       // 最大矩阵数量
    parameter MSG_LEN      = 32       // 最大消息长度
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // 矩阵存储信息
    input  wire [2:0]  mat_count,                         // 已存储矩阵数量 (0-4)
    input  wire [2:0]  mat_rows [0:MAX_MATRICES-1],       // 各矩阵行数
    input  wire [2:0]  mat_cols [0:MAX_MATRICES-1],       // 各矩阵列数
    
    // 查询条件
    input  wire [2:0]  query_row,                         // 查询行数 (0表示不限制)
    input  wire [2:0]  query_col,                         // 查询列数 (0表示不限制)
    
    // 控制信号
    input  wire        start,                              // 开始筛选
    output reg         done,                               // 筛选完成
    output reg         busy,                               // 忙标志
    
    // 筛选结果
    output reg  [2:0]  match_count,                        // 匹配的矩阵数量
    output reg  [MAX_MATRICES-1:0] match_mask,            // 匹配掩码
    
    // 输出消息 (ASCII格式)
    output reg  [7:0]  msg_data [0:MSG_LEN-1],            // ASCII消息数据
    output reg  [4:0]  msg_len                             // 消息长度
);

    //--------------------------------------------------------------------------
    // 状态定义
    //--------------------------------------------------------------------------
    localparam IDLE        = 3'd0;
    localparam SCAN        = 3'd1;   // 扫描匹配
    localparam GEN_COUNT   = 3'd2;   // 生成匹配数量
    localparam GEN_COLON   = 3'd3;   // 生成冒号
    localparam GEN_IDX     = 3'd4;   // 生成序号
    localparam GEN_COMMA   = 3'd5;   // 生成逗号分隔
    localparam FINISH      = 3'd6;   // 完成
    
    reg [2:0] state;
    reg [2:0] scan_idx;              // 扫描索引
    reg [2:0] gen_idx;               // 生成索引
    reg [4:0] write_ptr;             // 写入指针
    reg [2:0] temp_count;            // 临时计数
    
    // ASCII转换
    function [7:0] digit_to_ascii;
        input [3:0] digit;
        begin
            digit_to_ascii = 8'h30 + digit;
        end
    endfunction
    
    //--------------------------------------------------------------------------
    // 维度匹配检查
    //--------------------------------------------------------------------------
    function is_match;
        input [2:0] row, col;
        input [2:0] q_row, q_col;
        begin
            // 0表示不限制该维度
            is_match = ((q_row == 0) || (row == q_row)) &&
                       ((q_col == 0) || (col == q_col));
        end
    endfunction
    
    //--------------------------------------------------------------------------
    // 主状态机
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            scan_idx    <= 3'd0;
            gen_idx     <= 3'd0;
            write_ptr   <= 5'd0;
            done        <= 1'b0;
            busy        <= 1'b0;
            match_count <= 3'd0;
            match_mask  <= {MAX_MATRICES{1'b0}};
            msg_len     <= 5'd0;
            temp_count  <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy        <= 1'b1;
                        scan_idx    <= 3'd0;
                        gen_idx     <= 3'd0;
                        write_ptr   <= 5'd0;
                        match_count <= 3'd0;
                        match_mask  <= {MAX_MATRICES{1'b0}};
                        temp_count  <= 3'd0;
                        state       <= SCAN;
                    end
                end
                
                // 扫描所有矩阵进行匹配
                SCAN: begin
                    if (scan_idx < mat_count) begin
                        if (is_match(mat_rows[scan_idx], mat_cols[scan_idx], 
                                     query_row, query_col)) begin
                            match_mask[scan_idx] <= 1'b1;
                            temp_count <= temp_count + 1;
                        end
                        scan_idx <= scan_idx + 1;
                    end else begin
                        match_count <= temp_count;
                        state <= GEN_COUNT;
                    end
                end
                
                // 生成匹配数量
                GEN_COUNT: begin
                    msg_data[write_ptr] <= digit_to_ascii(temp_count);
                    write_ptr <= write_ptr + 1;
                    if (temp_count > 0) begin
                        state <= GEN_COLON;
                    end else begin
                        msg_len <= write_ptr + 1;
                        state   <= FINISH;
                    end
                end
                
                // 生成冒号
                GEN_COLON: begin
                    msg_data[write_ptr] <= 8'h3A; // ':'
                    write_ptr <= write_ptr + 1;
                    gen_idx   <= 3'd0;
                    state     <= GEN_IDX;
                end
                
                // 生成匹配矩阵的序号
                GEN_IDX: begin
                    if (gen_idx < mat_count) begin
                        if (match_mask[gen_idx]) begin
                            msg_data[write_ptr] <= digit_to_ascii(gen_idx + 1);
                            write_ptr <= write_ptr + 1;
                            
                            // 检查是否还有更多匹配项
                            if (gen_idx + 1 < mat_count) begin
                                // 检查后续是否还有匹配项
                                gen_idx <= gen_idx + 1;
                                state   <= GEN_COMMA;
                            end else begin
                                msg_len <= write_ptr + 1;
                                state   <= FINISH;
                            end
                        end else begin
                            gen_idx <= gen_idx + 1;
                        end
                    end else begin
                        msg_len <= write_ptr;
                        state   <= FINISH;
                    end
                end
                
                // 生成逗号分隔符（仅在还有更多匹配项时）
                GEN_COMMA: begin
                    // 检查是否还有更多匹配项
                    reg has_more;
                    has_more = 1'b0;
                    for (integer i = gen_idx; i < mat_count; i = i + 1) begin
                        if (match_mask[i]) has_more = 1'b1;
                    end
                    
                    if (has_more) begin
                        msg_data[write_ptr] <= 8'h2C; // ','
                        write_ptr <= write_ptr + 1;
                    end
                    state <= GEN_IDX;
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
    
    //--------------------------------------------------------------------------
    // 初始化
    //--------------------------------------------------------------------------
    integer j;
    initial begin
        for (j = 0; j < MSG_LEN; j = j + 1) begin
            msg_data[j] = 8'h00;
        end
    end

endmodule
