//==============================================================================
// convolution_controller.v
// 卷积运算控制器
// 功能：
// 1. 通过UART接收3x3卷积核数据（9个字节）
// 2. 启动卷积计算并统计时钟周期数
// 3. 通过UART串口输出8x10结果矩阵
// 4. 输出时钟周期数到数码管显示
//==============================================================================
module convolution_controller(
    input wire clk,
    input wire rst_n,
    
    // 控制接口
    input wire start_input,      // 开始接收卷积核
    input wire confirm,          // 确认键，开始计算
    
    // UART RX 接口
    input wire [7:0] uart_rx_data,
    input wire uart_rx_done,
    
    // UART TX 接口
    output reg [7:0] tx_data,
    output reg tx_start,
    input wire tx_busy,
    
    // 卷积核输出到convolution模块（展开为36位）
    output reg [35:0] kernel_flat_packed,  // 9个4位数打包
    output reg conv_start,
    input wire [15:0] conv_pixel_out,
    input wire conv_pixel_valid,
    input wire conv_done,
    
    // 状态输出
    output reg busy,
    output reg done,
    output reg [15:0] cycle_count  // 时钟周期数
);

    //==========================================================================
    // 状态机定义
    //==========================================================================
    localparam S_IDLE           = 4'd0;  // 空闲
    localparam S_INPUT_KERNEL   = 4'd1;  // 接收卷积核
    localparam S_WAIT_CONFIRM   = 4'd2;  // 等待确认
    localparam S_START_CONV     = 4'd3;  // 启动卷积
    localparam S_COUNTING       = 4'd4;  // 计算中，统计周期
    localparam S_COLLECT_RESULT = 4'd5;  // 收集结果
    localparam S_SEND_HEADER    = 4'd6;  // 发送输出头
    localparam S_SEND_RESULT    = 4'd7;  // 发送结果矩阵
    localparam S_SEND_CYCLES    = 4'd8;  // 发送周期数
    localparam S_DONE           = 4'd9;  // 完成
    
    reg [3:0] state, state_next;
    
    //==========================================================================
    // 卷积核输入缓存
    //==========================================================================
    reg [3:0] kernel_input_count;  // 已接收的字节数 (0-8)
    reg [7:0] rx_data_latch;
    reg [3:0] kernel_flat [0:8];   // 内部unpacked array
    
    // 将unpacked array打包到输出端口
    always @(*) begin
        kernel_flat_packed = {kernel_flat[8], kernel_flat[7], kernel_flat[6],
                             kernel_flat[5], kernel_flat[4], kernel_flat[3],
                             kernel_flat[2], kernel_flat[1], kernel_flat[0]};
    end
    
    //==========================================================================
    // 结果缓存（8x10 = 80个像素）
    //==========================================================================
    reg [15:0] result_buffer [0:79];
    reg [6:0] result_count;  // 已收集的像素数 (0-79)
    
    //==========================================================================
    // UART发送控制
    //==========================================================================
    reg [6:0] send_index;    // 发送索引
    reg [2:0] send_stage;    // 发送阶段（多字节数据）
    reg [3:0] tx_delay;      // 发送延迟计数器
    
    //==========================================================================
    // 时钟周期计数器
    //==========================================================================
    reg [15:0] cycle_counter;
    reg counting_active;
    
    //==========================================================================
    // 状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= state_next;
        end
    end
    
    always @(*) begin
        state_next = state;
        case (state)
            S_IDLE: begin
                if (start_input) state_next = S_INPUT_KERNEL;
            end
            
            S_INPUT_KERNEL: begin
                if (kernel_input_count == 9) state_next = S_WAIT_CONFIRM;
            end
            
            S_WAIT_CONFIRM: begin
                if (confirm) state_next = S_START_CONV;
            end
            
            S_START_CONV: begin
                state_next = S_COUNTING;
            end
            
            S_COUNTING: begin
                if (conv_done) state_next = S_COLLECT_RESULT;
            end
            
            S_COLLECT_RESULT: begin
                if (result_count == 80) state_next = S_SEND_HEADER;
            end
            
            S_SEND_HEADER: begin
                if (!tx_busy && tx_delay == 0) state_next = S_SEND_RESULT;
            end
            
            S_SEND_RESULT: begin
                if (send_index == 80 && !tx_busy && tx_delay == 0) 
                    state_next = S_SEND_CYCLES;
            end
            
            S_SEND_CYCLES: begin
                if (send_stage == 3 && !tx_busy && tx_delay == 0) 
                    state_next = S_DONE;
            end
            
            S_DONE: begin
                if (!confirm) state_next = S_IDLE;
            end
        endcase
    end
    
    //==========================================================================
    // 卷积核输入逻辑
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kernel_input_count <= 0;
            for (integer i = 0; i < 9; i = i + 1) begin
                kernel_flat[i] <= 4'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    if (start_input) begin
                        kernel_input_count <= 0;
                    end
                end
                
                S_INPUT_KERNEL: begin
                    if (uart_rx_done && kernel_input_count < 9) begin
                        // 接收一个字节，转换为4位（取低4位）
                        kernel_flat[kernel_input_count] <= uart_rx_data[3:0];
                        kernel_input_count <= kernel_input_count + 1;
                    end
                end
            endcase
        end
    end
    
    //==========================================================================
    // 卷积启动和时钟计数
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            conv_start <= 1'b0;
            cycle_counter <= 0;
            cycle_count <= 0;
            counting_active <= 1'b0;
        end else begin
            conv_start <= 1'b0;
            
            case (state)
                S_START_CONV: begin
                    conv_start <= 1'b1;
                    cycle_counter <= 0;
                    counting_active <= 1'b1;
                end
                
                S_COUNTING: begin
                    if (counting_active) begin
                        cycle_counter <= cycle_counter + 1;
                    end
                    if (conv_done) begin
                        counting_active <= 1'b0;
                        cycle_count <= cycle_counter;
                    end
                end
            endcase
        end
    end
    
    //==========================================================================
    // 结果收集逻辑
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_count <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    result_count <= 0;
                end
                
                S_COUNTING: begin
                    // 实时收集卷积输出
                    if (conv_pixel_valid) begin
                        result_buffer[result_count] <= conv_pixel_out;
                        result_count <= result_count + 1;
                    end
                end
                
                S_COLLECT_RESULT: begin
                    // 继续收集剩余结果
                    if (conv_pixel_valid && result_count < 80) begin
                        result_buffer[result_count] <= conv_pixel_out;
                        result_count <= result_count + 1;
                    end
                end
            endcase
        end
    end
    
    //==========================================================================
    // UART发送逻辑
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data <= 8'd0;
            tx_start <= 1'b0;
            send_index <= 0;
            send_stage <= 0;
            tx_delay <= 0;
        end else begin
            tx_start <= 1'b0;
            
            if (tx_delay > 0) begin
                tx_delay <= tx_delay - 1;
            end
            
            case (state)
                S_SEND_HEADER: begin
                    if (!tx_busy && tx_delay == 0) begin
                        tx_data <= 8'h0A;  // 换行
                        tx_start <= 1'b1;
                        tx_delay <= 4'd5;
                        send_index <= 0;
                        send_stage <= 0;
                    end
                end
                
                S_SEND_RESULT: begin
                    if (!tx_busy && tx_delay == 0 && send_index < 80) begin
                        // 发送每个结果的ASCII表示
                        // 格式: 3位十进制数 + 空格
                        case (send_stage)
                            0: begin  // 百位
                                tx_data <= 8'h30 + (result_buffer[send_index] / 100);
                                tx_start <= 1'b1;
                                tx_delay <= 4'd5;
                                send_stage <= 1;
                            end
                            1: begin  // 十位
                                tx_data <= 8'h30 + ((result_buffer[send_index] / 10) % 10);
                                tx_start <= 1'b1;
                                tx_delay <= 4'd5;
                                send_stage <= 2;
                            end
                            2: begin  // 个位
                                tx_data <= 8'h30 + (result_buffer[send_index] % 10);
                                tx_start <= 1'b1;
                                tx_delay <= 4'd5;
                                send_stage <= 3;
                            end
                            3: begin  // 空格或换行
                                if ((send_index + 1) % 10 == 0)
                                    tx_data <= 8'h0A;  // 每10个换行
                                else
                                    tx_data <= 8'h20;  // 空格
                                tx_start <= 1'b1;
                                tx_delay <= 4'd5;
                                send_stage <= 0;
                                send_index <= send_index + 1;
                            end
                        endcase
                    end
                end
                
                S_SEND_CYCLES: begin
                    if (!tx_busy && tx_delay == 0) begin
                        case (send_stage)
                            0: begin  // 发送 "Cycles: "
                                tx_data <= 8'h43;  // 'C'
                                tx_start <= 1'b1;
                                tx_delay <= 4'd5;
                                send_stage <= 1;
                            end
                            1: begin
                                tx_data <= 8'h3A;  // ':'
                                tx_start <= 1'b1;
                                tx_delay <= 4'd5;
                                send_stage <= 2;
                            end
                            2: begin
                                tx_data <= 8'h20;  // ' '
                                tx_start <= 1'b1;
                                tx_delay <= 4'd5;
                                send_stage <= 3;
                            end
                            default: begin
                                send_stage <= 3;
                            end
                        endcase
                    end
                end
            endcase
        end
    end
    
    //==========================================================================
    // 状态输出
    //==========================================================================
    always @(*) begin
        busy = (state != S_IDLE) && (state != S_DONE);
        done = (state == S_DONE);
    end

endmodule
