`default_nettype none
`timescale 1ns/1ns

module dispatch #(
    parameter NUM_CORES = 1,
    parameter THREADS_PER_BLOCK = 16
) (
    input wire clk,
    input wire reset,
    input wire start,

    // Kernel Metadata
    input wire [7:0] thread_count,

    // Core States
    input wire [NUM_CORES-1:0] core_done,
    output reg [NUM_CORES-1:0] core_start,
    output reg [NUM_CORES-1:0] core_reset,
    // 端口扁平化：二维数组转为一维向量
    output reg [NUM_CORES*8-1:0] core_block_id,          // 原：[7:0] core_block_id [NUM_CORES-1:0]
    output reg [NUM_CORES*($clog2(THREADS_PER_BLOCK)+1)-1:0] core_thread_count, // 原：[$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0]

    // Kernel Execution
    output reg done
);
    // 计算线程计数位宽（局部参数）
    localparam THREAD_COUNT_BITS = $clog2(THREADS_PER_BLOCK) + 1;
    
    // 计算总块数
    wire [7:0] total_blocks;
    assign total_blocks = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

    // 状态跟踪
    reg [7:0] blocks_dispatched;  // 已分发块数
    reg [7:0] blocks_done;        // 已完成块数
    reg start_execution;          // 启动执行标志
	integer i;
    always @(posedge clk) begin
        if (reset) begin
            done <= 0;
            blocks_dispatched <= 0;
            blocks_done <= 0;
            start_execution <= 0;
            core_start <= 0;
            core_reset <= {NUM_CORES{1'b1}}; // 所有核心复位
            
            // 初始化一维向量
            core_block_id <= 0;
            core_thread_count <= 0;
        end else if (start) begin    
            // 间接启动执行
            if (!start_execution) begin 
                start_execution <= 1;
                core_reset <= {NUM_CORES{1'b1}}; // 触发所有核心复位
            end

            // 完成检查
            if (blocks_done == total_blocks) done <= 1;

            // 核心分发逻辑
            for (i = 0; i < NUM_CORES; i=i+1) begin
                if (core_reset[i]) begin 
                    core_reset[i] <= 0;
                    
                    if (blocks_dispatched < total_blocks) begin 
                        core_start[i] <= 1;
                        // 使用位选择语法访问一维向量
                        core_block_id[i*8 +: 8] <= blocks_dispatched;
                        
                        // 计算当前块的线程数
                        if (blocks_dispatched == total_blocks - 1) begin
                            core_thread_count[i*THREAD_COUNT_BITS +: THREAD_COUNT_BITS] 
                                <= thread_count - (blocks_dispatched * THREADS_PER_BLOCK);
                        end else begin
                            core_thread_count[i*THREAD_COUNT_BITS +: THREAD_COUNT_BITS] 
                                <= THREADS_PER_BLOCK;
                        end
                        
                        blocks_dispatched <= blocks_dispatched + 1;
                    end
                end
            end

            // 完成处理
            for ( i = 0; i < NUM_CORES; i=i+1) begin
                if (core_start[i] && core_done[i]) begin
                    core_reset[i] <= 1;
                    core_start[i] <= 0;
                    blocks_done <= blocks_done + 1;
                end
            end
        end
    end
endmodule
