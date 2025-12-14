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
        
        // 设置初始限制
        user_set_limit = 4;

        // --- 释放复位 ---
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        $display("\n=== Simulation Started ===");

        // =========================================================
        // 测试用例 1: 模拟发送字符串 "2 3 1 2 3 4 5 6"
        // 目标：存储一个 2x3 的矩阵
        // =========================================================
        $display("\n[TEST 1] Sending String: '2 3 1 2 3 4 5 6' ...");
        current_state = 4'd1; // 切换到 S_INPUTER

        // 1. 发送行数 '2' (ASCII)
        send_uart_byte("2");  
        send_uart_byte(" ");  // 模拟空格 (Design会忽略它)

        // 2. 发送列数 '3' (ASCII)
        send_uart_byte("3");
        
        // *** 关键等待 ***
        // 收到列数后 Design 会进入 RX_CLEAR (需要25+时钟周期)
        // 仿真中必须等待，否则紧接着发的数据会被 ignore
        $display("   -> Waiting for memory clear...");
        repeat (40) @(negedge clk); 

        // 3. 发送数据 "1 2 3 4 5 6" (ASCII + 空格)
        // 注意：Design 遇到空格会跳过，遇到数字会处理
        
        send_uart_byte(" "); // 列数后面可能紧跟空格
        send_uart_byte("1"); send_uart_byte(" ");
        send_uart_byte("2"); send_uart_byte(" ");
        send_uart_byte("3"); send_uart_byte(" ");
        send_uart_byte("4"); send_uart_byte(" ");
        send_uart_byte("5"); send_uart_byte(" ");
        send_uart_byte("6"); 

        // 等待处理完成
        repeat (20) @(negedge clk);

        // --- 验证点 1 ---
        // 检查是否存入：Count=1, 维度 2x3
        if (mat_count_out == 1 && dim_row_A == 2 && dim_col_A == 3)
            $display("[PASS] Matrix 1 stored. Count: %0d, Dim: %0dx%0d", mat_count_out, dim_row_A, dim_col_A);
        else
            $display("[FAIL] Matrix 1 error. Count: %0d, Dim: %0dx%0d", mat_count_out, dim_row_A, dim_col_A);

        // =========================================================
        // 测试用例 2: 验证数据读取
        // =========================================================
        $display("\n[TEST 2] Verifying Data Integrity...");
        read_id_A = 0; 
        
        // 2行3列
        for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
            for (col_idx = 0; col_idx < 3; col_idx = col_idx + 1) begin
                read_addr_A = row_idx * 5 + col_idx;
                @(negedge clk);
                $display("  Read [Row %0d, Col %0d] = %0d", row_idx, col_idx, read_data_A);
            end
        end

        // =========================================================
        // 测试用例 3: 动态限制 + 覆盖测试 (同样使用 ASCII 输入)
        // =========================================================
        $display("\n[TEST 3] Testing User Limit Logic (ASCII Input)...");
        user_set_limit = 1;
        $display("User set limit changed to: 1");

        // 发送 "2 2 9 9 9 9"
        send_uart_byte("2"); // Rows
        send_uart_byte(" ");
        send_uart_byte("2"); // Cols
        
        repeat (40) @(negedge clk); // Wait Clear

        send_uart_byte(" ");
        send_uart_byte("9"); send_uart_byte(" ");
        send_uart_byte("9"); send_uart_byte(" ");
        send_uart_byte("9"); send_uart_byte(" ");
        send_uart_byte("9"); 
        
        repeat (20) @(negedge clk);

        // --- 验证点 3 ---
        $display("Current Mat Count: %0d (Expected: 1)", mat_count_out);
        
        read_id_A = 0;
        @(negedge clk);
        // 检查是否变成了 2x2
        if (dim_row_A == 2 && dim_col_A == 2)
            $display("[PASS] Slot 0 updated with new 2x2 matrix.");
        else
            $display("[INFO] Slot 0 dimension: %0dx%0d", dim_row_A, dim_col_A);

        // =========================================================
        repeat (10) @(negedge clk);
        $display("\n=== Simulation Finished ===");
        $finish;
    end

endmodule