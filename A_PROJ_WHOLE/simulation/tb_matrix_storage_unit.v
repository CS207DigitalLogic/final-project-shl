`timescale 1ns / 1ps

module tb_matrix_storage_unit;

    //==========================================================================
    // 1. 参数定义 (Parameters)
    //==========================================================================
    // 这里我们要覆盖 Design 中的默认参数，测试更大的容量
    parameter HARD_MAX_MATRICES = 5; 
    parameter PTR_WIDTH         = 3; // 3位宽可以表示 0-7

    //==========================================================================
    // 2. 信号声明 (Signals)
    //==========================================================================
    reg clk;
    reg rst_n;

    // 用户设置的矩阵数量限制
    reg [PTR_WIDTH:0] user_set_limit;

    // 控制信号
    reg [3:0] current_state;
    reg confirm_signal;

    // UART 模拟信号
    reg [7:0] uart_rx_data;
    reg       uart_rx_done;

    // 读端口 A
    reg [PTR_WIDTH-1:0] read_id_A;
    reg [4:0]           read_addr_A;
    wire [2:0]          dim_row_A;
    wire [2:0]          dim_col_A;
    wire [3:0]          read_data_A;

    // 读端口 B
    reg [PTR_WIDTH-1:0] read_id_B;
    reg [4:0]           read_addr_B;
    wire [2:0]          dim_row_B;
    wire [2:0]          dim_col_B;
    wire [3:0]          read_data_B;

    // 状态反馈
    wire                input_error;
    wire [PTR_WIDTH:0]  mat_count_out;

    // 循环变量
    integer row_idx;
    integer col_idx;

    //==========================================================================
    // 3. 待测模块实例化 (DUT Instantiation)
    //==========================================================================
    matrix_storage_unit #(
        .HARD_MAX_MATRICES(HARD_MAX_MATRICES),
        .PTR_WIDTH(PTR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .user_set_limit(user_set_limit), // 连接新增的限制信号
        .current_state(current_state),
        .confirm_signal(confirm_signal),
        .uart_rx_data(uart_rx_data),
        .uart_rx_done(uart_rx_done),
        
        // Port A
        .read_id_A(read_id_A),
        .dim_row_A(dim_row_A),
        .dim_col_A(dim_col_A),
        .read_addr_A(read_addr_A),
        .read_data_A(read_data_A),
        
        // Port B
        .read_id_B(read_id_B),
        .dim_row_B(dim_row_B),
        .dim_col_B(dim_col_B),
        .read_addr_B(read_addr_B),
        .read_data_B(read_data_B),
        
        // Feedback
        .input_error(input_error),
        .mat_count_out(mat_count_out)
    );

    //==========================================================================
    // 4. 时钟生成 (100MHz)
    //==========================================================================
    initial clk = 1'b0;
    always #5 clk = ~clk;

    //==========================================================================
    // 5. 辅助任务：模拟 UART 发送 (Task)
    //==========================================================================
    task send_uart_byte(input [7:0] value);
    begin
        @(negedge clk);
        uart_rx_data <= value;
        uart_rx_done <= 1'b1;
        @(negedge clk);
        uart_rx_done <= 1'b0; // 脉冲结束
        uart_rx_data <= 8'd0;
        @(negedge clk);       // 额外等待一个周期
    end
    endtask

    //==========================================================================
    // 6. 测试主流程 (Main Test Stimulus)
    //==========================================================================
    initial begin
        // --- 初始化 ---
        rst_n = 1'b0;
        current_state = 4'd0; // S_MENU
        confirm_signal = 1'b0;
        uart_rx_data = 8'd0;
        uart_rx_done = 1'b0;
        read_id_A = 0; read_addr_A = 0;
        read_id_B = 0; read_addr_B = 0;
        
        // **设置初始矩阵数量限制为 4**
        user_set_limit = 4;

        // --- 释放复位 ---
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        $display("\n=== Simulation Started ===");

        // =========================================================
        // 测试用例 1: 正常录入第一个矩阵 (S_INPUTER)
        // 目标：存储一个 3x2 的矩阵
        // =========================================================
        $display("\n[TEST 1] Input Matrix 1 (3x2)...");
        current_state = 4'd1; // 切换到 S_INPUTER

        // 1. 发送行数 (3)
        send_uart_byte(8'd3);
        // 2. 发送列数 (2)
        send_uart_byte(8'd2);
        
        // **关键等待**: Design中收到列数后会进入 RX_CLEAR 清空内存 (25个周期)
        // 必须等待清空完成，否则数据发进去会被吞掉或清零
        $display("waiting for memory clear...");
        repeat (40) @(negedge clk);

        // 3. 发送数据 (1, 2, 3, 4, 5, 6)
        send_uart_byte(8'd1);
        send_uart_byte(8'd2);
        send_uart_byte(8'd3);
        send_uart_byte(8'd4);
        send_uart_byte(8'd5);
        send_uart_byte(8'd6);

        // 等待状态机自动跳转到 CONFIRM 并处理
        repeat (20) @(negedge clk);

        // --- 验证点 1: 检查计数和维度 ---
        if (mat_count_out == 1 && dim_row_A == 3 && dim_col_A == 2)
            $display("[PASS] Matrix 1 stored. Count: %0d (Exp: 1)", mat_count_out);
        else
            $display("[FAIL] Matrix 1 error. Count: %0d, Dim: %0dx%0d", mat_count_out, dim_row_A, dim_col_A);

        // =========================================================
        // 测试用例 2: 验证数据读取 (Port A Reading)
        // =========================================================
        $display("\n[TEST 2] Verifying Data Integrity...");
        read_id_A = 0; // 读取第0号矩阵
        
        // 遍历读取
        for (row_idx = 0; row_idx < 3; row_idx = row_idx + 1) begin
            for (col_idx = 0; col_idx < 2; col_idx = col_idx + 1) begin
                read_addr_A = row_idx * 5 + col_idx;
                @(negedge clk); // 等待数据稳定
                $display("  Read [Row %0d, Col %0d] = %0d", row_idx, col_idx, read_data_A);
            end
        end

        // =========================================================
        // 测试用例 3: 动态修改限制 (User Limit Logic)
        // =========================================================
        $display("\n[TEST 3] Testing User Limit Logic...");
        
        // 当前 mat_count = 1。
        // 我们将 user_set_limit 修改为 1。
        // 再尝试输入一个矩阵，看看是否会增加计数，或者覆盖旧的。
        user_set_limit = 1;
        $display("User set limit changed to: 1");

        // 输入一个新的 2x2 矩阵
        send_uart_byte(8'd2); // Rows
        send_uart_byte(8'd2); // Cols
        repeat (40) @(negedge clk); // Wait Clear

        send_uart_byte(8'd9); // Data: 9
        send_uart_byte(8'd9); // Data: 9
        send_uart_byte(8'd9); // Data: 9
        send_uart_byte(8'd9); // Data: 9
        
        repeat (20) @(negedge clk);

        // --- 验证点 3 ---
        // 预期：
        // 1. mat_count 应该仍然是 1 (因为 limit 是 1，之前已经是 1 了，不会变成 2)。
        // 2. 根据 find_slot 逻辑，如果找不到空位且已满，它可能会覆盖当前 ID (curr_mat_id) 或者 slot 0。
        //    (这取决于你的 fallback 逻辑)。
        $display("Current Mat Count: %0d (Expected: 1, because limit is 1)", mat_count_out);
        
        // 读取 Slot 0 看看是否变成了 2x2 的矩阵 (如果是覆盖策略)
        read_id_A = 0;
        @(negedge clk);
        if (dim_row_A == 2 && dim_col_A == 2)
            $display("[PASS] Slot 0 updated with new 2x2 matrix (Overwrite behavior).");
        else
            $display("[INFO] Slot 0 dimension: %0dx%0d (Check specific replacement logic).", dim_row_A, dim_col_A);

        // =========================================================
        // 结束
        // =========================================================
        repeat (10) @(negedge clk);
        $display("\n=== Simulation Finished ===");
        $finish;
    end

endmodule