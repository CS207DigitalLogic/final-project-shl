`timescale 1ns / 1ps
module matrix_storage_unit #(
    parameter HARD_MAX_MATRICES = 15,       
    parameter PTR_WIDTH         = 4         
)(
    input wire clk,
    input wire rst_n,

    // 限制每种规格最大存储数量 (0-7)
    input wire [2:0] max_per_dim, 

    // 控制信号
    input wire [3:0] current_state, 
    input wire confirm_signal,      // 用于 "输入不足" 时手动结束

    // UART 数据
    input wire [7:0] uart_rx_data,
    input wire       uart_rx_done,

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

    // 状态反馈
    output reg  input_error,   
    output wire [PTR_WIDTH:0] mat_count_out   
);

    //==========================================================================
    // 0. 参数与定义
    //==========================================================================
    localparam S_INPUTER   = 4'd1;
    localparam S_GENERATOR = 4'd2;

    // 存储堆
    reg [3:0]  mem_data [0:HARD_MAX_MATRICES-1][0:24];
    reg [2:0]  mem_rows [0:HARD_MAX_MATRICES-1];
    reg [2:0]  mem_cols [0:HARD_MAX_MATRICES-1];
    reg [PTR_WIDTH:0]  mat_count;

    // 状态机
    localparam RX_IDLE     = 3'd0; // 等待行
    localparam RX_ROW      = 3'd1; // 等待列
    localparam RX_DATA     = 3'd2; // 接收数据
    localparam RX_CLEAR    = 3'd5; // 清零内存 (实现补0功能)
    
    localparam GEN_IDLE    = 3'd0;
    localparam GEN_COL     = 3'd2;
    localparam GEN_COUNT   = 3'd3;
    localparam GEN_WORKING = 3'd4;
    localparam GEN_DONE    = 3'd5;

    reg [2:0] rx_state;
    reg [2:0] gen_state;

    // 内部变量
    reg [PTR_WIDTH-1:0] curr_mat_id;
    reg [2:0] curr_row, curr_col;
    reg [2:0] target_rows, target_cols;
    reg [4:0] elem_count;
    reg [4:0] total_elements;
    reg       input_complete;

    // Generator 变量
    reg [2:0] gen_rows, gen_cols;
    reg [2:0] gen_mat_count_target;
    reg [2:0] gen_mat_idx;
    reg [4:0] gen_elem_idx;
    reg [PTR_WIDTH-1:0] gen_slot;

    // 覆盖指针
    reg [2:0] overwrite_ptr [1:5][1:5]; 
    
    // 查找辅助变量
    reg [PTR_WIDTH-1:0] match_indices [0:HARD_MAX_MATRICES-1];
    reg is_overwrite_mode;
    
    // 临时变量，用于接收 Task 的即时输出
    reg task_error_flag;
    reg task_overwrite_flag;

    // ASCII 转换
    wire [3:0] numeric_val = uart_rx_data[3:0];

    // 用于累加多位数字
    reg [7:0] parse_val;         
    // 标记当前 parse_val 是否包含有效数字
    reg       parse_valid;    
    
    // 辅助信号
    wire is_digit = (uart_rx_data >= 8'h30 && uart_rx_data <= 8'h39);
    wire is_separator = (uart_rx_data == 8'h20 || uart_rx_data == 8'h0D || uart_rx_data == 8'h0A); // 空格/回车/换行

    // 收到分隔符，或者按下Confirm且缓冲区有数
    wire commit_request = (uart_rx_done && is_separator) || (confirm_signal && parse_valid);
    
    //==========================================================================
    // 1. 读取逻辑
    //==========================================================================
    assign mat_count_out = mat_count;
    assign dim_row_A   = mem_rows[read_id_A];
    assign dim_col_A   = mem_cols[read_id_A];
    assign read_data_A = mem_data[read_id_A][read_addr_A];
    assign dim_row_B   = mem_rows[read_id_B];
    assign dim_col_B   = mem_cols[read_id_B];
    assign read_data_B = mem_data[read_id_B][read_addr_B];

    //==========================================================================
    // 2. 辅助 Task: 查找与分配逻辑 
    //==========================================================================
    // 只要涉及到分配ID，无论是 Inputer 还是 Generator，都调用这个 Task
    integer k;
    integer match_cnt_task;
    reg [PTR_WIDTH-1:0] first_empty_task;
    reg has_empty_task;
    
    task find_and_allocate;
        input [2:0] r_req;
        input [2:0] c_req;
        output [PTR_WIDTH-1:0] allocated_id;
        output error_flag;
        output overwrite_flag; 
        
        integer i, ptr_idx;
    begin
        match_cnt_task = 0;
        has_empty_task = 0;
        first_empty_task = 0;
        error_flag = 0;
        overwrite_flag = 0;

        // 1. 扫描物理内存 (0 ~ 14)
        for (i = 0; i < HARD_MAX_MATRICES; i = i + 1) begin
            // 找空位
            if (!has_empty_task && mem_rows[i] == 0) begin
                first_empty_task = i[PTR_WIDTH-1:0];
                has_empty_task = 1;
            end
            // 找规格匹配
            if (mem_rows[i] == r_req && mem_cols[i] == c_req) begin
                match_indices[match_cnt_task] = i[PTR_WIDTH-1:0];
                match_cnt_task = match_cnt_task + 1;
            end
        end

        // 2. 决策
        // 情况 A: 该规格数量已达 max_per_dim -> 覆盖旧的
        if (match_cnt_task >= max_per_dim) begin
            ptr_idx = overwrite_ptr[r_req][c_req];
            
            // 容错：如果 limit 突然被调小了，ptr 可能会越界
            if (ptr_idx >= match_cnt_task) ptr_idx = 0; 
            
            allocated_id = match_indices[ptr_idx]; // 获取要牺牲的那个矩阵的ID
            overwrite_flag = 1;

            // 更新指针 (Round Robin)
            if (ptr_idx + 1 >= match_cnt_task)
                overwrite_ptr[r_req][c_req] <= 0;
            else
                overwrite_ptr[r_req][c_req] <= ptr_idx + 1;
        end
        // 情况 B: 未达上限 & 有物理空位 -> 新增
        else if (has_empty_task) begin
            allocated_id = first_empty_task;
            overwrite_flag = 0;
        end
        // 情况 C: 未达上限 但 物理已满 -> 无法分配，报错
        else begin
            allocated_id = 0;
            error_flag = 1;
        end
    end
    endtask

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
    integer idx_clr, r_init, c_init;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            gen_state <= GEN_IDLE;
            curr_mat_id <= 0;
            curr_row <= 0; curr_col <= 0;
            target_rows <= 0; target_cols <= 0;
            elem_count <= 0; total_elements <= 0;
            input_error <= 0; input_complete <= 0;
            mat_count <= 0;

            parse_val <= 0;
            parse_valid <= 0;

            // ... Generator 复位 ...
            for (idx_clr = 0; idx_clr < HARD_MAX_MATRICES; idx_clr = idx_clr + 1) begin
                mem_rows[idx_clr] <= 0; mem_cols[idx_clr] <= 0;
            end
            for (r_init=1; r_init<=5; r_init=r_init+1) 
                for (c_init=1; c_init<=5; c_init=c_init+1) 
                    overwrite_ptr[r_init][c_init] <= 0;

        end else begin
            input_complete <= 1'b0;

            // -----------------------------------------------------------------
            // A. INPUTER 模式
            // -----------------------------------------------------------------
            if (current_state == S_INPUTER) begin
                gen_state <= GEN_IDLE;

                // 1. 处理 UART 数据
                if (uart_rx_done) begin
                    
                    // === Case A: 收到数字 (0-9) -> 累加到缓冲区 ===
                    if (is_digit) begin
                        input_error <= 1'b0; // 新输入开始，清除之前的报错
                        
                        // 累加逻辑: val = val * 10 + digit
                        // 加上简单的防溢出保护 (<200)
                        if (parse_val < 200) 
                            parse_val <= parse_val * 10 + (uart_rx_data - 8'h30);
                        
                        parse_valid <= 1'b1; // 标记缓冲区有效
                    end
                    
                    // === Case B: 收到分隔符 (空格/回车) -> 提交缓冲区数据 ===
                    else if (is_separator) begin
                        // 只有当缓冲区有数据时才处理 (避免连续空格导致逻辑错误)
                        if (parse_valid) begin
                            case (rx_state)
                                // -------------------------------------------------------
                                // 状态 1: 提交行数
                                // -------------------------------------------------------
                                RX_IDLE: begin 
                                    // 检查是否在 1-5 之间 (现在可以正确判断 "12" 了)
                                    if (parse_val >= 1 && parse_val <= 5) begin
                                        target_rows <= parse_val[2:0];
                                        rx_state <= RX_ROW;
                                    end else begin
                                        input_error <= 1'b1; // 报错 (例如输入了 12)
                                        // 保持在 IDLE
                                    end
                                end

                                // -------------------------------------------------------
                                // 状态 2: 提交列数
                                // -------------------------------------------------------
                                RX_ROW: begin 
                                    if (parse_val >= 1 && parse_val <= 5) begin
                                        target_cols <= parse_val[2:0];
                                        total_elements <= target_rows * parse_val[2:0];
                                        
                                        // 使用临时变量接收结果
                                        find_and_allocate(target_rows, parse_val[2:0], curr_mat_id, task_error_flag, task_overwrite_flag);
                                        
                                        // 将结果同步给全局信号
                                        input_error <= task_error_flag;
                                        is_overwrite_mode <= task_overwrite_flag;

                                        // 使用临时变量进行判断
                                        if (!task_error_flag) begin 
                                            elem_count <= 5'd0;
                                            rx_state <= RX_CLEAR; 
                                        end else begin
                                            rx_state <= RX_IDLE;
                                        end
                                    end else begin
                                        input_error <= 1'b1; 
                                        rx_state <= RX_IDLE;
                                    end
                                end

                                // -------------------------------------------------------
                                // 状态 3: 提交矩阵元素
                                // -------------------------------------------------------
                                RX_DATA: begin 
                                    // 检查数据范围 (例如 0-9)
                                    if (parse_val >= 0 && parse_val <= 9) begin
                                        if (elem_count < total_elements) begin
                                            mem_data[curr_mat_id][curr_row * 5 + curr_col] <= parse_val[3:0];
                                            elem_count <= elem_count + 1;
                                            
                                            // 更新坐标
                                            if (curr_col == target_cols - 1) begin
                                                curr_col <= 3'd0;
                                                curr_row <= curr_row + 1;
                                            end else begin
                                                curr_col <= curr_col + 1;
                                            end

                                            // 满即自动提交
                                            if (elem_count + 1 == total_elements) begin
                                                mem_rows[curr_mat_id] <= target_rows;
                                                mem_cols[curr_mat_id] <= target_cols;
                                                
                                                if (!is_overwrite_mode && mat_count < HARD_MAX_MATRICES)
                                                    mat_count <= mat_count + 1;
                                                
                                                input_complete <= 1'b1;
                                                rx_state <= RX_IDLE; // 重置
                                                target_rows <= 0; target_cols <= 0; elem_count <= 0;
                                            end
                                        end
                                    end else begin
                                        input_error <= 1'b1; // 数据错误 (例如输入了 12)
                                        rx_state <= RX_IDLE;
                                    end
                                end
                                default: ;
                            endcase
                            
                            // 处理完一次提交后，清空缓冲区
                            parse_val <= 0;
                            parse_valid <= 0;
                        end
                    end
                    
                    // === Case C: 非法字符 (既非数字也非分隔符，如 'a') ===
                    else begin
                        input_error <= 1'b1;
                        rx_state <= RX_IDLE;
                        parse_val <= 0;
                        parse_valid <= 0;
                    end
                end 

                // 2. 自动清零逻辑 (Pre-fill 0s) - 保持不变
                else if (rx_state == RX_CLEAR) begin
                     if (elem_count < 25) begin
                         mem_data[curr_mat_id][elem_count] <= 4'd0;
                         elem_count <= elem_count + 1;
                     end else begin
                         rx_state <= RX_DATA;
                         curr_row <= 3'd0;
                         curr_col <= 3'd0;
                         elem_count <= 5'd0;
                         // 确保进入 DATA 状态时缓冲区是干净的
                         parse_val <= 0;
                         parse_valid <= 0;
                     end
                end

                // 3. Confirm 信号处理
                if (confirm_signal) begin
                    if (rx_state == RX_DATA) begin
                        if (parse_valid && elem_count < total_elements) begin
                             mem_data[curr_mat_id][curr_row * 5 + curr_col] <= parse_val[3:0];
                        end
                        mem_rows[curr_mat_id] <= target_rows;
                        mem_cols[curr_mat_id] <= target_cols;
                        if (!is_overwrite_mode && mat_count < HARD_MAX_MATRICES) 
                            mat_count <= mat_count + 1;
                        input_complete <= 1'b1;
                    end
                    
                    // 复位所有状态
                    rx_state <= RX_IDLE;
                    target_rows <= 0; target_cols <= 0; elem_count <= 0;
                    input_error <= 0;
                    // 清空解析器
                    parse_val <= 0;
                    parse_valid <= 0;
                end
            end

            // -----------------------------------------------------------------
            // B. GENERATOR 模式 (修复版)
            // -----------------------------------------------------------------
            else if (current_state == S_GENERATOR) begin
                
                // 1. 数据解析逻辑
                // 优先级 A: 收到数字 -> 累加
                if (uart_rx_done && is_digit) begin
                    input_error <= 1'b0; 
                    if (parse_val < 200) 
                        parse_val <= parse_val * 10 + (uart_rx_data - 8'h30);
                    parse_valid <= 1'b1;
                end
                
                // 优先级 B: 提交数据 (空格 或 Confirm)
                else if (commit_request) begin
                    if (parse_valid) begin
                        case (gen_state)
                            // 第一步：输入行数
                            GEN_IDLE: begin
                                if (parse_val >= 1 && parse_val <= 5) begin
                                    gen_rows <= parse_val[2:0];
                                    gen_state <= GEN_COL;
                                end else begin
                                    input_error <= 1'b1;
                                end
                            end
                            // 第二步：输入列数
                            GEN_COL: begin
                                if (parse_val >= 1 && parse_val <= 5) begin
                                    gen_cols <= parse_val[2:0];
                                    gen_state <= GEN_COUNT;
                                end else begin
                                    input_error <= 1'b1;
                                    gen_state <= GEN_IDLE;
                                end
                            end
                            // 第三步：输入生成个数
                            GEN_COUNT: begin
                                if (parse_val >= 1 && parse_val <= max_per_dim) begin
                                    gen_mat_count_target <= parse_val[2:0];
                                    gen_mat_idx <= 3'd0;
                                    gen_elem_idx <= 5'd0;
                                    
                                    // [修复时序竞争] 使用临时变量接收 Task 结果
                                    find_and_allocate(gen_rows, gen_cols, gen_slot, task_error_flag, task_overwrite_flag);
                                    
                                    // 同步到全局输出
                                    input_error <= task_error_flag;
                                    is_overwrite_mode <= task_overwrite_flag;
                                    
                                    // 根据临时变量判断跳转
                                    if (!task_error_flag) begin 
                                        gen_state <= GEN_WORKING;
                                    end else begin
                                        gen_state <= GEN_IDLE; // 满了
                                    end
                                end else begin
                                    input_error <= 1'b1; // 数量超限
                                    gen_state <= GEN_IDLE;
                                end
                            end
                            default: ;
                        endcase
                        
                        // 提交后清空缓冲区
                        parse_val <= 0;
                        parse_valid <= 0;
                    end
                end
                
                // 优先级 C: 非法字符
                else if (uart_rx_done && !is_digit && !is_separator) begin
                    input_error <= 1'b1;
                    parse_val <= 0;
                    parse_valid <= 0;
                    gen_state <= GEN_IDLE;
                end

                // 2. 自动生成逻辑 (独立于 UART 运行)
                if (gen_state == GEN_WORKING) begin
                    if (gen_elem_idx < gen_rows * gen_cols) begin
                        mem_data[gen_slot][gen_elem_idx] <= random_digit;
                        gen_elem_idx <= gen_elem_idx + 1;
                    end else begin
                        // 保存当前矩阵
                        mem_rows[gen_slot] <= gen_rows;
                        mem_cols[gen_slot] <= gen_cols;
                        
                        if (!is_overwrite_mode && mat_count < HARD_MAX_MATRICES) 
                            mat_count <= mat_count + 1;

                        // 准备生成下一个
                        if (gen_mat_idx + 1 < gen_mat_count_target) begin
                            gen_mat_idx <= gen_mat_idx + 1;
                            gen_elem_idx <= 0;
                            
                            // [修复时序竞争] 再次调用分配
                            find_and_allocate(gen_rows, gen_cols, gen_slot, task_error_flag, task_overwrite_flag);
                            input_error <= task_error_flag;
                            is_overwrite_mode <= task_overwrite_flag;
                            
                            if (task_error_flag) gen_state <= GEN_DONE; 
                        end else begin
                            gen_state <= GEN_DONE;
                        end
                    end
                end

                // 3. 结束确认
                if (gen_state == GEN_DONE) begin
                    // 如果按 Confirm，回到 IDLE 并通知顶层
                    if (confirm_signal) begin 
                        gen_state <= GEN_IDLE;
                        input_complete <= 1'b1;
                    end
                end
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