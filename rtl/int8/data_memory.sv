module data_memory #(
    MEM_NUM_CHANNELS = 16,
    MEM_DATA_BITS = 8,
    MEM_ADDR_BITS = 8
) (
    input wire clk,
    input wire reset,
    input wire [MEM_NUM_CHANNELS-1:0] mem_read_valid,
    input wire [MEM_NUM_CHANNELS*MEM_ADDR_BITS-1:0] mem_read_address, // 一维地址向量
    output reg [MEM_NUM_CHANNELS-1:0] mem_read_ready,
    output reg [MEM_NUM_CHANNELS*MEM_DATA_BITS-1:0] mem_read_data,    // 一维数据向量

    input wire [MEM_NUM_CHANNELS-1:0] mem_write_valid,
    input wire [MEM_NUM_CHANNELS*MEM_ADDR_BITS-1:0] mem_write_address,         // 一维地址向量
    input wire [MEM_NUM_CHANNELS*MEM_DATA_BITS-1:0] mem_write_data,            // 一维数据向量
    output reg [MEM_NUM_CHANNELS-1:0] mem_write_ready
);
    localparam MEM_DEEPTH = 2 ** MEM_ADDR_BITS;
 reg [7:0] data_memory [0:MEM_NUM_CHANNELS*MEM_DEEPTH-1];
 integer i;

always @(posedge clk) begin
       
        if (reset) begin 
            mem_read_ready <= 0;
            mem_read_data <= 0;
            mem_write_ready <= 0;
            for (i = 0; i < MEM_NUM_CHANNELS*MEM_DEEPTH; i = i + 1) begin
            data_memory[i] <= i%13;
        end
        end else begin
        
        // 处理数据内存读取
        for (i = 0; i < MEM_NUM_CHANNELS; i = i + 1) begin
            if (mem_read_valid[i]) begin
                mem_read_ready[i] <= 1;
                mem_read_data[i*MEM_DATA_BITS +: MEM_DATA_BITS] <= data_memory[mem_read_address[i*MEM_ADDR_BITS +: MEM_ADDR_BITS]+i*MEM_DEEPTH];
            end else begin
                mem_read_ready[i] <= 0;
            end
        end
        
        // 处理数据内存写入
        for (i = 0; i < MEM_NUM_CHANNELS; i = i + 1) begin
            if (mem_write_valid[i]) begin
                mem_write_ready[i] <= 1;
                data_memory[mem_write_address[i*MEM_ADDR_BITS +: MEM_ADDR_BITS]+i*MEM_DEEPTH] <= mem_write_data[i*MEM_DATA_BITS +: MEM_DATA_BITS];
            end else begin
                mem_write_ready[i] <= 0;
            end
        end
        end
    end
    endmodule
