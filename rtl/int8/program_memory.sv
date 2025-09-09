module program_memory #(
    MEM_NUM_CHANNELS = 1,
    MEM_DATA_BITS = 32,
    MEM_ADDR_BITS = 6
) (
    input wire clk,
    input wire reset,
    input wire [MEM_NUM_CHANNELS-1:0] mem_read_valid,
    input wire [MEM_NUM_CHANNELS*MEM_ADDR_BITS-1:0] mem_read_address, // 一维地址向量
    output reg [MEM_NUM_CHANNELS-1:0] mem_read_ready,
    output reg [MEM_NUM_CHANNELS*MEM_DATA_BITS-1:0] mem_read_data    // 一维数据向量

    //input wire [MEM_NUM_CHANNELS-1:0] mem_write_valid,
    //input wire [MEM_NUM_CHANNELS*MEM_ADDR_BITS-1:0] mem_write_address,         // 一维地址向量
    //input wire [MEM_NUM_CHANNELS*MEM_DATA_BITS-1:0] mem_write_data,            // 一维数据向量
    //output reg [MEM_NUM_CHANNELS-1:0] mem_write_ready
);
    localparam MEM_DEEPTH = 2 ** MEM_ADDR_BITS;
 reg [MEM_DATA_BITS-1:0] program_memory [0:MEM_NUM_CHANNELS*MEM_DEEPTH-1];
 integer i;

        
        


always @(posedge clk) begin
       
        if (reset) begin 
            mem_read_ready <= 0;
            mem_read_data <= 0;
          //  mem_write_ready <= 0;
          //程序内存初始化
            for (i = 0; i < MEM_DEEPTH; i = i + 1) begin
            program_memory[i] = 32'h00000000;
        end
    
        end else begin
        
         if (mem_read_valid[0]) begin
            mem_read_ready[0] <= 1;
            mem_read_data <= program_memory[mem_read_address];
        end else begin
            mem_read_ready[0] <= 0;
        end

        end
    end
    endmodule
