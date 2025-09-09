module tensor (
	clk,
	reset,
	enable,
	core_state,
	rs,
	rt,
	tensor_out,
   // predicate,
    decoded_always_execute
);
	input wire clk;
	input wire reset;
	input wire enable;
	input wire [2:0] core_state;
	input wire [8*4*4-1:0] rs;
	input wire [8*4*4-1:0] rt;
	output wire [8*4*4-1:0] tensor_out;
    //input wire predicate;
    input wire decoded_always_execute;

	reg [7:0] tensor_out_reg[4-1:0][4-1:0];
	wire [7:0] fp8_tensor_out[4-1:0][4-1:0];
	//tensor core 矩阵乘法实现
	genvar i, j;
	generate
		for (i = 0;i < 4 ;i=i+1 ) begin : row
			for (j = 0;j < 4 ;j=j+1 ) begin :col
			  int8_to_fp8 int8_to_fp8_inst(
        		.int8_data(tensor_out_reg[i][j]),
        		.fp8_data(fp8_tensor_out[i][j])
    		);
				assign tensor_out[8*(i*4 + j) +: 8] = fp8_tensor_out[i][j];
				always @(posedge clk)begin
					if (reset)
						tensor_out_reg[i][j] <= 18'b0;
					else if (enable) begin
                        if (decoded_always_execute ) begin 
						if (core_state == 3'b101) begin
								tensor_out_reg[i][j] <= rs[8*(i*4+0)+:8] * rt[8*(j*4+0) +:8] + rs[8*(i*4+1)+:8] * rt[8*(j*4+1) +:8]
													  + rs[8*(i*4+2)+:8] * rt[8*(j*4+2) +:8] + rs[8*(i*4+3)+:8] * rt[8*(j*4+3) +:8];		
						end
                        end
					end
				end
			end
		end
	endgenerate
	
endmodule
