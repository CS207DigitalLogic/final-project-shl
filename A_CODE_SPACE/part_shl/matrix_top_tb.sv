`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 测试模块: Matrix_System_Top Testbench
// 功能: 测试矩阵计算系统的各种运算功能
// 包括: 转置、加法、标量乘法、矩阵乘法、卷积
//////////////////////////////////////////////////////////////////////////////////

module matrix_top_tb();

    // ============================================================
    // 时钟和复位信号
    // ============================================================
    reg clk;
    reg rst_n;
    
    // ============================================================
    // DUT 输入信号
    // ============================================================
    reg [2:0] sw_op_type;
    reg [1:0] sw_id_A;
    reg [1:0] sw_id_B;
    reg [3:0] sw_scalar;
    reg btn_start;
    reg btn_confirm;
    reg [3:0] sw_countdown;
    reg sw_manual_mode;
    
    // UART 接口
    reg uart_rx_valid;
    reg [7:0] uart_rx_data;
    wire [7:0] uart_tx_data;
    wire uart_tx_start;
    reg uart_tx_busy;
    
    // ============================================================
    // DUT 输出信号
    // ============================================================
    wire led_error;
    wire led_idle;
    wire led_busy;
    wire led_done;
    wire [6:0] seg_display;
    wire [3:0] seg_select;
    
    // ============================================================
    // DUT 实例化
    // ============================================================
    Matrix_System_Top u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .sw_op_type(sw_op_type),
        .sw_id_A(sw_id_A),
        .sw_id_B(sw_id_B),
        .sw_scalar(sw_scalar),
        .btn_start(btn_start),
        .btn_confirm(btn_confirm),
        .sw_countdown(sw_countdown),
        .sw_manual_mode(sw_manual_mode),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data(uart_rx_data),
        .uart_tx_busy(uart_tx_busy),
        .uart_tx_data(uart_tx_data),
        .uart_tx_start(uart_tx_start),
        .led_error(led_error),
        .led_idle(led_idle),
        .led_busy(led_busy),
        .led_done(led_done),
        .seg_display(seg_display),
        .seg_select(seg_select)
    );

    // ============================================================
    // 时钟生成 (100MHz)
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns 周期 = 100MHz
    end
    
    // ============================================================
    // 辅助任务: UART 发送单个字节
    // ============================================================
    task uart_send_byte(input [7:0] data);
        begin
            @(posedge clk);
            uart_rx_data = data;
            uart_rx_valid = 1;
            @(posedge clk);
            uart_rx_valid = 0;
            repeat(5) @(posedge clk); // 等待处理
        end
    endtask
    
    // ============================================================
    // 辅助任务: 通过 UART 录入矩阵
    // 参数: id=矩阵ID, rows=行数, cols=列数, data=数据数组
    // ============================================================
    task uart_load_matrix(
        input [1:0] id,
        input [2:0] rows,
        input [2:0] cols,
        input [3:0] data [0:24]
    );
        integer r, c;
        begin
            $display("[%0t] Loading matrix %0d (%0dx%0d) via UART...", $time, id, rows, cols);
            
            // 发送帧头
            uart_send_byte(8'hAA);
            // 发送 ID
            uart_send_byte({6'b0, id});
            // 发送行数
            uart_send_byte({5'b0, rows});
            // 发送列数
            uart_send_byte({5'b0, cols});
            
            // 发送数据
            for (r = 0; r < rows; r = r + 1) begin
                for (c = 0; c < cols; c = c + 1) begin
                    uart_send_byte({4'b0, data[r * 5 + c]});
                end
            end
            
            $display("[%0t] Matrix %0d loaded.", $time, id);
        end
    endtask
    
    // ============================================================
    // 辅助任务: 按下启动按钮
    // ============================================================
    task press_start();
        begin
            @(posedge clk);
            btn_start = 1;
            @(posedge clk);
            btn_start = 0;
            $display("[%0t] Start button pressed.", $time);
        end
    endtask
    
    // ============================================================
    // 辅助任务: 等待计算完成
    // ============================================================
    task wait_for_done(input integer timeout_cycles);
        integer cnt;
        begin
            cnt = 0;
            while (!led_done && cnt < timeout_cycles) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            if (cnt >= timeout_cycles) begin
                $display("[%0t] ERROR: Timeout waiting for done!", $time);
            end else begin
                $display("[%0t] Calculation done after %0d cycles.", $time, cnt);
            end
        end
    endtask
    
    // ============================================================
    // 测试矩阵数据
    // ============================================================
    reg [3:0] matrix_A [0:24];
    reg [3:0] matrix_B [0:24];
    
    // ============================================================
    // 主测试流程
    // ============================================================
    initial begin
        // 初始化所有信号
        rst_n = 0;
        sw_op_type = 3'b000;
        sw_id_A = 2'b00;
        sw_id_B = 2'b01;
        sw_scalar = 4'd2;
        btn_start = 0;
        btn_confirm = 0;
        sw_countdown = 4'd10;
        sw_manual_mode = 0;
        uart_rx_valid = 0;
        uart_rx_data = 8'h00;
        uart_tx_busy = 0;
        
        // 初始化测试矩阵 (全0)
        for (integer i = 0; i < 25; i = i + 1) begin
            matrix_A[i] = 4'd0;
            matrix_B[i] = 4'd0;
        end
        
        // 复位
        $display("\n========================================");
        $display("=== Matrix System Top Testbench ===");
        $display("========================================\n");
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        $display("[%0t] Reset released.\n", $time);
        
        // ========================================
        // 测试 1: 矩阵转置 (2x3 -> 3x2)
        // ========================================
        $display("========================================");
        $display("TEST 1: Matrix Transpose (2x3 -> 3x2)");
        $display("========================================");
        
        // 矩阵 A (2x3):
        // | 1  2  3 |
        // | 4  5  6 |
        matrix_A[0] = 4'd1; matrix_A[1] = 4'd2; matrix_A[2] = 4'd3;
        matrix_A[5] = 4'd4; matrix_A[6] = 4'd5; matrix_A[7] = 4'd6;
        
        uart_load_matrix(2'd0, 3'd2, 3'd3, matrix_A);
        
        // 配置运算
        sw_op_type = 3'b000; // 转置
        sw_id_A = 2'b00;
        
        repeat(10) @(posedge clk);
        press_start();
        wait_for_done(1000);
        
        // 期望结果 (3x2):
        // | 1  4 |
        // | 2  5 |
        // | 3  6 |
        $display("Expected result: 3x2 matrix");
        $display("| 1  4 |");
        $display("| 2  5 |");
        $display("| 3  6 |");
        
        repeat(100) @(posedge clk);
        
        // ========================================
        // 测试 2: 矩阵加法 (2x2 + 2x2)
        // ========================================
        $display("\n========================================");
        $display("TEST 2: Matrix Addition (2x2 + 2x2)");
        $display("========================================");
        
        // 重置矩阵数据
        for (integer i = 0; i < 25; i = i + 1) begin
            matrix_A[i] = 4'd0;
            matrix_B[i] = 4'd0;
        end
        
        // 矩阵 A (2x2):
        // | 1  2 |
        // | 3  4 |
        matrix_A[0] = 4'd1; matrix_A[1] = 4'd2;
        matrix_A[5] = 4'd3; matrix_A[6] = 4'd4;
        
        // 矩阵 B (2x2):
        // | 5  6 |
        // | 7  8 |
        matrix_B[0] = 4'd5; matrix_B[1] = 4'd6;
        matrix_B[5] = 4'd7; matrix_B[6] = 4'd8;
        
        uart_load_matrix(2'd0, 3'd2, 3'd2, matrix_A);
        uart_load_matrix(2'd1, 3'd2, 3'd2, matrix_B);
        
        // 配置运算
        sw_op_type = 3'b001; // 加法
        sw_id_A = 2'b00;
        sw_id_B = 2'b01;
        
        repeat(10) @(posedge clk);
        press_start();
        wait_for_done(1000);
        
        // 期望结果 (2x2):
        // | 6   8  |
        // | 10  12 |
        $display("Expected result: 2x2 matrix");
        $display("| 6   8  |");
        $display("| 10  12 |");
        
        repeat(100) @(posedge clk);
        
        // ========================================
        // 测试 3: 标量乘法 (2x2 * 3)
        // ========================================
        $display("\n========================================");
        $display("TEST 3: Scalar Multiplication (2x2 * 3)");
        $display("========================================");
        
        // 矩阵 A (2x2) 已经在内存中:
        // | 1  2 |
        // | 3  4 |
        
        // 配置运算
        sw_op_type = 3'b010; // 标量乘
        sw_id_A = 2'b00;
        sw_scalar = 4'd3;
        
        repeat(10) @(posedge clk);
        press_start();
        wait_for_done(1000);
        
        // 期望结果 (2x2):
        // | 3   6  |
        // | 9   12 |
        $display("Expected result: 2x2 matrix");
        $display("| 3   6  |");
        $display("| 9   12 |");
        
        repeat(100) @(posedge clk);
        
        // ========================================
        // 测试 4: 矩阵乘法 (2x3 * 3x2)
        // ========================================
        $display("\n========================================");
        $display("TEST 4: Matrix Multiplication (2x3 * 3x2)");
        $display("========================================");
        
        // 重置矩阵数据
        for (integer i = 0; i < 25; i = i + 1) begin
            matrix_A[i] = 4'd0;
            matrix_B[i] = 4'd0;
        end
        
        // 矩阵 A (2x3):
        // | 1  2  3 |
        // | 4  5  6 |
        matrix_A[0] = 4'd1; matrix_A[1] = 4'd2; matrix_A[2] = 4'd3;
        matrix_A[5] = 4'd4; matrix_A[6] = 4'd5; matrix_A[7] = 4'd6;
        
        // 矩阵 B (3x2):
        // | 1  2 |
        // | 3  4 |
        // | 5  6 |
        matrix_B[0]  = 4'd1; matrix_B[1]  = 4'd2;
        matrix_B[5]  = 4'd3; matrix_B[6]  = 4'd4;
        matrix_B[10] = 4'd5; matrix_B[11] = 4'd6;
        
        uart_load_matrix(2'd0, 3'd2, 3'd3, matrix_A);
        uart_load_matrix(2'd1, 3'd3, 3'd2, matrix_B);
        
        // 配置运算
        sw_op_type = 3'b011; // 矩阵乘法
        sw_id_A = 2'b00;
        sw_id_B = 2'b01;
        
        repeat(10) @(posedge clk);
        press_start();
        wait_for_done(1000);
        
        // 期望结果 (2x2):
        // A * B = | 1*1+2*3+3*5   1*2+2*4+3*6 |  = | 22  28 |
        //         | 4*1+5*3+6*5   4*2+5*4+6*6 |    | 49  64 |
        $display("Expected result: 2x2 matrix");
        $display("| 22  28 |");
        $display("| 49  64 |");
        
        repeat(100) @(posedge clk);
        
        // ========================================
        // 测试 5: 维度不匹配错误检测
        // ========================================
        $display("\n========================================");
        $display("TEST 5: Dimension Mismatch Detection");
        $display("========================================");
        
        // 尝试用不同维度的矩阵做加法
        // 重置矩阵数据
        for (integer i = 0; i < 25; i = i + 1) begin
            matrix_A[i] = 4'd0;
            matrix_B[i] = 4'd0;
        end
        
        // 矩阵 A (2x2)
        matrix_A[0] = 4'd1; matrix_A[1] = 4'd2;
        matrix_A[5] = 4'd3; matrix_A[6] = 4'd4;
        
        // 矩阵 B (2x3) - 维度不匹配
        matrix_B[0] = 4'd1; matrix_B[1] = 4'd2; matrix_B[2] = 4'd3;
        matrix_B[5] = 4'd4; matrix_B[6] = 4'd5; matrix_B[7] = 4'd6;
        
        uart_load_matrix(2'd0, 3'd2, 3'd2, matrix_A);
        uart_load_matrix(2'd1, 3'd2, 3'd3, matrix_B);
        
        // 配置加法运算 (应该失败)
        sw_op_type = 3'b001; // 加法
        sw_id_A = 2'b00;
        sw_id_B = 2'b01;
        
        repeat(10) @(posedge clk);
        press_start();
        repeat(20) @(posedge clk);
        
        if (led_error) begin
            $display("[%0t] PASS: Dimension mismatch correctly detected (led_error = 1)", $time);
        end else begin
            $display("[%0t] FAIL: Dimension mismatch NOT detected!", $time);
        end
        
        repeat(100) @(posedge clk);
        
        // ========================================
        // 测试 6: 卷积运算 (3x3 kernel on 4x4 image)
        // ========================================
        $display("\n========================================");
        $display("TEST 6: Convolution (3x3 kernel on 4x4 image)");
        $display("========================================");
        
        // 重置矩阵数据
        for (integer i = 0; i < 25; i = i + 1) begin
            matrix_A[i] = 4'd0;
            matrix_B[i] = 4'd0;
        end
        
        // 矩阵 A 作为卷积核 (3x3):
        // | 1  0  -1 | (使用无符号，这里用 | 1  0  1 |)
        // | 1  0  -1 |                      | 1  0  1 |
        // | 1  0  -1 |                      | 1  0  1 |
        matrix_A[0]  = 4'd1; matrix_A[1]  = 4'd0; matrix_A[2]  = 4'd1;
        matrix_A[5]  = 4'd1; matrix_A[6]  = 4'd0; matrix_A[7]  = 4'd1;
        matrix_A[10] = 4'd1; matrix_A[11] = 4'd0; matrix_A[12] = 4'd1;
        
        // 矩阵 B 作为图像 (4x4):
        // | 1  2  3  4 |
        // | 5  6  7  8 |
        // | 9  10 11 12|
        // | 13 14 15 0 |
        matrix_B[0]  = 4'd1;  matrix_B[1]  = 4'd2;  matrix_B[2]  = 4'd3;  matrix_B[3]  = 4'd4;
        matrix_B[5]  = 4'd5;  matrix_B[6]  = 4'd6;  matrix_B[7]  = 4'd7;  matrix_B[8]  = 4'd8;
        matrix_B[10] = 4'd9;  matrix_B[11] = 4'd10; matrix_B[12] = 4'd11; matrix_B[13] = 4'd12;
        matrix_B[15] = 4'd13; matrix_B[16] = 4'd14; matrix_B[17] = 4'd15; matrix_B[18] = 4'd0;
        
        uart_load_matrix(2'd0, 3'd3, 3'd3, matrix_A); // 卷积核
        uart_load_matrix(2'd1, 3'd4, 3'd4, matrix_B); // 图像
        
        // 配置运算
        sw_op_type = 3'b100; // 卷积
        sw_id_A = 2'b00; // 卷积核
        sw_id_B = 2'b01; // 图像
        
        repeat(10) @(posedge clk);
        press_start();
        wait_for_done(2000);
        
        // 输出结果应该是 2x2 矩阵
        $display("Expected result: 2x2 matrix (output = image_size - kernel_size + 1)");
        
        repeat(100) @(posedge clk);
        
        // ========================================
        // 测试完成
        // ========================================
        $display("\n========================================");
        $display("=== All Tests Completed ===");
        $display("========================================\n");
        
        $finish;
    end
    
    // ============================================================
    // 超时保护
    // ============================================================
    initial begin
        #1000000; // 1ms 超时
        $display("\n[TIMEOUT] Simulation timeout!");
        $finish;
    end
    
    // ============================================================
    // 波形记录 (可选)
    // ============================================================
    initial begin
        $dumpfile("matrix_top_tb.vcd");
        $dumpvars(0, matrix_top_tb);
    end

endmodule
