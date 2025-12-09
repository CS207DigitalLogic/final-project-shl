//==============================================================================
// brief_displayer.v
// 矩阵信息简要显示模块
// 功能：将已存储的矩阵信息转换为UART发送格式
// 格式：矩阵总数 行数1*列数1*序号1 行数2*列数2*序号2 ...
// 示例：3 2*2*1 4*5*2 3*3*3
//==============================================================================
module brief_displayer #(
    parameter MAX_MATRICES = 4,       // 最大矩阵数量
    parameter MAX_DIM      = 5,       // 最大维度
    parameter MSG_LEN      = 64       // 最大消息长度
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // 矩阵存储信息
    input  wire [2:0]  mat_count,                         // 已存储矩阵数量 (0-4)
    input  wire [2:0]  mat_rows [0:MAX_MATRICES-1],       // 各矩阵行数
    input  wire [2:0]  mat_cols [0:MAX_MATRICES-1],       // 各矩阵列数
    
    // 控制信号
    input  wire        start,                              // 开始生成消息
    output reg         done,                               // 消息生成完成
    output reg         busy,                               // 忙标志
    
    // 输出消息
    output reg  [7:0]  msg_data [0:MSG_LEN-1],            // ASCII消息数据
    output reg  [5:0]  msg_len                             // 消息长度
);

    //--------------------------------------------------------------------------
    // 状态定义
    //--------------------------------------------------------------------------
    localparam IDLE       = 3'd0;
    localparam GEN_COUNT  = 3'd1;   // 生成矩阵总数
    localparam GEN_SPACE  = 3'd2;   // 生成空格
    localparam GEN_ROW    = 3'd3;   // 生成行数
    localparam GEN_STAR1  = 3'd4;   // 生成第一个*
    localparam GEN_COL    = 3'd5;   // 生成列数
    localparam GEN_STAR2  = 3'd6;   // 生成第二个*
    localparam GEN_IDX    = 3'd7;   // 生成序号
    
    reg [2:0] state;
    reg [2:0] mat_idx;              // 当前处理的矩阵索引
    reg [5:0] write_ptr;            // 写入指针
    
    // ASCII转换函数
    function [7:0] digit_to_ascii;
        input [3:0] digit;
        begin
            digit_to_ascii = 8'h30 + digit; // '0' = 0x30
        end
    endfunction
    
    //--------------------------------------------------------------------------
    // 主状态机
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            mat_idx   <= 3'd0;
            write_ptr <= 6'd0;
            done      <= 1'b0;
            busy      <= 1'b0;
            msg_len   <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy      <= 1'b1;
                        write_ptr <= 6'd0;
                        mat_idx   <= 3'd0;
                        state     <= GEN_COUNT;
                    end
                end
                
                // 生成矩阵总数
                GEN_COUNT: begin
                    msg_data[write_ptr] <= digit_to_ascii(mat_count[3:0]);
                    write_ptr <= write_ptr + 1;
                    if (mat_count > 0) begin
                        state <= GEN_SPACE;
                    end else begin
                        // 没有矩阵，直接结束
                        msg_len <= write_ptr + 1;
                        done    <= 1'b1;
                        busy    <= 1'b0;
                        state   <= IDLE;
                    end
                end
                
                // 生成空格分隔符
                GEN_SPACE: begin
                    msg_data[write_ptr] <= 8'h20; // 空格
                    write_ptr <= write_ptr + 1;
                    state     <= GEN_ROW;
                end
                
                // 生成行数
                GEN_ROW: begin
                    msg_data[write_ptr] <= digit_to_ascii(mat_rows[mat_idx][2:0]);
                    write_ptr <= write_ptr + 1;
                    state     <= GEN_STAR1;
                end
                
                // 生成第一个*
                GEN_STAR1: begin
                    msg_data[write_ptr] <= 8'h2A; // '*'
                    write_ptr <= write_ptr + 1;
                    state     <= GEN_COL;
                end
                
                // 生成列数
                GEN_COL: begin
                    msg_data[write_ptr] <= digit_to_ascii(mat_cols[mat_idx][2:0]);
                    write_ptr <= write_ptr + 1;
                    state     <= GEN_STAR2;
                end
                
                // 生成第二个*
                GEN_STAR2: begin
                    msg_data[write_ptr] <= 8'h2A; // '*'
                    write_ptr <= write_ptr + 1;
                    state     <= GEN_IDX;
                end
                
                // 生成序号 (1-based索引)
                GEN_IDX: begin
                    msg_data[write_ptr] <= digit_to_ascii(mat_idx + 1);
                    write_ptr <= write_ptr + 1;
                    
                    if (mat_idx + 1 < mat_count) begin
                        mat_idx <= mat_idx + 1;
                        state   <= GEN_SPACE;
                    end else begin
                        // 所有矩阵处理完毕
                        msg_len <= write_ptr + 1;
                        done    <= 1'b1;
                        busy    <= 1'b0;
                        state   <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    //--------------------------------------------------------------------------
    // 初始化消息缓冲区
    //--------------------------------------------------------------------------
    integer i;
    initial begin
        for (i = 0; i < MSG_LEN; i = i + 1) begin
            msg_data[i] = 8'h00;
        end
    end

endmodule
