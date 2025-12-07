//======================================================================
// File Name    : FPU_v1_0.v
// Module Name  : FPU_v1_0
// Author       : Hzt
// Version      : 1.0
// Modified     : 2025/03/6 11:40
// Description  : The FPU module with pure logic
//======================================================================
`timescale 1ns/1ps

//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module FPU_v1_0 #(
        parameter WIDTH = 32,
        parameter PRECISION = 32           //32 or 16 to support the 32bit /  16bit
    )(
        input wire                 clk,
        input wire                 rst,
        input wire [WIDTH-1:0]     A,
        input wire [WIDTH-1:0]     B,
        input wire                 Control,//0 - FADD, 1 - FMUL

        output reg [WIDTH-1:0]     Result
    );

//--------------------------------------------------------------------------
// Internal Signal Declaration
//--------------------------------------------------------------------------
    wire Sign_A;
    wire Sign_B;
    wire [7:0] Exponent_A;
    wire [7:0] Exponent_B;
    wire [22:0] Mantissa_A;
    wire [22:0] Mantissa_B;
    wire NaN;
    wire infinite;
    wire infinite_A;
    wire infinite_B;
    wire zero;

    //Pretend 1 to form mantissa
    wire [23:0] Mantissa_A_extend;
    wire [23:0] Mantissa_B_extend;
    //compare the exponent 
    wire [7:0] exp_diff;
    wire [7:0] exp_max;
    //standardize the mantissa
    wire [23:0] Mantissa_A_shifted;
    wire [23:0] Mantissa_B_shifted;
    //choose the bigger mantissa
    wire [23:0] Mantissa_max;
    wire [23:0] Mantissa_min;

//--------------------------------------------------------------------------
// assign the wire to the input
//--------------------------------------------------------------------------
    assign Sign_A = A[31];
    assign Sign_B = B[31];
    assign Exponent_A = A[30:23];
    assign Exponent_B = B[30:23];
    assign Mantissa_A = A[22:0];
    assign Mantissa_B = B[22:0];

//--------------------------------------------------------------------------
// Judge the input whether is NaN, infinite or zero
// The signal means the input has the value of NaN, infinite or zero
//--------------------------------------------------------------------------
    assign NaN=((Exponent_A==8'hff)&(Mantissa_A != 23'd0))|((Exponent_B==8'hff)&(Mantissa_B != 23'd0));
    assign infinite_A=(Exponent_A==8'hff)&(Mantissa_A == 23'd0);
    assign infinite_B=(Exponent_B==8'hff)&(Mantissa_B == 23'd0);
    assign infinite=infinite_A|infinite_B;
    assign zero=((Exponent_A==8'd0)&(Mantissa_A==23'd0))|((Exponent_B==8'd0)&(Mantissa_B==23'd0));

//--------------------------------------------------------------------------
// Standardize the input to facilitate the subsequent operation
//--------------------------------------------------------------------------

    //Pretend leading 1 to form matissa
    assign Mantissa_A_extend={1'b1,Mantissa_A[22:0]};
    assign Mantissa_B_extend={1'b1,Mantissa_B[22:0]};
    //compare the exponent
    assign exp_diff=(Exponent_A>=Exponent_B)?(Exponent_A-Exponent_B):(Exponent_B-Exponent_A);
    assign exp_max=(Exponent_A>=Exponent_B)?Exponent_A:Exponent_B;
    //standardize the mantissa
    assign Mantissa_A_shifted=(Exponent_A>=Exponent_B)?Mantissa_A_extend:(Mantissa_A_extend>>exp_diff);
    assign Mantissa_B_shifted=(Exponent_B>Exponent_A)?Mantissa_B_extend:(Mantissa_B_extend>>exp_diff);
    //choose the bigger mantissa
    assign Mantissa_max=(Mantissa_A_shifted>=Mantissa_B_shifted)? Mantissa_A_shifted:Mantissa_B_shifted;
    assign Mantissa_min=(Mantissa_A_shifted>=Mantissa_B_shifted)? Mantissa_B_shifted:Mantissa_A_shifted;



//--------------------------------------------------------------------------
// FPU ADD
//--------------------------------------------------------------------------
    //execute add
    wire [24:0]mantissa_sum;
    assign mantissa_sum=(Sign_A ^ Sign_B)?(Mantissa_max-Mantissa_min):(Mantissa_max+Mantissa_min);
    integer MSB;
    always @(*) begin
        casex (mantissa_sum)
                25'b0_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx: MSB=24;
                25'b0_01xx_xxxx_xxxx_xxxx_xxxx_xxxx: MSB=23;
                25'b0_001x_xxxx_xxxx_xxxx_xxxx_xxxx: MSB=22;
                25'b0_0001_xxxx_xxxx_xxxx_xxxx_xxxx: MSB=21;
                25'b0_0000_1xxx_xxxx_xxxx_xxxx_xxxx: MSB=20;
                25'b0_0000_01xx_xxxx_xxxx_xxxx_xxxx: MSB=19;
                25'b0_0000_001x_xxxx_xxxx_xxxx_xxxx: MSB=18;
                25'b0_0000_0001_xxxx_xxxx_xxxx_xxxx: MSB=17;
                25'b0_0000_0000_1xxx_xxxx_xxxx_xxxx: MSB=16;
                25'b0_0000_0000_01xx_xxxx_xxxx_xxxx: MSB=15;
                25'b0_0000_0000_001x_xxxx_xxxx_xxxx: MSB=14;
                25'b0_0000_0000_0001_xxxx_xxxx_xxxx: MSB=13;
                25'b0_0000_0000_0000_1xxx_xxxx_xxxx: MSB=12;
                25'b0_0000_0000_0000_01xx_xxxx_xxxx: MSB=11;
                25'b0_0000_0000_0000_001x_xxxx_xxxx: MSB=10;
                25'b0_0000_0000_0000_0001_xxxx_xxxx: MSB=9;
                25'b0_0000_0000_0000_0000_1xxx_xxxx: MSB=8;
                25'b0_0000_0000_0000_0000_01xx_xxxx: MSB=7;
                25'b0_0000_0000_0000_0000_001x_xxxx: MSB=6;
                25'b0_0000_0000_0000_0000_0001_xxxx: MSB=5;
                25'b0_0000_0000_0000_0000_0000_1xxx: MSB=4;
                25'b0_0000_0000_0000_0000_0000_01xx: MSB=3;
                25'b0_0000_0000_0000_0000_0000_001x: MSB=2;
                25'b0_0000_0000_0000_0000_0000_0001: MSB=1;
                default:
                MSB=24;
            endcase
    end
    
    //intermediate variable
    wire [7:0] buffer_exponent;
    wire [24:0] buffer_mantissa;

    assign buffer_mantissa = mantissa_sum<<(24-MSB);//Move MSB to mantissa_sum[23]
    assign buffer_exponent = (mantissa_sum[24])?(exp_max+1'b1):(exp_max);
    
    //The result of FPU ADD
    reg sum_sign;
    reg [7:0] sum_exp;
    reg [22:0] sum_mantissa;

    always @( *) begin
        if (NaN) begin//A or B is NaN
            sum_sign = 1'b1;
            sum_mantissa = 23'h7FFFFF;
            sum_exp = 8'b1111_1111;
        end
        else if (infinite) begin//A or B is infinite
            if ((infinite_A & infinite_B)& (Sign_A ^ Sign_B)) begin //+infinite - infinite = NaN
                sum_sign = 1'b1;
                sum_mantissa = 23'h7FFFFF;
                sum_exp = 8'b1111_1111;
            end
            else begin
            sum_sign = (Mantissa_A_shifted==Mantissa_max)? Sign_A:Sign_B;
            sum_mantissa = 23'd0;
            sum_exp = 8'b1111_1111;
            end
        end
        else if (mantissa_sum == 25'd0) begin//result is 0
            sum_sign = 1'b1;
            sum_mantissa = 23'd0;
            sum_exp = 8'd0;
        end
        else if (Sign_A == Sign_B) begin//the A+B
            sum_sign = (Mantissa_A_shifted==Mantissa_max)? Sign_A:Sign_B;
            sum_exp = buffer_exponent;
            if (buffer_exponent == 8'b1111_1111) begin//the result is infinite case
                sum_mantissa = 23'd0;
            end
            else begin
                sum_mantissa = (mantissa_sum[24])?(mantissa_sum[23:1]):(mantissa_sum[22:0]);
            end
        end
        else begin//A-B maybe result the mantissa_sum[23]==0; the A+B will not make the mantissa_sum[23]==0
            sum_sign = (Mantissa_A_shifted==Mantissa_max)? Sign_A:Sign_B;
            sum_mantissa = buffer_mantissa[22:0];
            sum_exp = exp_max-(24-MSB);
        end
    end
    

//--------------------------------------------------------------------------
// FPU MUL
//--------------------------------------------------------------------------

    //execute mul module

    wire [47:0] mantissa_mul;

    int_multiplier_24 #(
        .WIDTH     	( 24     ),
        .WIDTHX2   	( 48     ),
        .PRECISION 	( 24  ))
    u_int_multiplier_24(
        .clk    	( clk     ),
        .rst    	( rst     ),
        .a      	( Mantissa_A_extend       ),
        .b      	( Mantissa_B_extend       ),
        .result 	( mantissa_mul  )
    );

    //The result of FPU MUL
    reg mul_sign;
    reg [7:0] mul_exp;
    reg [22:0] mul_mantissa;
    wire [9:0] mul_exp_buffer;//To judge the result is infinite or not
    wire [47:0] mul_mantissa_buffer;

    assign mul_exp_buffer = (mantissa_mul[47]) ? (Exponent_A+Exponent_B-8'd127+1'd1):(Exponent_A+Exponent_B-8'd127);
    assign mul_mantissa_buffer = (mantissa_mul[47])?(mantissa_mul):(mantissa_mul << 1);

    always @(*) begin
        if (NaN) begin//A or B is NaN
            mul_sign = 1'b1;
            mul_mantissa = 23'h7FFFFF;
            mul_exp = 8'b1111_1111;
        end
        else if (zero & infinite) begin//zero * infinite = NaN
            mul_sign = 1'b1;
            mul_mantissa = 23'h7FFFFF;
            mul_exp = 8'b1111_1111;
        end
        else if (zero) begin//A or B is zero
            mul_sign = 1'b0;
            mul_mantissa = 23'd0;
            mul_exp = 8'd0;
        end
        else if (infinite) begin//A or B is infinite
            mul_sign = Sign_A^Sign_B;
            mul_mantissa = 23'd0;
            mul_exp = 8'b1111_1111;
        end
        else begin// process correctly 
            
            if (mul_exp_buffer[9]) begin//the exp is negtive; the result is zero
                mul_sign = 1'b0;
                mul_mantissa = 23'd0;
                mul_exp = 8'd0;
            end
            else if (mul_exp_buffer >= 10'b00_1111_1111) begin//the result is infinite
                mul_sign = Sign_A ^ Sign_B;
                mul_mantissa=23'd0;
                mul_exp=8'b1111_1111;
            end
            else begin
                mul_sign = Sign_A ^ Sign_B;
                mul_mantissa=mul_mantissa_buffer[46:24];//neglect the first 1 round the smaller 24 bit
                if (mantissa_mul[47]) begin
                    mul_exp = Exponent_A+Exponent_B-8'd127+1'd1;
                end
                else begin
                    mul_exp = Exponent_A+Exponent_B-8'd127;
                end
            end
        end
    end


//--------------------------------------------------------------------------
// FPU Output
//--------------------------------------------------------------------------
always @(*) begin
    if (~Control) begin
        Result = {sum_sign,sum_exp,sum_mantissa};
    end
    else begin
        Result = {mul_sign,mul_exp,mul_mantissa};
    end
end

// reg [WIDTH-1:0]   Result_fianl;

// always @(posedge clk or negedge rst ) begin
//     if (!rst) begin
//         Result_fianl <= 0;
//     end
//     else if (~Control) begin
//         Result_fianl <= {sum_sign,sum_exp,sum_mantissa};
//     end
//     else begin
//         Result_fianl <= {mul_sign,mul_exp,mul_mantissa};
//     end
// end

// always @(posedge clk) begin
//     Result <= Result_fianl;
// end





endmodule