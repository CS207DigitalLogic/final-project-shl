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
    input wire confirm_signal,      // 确认/清除错误信号

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
    // 0. 全局参数与定义
    //==========================================================================

    // a. 核心存储堆 (Storage Heap)
    reg [3:0]           mem_data [0:HARD_MAX_MATRICES-1][0:24]; // 矩阵数据
    reg [2:0]           mem_rows [0:HARD_MAX_MATRICES-1];       // 行记录
    reg [2:0]           mem_cols [0:HARD_MAX_MATRICES-1];       // 列记录
    reg [PTR_WIDTH:0]   mat_count;                              // 当前总数
    //--------------------------------------------------------------------------
    // b. 状态机定义 (FSM Parameters)
    //--------------------------------------------------------------------------
    // 主状态机
    localparam S_INPUTER   = 4'd1;
    localparam S_GENERATOR = 4'd2;

    // --- Inputer 模式状态 ---
    localparam RX_IDLE      = 3'd0; // 等待输入行 
    localparam RX_ROW       = 3'd1; // 等待输入列 
    localparam RX_DATA      = 3'd2; // 接收矩阵元素数据
    localparam RX_ERROR     = 3'd3; // 错误死锁状态
    localparam RX_DONE      = 3'd4; // 输入完成，等待confirm
    localparam RX_CLEAR     = 3'd5; // 自动补0/清空内存

    // --- Generator 模式状态 ---
    localparam GEN_IDLE       = 3'd0; // 等待输入行 
    localparam GEN_WAIT_COL   = 3'd1; // 等待输入列 
    localparam GEN_WAIT_COUNT = 3'd2; // 等待输入数量 
    localparam GEN_CHECK      = 3'd3; // 容量预检查 
    localparam GEN_WORKING    = 3'd4; // 自动生成中
    localparam GEN_DONE       = 3'd5; // 生成完成
    localparam GEN_ERROR      = 3'd6; // 生成错误/超标
    localparam GEN_ALLOC_NEXT = 3'd7; // 等待内存写入生效

    // 状态寄存器
    reg [2:0] rx_state;
    reg [2:0] gen_state;

    //--------------------------------------------------------------------------
    // c. UART 解析与辅助信号
    //--------------------------------------------------------------------------

    // 基础判断
    wire is_digit     = (uart_rx_data >= 8'h30 && uart_rx_data <= 8'h39);
    wire is_separator = (uart_rx_data == 8'h20 || uart_rx_data == 8'h0D || uart_rx_data == 8'h0A);
    wire [3:0] numeric_val = uart_rx_data[3:0]; // 单位数字直接提取

    // 高级解析 (用于处理多位数)
    reg [7:0] parse_val;   // 当前累加值缓冲区
    reg       parse_valid; // 缓冲区有效标志
    
    // 预判值 (Lookahead): 用于在接收当前位时，预判是否溢出
    wire [7:0] lookahead_val = parse_val * 10 + (uart_rx_data - 8'h30);

    //--------------------------------------------------------------------------
    // d. Inputer 模式专用变量
    //--------------------------------------------------------------------------

    reg [PTR_WIDTH-1:0] curr_mat_id;
    reg [2:0]           curr_row, curr_col;
    reg [2:0]           target_rows, target_cols;
    reg [4:0]           elem_count;
    reg [4:0]           total_elements;
    reg                 input_complete;
    
    // 临时标志位 (用于 find_and_allocate 的返回)
    reg tmp_error_flag;      
    reg tmp_overwrite_flag;  

    //--------------------------------------------------------------------------
    // e. Generator 模式专用变量
    //--------------------------------------------------------------------------
    reg [2:0]           gen_rows;
    reg [2:0]           gen_cols;

    reg [2:0]           gen_mat_count_target; 
    reg [2:0]           gen_mat_idx;
    
    reg [4:0]           gen_elem_idx;
    reg [PTR_WIDTH-1:0] gen_slot;
    
    // 循环辅助变量 (用于 GEN_CHECK 阶段统计数量)
    integer idx_chk;
    integer match_count_chk;

    //--------------------------------------------------------------------------
    // f. 分配与覆盖策略
    //--------------------------------------------------------------------------

    // 覆盖指针表: overwrite_ptr[row][col]
    reg [2:0]           overwrite_ptr [1:5][1:5];
    // 查找结果缓存
    reg [PTR_WIDTH-1:0] match_indices [0:HARD_MAX_MATRICES-1];
    reg                 is_overwrite_mode;

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

        // 1. 扫描物理内存
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
            allocated_id = match_indices[ptr_idx]; 
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
    // 4. 核心控制逻辑
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
            tmp_error_flag <= 0;
            tmp_overwrite_flag <= 0;

            // 清理存储堆
            for (idx_clr = 0; idx_clr < HARD_MAX_MATRICES; idx_clr = idx_clr + 1) begin
                mem_rows[idx_clr] <= 0;
                mem_cols[idx_clr] <= 0;
            end
            // 清理覆盖指针
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

                // 如果处于 ERROR 状态，锁定直到 Confirm
                if (rx_state == RX_ERROR) begin
                    if (confirm_signal) begin
                        rx_state <= RX_IDLE;
                        input_error <= 1'b0;
                        // 清理残留数据
                        parse_val <= 0;
                        parse_valid <= 0;
                        target_rows <= 0;
                        target_cols <= 0;
                        elem_count <= 0;
                    end
                    // 否则，忽略所有 uart_rx_data，保持报错灯亮
                end
                
                else begin 
                    // 1. UART 数据处理
                    if (uart_rx_done) begin
                        
                        // === Case A: 数字 (引入即时预判)===
                        if (is_digit) begin
                            case (rx_state)
                                RX_IDLE, RX_ROW: begin
                                    // 维度限制: 1-5。如果累计值 > 5，立刻报错
                                    // 如果 lookahead_val 是 0 (输入了0)，暂时不报错，等到分隔符时再报
                                    // 主要是为了拦截 > 5 的情况
                                    if (lookahead_val > 5 && lookahead_val < 200) begin
                                        input_error <= 1'b1;
                                        rx_state <= RX_ERROR;
                                    end else begin
                                        parse_val <= lookahead_val;
                                        parse_valid <= 1'b1;
                                    end
                                end
                                
                                RX_DATA: begin
                                    // 元素限制: 0-9。如果累计值 > 9，立刻报错
                                    if (lookahead_val > 9 && lookahead_val < 200) begin
                                        input_error <= 1'b1;
                                        rx_state <= RX_ERROR;
                                    end else begin
                                        parse_val <= lookahead_val;
                                        parse_valid <= 1'b1;
                                    end
                                end
                                
                                RX_DONE: begin
                                    // 输入完成状态，忽略后续数字输入
                                end
                                
                                default: begin // 其他状态，默认接收
                                    parse_val <= lookahead_val;
                                    parse_valid <= 1'b1;
                                end
                            endcase
                        end
                        
                        // === Case B: 分隔符 (空格/回车) ===
                        else if (is_separator) begin
                            if (parse_valid) begin
                                case (rx_state)
                                    // 1. 行数
                                    RX_IDLE: begin 
                                        if (parse_val >= 1 && parse_val <= 5) begin
                                            target_rows <= parse_val[2:0];
                                            rx_state <= RX_ROW;
                                        end else begin
                                            // 维度错误 -> 进入死锁状态 RX_ERROR
                                            input_error <= 1'b1;
                                            rx_state <= RX_ERROR;
                                        end
                                    end

                                    // 2. 列数
                                    RX_ROW: begin 
                                        if (parse_val >= 1 && parse_val <= 5) begin
                                            target_cols <= parse_val[2:0];
                                            total_elements <= target_rows * parse_val[2:0];
                                            
                                            find_and_allocate(target_rows, parse_val[2:0], curr_mat_id, tmp_error_flag, tmp_overwrite_flag);
                                            is_overwrite_mode <= tmp_overwrite_flag;

                                            if (tmp_error_flag == 0) begin
                                                elem_count <= 5'd0;
                                                rx_state <= RX_CLEAR; // 分配成功，去清内存
                                            end else begin
                                                // 物理满了，不算格式错误，回到 IDLE
                                                rx_state <= RX_IDLE; 
                                            end
                                        end else begin
                                            // 维度错误 -> 进入死锁状态 RX_ERROR
                                            input_error <= 1'b1; 
                                            rx_state <= RX_ERROR;
                                        end
                                    end

                                    // 3. 数据元素
                                    RX_DATA: begin 
                                        if (parse_val >= 0 && parse_val <= 9) begin
                                            if (elem_count < total_elements) begin
                                                mem_data[curr_mat_id][curr_row * 5 + curr_col] <= parse_val[3:0];
                                                elem_count <= elem_count + 1;
                                                
                                                // 坐标更新
                                                if (curr_col == target_cols - 1) begin
                                                    curr_col <= 3'd0;
                                                    curr_row <= curr_row + 1;
                                                end else begin
                                                    curr_col <= curr_col + 1;
                                                end

                                                // 自动完成
                                                if (elem_count + 1 == total_elements) begin
                                                    mem_rows[curr_mat_id] <= target_rows;
                                                    mem_cols[curr_mat_id] <= target_cols;
                                                    if (!is_overwrite_mode && mat_count < HARD_MAX_MATRICES)
                                                        mat_count <= mat_count + 1;
                                                    
                                                    input_complete <= 1'b1;
                                                    rx_state <= RX_DONE; // 进入完成状态，忽略后续输入
                                                    target_rows <= 0; target_cols <= 0; elem_count <= 0;
                                                end
                                            end
                                        end else begin
                                            // 元素值错误 -> 进入死锁状态 RX_ERROR
                                            input_error <= 1'b1;
                                            rx_state <= RX_ERROR;
                                        end
                                    end
                                    
                                    default: ;
                                endcase
                                // 清空缓冲区
                                parse_val <= 0;
                                parse_valid <= 0;
                            end
                        end
                        
                        // === Case C: 非法字符 ===
                        else begin
                            // RX_DONE 状态忽略所有输入
                            if (rx_state != RX_DONE) begin
                                // 输入了字母 -> 进入死锁状态 RX_ERROR
                                input_error <= 1'b1;
                                rx_state <= RX_ERROR;
                                parse_val <= 0;
                                parse_valid <= 0;
                            end
                        end
                    end 

                    // 2. 自动清零 (RX_CLEAR)
                    else if (rx_state == RX_CLEAR) begin
                        if (elem_count < 25) begin
                            mem_data[curr_mat_id][elem_count] <= 4'd0;
                            elem_count <= elem_count + 1;
                        end else begin
                            rx_state <= RX_DATA;
                            curr_row <= 3'd0;
                            curr_col <= 3'd0;
                            elem_count <= 5'd0;
                            parse_val <= 0;
                            parse_valid <= 0;
                        end
                    end

                    // 3. Confirm 信号处理 (在正常状态下按 Confirm)
                    if (confirm_signal) begin
                        if (rx_state == RX_DATA) begin
                            if (parse_valid) begin
                                // 缓冲区还有数据 (比如 "12" 且之前没被 error 拦截，这理论上不可能发生，除非是 "9")
                                // 因为 digit 阶段已经预判了，所以这里的 parse_val 肯定是 <=9 的
                                if (parse_val <= 9) begin
                                    if (elem_count < total_elements) begin
                                        mem_data[curr_mat_id][curr_row * 5 + curr_col] <= parse_val[3:0];
                                    end
                                    mem_rows[curr_mat_id] <= target_rows;
                                    mem_cols[curr_mat_id] <= target_cols;
                                    if (!is_overwrite_mode && mat_count < HARD_MAX_MATRICES) 
                                        mat_count <= mat_count + 1;
                                    input_complete <= 1'b1;
                                    rx_state <= RX_IDLE;
                                    input_error <= 0;
                                end else begin
                                    input_error <= 1'b1;
                                    rx_state <= RX_ERROR;
                                end
                            end else begin
                                // 正常结束
                                mem_rows[curr_mat_id] <= target_rows;
                                mem_cols[curr_mat_id] <= target_cols;
                                if (!is_overwrite_mode && mat_count < HARD_MAX_MATRICES) 
                                    mat_count <= mat_count + 1;
                                input_complete <= 1'b1;
                                rx_state <= RX_IDLE;
                                input_error <= 0;
                            end
                        end 
                        else if (rx_state == RX_IDLE) begin
                            input_error <= 0;
                        end
                        else if (rx_state == RX_DONE) begin
                            // 输入完成状态，按 confirm 回到 IDLE
                            rx_state <= RX_IDLE;
                            input_error <= 0;
                            parse_val <= 0;
                            parse_valid <= 0;
                        end
                        else begin
                            rx_state <= RX_IDLE;
                            input_error <= 0;
                        end
                        
                        if (rx_state != RX_ERROR) begin
                            target_rows <= 0; target_cols <= 0; elem_count <= 0;
                            parse_val <= 0; parse_valid <= 0;
                        end
                    end
                end 
            end
            // -----------------------------------------------------------------
            // B. GENERATOR 
            // -----------------------------------------------------------------
            else if (current_state == S_GENERATOR) begin

                rx_state <= RX_IDLE; 
                
                if (gen_state == GEN_ERROR) 
                    input_error <= 1'b1;
                else 
                    input_error <= 1'b0;

                // 错误复位
                if (gen_state == GEN_ERROR) begin
                    if (confirm_signal) begin
                        gen_state <= GEN_IDLE;
                        input_error <= 1'b0;
                        parse_val <= 0; 
                        parse_valid <= 0;
                    end
                end

                else begin
                    if (uart_rx_done) begin
                        
                        // === Case A: 数字输入  ===
                        if (is_digit) begin
                            if (lookahead_val < 200) begin 
                                parse_val <= lookahead_val;
                                parse_valid <= 1'b1;
                            end

                            if (gen_state == GEN_WAIT_COUNT) begin
                                // 统计当前同规格矩阵数量
                                match_count_chk = 0;
                                for (idx_chk = 0; idx_chk < HARD_MAX_MATRICES; idx_chk = idx_chk + 1) begin
                                    if (mem_rows[idx_chk] == gen_rows && mem_cols[idx_chk] == gen_cols)
                                        match_count_chk = match_count_chk + 1;
                                end

                                if ((match_count_chk + lookahead_val) > max_per_dim) begin
                                    gen_state <= GEN_ERROR;
                                    input_error <= 1'b1; 
                                    parse_val <= 0; 
                                    parse_valid <= 0;
                                end
                            end
                        end
                        
                        // === Case B: 分隔符处理 (空格/回车) ===
                        else if (is_separator) begin
                            if (parse_valid) begin // 确保缓冲区有数据
                                case (gen_state)
                                    GEN_IDLE: begin
                                        if (parse_val >= 1 && parse_val <= 5) begin
                                            gen_rows <= parse_val[2:0];
                                            gen_state <= GEN_WAIT_COL;
                                        end else begin
                                            gen_state <= GEN_ERROR;
                                            input_error <= 1'b1;
                                        end
                                        parse_val <= 0; parse_valid <= 0;
                                    end

                                    GEN_WAIT_COL: begin
                                        if (parse_val >= 1 && parse_val <= 5) begin
                                            gen_cols <= parse_val[2:0];
                                            gen_state <= GEN_WAIT_COUNT;
                                        end else begin
                                            gen_state <= GEN_ERROR;
                                            input_error <= 1'b1;
                                        end
                                        parse_val <= 0; parse_valid <= 0;
                                    end

                                    GEN_WAIT_COUNT: begin
                                        if (parse_val >= 1 && parse_val <= HARD_MAX_MATRICES) begin
                                            match_count_chk = 0;
                                            for (idx_chk = 0; idx_chk < HARD_MAX_MATRICES; idx_chk = idx_chk + 1) begin
                                                if (mem_rows[idx_chk] == gen_rows && mem_cols[idx_chk] == gen_cols)
                                                    match_count_chk = match_count_chk + 1;
                                            end
                                            
                                            if ((match_count_chk + parse_val) > max_per_dim) begin
                                                gen_state <= GEN_ERROR;
                                                input_error <= 1'b1;
                                            end else begin
                                                // 检查通过，开始生成
                                                gen_mat_count_target <= parse_val[3:0];
                                                gen_mat_idx <= 0;
                                                gen_elem_idx <= 0;
                                                
                                                find_and_allocate(gen_rows, gen_cols, gen_slot, tmp_error_flag, tmp_overwrite_flag);
                                                is_overwrite_mode <= tmp_overwrite_flag;
                                                
                                                if (!tmp_error_flag) 
                                                    gen_state <= GEN_WORKING;
                                                else begin
                                                    gen_state <= GEN_ERROR;
                                                    input_error <= 1'b1;
                                                end
                                            end
                                        end else begin
                                            gen_state <= GEN_ERROR;
                                            input_error <= 1'b1;
                                        end
                                        parse_val <= 0; parse_valid <= 0;
                                    end
                                    default: ;
                                endcase
                            end
                        end
                    end
                    
                    // ---------------------------------------------------------
                    // 4. Confirm 信号处理 
                    // ---------------------------------------------------------
                    if (confirm_signal) begin
                        // 只有在缓冲区有有效数据时才处理
                        if (parse_valid) begin
                            case (gen_state)
                                // 只有在输入数量阶段，Confirm 才是合法的提交信号
                                GEN_WAIT_COUNT: begin
                                    if (parse_val >= 1 && parse_val <= HARD_MAX_MATRICES) begin
                                        // 再次进行容量计算
                                        match_count_chk = 0;
                                        for (idx_chk = 0; idx_chk < HARD_MAX_MATRICES; idx_chk = idx_chk + 1) begin
                                            if (mem_rows[idx_chk] == gen_rows && mem_cols[idx_chk] == gen_cols)
                                                match_count_chk = match_count_chk + 1;
                                        end
                                        
                                        // 检查是否超标
                                        if ((match_count_chk + parse_val) > max_per_dim) begin
                                            gen_state <= GEN_ERROR;
                                            input_error <= 1'b1;
                                        end else begin
                                            // 检查通过，开始生成
                                            gen_mat_count_target <= parse_val[3:0];
                                            gen_mat_idx <= 0;
                                            gen_elem_idx <= 0;
                                            
                                            find_and_allocate(gen_rows, gen_cols, gen_slot, tmp_error_flag, tmp_overwrite_flag);
                                            is_overwrite_mode <= tmp_overwrite_flag;
                                            
                                            if (!tmp_error_flag) 
                                                gen_state <= GEN_WORKING;
                                            else begin
                                                gen_state <= GEN_ERROR;
                                                input_error <= 1'b1;
                                            end
                                        end
                                    end else begin
                                        // 数量格式错误
                                        gen_state <= GEN_ERROR;
                                        input_error <= 1'b1;
                                    end
                                end

                                GEN_IDLE: begin
                                    gen_state <= GEN_ERROR;
                                    input_error <= 1'b1;
                                end

                                GEN_WAIT_COL: begin
                                    gen_state <= GEN_ERROR;
                                    input_error <= 1'b1;
                                end
                                
                                default: ;
                            endcase
                            
                            // 清空缓冲区
                            parse_val <= 0;
                            parse_valid <= 0;
                        end
                    end
                    
                    // ---------------------------------------------------------
                    // 自动运行的状态 (Working & Done)
                    // ---------------------------------------------------------
                    case (gen_state)
                        GEN_WORKING: begin
                            if (gen_elem_idx < gen_rows * gen_cols) begin
                                mem_data[gen_slot][gen_elem_idx] <= random_digit;
                                gen_elem_idx <= gen_elem_idx + 1;
                            end else begin
                                mem_rows[gen_slot] <= gen_rows;
                                mem_cols[gen_slot] <= gen_cols;
                                
                                if (!is_overwrite_mode && mat_count < HARD_MAX_MATRICES) 
                                    mat_count <= mat_count + 1;
                                
                                if (gen_mat_idx + 1 < gen_mat_count_target) begin
                                    gen_mat_idx <= gen_mat_idx + 1;
                                    gen_elem_idx <= 0;
                                    gen_state <= GEN_ALLOC_NEXT; 
                                end else begin
                                    gen_state <= GEN_DONE;
                                end
                            end
                        end

                        GEN_ALLOC_NEXT: begin
                            find_and_allocate(gen_rows, gen_cols, gen_slot, tmp_error_flag, tmp_overwrite_flag);
                            is_overwrite_mode <= tmp_overwrite_flag;

                            if (!tmp_error_flag) 
                                gen_state <= GEN_WORKING; 
                            else begin
                                gen_state <= GEN_ERROR;
                                input_error <= 1'b1;
                            end
                        end
                        
                        GEN_DONE: begin
                            if (confirm_signal) begin
                                gen_state <= GEN_IDLE;
                                parse_val <= 0;
                            end
                        end
                    endcase
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