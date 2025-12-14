//storage, input parsing, and random generation of matrices for a calculator system.
`timescale 1ns / 1ps
module matrix_storage_unit #(
    // =========================================================
    // 物理参数 (Physical Hard Limit) - 综合后占用固定资源
    // =========================================================
    parameter HARD_MAX_MATRICES = 7,        // 预留 7 个位置，即使默认只用 4 个
    parameter PTR_WIDTH         = 3         // 3位宽足够表示 0-7
)(
    input wire clk,
    input wire rst_n,

    // 来自设置菜单寄存器，决定当前能用几个矩阵
    input wire [PTR_WIDTH:0] user_set_limit, // 比如输入 4, 6, 7

    // 1. 控制信号
    input wire [3:0] current_state, // 外部传入的状态 (state)
    input wire confirm_signal,      // 外部传入的确认信号 (confirm_flag)

    // 2. 数据输入源 (UART)
    input wire [7:0] uart_rx_data,
    input wire       uart_rx_done,

    // 3. 数据输出 (提供给 Calculator 和 Display)
    // 读端口 A
    input wire [PTR_WIDTH-1:0]  read_id_A,      
    output wire [2:0] dim_row_A,      
    output wire [2:0] dim_col_A,      
    input wire [4:0]  read_addr_A,    
    output wire [3:0] read_data_A,    

    // 读端口 B
    input wire [PTR_WIDTH-1:0]  read_id_B,
    output wire [2:0] dim_row_B,
    output wire [2:0] dim_col_B,
    input wire [4:0]  read_addr_B,
    output wire [3:0] read_data_B,

    // 4. 状态反馈
    output reg  input_error,    // 改为 reg 以便在 always 中赋值
    output wire [PTR_WIDTH:0] mat_count_out   // 当前存了几个矩阵
);

    //==========================================================================
    // 0. 参数与内部变量定义
    //==========================================================================

    // 状态机编码 (需与 Top 保持一致)
    localparam S_INPUTER   = 4'd1;
    localparam S_GENERATOR = 4'd2;

    // 存储堆
    reg [3:0]  mem_data [0:HARD_MAX_MATRICES-1][0:24];
    reg [2:0]  mem_rows [0:HARD_MAX_MATRICES-1];
    reg [2:0]  mem_cols [0:HARD_MAX_MATRICES-1];
    reg [PTR_WIDTH:0]  mat_count;

    // 状态机定义
    localparam RX_IDLE     = 3'd0;
    localparam RX_ROW      = 3'd1;
    localparam RX_DATA     = 3'd2;
    localparam RX_OVERFLOW = 3'd3;
    localparam RX_CONFIRM  = 3'd4;
    localparam RX_CLEAR    = 3'd5; // 清空状态,收到行/列指令 花 25 个周期把这块地全填0, 再写数据
    
    localparam GEN_IDLE    = 3'd0;
    localparam GEN_ROW     = 3'd1;
    localparam GEN_COL     = 3'd2;
    localparam GEN_COUNT   = 3'd3;
    localparam GEN_WORKING = 3'd4;
    localparam GEN_DONE    = 3'd5;

    reg [2:0] rx_state;
    reg [2:0] gen_state;

    // 通用变量
    reg [PTR_WIDTH-1:0] curr_mat_id;
    reg [2:0] curr_row, curr_col;
    reg [2:0] target_rows, target_cols;
    reg [4:0] elem_count;
    reg [4:0] total_elements;
    reg       input_complete;

    // Generator 变量
    reg [2:0] gen_rows, gen_cols;
    reg [1:0] gen_mat_count_target;
    reg [1:0] gen_mat_idx;
    reg [4:0] gen_elem_idx;
    reg [1:0] gen_slot;

    // 定义辅助信号 numeric_val (从 ASCII 提取数值)
    // ASCII '0'(0x30) -> 0, '9'(0x39) -> 9. 低4位正好对应数值。
    wire [3:0] numeric_val = uart_rx_data[3:0];

    //==========================================================================
    // 1. 读取逻辑
    //==========================================================================
    assign mat_count_out = mat_count;

    // Port A 读取
    assign dim_row_A   = mem_rows[read_id_A];
    assign dim_col_A   = mem_cols[read_id_A];
    assign read_data_A = mem_data[read_id_A][read_addr_A];

    // Port B 读取
    assign dim_row_B   = mem_rows[read_id_B];
    assign dim_col_B   = mem_cols[read_id_B];
    assign read_data_B = mem_data[read_id_B][read_addr_B];

    //==========================================================================
    // 2. 辅助函数
    //==========================================================================
    function [PTR_WIDTH-1:0] find_slot;
        input [2:0] rows, cols;
        integer k;
        reg found_empty, found_match;
        reg [PTR_WIDTH-1:0] temp_empty, temp_match;
        begin
            found_empty = 0; found_match = 0;
            temp_empty = 0; temp_match = 0;

            // 循环必须是静态的 (0 到 HARD_MAX)，但在内部用 if 判断逻辑边界
            for (k = 0; k < HARD_MAX_MATRICES; k = k + 1) begin
                // *** 关键修改 ***
                // 只有当索引 k 小于用户设置的上限时，才允许被选中
                if (k < user_set_limit) begin
                    
                    // 找空槽
                    if (!found_empty && mem_rows[k] == 0 && mem_cols[k] == 0) begin
                        temp_empty = k[PTR_WIDTH-1:0];
                        found_empty = 1;
                    end
                    
                    // 找匹配槽
                    if (!found_match && mem_rows[k] == rows && mem_cols[k] == cols) begin
                        temp_match = k[PTR_WIDTH-1:0];
                        found_match = 1;
                    end
                end
            end

            if (found_empty)      find_slot = temp_empty;
            else if (found_match) find_slot = temp_match;
            else                  find_slot = curr_mat_id; 
        end
    endfunction

    //==========================================================================
    // 3. LFSR 随机数生成
    //==========================================================================
    reg [15:0] lfsr;
    wire [3:0] random_digit = lfsr[3:0] % 10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) lfsr <= 16'hACE1;
        else lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    //==========================================================================
    // 4. 核心控制逻辑 (Inputer + Generator 合并)
    //==========================================================================
    // 将所有对 mem_data 的写操作合并到一个 always 块中，防止多重驱动错误
    integer idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 全局复位
            rx_state <= RX_IDLE;
            gen_state <= GEN_IDLE;
            curr_mat_id <= 2'd0;
            curr_row <= 3'd0;
            curr_col <= 3'd0;
            target_rows <= 3'd0;
            target_cols <= 3'd0;
            elem_count <= 5'd0;
            total_elements <= 5'd0;
            input_error <= 1'b0;
            input_complete <= 1'b0;
            mat_count <= 3'd0;
            
            // Generator 复位
            gen_rows <= 3'd0;
            gen_cols <= 3'd0;
            gen_mat_count_target <= 2'd0;
            gen_mat_idx <= 2'd0;
            gen_elem_idx <= 5'd0;
            gen_slot <= 2'd0;

            // 内存初始化 (可选)
            for (idx = 0; idx < HARD_MAX_MATRICES; idx = idx + 1) begin
                mem_rows[idx] <= 0;
                mem_cols[idx] <= 0;
            end

        end else begin
            // 默认信号
            input_complete <= 1'b0;

            // -----------------------------------------------------------------
            // A. INPUTER 模式逻辑 (支持 ASCII 输入和空格分隔)
            // -----------------------------------------------------------------
            if (current_state == S_INPUTER) begin
                // 重置 Generator 状态
                gen_state <= GEN_IDLE;

                // 只有当接收到新数据时才进行处理
                if (uart_rx_done) begin
                    
                    // --- 1. 收到分隔符 (空格 0x20, 回车 0x0D, 换行 0x0A)，直接跳过，等待下一个字符
                    if (uart_rx_data == 8'h20 || uart_rx_data == 8'h0D || uart_rx_data == 8'h0A) begin
                        // Do nothing (Ignore separators)
                    end
                    
                    // --- 2. 处理有效数字字符 ('0'~'9' -> 0x30~0x39) ---
                    else if (uart_rx_data >= 8'h30 && uart_rx_data <= 8'h39) begin

                        case (rx_state)
                            RX_IDLE: begin // 等待行数 (1-5)
                                if (numeric_val >= 4'd1 && numeric_val <= 4'd5) begin
                                    target_rows <= numeric_val[2:0];
                                    input_error <= 1'b0;
                                    rx_state <= RX_ROW;
                                end else begin
                                    // 输入了 '0' 或 '6'-'9'，超出范围
                                    input_error <= 1'b1; 
                                end
                            end

                            RX_ROW: begin // 等待列数 (1-5)
                                if (numeric_val >= 4'd1 && numeric_val <= 4'd5) begin
                                    target_cols <= numeric_val[2:0];
                                    total_elements <= target_rows * numeric_val[2:0];
                                    
                                    // 查找存储槽位
                                    curr_mat_id <= find_slot(target_rows, numeric_val[2:0]);
                                    
                                    // 准备清空内存
                                    elem_count <= 5'd0; 
                                    rx_state <= RX_CLEAR;
                                    input_error <= 1'b0;
                                end else begin
                                    input_error <= 1'b1;
                                    rx_state <= RX_IDLE;
                                end
                            end

                            // RX_CLEAR 状态不需要在这里处理，因为它不依赖 uart_rx_done
                            // 它会在下面的 else 逻辑中自动运行

                            RX_DATA: begin // 等待矩阵元素 (0-9)
                                if (elem_count < total_elements) begin
                                    // 这里 numeric_val 已经是 0-9 了，直接存
                                    mem_data[curr_mat_id][curr_row * 5 + curr_col] <= numeric_val;
                                    input_error <= 1'b0;
                                    elem_count <= elem_count + 1;
                                    
                                    // 地址更新逻辑
                                    if (curr_col == target_cols - 1) begin
                                        curr_col <= 3'd0;
                                        curr_row <= curr_row + 1;
                                    end else begin
                                        curr_col <= curr_col + 1;
                                    end

                                    // 如果这是最后一个元素，跳转到 Confirm
                                    if (elem_count + 1 == total_elements) 
                                        rx_state <= RX_CONFIRM;
                                end else begin
                                    rx_state <= RX_OVERFLOW;
                                end
                            end
                            
                            default: ; // 其他状态忽略输入
                        endcase
                    end
                    
                    // --- 3. 非法字符 (既不是分隔符，也不是数字) ---
                    else begin
                        // 例如输入了字母 'a'，报错
                        input_error <= 1'b1;
                    end
                end 
                
                // 处理不需要 UART 输入的自动跳转状态 (RX_CLEAR)
                // 注意：这里要把 RX_CLEAR 移出 uart_rx_done 的判断块，或者像之前一样独立处理
                else if (rx_state == RX_CLEAR) begin
                     if (elem_count < 25) begin
                         mem_data[curr_mat_id][elem_count] <= 4'd0;
                         elem_count <= elem_count + 1;
                     end else begin
                         rx_state <= RX_DATA;
                         curr_row <= 3'd0;
                         curr_col <= 3'd0;
                         elem_count <= 5'd0;
                     end
                end
                
                // 提前按 Confirm 逻辑
                if (confirm_signal) begin
                    if (rx_state == RX_DATA || rx_state == RX_OVERFLOW) 
                        rx_state <= RX_CONFIRM;
                end
                
                // RX_CONFIRM 逻辑
                if (rx_state == RX_CONFIRM) begin
                    mem_rows[curr_mat_id] <= target_rows;
                    mem_cols[curr_mat_id] <= target_cols;
                    if (mat_count < user_set_limit) mat_count <= mat_count + 1;
                    input_complete <= 1'b1;
                    rx_state <= RX_IDLE;
                    target_rows <= 3'd0;
                    target_cols <= 3'd0;
                    elem_count <= 5'd0;
                end
            end

            // -----------------------------------------------------------------
            // B. GENERATOR 模式
            // -----------------------------------------------------------------
            else if (current_state == S_GENERATOR) begin
                rx_state <= RX_IDLE;
                input_error <= 1'b0;
                case (gen_state)
                    GEN_IDLE: begin
                        // 这里也要用 ASCII 判断
                        if (uart_rx_done && uart_rx_data >= 8'h31 && uart_rx_data <= 8'h35) begin
                            gen_rows <= numeric_val[2:0];
                            gen_state <= GEN_COL;
                        end
                    end
                    GEN_COL: begin
                        if (uart_rx_done && uart_rx_data >= 8'h31 && uart_rx_data <= 8'h35) begin
                            gen_cols <= numeric_val[2:0];
                            gen_state <= GEN_COUNT;
                        end
                    end
                    GEN_COUNT: begin
                        if (uart_rx_done && uart_rx_data >= 8'h31 && uart_rx_data <= 8'h32) begin
                            gen_mat_count_target <= numeric_val[1:0];
                            gen_mat_idx <= 2'd0;
                            gen_elem_idx <= 5'd0;
                            gen_slot <= find_slot(gen_rows, gen_cols);
                            gen_state <= GEN_WORKING;
                        end
                    end
                    GEN_WORKING: begin
                        if (gen_elem_idx < gen_rows * gen_cols) begin
                            mem_data[gen_slot][gen_elem_idx] <= random_digit;
                            gen_elem_idx <= gen_elem_idx + 1;
                        end else begin
                            mem_rows[gen_slot] <= gen_rows;
                            mem_cols[gen_slot] <= gen_cols;
                            if (mat_count < user_set_limit) mat_count <= mat_count + 1;
                            if (gen_mat_idx + 1 < gen_mat_count_target) begin
                                gen_mat_idx <= gen_mat_idx + 1;
                                gen_elem_idx <= 5'd0;
                                gen_slot <= find_slot(gen_rows, gen_cols);
                            end else begin
                                gen_state <= GEN_DONE;
                            end
                        end
                    end
                    GEN_DONE: begin
                        if (confirm_signal) gen_state <= GEN_IDLE;
                    end
                endcase
            end

            // -----------------------------------------------------------------
            // C. 其他模式 (Reset 临时状态)
            // -----------------------------------------------------------------
            else begin
                rx_state <= RX_IDLE;
                gen_state <= GEN_IDLE;
                input_error <= 1'b0;
            end
        end
    end

endmodule