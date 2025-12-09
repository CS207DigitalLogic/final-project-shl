// ============================================================
// timer.v
// 功能：实现可配置的倒计时功能
// 倒计时默认10秒，可配置范围5-15秒
// 输出：倒计时值（用于7段数码管显示）、超时标志
// ============================================================
module timer(
    input wire clk,
    input wire rst_n,
    
    // 控制信号
    input wire start,              // 开始倒计时
    input wire stop,               // 停止倒计时（用户及时输入）
    
    // 配置信号
    input wire [3:0] cfg_seconds,  // 可配置的倒计时秒数 (5~15)
    
    // 时钟分频参数 (假设100MHz时钟)
    // 100_000_000 / 1 = 100M cycles per second
    
    // 输出信号
    output reg timeout_flag,       // 超时标志
    output reg counting,           // 正在计时中
    output reg [3:0] remain_tens,  // 剩余时间十位 (用于数码管)
    output reg [3:0] remain_units  // 剩余时间个位 (用于数码管)
);

    // ============================================================
    // 参数定义
    // ============================================================
    // 假设系统时钟为 100MHz
    localparam CLK_FREQ = 100_000_000;
    localparam ONE_SECOND = CLK_FREQ; // 1秒的时钟周期数
    
    // ============================================================
    // 内部寄存器
    // ============================================================
    reg [26:0] clk_counter;        // 时钟计数器 (足够计数1秒)
    reg [3:0] seconds_left;        // 剩余秒数
    
    // 配置值限制 (5~15秒)
    wire [3:0] valid_cfg_seconds;
    assign valid_cfg_seconds = (cfg_seconds < 5) ? 4'd10 :
                               (cfg_seconds > 15) ? 4'd15 : cfg_seconds;

    // ============================================================
    // 状态机
    // ============================================================
    localparam S_IDLE    = 2'd0;
    localparam S_COUNTING = 2'd1;
    localparam S_TIMEOUT = 2'd2;
    
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            clk_counter <= 0;
            seconds_left <= 0;
            timeout_flag <= 0;
            counting <= 0;
            remain_tens <= 0;
            remain_units <= 0;
        end else begin
            case (state)
                // --- 空闲状态 ---
                S_IDLE: begin
                    timeout_flag <= 0;
                    counting <= 0;
                    
                    if (start) begin
                        // 初始化倒计时
                        seconds_left <= valid_cfg_seconds;
                        clk_counter <= 0;
                        state <= S_COUNTING;
                        counting <= 1;
                        
                        // 更新显示
                        remain_tens <= valid_cfg_seconds / 10;
                        remain_units <= valid_cfg_seconds % 10;
                    end
                end

                // --- 计时状态 ---
                S_COUNTING: begin
                    if (stop) begin
                        // 用户及时完成输入，停止计时
                        state <= S_IDLE;
                        counting <= 0;
                    end else if (clk_counter >= ONE_SECOND - 1) begin
                        // 1秒过去了
                        clk_counter <= 0;
                        
                        if (seconds_left <= 1) begin
                            // 倒计时结束
                            seconds_left <= 0;
                            remain_tens <= 0;
                            remain_units <= 0;
                            state <= S_TIMEOUT;
                        end else begin
                            // 继续倒计时
                            seconds_left <= seconds_left - 1;
                            remain_tens <= (seconds_left - 1) / 10;
                            remain_units <= (seconds_left - 1) % 10;
                        end
                    end else begin
                        clk_counter <= clk_counter + 1;
                    end
                end

                // --- 超时状态 ---
                S_TIMEOUT: begin
                    timeout_flag <= 1;
                    counting <= 0;
                    
                    // 等待外部复位或重新启动
                    if (start) begin
                        timeout_flag <= 0;
                        seconds_left <= valid_cfg_seconds;
                        clk_counter <= 0;
                        state <= S_COUNTING;
                        counting <= 1;
                        remain_tens <= valid_cfg_seconds / 10;
                        remain_units <= valid_cfg_seconds % 10;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
