module convolution(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // 用户输入的卷积核 (3x3 = 9个元素，打平输入)
    // kernel[0]对应(0,0), kernel[1]对应(0,1)... kernel[8]对应(2,2)
    input wire [3:0] kernel_flat [0:8], 
    
    // 结果输出流 (串行输出，每次算完一个点吐出来)
    output reg [15:0] pixel_out,  // 卷积结果 (累加值可能会大，用16位安全)
    output reg pixel_valid,       // 结果有效信号
    output reg done               // 全部计算完成
);

    // =========================================================
    // 1. 内部变量与计数器
    // =========================================================
    
    // 输出图像坐标 (8行 10列)
    reg [3:0] out_row; // 0~7
    reg [3:0] out_col; // 0~9
    
    // 卷积核内部坐标 (3x3)
    reg [1:0] k_row;   // 0~2
    reg [1:0] k_col;   // 0~2
    
    // 累加器
    reg [15:0] accumulator;
    
    // ROM 接口信号
    reg [3:0] rom_addr_x;
    reg [3:0] rom_addr_y;
    wire [3:0] rom_data_out;

    // 实例化 ROM
    input_image_rom u_rom (
        .clk(clk),
        .x(rom_addr_x),
        .y(rom_addr_y),
        .data_out(rom_data_out)
    );

    // 状态机定义
    localparam IDLE = 3'd0;
    localparam SET_ADDR = 3'd1; // 设置读取地址
    localparam CALC = 3'd2;     // 读取数据并累加
    localparam OUTPUT = 3'd3;   // 输出一个像素的结果
    localparam FINISH = 3'd4;   // 全部结束

    reg [2:0] state;

    // =========================================================
    // 2. 核心状态机逻辑
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
            out_row <= 0; out_col <= 0;
            k_row <= 0; k_col <= 0;
            accumulator <= 0;
            pixel_valid <= 0;
            done <= 0;
            rom_addr_x <= 0; rom_addr_y <= 0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    pixel_valid <= 0;
                    if(start) begin
                        state <= SET_ADDR;
                        out_row <= 0; out_col <= 0; // 从结果图像(0,0)开始
                        k_row <= 0; k_col <= 0;     // 卷积核偏移归零
                        accumulator <= 0;
                    end
                end

                // --- 步骤1: 准备从ROM读数 ---
                SET_ADDR: begin
                    pixel_valid <= 0;
                    // 计算绝对坐标：图像行 = 输出行 + 核偏移行
                    rom_addr_x <= out_row + k_row;
                    rom_addr_y <= out_col + k_col;
                    
                    // ROM读取有延迟，下一拍数据才出来，所以跳到CALC状态
                    state <= CALC; 
                end

                // --- 步骤2: 拿到数据，乘法累加 ---
                CALC: begin
                    // 核心计算: 累加器 += 图像数据 * 卷积核对应系数
                    // kernel_flat 索引 = k_row * 3 + k_col
                    accumulator <= accumulator + (rom_data_out * kernel_flat[k_row*3 + k_col]);
                    
                    // 移动卷积核窗口
                    if(k_col == 2) begin
                        k_col <= 0;
                        if(k_row == 2) begin
                            // 3x3 窗口遍历完了，准备输出
                            state <= OUTPUT;
                        end else begin
                            k_row <= k_row + 1;
                            state <= SET_ADDR; // 读下一个点
                        end
                    end else begin
                        k_col <= k_col + 1;
                        state <= SET_ADDR; // 读下一个点
                    end
                end

                // --- 步骤3: 输出一个像素 ---
                OUTPUT: begin
                    pixel_out <= accumulator; // 输出累加结果
                    pixel_valid <= 1;         // 告诉外面结果有效
                    
                    // 重置卷积核计数器和累加器，为下一个像素做准备
                    k_row <= 0; k_col <= 0;
                    accumulator <= 0;
                    
                    // 移动输出图像坐标 (遍历 8x10)
                    if(out_col == 9) begin // 10列 (0-9)
                        out_col <= 0;
                        if(out_row == 7) begin // 8行 (0-7)
                            state <= FINISH; // 全图算完
                        end else begin
                            out_row <= out_row + 1;
                            state <= SET_ADDR; // 开始算下一行第一个点
                        end
                    end else begin
                        out_col <= out_col + 1;
                        state <= SET_ADDR; // 开始算这一行下一个点
                    end
                end

                // --- 步骤4: 完成 ---
                FINISH: begin
                    pixel_valid <= 0;
                    done <= 1;
                    if(!start) state <= IDLE; // 等待start复位
                end
            endcase
        end
    end

endmodule