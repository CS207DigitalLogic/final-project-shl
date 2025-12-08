// 倒计时控制模块 - 核心控制逻辑
module TimerControl(
    input wire clk,
    input wire rst_n,
    input wire clk_1hz,          // 1Hz时钟
    input wire start_pulse,      // 开始脉冲
    input wire pause_pulse,      // 暂停脉冲
    input wire reset_pulse,      // 复位脉冲
    input wire [3:0] time_setting, // 设置的时间
    output reg [3:0] time_value, // 当前倒计时值
    output reg [1:0] state,      // 当前状态
    output reg buzzer            // 蜂鸣器输出
);

// =========================== 状态定义 ===========================
localparam IDLE      = 2'b00;    // 空闲状态
localparam RUNNING   = 2'b01;    // 运行状态
localparam PAUSED    = 2'b10;    // 暂停状态
localparam FINISHED  = 2'b11;    // 完成状态

// =========================== 内部寄存器 ===========================
reg [3:0] saved_time;      // 保存的倒计时时间
reg [3:0] buzzer_counter;  // 蜂鸣器计数器
reg clk_1hz_dly;           // 1Hz时钟延迟

// =========================== 1Hz时钟边沿检测 ===========================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_1hz_dly <= 0;
    end else begin
        clk_1hz_dly <= clk_1hz;
    end
end

wire clk_1hz_rising = clk_1hz && ~clk_1hz_dly;  // 1Hz上升沿检测

// =========================== 主状态机 ===========================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        time_value <= 10;  // 默认10秒
        saved_time <= 10;
        buzzer <= 0;
        buzzer_counter <= 0;
    end else begin
        // 蜂鸣器控制
        if (state == FINISHED) begin
            // 倒计时结束时蜂鸣器响1秒
            if (clk_1hz_rising) begin
                if (buzzer_counter < 1) begin  // 响1秒
                    buzzer <= ~buzzer;  // 产生蜂鸣声
                    buzzer_counter <= buzzer_counter + 1;
                end else begin
                    buzzer <= 0;
                end
            end
        end else begin
            buzzer <= 0;
            buzzer_counter <= 0;
        end
        
        // 状态转换逻辑，有些状态可以不要
        case (state)
            IDLE: begin
                // 空闲状态
                if (reset_pulse) begin
                    time_value <= time_setting;
                    saved_time <= time_setting;
                end else if (start_pulse) begin
                    state <= RUNNING;
                    time_value <= saved_time;
                end
            end
            
            RUNNING: begin
                // 运行状态
                if (pause_pulse) begin
                    state <= PAUSED;
                end else if (reset_pulse) begin
                    state <= IDLE;
                    time_value <= time_setting;
                    saved_time <= time_setting;
                end else if (clk_1hz_rising) begin
                    if (time_value > 0) begin
                        time_value <= time_value - 1;
                        saved_time <= time_value;  // 保存当前值
                    end else begin
                        state <= FINISHED;
                    end
                end
            end
            
            PAUSED: begin
                // 暂停状态
                if (start_pulse) begin
                    state <= RUNNING;
                end else if (reset_pulse) begin
                    state <= IDLE;
                    time_value <= time_setting;
                    saved_time <= time_setting;
                end
            end
            
            FINISHED: begin
                // 完成状态
                if (start_pulse) begin
                    state <= RUNNING;
                    time_value <= saved_time;
                end else if (reset_pulse) begin
                    state <= IDLE;
                    time_value <= time_setting;
                    saved_time <= time_setting;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule