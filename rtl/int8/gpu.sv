`default_nettype none
`timescale 1ns/1ns

module gpu #(
    parameter DATA_MEM_ADDR_BITS = 8,        // 数据内存地址位数
    parameter DATA_MEM_DATA_BITS = 8,        // 数据内存数据位数
    parameter DATA_MEM_NUM_CHANNELS = 16,     // 数据内存通道数
    parameter PROGRAM_MEM_ADDR_BITS = 6,     // 程序内存地址位数
    parameter PROGRAM_MEM_DATA_BITS = 32,     // 程序内存数据位数
    parameter PROGRAM_MEM_NUM_CHANNELS = 1,  // 程序内存通道数
    parameter NUM_CORES = 1,                 // 核心数量
    parameter THREADS_PER_BLOCK = 16           // 每块线程数
) (
    input wire clk,
    input wire reset,
    input wire start,                        // 启动信号
    output wire done,                        // 完成信号

    // 设备控制寄存器
    input wire device_control_write_enable,
    input wire [7:0] device_control_data

 
);
    // 线程计数
    wire [7:0] thread_count;

    //数据和程序存取写入
    // 程序内存接口（扁平化为一维向量）
    wire [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_valid;
    wire [PROGRAM_MEM_NUM_CHANNELS*PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address; // 一维地址向量
    wire [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_ready;
    wire [PROGRAM_MEM_NUM_CHANNELS*PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data;     // 一维数据向量

    // 数据内存接口（扁平化为一维向量）
    wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid;
    wire [DATA_MEM_NUM_CHANNELS*DATA_MEM_ADDR_BITS-1:0] data_mem_read_address;          // 一维地址向量
    wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready;
    wire [DATA_MEM_NUM_CHANNELS*DATA_MEM_DATA_BITS-1:0] data_mem_read_data;              // 一维数据向量
    wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid;
    wire [DATA_MEM_NUM_CHANNELS*DATA_MEM_ADDR_BITS-1:0] data_mem_write_address;         // 一维地址向量
    wire [DATA_MEM_NUM_CHANNELS*DATA_MEM_DATA_BITS-1:0] data_mem_write_data;            // 一维数据向量
    wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready;
     //program_mem

     program_memory #(
        .MEM_NUM_CHANNELS(PROGRAM_MEM_NUM_CHANNELS),  // 设置通道数
        .MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),        // 设置数据位宽
        .MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS)         // 设置地址位宽
     ) u_program_memory (
        .clk(clk),
        .reset(reset),
        // 读通道
        .mem_read_valid(program_mem_read_valid),
        .mem_read_address(program_mem_read_address),
        .mem_read_ready(program_mem_read_ready),
        .mem_read_data(program_mem_read_data)
        
    );

    //data_mem
    data_memory #(
        .MEM_NUM_CHANNELS(DATA_MEM_NUM_CHANNELS),  // 设置通道数
        .MEM_DATA_BITS(DATA_MEM_DATA_BITS),        // 设置数据位宽
        .MEM_ADDR_BITS(DATA_MEM_ADDR_BITS)         // 设置地址位宽
    ) u_data_memory (
        .clk(clk),
        .reset(reset),
        // 读通道
        .mem_read_valid(data_mem_read_valid),
        .mem_read_address(data_mem_read_address),
        .mem_read_ready(data_mem_read_ready),
        .mem_read_data(data_mem_read_data),
        // 写通道
        .mem_write_valid(data_mem_write_valid),
        .mem_write_address(data_mem_write_address),
        .mem_write_data(data_mem_write_data),
        .mem_write_ready(data_mem_write_ready)
    );

   

    // 核心状态信号（扁平化为一维向量）
    reg [NUM_CORES-1:0] core_start;
    reg [NUM_CORES-1:0] core_reset;
    reg [NUM_CORES-1:0] core_done;
    // 核心块ID和线程计数（一维向量）
    reg [NUM_CORES*8-1:0] core_block_id; 
    localparam THREAD_COUNT_BITS = $clog2(THREADS_PER_BLOCK) + 1;
    reg [NUM_CORES*THREAD_COUNT_BITS-1:0] core_thread_count;

    // LSU接口信号（扁平化为一维向量）
    localparam NUM_LSUS = NUM_CORES * THREADS_PER_BLOCK;
    reg [NUM_LSUS-1:0] lsu_read_valid;
    reg [NUM_LSUS*DATA_MEM_ADDR_BITS-1:0] lsu_read_address;  // 一维地址向量
    reg [NUM_LSUS-1:0] lsu_read_ready;
    reg [NUM_LSUS*DATA_MEM_DATA_BITS-1:0] lsu_read_data;     // 一维数据向量
    reg [NUM_LSUS-1:0] lsu_write_valid;
    reg [NUM_LSUS*DATA_MEM_ADDR_BITS-1:0] lsu_write_address; // 一维地址向量
    reg [NUM_LSUS*DATA_MEM_DATA_BITS-1:0] lsu_write_data;    // 一维数据向量
    reg [NUM_LSUS-1:0] lsu_write_ready;

    // Fetcher接口信号（扁平化为一维向量）
    localparam NUM_FETCHERS = NUM_CORES;
    reg [NUM_FETCHERS-1:0] fetcher_read_valid;
    reg [NUM_FETCHERS*PROGRAM_MEM_ADDR_BITS-1:0] fetcher_read_address; // 一维地址向量
    reg [NUM_FETCHERS-1:0] fetcher_read_ready;
    reg [NUM_FETCHERS*PROGRAM_MEM_DATA_BITS-1:0] fetcher_read_data;     // 一维数据向量

    // 设备控制寄存器实例
    dcr dcr_instance (
        .clk(clk),
        .reset(reset),
        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        .thread_count(thread_count)
    );

    // 数据内存控制器实例
    controller #(
        .ADDR_BITS(DATA_MEM_ADDR_BITS),
        .DATA_BITS(DATA_MEM_DATA_BITS),
        .NUM_CONSUMERS(NUM_LSUS),
        .NUM_CHANNELS(DATA_MEM_NUM_CHANNELS)
    ) data_memory_controller (
        .clk(clk),
        .reset(reset),
        .consumer_read_valid(lsu_read_valid),
        .consumer_read_address(lsu_read_address),   // 一维向量
        .consumer_read_ready(lsu_read_ready),
        .consumer_read_data(lsu_read_data),          // 一维向量
        .consumer_write_valid(lsu_write_valid),
        .consumer_write_address(lsu_write_address),  // 一维向量
        .consumer_write_data(lsu_write_data),         // 一维向量
        .consumer_write_ready(lsu_write_ready),
        .mem_read_valid(data_mem_read_valid),
        .mem_read_address(data_mem_read_address),     // 一维向量
        .mem_read_ready(data_mem_read_ready),
        .mem_read_data(data_mem_read_data),           // 一维向量
        .mem_write_valid(data_mem_write_valid),
        .mem_write_address(data_mem_write_address),  // 一维向量
        .mem_write_data(data_mem_write_data),         // 一维向量
        .mem_write_ready(data_mem_write_ready)
    );

    // 程序内存控制器实例
    controller #(
        .ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
        .DATA_BITS(PROGRAM_MEM_DATA_BITS),
        .NUM_CONSUMERS(NUM_FETCHERS),
        .NUM_CHANNELS(PROGRAM_MEM_NUM_CHANNELS),
        .WRITE_ENABLE(0)
    ) program_memory_controller (
        .clk(clk),
        .reset(reset),
        .consumer_read_valid(fetcher_read_valid),
        .consumer_read_address(fetcher_read_address), // 一维向量
        .consumer_read_ready(fetcher_read_ready),
        .consumer_read_data(fetcher_read_data),       // 一维向量
        .mem_read_valid(program_mem_read_valid),
        .mem_read_address(program_mem_read_address), // 一维向量
        .mem_read_ready(program_mem_read_ready),
        .mem_read_data(program_mem_read_data)        // 一维向量
    );

    // 调度器实例
    dispatch #(
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dispatch_instance (
        .clk(clk),
        .reset(reset),
        .start(start),
        .thread_count(thread_count),
        .core_done(core_done),
        .core_start(core_start),
        .core_reset(core_reset),
        .core_block_id(core_block_id),             // 一维向量
        .core_thread_count(core_thread_count),      // 一维向量
        .done(done)
    );

    // 计算核心生成块
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : cores
            // 核心的LSU信号（扁平化为一维向量）
            reg [THREADS_PER_BLOCK-1:0] core_lsu_read_valid;
            reg [THREADS_PER_BLOCK*DATA_MEM_ADDR_BITS-1:0] core_lsu_read_address;  // 一维向量
            reg [THREADS_PER_BLOCK-1:0] core_lsu_read_ready;
            reg [THREADS_PER_BLOCK*DATA_MEM_DATA_BITS-1:0] core_lsu_read_data;     // 一维向量
            reg [THREADS_PER_BLOCK-1:0] core_lsu_write_valid;
            reg [THREADS_PER_BLOCK*DATA_MEM_ADDR_BITS-1:0] core_lsu_write_address; // 一维向量
            reg [THREADS_PER_BLOCK*DATA_MEM_DATA_BITS-1:0] core_lsu_write_data;    // 一维向量
            reg [THREADS_PER_BLOCK-1:0] core_lsu_write_ready;

            // LSU与内存控制器信号连接
            genvar j;
            for (j = 0; j < THREADS_PER_BLOCK; j = j + 1) begin
                localparam lsu_index = i * THREADS_PER_BLOCK + j;
                always @(posedge clk) begin 
                    // 读取路径
                    lsu_read_valid[lsu_index] <= core_lsu_read_valid[j];
                    lsu_read_address[lsu_index*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS] 
                        <= core_lsu_read_address[j*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS];
                    
                    // 写入路径
                    lsu_write_valid[lsu_index] <= core_lsu_write_valid[j];
                    lsu_write_address[lsu_index*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS] 
                        <= core_lsu_write_address[j*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS];
                    lsu_write_data[lsu_index*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS] 
                        <= core_lsu_write_data[j*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS];
                    
                    // 就绪信号
                    core_lsu_read_ready[j] <= lsu_read_ready[lsu_index];
                    core_lsu_read_data[j*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS] 
                        <= lsu_read_data[lsu_index*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS];
                    core_lsu_write_ready[j] <= lsu_write_ready[lsu_index];
                end
            end

            // 计算核心实例化
            core #(
                .DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS),
                .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS),
                .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
                .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),
                .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
            ) core_instance (
                .clk(clk),
                .reset(core_reset[i]),
                .start(core_start[i]),
                .done(core_done[i]),
                .block_id(core_block_id[i*8 +: 8]),                 // 位选择语法
                .thread_count(core_thread_count[i*THREAD_COUNT_BITS +: THREAD_COUNT_BITS]), // 位选择语法
                .program_mem_read_valid(fetcher_read_valid[i]),
                .program_mem_read_address(fetcher_read_address[i*PROGRAM_MEM_ADDR_BITS +: PROGRAM_MEM_ADDR_BITS]), // 位选择
                .program_mem_read_ready(fetcher_read_ready[i]),
                .program_mem_read_data(fetcher_read_data[i*PROGRAM_MEM_DATA_BITS +: PROGRAM_MEM_DATA_BITS]), // 位选择
                .data_mem_read_valid(core_lsu_read_valid),
                .data_mem_read_address(core_lsu_read_address),      // 一维向量
                .data_mem_read_ready(core_lsu_read_ready),
                .data_mem_read_data(core_lsu_read_data),             // 一维向量
                .data_mem_write_valid(core_lsu_write_valid),
                .data_mem_write_address(core_lsu_write_address),     // 一维向量
                .data_mem_write_data(core_lsu_write_data),           // 一维向量
                .data_mem_write_ready(core_lsu_write_ready)
            );
        end
    endgenerate
endmodule