// 按键消抖模块
module ButtonDebounce(
    input wire clk,
    input wire rst_n,
    input wire button_in,
    output reg button_out
);

// =========================== 参数定义 ===========================
localparam DEBOUNCE_TIME = 20_000;  // 20ms消抖时间(100MHz时钟)
localparam IDLE   = 2'b00;
localparam PRESS  = 2'b01;
localparam WAIT  = 2'b10;
localparam RELEASE  = 2'b11;

// =========================== 内部寄存器 ===========================
reg [1:0] state;
reg [15:0] counter;
reg button_sync0, button_sync1;

// =========================== 同步器 ===========================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        button_sync0 <= 1'b0;
        button_sync1 <= 1'b0;
    end else begin
        button_sync0 <= button_in;
        button_sync1 <= button_sync0;
    end
end

// =========================== 状态机 ===========================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        counter <= 0;
        button_out <= 0;
    end else begin
        case (state)
            IDLE: begin
                button_out <= 0;
                if (button_sync1 == 1) begin  // 检测到按键按下
                    state <= PRESS;
                    counter <= 0;
                end
            end
            
            PRESS: begin
                if (button_sync1 == 0) begin  // 按键释放
                    state <= IDLE;
                end else if (counter == DEBOUNCE_TIME) begin  // 消抖完成
                    state <= HOLD;
                    button_out <= 1;  // 输出一个脉冲
                end else begin
                    counter <= counter + 1;
                end
            end
            WAIT: begin
                button_out <= 0;  //一个周期脉冲
                if (button_sync1 == 0) begin  // 按键释放
                    state <= RELEASE;
                end 
            end
            
            RELEASE: begin
                if (button_sync1 == 1) begin  // 又被按下
                    state <= WAIT;
                end else if (counter == DEBOUNCE_TIME) begin  // 消抖完成
                    state <= IDLE;
                end else begin
                    counter <= counter + 1;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule