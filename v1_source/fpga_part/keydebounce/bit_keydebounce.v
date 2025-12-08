module bit_keydebounce #(parameter CLK_FREQ = 50_000_000)
(   
    input  wire     clk,     //系统时钟 50MHz
    input  wire     rst_n,   //复位信号
    input  wire     key,     //按键输入信号
    output reg      key_done //消抖之后的按键信号
);

reg                 key_r0;  //同步信号(滤波作用，滤除小于一个周期的抖动)
reg                 key_r1;  //打拍
reg                 flag;    //标志位
wire                nedge;   //下降沿检测(检测到下降沿代表开始抖动)

//计时器定义
reg [19:0]          cnt;
wire                add_cnt;  //计时器开启
wire                end_cnt;  //计时记满

parameter           MAX_CNT=20'd1_000_000;  //20ms延时

//同步
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_r0<=1'b1;
    end
    else
        key_r0<=key;
end

//打拍
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_r1<=1'b1;    
    end
    else
        key_r1<=key_r0;
end

assign nedge = ~key_r0 & key_r1;  //检测到下降沿拉高

//标志位
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        flag<=1'b0; 
    end
    else if (nedge) begin
        flag<=1'b1; 
    end
    else if (end_cnt) begin
        flag<=1'b0;
    end
end

//延时模块
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt<=20'b0;
    end
    else if (add_cnt) begin
        if (end_cnt) begin
            cnt<=20'b0;
        end
        else
            cnt<=cnt+1;
    end
end

assign add_cnt=flag;                    //计时器开启
assign end_cnt=add_cnt&&cnt==MAX_CNT-1; //计时器关闭

//key_done输出
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_done<=1'b0; 
    end
    else if (end_cnt) begin            //延时满20ms采样
        key_done<=(~key_r0);
    end
    else
        key_done<=(1'b0);
end

endmodule 
