module int8_to_fp8 (
    input wire signed [7:0] int8_data,  // 有符号8位整数输入
    output reg [7:0] fp8_data          // E4M3格式FP8输出
  
);

// E4M3格式参数
localparam EXP_BIAS = 7;               // 指数偏置
localparam EXP_MAX = 14;               // 最大指数值（不包括特殊值）
localparam MANTISSA_BITS = 3;          // 尾数位数

// 内部信号
reg sign;
reg [7:0] abs_value;
reg [4:0] exponent;                   // 5位用于计算
reg [2:0] mantissa;
reg [7:0] temp_value;
integer leading_zeros;
integer i;
reg overflow;               // 溢出标志
reg underflow ;               // 下溢标志
always @(*) begin
    // 初始化
    overflow = 1'b0;
    underflow = 1'b0;
    fp8_data = 8'b0;
    
    // 提取符号和绝对值
    sign = int8_data[7];
    abs_value = (int8_data[7]) ? (-int8_data) : int8_data;
    
    // 处理零值
    if (abs_value == 8'b0) begin
        fp8_data = {sign, 7'b0};
    end
    else begin
        // 计算前导零的数量
        leading_zeros = 0;
        for (i = 7; i >= 0; i = i - 1) begin
            if (abs_value[i] == 1'b1) begin
                leading_zeros = 7 - i;
                i = -1; // 退出循环
            end
        end
        
        // 计算指数
        exponent = 7 - leading_zeros + EXP_BIAS; // 7 - leading_zeros 是最高位位置
        
        // 检查指数是否超出范围
        if (exponent > EXP_MAX) begin
            // 溢出，返回最大可表示值或无穷大
            overflow = 1'b1;
            fp8_data = {sign, 4'b1110, 3'b111}; // 最大正常数
        end
        else if (exponent < 1) begin
            // 下溢，返回零
            underflow = 1'b1;
            fp8_data = {sign, 7'b0};
        end
        else begin
            // 提取尾数
            // 根据最高位位置提取尾数位
            if (leading_zeros <= 4) begin
                // 值足够大，尾数从最高位后的3位提取
                mantissa = abs_value[(6-leading_zeros)+:3];
            end
            else begin
                // 值较小，尾数需要移位
                temp_value = abs_value << (leading_zeros - 4);
                mantissa = temp_value[6:4];
            end
            
            // 组合结果
            fp8_data = {sign, exponent[3:0], mantissa};
        end
    end
end

endmodule