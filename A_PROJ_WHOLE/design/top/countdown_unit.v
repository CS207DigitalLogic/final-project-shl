`timescale 1ns / 1ps
// 倒计时模块：支持 5-15s 设置，默认 10s，输出当前秒数和超时脉冲
module countdown_unit #(
    parameter CLK_FREQ = 100_000_000 // 默认 100MHz
)(
    input  wire       clk,
    input  wire       rst_n,
    
    // 控制接口
    input  wire       start,          // 启动信号 (脉冲)
    input  wire [3:0] setting_in,     // 来自开关的设置值 (sw_scalar_count_down)
    
    // 状态输出
    output reg  [3:0] current_seconds,// 输出给数码管显示
    output reg        active,         // 是否正在倒计时 (用于点亮 LED Busy)
    output reg        timeout         // 倒计时结束脉冲 (一周期高电平)
);

    // 1. 设置值预处理 (5~15 范围限制)
    wire [3:0] effective_setting;
    assign effective_setting = (setting_in >= 4'd5 && setting_in <= 4'd15) ? 
                                setting_in : 4'd10;

    // 2. 内部计数器
    reg [31:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter         <= 32'd0;
            current_seconds <= 4'd0;
            active          <= 1'b0;
            timeout         <= 1'b0;
        end else begin
            // 默认拉低超时信号 (产生脉冲)
            timeout <= 1'b0;

            if (active) begin
                // 正在倒计时
                if (counter >= CLK_FREQ - 1) begin
                    counter <= 32'd0;
                    if (current_seconds > 0) begin
                        current_seconds <= current_seconds - 1;
                    end else begin
                        // 倒计时结束
                        active  <= 1'b0;
                        timeout <= 1'b1; // 触发结束信号
                    end
                end else begin
                    counter <= counter + 1;
                end
            end else begin
                // 等待启动信号
                // 逻辑：当收到 start 且当前不在忙碌时启动
                if (start) begin
                    active          <= 1'b1;
                    current_seconds <= effective_setting;
                    counter         <= 32'd0;
                end
            end
        end
    end

endmodule