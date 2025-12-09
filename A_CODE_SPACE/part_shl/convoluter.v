// ============================================================
// convoluter.v
// 功能：执行 2D 卷积运算 (Bonus)
// 支持：任意尺寸图像 + 任意尺寸卷积核 (在限制范围内)
// 计算：result[i][j] = sum(image[i+ki][j+kj] * kernel[ki][kj])
// ============================================================
module convoluter(
    input wire clk,
    input wire rst_n,
    input wire start,               // 开始信号
    
    // 图像输入 (最大支持 5x5)
    input wire [3:0] image_flat [0:24],  // 扁平化图像数据 (4位宽)
    input wire [2:0] image_row,          // 图像行数
    input wire [2:0] image_col,          // 图像列数
    
    // 卷积核输入 (最大支持 3x3)
    input wire [3:0] kernel_flat [0:8],  // 扁平化卷积核 (4位宽)
    input wire [1:0] kernel_row,         // 卷积核行数 (1-3)
    input wire [1:0] kernel_col,         // 卷积核列数 (1-3)
    
    // 结果输出
    output reg done,                     // 完成信号
    output reg [15:0] result_flat [0:24],// 扁平化结果 (16位防溢出)
    output reg [2:0] result_row,         // 结果行数
    output reg [2:0] result_col          // 结果列数
);

    // ============================================================
    // 状态机定义
    // ============================================================
    localparam S_IDLE    = 3'd0;  // 空闲状态
    localparam S_INIT    = 3'd1;  // 初始化
    localparam S_CALC    = 3'd2;  // 计算卷积
    localparam S_ACC     = 3'd3;  // 累加
    localparam S_STORE   = 3'd4;  // 存储结果
    localparam S_DONE    = 3'd5;  // 完成

    reg [2:0] state;

    // ============================================================
    // 计数器与寄存器
    // ============================================================
    // 输出图像坐标
    reg [2:0] out_r, out_c;
    
    // 卷积核内部坐标
    reg [1:0] k_r, k_c;
    
    // 累加器
    reg [15:0] accumulator;
    
    // 临时变量：图像和卷积核索引
    reg [4:0] img_idx;   // image_flat 索引 (0-24)
    reg [3:0] ker_idx;   // kernel_flat 索引 (0-8)
    
    // 乘法结果
    reg [7:0] mul_result;

    // ============================================================
    // 状态机逻辑
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            out_r <= 0; out_c <= 0;
            k_r <= 0; k_c <= 0;
            accumulator <= 0;
            result_row <= 0;
            result_col <= 0;
        end else begin
            case (state)
                // --- 空闲状态 ---
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_INIT;
                    end
                end

                // --- 初始化 ---
                S_INIT: begin
                    // 计算输出尺寸
                    result_row <= image_row - kernel_row + 1;
                    result_col <= image_col - kernel_col + 1;
                    
                    // 重置计数器
                    out_r <= 0;
                    out_c <= 0;
                    k_r <= 0;
                    k_c <= 0;
                    accumulator <= 0;
                    
                    state <= S_CALC;
                end

                // --- 计算卷积 (乘法) ---
                S_CALC: begin
                    // 计算索引
                    // 图像索引: (out_r + k_r) * 5 + (out_c + k_c)
                    // 注意：存储时按固定宽度5来存
                    img_idx <= (out_r + k_r) * 5 + (out_c + k_c);
                    ker_idx <= k_r * 3 + k_c; // 卷积核最大3x3
                    
                    state <= S_ACC;
                end

                // --- 累加 ---
                S_ACC: begin
                    // 执行乘法并累加
                    accumulator <= accumulator + (image_flat[img_idx] * kernel_flat[ker_idx]);
                    
                    // 更新卷积核坐标
                    if (k_c == kernel_col - 1) begin
                        k_c <= 0;
                        if (k_r == kernel_row - 1) begin
                            // 当前输出点计算完成
                            state <= S_STORE;
                        end else begin
                            k_r <= k_r + 1;
                            state <= S_CALC;
                        end
                    end else begin
                        k_c <= k_c + 1;
                        state <= S_CALC;
                    end
                end

                // --- 存储结果 ---
                S_STORE: begin
                    // 存储当前输出点的结果
                    result_flat[out_r * 5 + out_c] <= accumulator;
                    
                    // 重置累加器和卷积核坐标
                    accumulator <= 0;
                    k_r <= 0;
                    k_c <= 0;
                    
                    // 更新输出坐标
                    if (out_c == result_col - 1) begin
                        out_c <= 0;
                        if (out_r == result_row - 1) begin
                            // 全部计算完成
                            state <= S_DONE;
                        end else begin
                            out_r <= out_r + 1;
                            state <= S_CALC;
                        end
                    end else begin
                        out_c <= out_c + 1;
                        state <= S_CALC;
                    end
                end

                // --- 完成状态 ---
                S_DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
