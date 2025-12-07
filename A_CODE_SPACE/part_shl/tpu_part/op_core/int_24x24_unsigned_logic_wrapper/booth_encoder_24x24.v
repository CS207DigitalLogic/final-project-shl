//======================================================================
// File Name    : booth_encoder_24x24.v
// Module Name  : booth_encoder_24x24
// Author       : Hzt
// Version      : 1.0
// Modified     : 2025/03/2 16:50
// Description  : To generate the control signal
//======================================================================
module booth_encoder_24x24(
	input [2:0] code,
	output neg,
	output zero,
	output two
);

assign neg  = code[2];
assign zero = (code==3'b000) || (code==3'b111);
assign two  = (code==3'b100) || (code==3'b011);

endmodule