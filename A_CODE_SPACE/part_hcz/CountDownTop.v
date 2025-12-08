// 顶层模块：可配置倒计时器
module CountDownTop(
    // 系统信号
    input wire clk_100m,      // 100MHz时钟
    input wire rst_n,         // 低电平复位
    
    // 控制信号
    input wire start_btn,     // 开始按钮
    input wire pause_btn,     // 暂停按钮
    input wire reset_btn,     // 复位按钮
    
    // 配置输入
    input wire [3:0] dip_sw,  // 拨码开关配置倒计时时间
    
    // 显示输出
    output wire [3:0] seg_sel, // 数码管位选
    output wire [7:0] seg_data, // 数码管段选
    output wire buzzer,        // 蜂鸣器
    output wire [3:0] led      // 状态指示灯
);

// =========================== 内部信号定义 ===========================
wire clk_1hz;          // 1Hz时钟
wire clk_1khz;         // 1kHz时钟（数码管扫描）
wire btn_start_pulse;  // 开始按钮消抖脉冲
wire btn_pause_pulse;  // 暂停按钮消抖脉冲
wire btn_reset_pulse;  // 复位按钮消抖脉冲
wire [3:0] time_value; // 当前倒计时值
wire [3:0] time_setting; // 设置的时间值
wire [1:0] state;      // 当前状态

// =========================== 实例化各子模块 ===========================

// 时钟分频模块
ClkDivider u_clk_divider(
    .clk_100m(clk_100m),
    .rst_n(rst_n),
    .clk_1hz(clk_1hz),
    .clk_1khz(clk_1khz)
);

// 按键消抖模块
ButtonDebounce u_btn_start(
    .clk(clk_100m),
    .rst_n(rst_n),
    .button_in(start_btn),
    .button_out(btn_start_pulse)
);

ButtonDebounce u_btn_pause(
    .clk(clk_100m),
    .rst_n(rst_n),
    .button_in(pause_btn),
    .button_out(btn_pause_pulse)
);

ButtonDebounce u_btn_reset(
    .clk(clk_100m),
    .rst_n(rst_n),
    .button_in(reset_btn),
    .button_out(btn_reset_pulse)
);

// 时间配置模块
TimeDesign u_time_config(
    .clk(clk_100m),
    .rst_n(rst_n),
    .dip_sw(dip_sw),
    .config_valid(1'b1),  // 始终有效
    .time_setting(time_setting)
);

// 倒计时控制模块
TimerControl u_timer_control(
    .clk(clk_100m),
    .rst_n(rst_n),
    .clk_1hz(clk_1hz),
    .start_pulse(btn_start_pulse),
    .pause_pulse(btn_pause_pulse),
    .reset_pulse(btn_reset_pulse),
    .time_setting(time_setting),
    .time_value(time_value),
    .state(state),
    .buzzer(buzzer)
);

// 数码管显示模块
SegDisplay u_seg_display(
    .clk_100m(clk_100m),
    .clk_1khz(clk_1khz),
    .rst_n(rst_n),
    .value(time_value),
    .state(state),
    .seg_sel(seg_sel),
    .seg_data(seg_data)
);

// LED状态指示模块
assign led[0] = (state == 2'b00);  // 空闲状态
assign led[1] = (state == 2'b01);  // 运行状态
assign led[2] = (state == 2'b10);  // 暂停状态
assign led[3] = (state == 2'b11);  // 完成状态

endmodule