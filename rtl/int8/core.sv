`default_nettype none
`timescale 1ns/1ns

// COMPUTE CORE
// > Handles processing 1 block at a time
// > The core also has it's own scheduler to manage control flow
// > Each core contains 1 fetcher & decoder, and register files, ALUs, LSUs, PC for each thread
module core #(
    parameter DATA_MEM_ADDR_BITS = 8,
    parameter DATA_MEM_DATA_BITS = 8,
    parameter PROGRAM_MEM_ADDR_BITS = 6,
    parameter PROGRAM_MEM_DATA_BITS = 32,
    parameter THREADS_PER_BLOCK = 16
) (
    input wire clk,
    input wire reset,
    input wire start,
    output wire done,
    input wire [7:0] block_id,
    input wire [$clog2(THREADS_PER_BLOCK):0] thread_count,

    // Program Memory (保持一维)
    output reg program_mem_read_valid,
    output reg [PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address,
    input wire program_mem_read_ready,
    input wire [PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data,

    // 数据内存接口扁平化（关键修改）
    // 原二维数组转换为单向量：宽度 = 线程数 * 地址/数据位宽
    output reg [THREADS_PER_BLOCK-1:0] data_mem_read_valid,
    output reg [THREADS_PER_BLOCK*DATA_MEM_ADDR_BITS-1:0] data_mem_read_address, // 一维向量
    input wire [THREADS_PER_BLOCK-1:0] data_mem_read_ready,
    input wire [THREADS_PER_BLOCK*DATA_MEM_DATA_BITS-1:0] data_mem_read_data,    // 一维向量
    output reg [THREADS_PER_BLOCK-1:0] data_mem_write_valid,
    output reg [THREADS_PER_BLOCK*DATA_MEM_ADDR_BITS-1:0] data_mem_write_address, // 一维向量
    output reg [THREADS_PER_BLOCK*DATA_MEM_DATA_BITS-1:0] data_mem_write_data,   // 一维向量
    input wire [THREADS_PER_BLOCK-1:0] data_mem_write_ready
);
    // State
    reg [2:0] core_state;
    reg [2:0] fetcher_state;
    reg [PROGRAM_MEM_DATA_BITS-1:0] instruction;

    // Intermediate Signals
    reg [PROGRAM_MEM_ADDR_BITS-1:0] current_pc;
    wire [PROGRAM_MEM_ADDR_BITS-1:0] next_pc;
    reg [DATA_MEM_DATA_BITS-1:0] rs[THREADS_PER_BLOCK-1:0];
    reg [DATA_MEM_DATA_BITS-1:0] rt[THREADS_PER_BLOCK-1:0];
    reg [DATA_MEM_DATA_BITS-1:0] tensor_out[THREADS_PER_BLOCK-1:0];
    reg [2*THREADS_PER_BLOCK-1:0] lsu_state;
    reg [DATA_MEM_DATA_BITS-1:0] lsu_out[THREADS_PER_BLOCK-1:0];
    wire [DATA_MEM_DATA_BITS-1:0] alu_out[THREADS_PER_BLOCK-1:0];
    
    // Decoded Instruction Signals
    reg [7:0] decoded_rd_address;
    reg [7:0] decoded_rs_address;
    reg [7:0] decoded_rt_address;
    reg [1:0] decoded_predicate_address;
   // reg [2:0] decoded_nzp;
    reg [7:0] decoded_immediate;

    // Decoded Control Signals
    reg decoded_reg_write_enable;           // Enable writing to a register
    reg decoded_mem_read_enable;            // Enable reading from memory
    reg decoded_mem_write_enable;           // Enable writing to memory
    //reg decoded_nzp_write_enable;           // Enable writing to NZP register
    reg [1:0] decoded_reg_input_mux;        // Select input to register
    reg [1:0] decoded_alu_arithmetic_mux;   // Select arithmetic operation
    reg decoded_alu_output_mux;             // Select operation in ALU
    reg decoded_pc_mux;                     // Select source of next PC
    reg decoded_ret;

    wire decoded_predicate_write_enable;
    wire decoded_always_execute;
	wire decoded_alu;
	wire decoded_tensor_core;
	wire [3:0] predicate_value[THREADS_PER_BLOCK-1:0];
    wire decoded_predicate_on;

    // Fetcher
    fetcher #(
        .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
        .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS)
    ) fetcher_instance (
        .clk(clk),
        .reset(reset),
        .core_state(core_state),
        .current_pc(current_pc),
        .mem_read_valid(program_mem_read_valid),
        .mem_read_address(program_mem_read_address),
        .mem_read_ready(program_mem_read_ready),
        .mem_read_data(program_mem_read_data),
        .fetcher_state(fetcher_state),
        .instruction(instruction) 
    );

    // Decoder
    decoder  #(
        .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
        .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS)
    ) decoder_instance (
        .clk(clk),
        .reset(reset),
        .core_state(core_state),
        .instruction(instruction),
        .decoded_rd_address(decoded_rd_address),
        .decoded_rs_address(decoded_rs_address),
        .decoded_rt_address(decoded_rt_address),
        .decoded_predicate_address(decoded_predicate_address),
        .decoded_immediate(decoded_immediate),
        .decoded_reg_write_enable(decoded_reg_write_enable),
        .decoded_mem_read_enable(decoded_mem_read_enable),
        .decoded_mem_write_enable(decoded_mem_write_enable),
        
        .decoded_reg_input_mux(decoded_reg_input_mux),
        .decoded_alu_arithmetic_mux(decoded_alu_arithmetic_mux),
        .decoded_alu_output_mux(decoded_alu_output_mux),
        .decoded_pc_mux(decoded_pc_mux),
        .decoded_ret(decoded_ret),
        .decoded_predicate_write_enable(decoded_predicate_write_enable),
        .decoded_always_execute(decoded_always_execute),
        .decoded_predicate_on(decoded_predicate_on)
    );

    // Scheduler
    scheduler #(
         
        .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
        .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) scheduler_instance (
        .clk(clk),
        .reset(reset),
        .start(start),
        .fetcher_state(fetcher_state),
        .core_state(core_state),
       
        .decoded_ret(decoded_ret),
       
        .lsu_state(lsu_state),
        .current_pc(current_pc),
        .next_pc(next_pc),
        .done(done)
    );

    // Dedicated ALU, LSU, registers, & PC unit for each thread this core has capacity for

    //tensor_core
    tensor tensorcore (
	.clk					(clk),
	.reset					(reset),
	.enable					(thread_count==16),
	.core_state				(core_state),
	.rs						({rs[0],rs[1],rs[2],rs[3],rs[4],rs[5],rs[6],rs[7],rs[8],rs[9],rs[10],rs[11],rs[12],rs[13],rs[14],rs[15]}),
	.rt						({rt[0],rt[1],rt[2],rt[3],rt[4],rt[5],rt[6],rt[7],rt[8],rt[9],rt[10],rt[11],rt[12],rt[13],rt[14],rt[15]} ),
	.tensor_out				({tensor_out[0],tensor_out[1],tensor_out[2],tensor_out[3],tensor_out[4],tensor_out[5],tensor_out[6],tensor_out[7],tensor_out[8],tensor_out[9],tensor_out[10],tensor_out[11],tensor_out[12],tensor_out[13],tensor_out[14],tensor_out[15]} ),
   
    .decoded_always_execute(decoded_always_execute)
);
// Program Counter
            pc #(
                .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS),
                .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS)
            ) pc_instance (
                .clk(clk),
                .reset(reset),
              
                .core_state(core_state),
              
                .decoded_pc_mux(decoded_pc_mux),
               
                .current_pc(current_pc),
                .next_pc(next_pc),
                
                .decoded_always_execute(decoded_always_execute)
               
                //.predicate_value({predicate_value[0],predicate_value[1],predicate_value[2],predicate_value[3],predicate_value[4],predicate_value[5],predicate_value[6],predicate_value[7],predicate_value[8],predicate_value[9],predicate_value[10],predicate_value[11],predicate_value[12],predicate_value[13],predicate_value[14],predicate_value[15]})
            );
    genvar i;
    generate
        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin : threads
            // ALU
            alu alu_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .core_state(core_state),
                .decoded_alu_arithmetic_mux(decoded_alu_arithmetic_mux),
                .decoded_alu_output_mux(decoded_alu_output_mux),
                .rs(rs[i]),
                .rt(rt[i]),
                .alu_out(alu_out[i]),
                .predicate(predicate_value[i]),
                .decoded_always_execute(decoded_always_execute),
                .decoded_predicate_on(decoded_predicate_on)
            );

            // LSU
                lsu lsu_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .core_state(core_state),
                .decoded_mem_read_enable(decoded_mem_read_enable),
                .decoded_mem_write_enable(decoded_mem_write_enable),
                .mem_read_valid(data_mem_read_valid[i]),
                // 使用位选语法访问地址段：i*ADDR_BITS 起始，取 ADDR_BITS 位
                .mem_read_address(data_mem_read_address[i*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS]),
                .mem_read_ready(data_mem_read_ready[i]),
                // 数据段访问同理
                .mem_read_data(data_mem_read_data[i*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS]),
                .mem_write_valid(data_mem_write_valid[i]),
                .mem_write_address(data_mem_write_address[i*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS]),
                .mem_write_data(data_mem_write_data[i*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS]),
                .mem_write_ready(data_mem_write_ready[i]),
                .rs(rs[i]),
                .rt(rt[i]),
                .lsu_state(lsu_state[i*2 +: 2]),
                .lsu_out(lsu_out[i])
               
            );

            // Register File
            registers #(
                .THREADS_PER_BLOCK(THREADS_PER_BLOCK),
                .THREAD_ID(i),
                .DATA_BITS(DATA_MEM_DATA_BITS)
            )  register_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .block_id(block_id),
                .core_state(core_state),
                .decoded_reg_write_enable(decoded_reg_write_enable),
                .decoded_reg_input_mux(decoded_reg_input_mux),
                .decoded_rd_address(decoded_rd_address),
                .decoded_rs_address(decoded_rs_address),
                .decoded_rt_address(decoded_rt_address),
                .decoded_immediate(decoded_immediate),
                .decoded_predicate_address(decoded_predicate_address),
                .alu_out(alu_out[i]),
                .lsu_out(lsu_out[i]),
                .tensor_out(tensor_out[i]),
                .rs(rs[i]),
                .rt(rt[i]),
                .predicate_value(predicate_value[i]),
                .decoded_predicate_write_enable(decoded_predicate_write_enable),
                .decoded_always_execute(decoded_always_execute),
                .decoded_predicate_on(decoded_predicate_on)
            );

            
        end
    endgenerate
endmodule
