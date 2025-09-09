`default_nettype none
`timescale 1ns/1ns

// SCHEDULER

module scheduler #(
    parameter THREADS_PER_BLOCK = 16,
    parameter PROGRAM_MEM_ADDR_BITS = 8,
    parameter PROGRAM_MEM_DATA_BITS = 32
) (
    input wire clk,
    input wire reset,
    input wire start,
    
    // Control Signals
    //input wire decoded_mem_read_enable,
    //input wire decoded_mem_write_enable,
    input wire decoded_ret,
   
    //input reg tensor_core_execute_ready,

    // Memory Access State
    input wire [2:0] fetcher_state,
    input wire [2*THREADS_PER_BLOCK-1:0] lsu_state ,

    // Current & Next PC
    output reg [PROGRAM_MEM_ADDR_BITS-1:0] current_pc,
    input wire [PROGRAM_MEM_ADDR_BITS-1:0] next_pc,

    // Execution State
    output reg [2:0] core_state,
    output reg done
);
    localparam IDLE = 3'b000, // Waiting to start
        FETCH = 3'b001,       // Fetch instructions from program memory
        DECODE = 3'b010,      // Decode instructions into control signals
        REQUEST = 3'b011,     // Request data from registers or memory
        WAIT = 3'b100,        // Wait for response from memory if necessary
        EXECUTE = 3'b101,     // Execute ALU and PC calculations
        UPDATE = 3'b110,      // Update registers, NZP, and PC
        DONE = 3'b111;        // Done executing this block
    reg [THREADS_PER_BLOCK-1:0] any_lsu_waiting;
    //lsu 等待逻辑

	//integer i;
genvar i;
    generate
    for ( i = 0; i < THREADS_PER_BLOCK; i=i+1) 
        begin
                        // Make sure no lsu_state = REQUESTING or WAITING
        assign any_lsu_waiting[i] = (lsu_state[i*2 +: 2] == 2'b01 || lsu_state[i*2 +: 2] == 2'b10);
                            
           
        end

    endgenerate

    always @(posedge clk) begin 
        if (reset) begin
            current_pc <= 0;
            core_state <= IDLE;
            done <= 0;
	        //any_lsu_waiting = 0;
        end else begin 
            case (core_state)
                IDLE: begin
                    // Here after reset (before kernel is launched, or after previous block has been processed)
                    if (start) begin 
                        // Start by fetching the next instruction for this block based on PC
                        core_state <= FETCH;
                    end
                end
                FETCH: begin 
                    // Move on once fetcher_state = FETCHED
                    if (fetcher_state == 3'b010) begin 
                        core_state <= DECODE;
                    end
                end
                DECODE: begin
                    // Decode is synchronous so we move on after one cycle
                    core_state <= REQUEST;
                end
                REQUEST: begin 
                    //读取操作数控制
                   
                        core_state <= WAIT;
                    
                end
                WAIT: begin
                    // Wait for all LSUs to finish their request before continuing
                    // any_lsu_waiting = 1'b0;
                    
                    // If no LSU is waiting for a response, move onto the next stage
                    if ( ~any_lsu_waiting ) begin
                        core_state <= EXECUTE;
                    end
                end
                EXECUTE: begin
                  //执行状态控制
                    
                        core_state <= UPDATE;
                    
                   
                    
                end
                UPDATE: begin 
                    //写回状态控制
                    if (decoded_ret) begin 
                        // If we reach a RET instruction, this block is done executing
                        done <= 1;
                        core_state <= DONE;
                    end else begin 
                        // Branch divergence. 
                        //分支同步
                        current_pc <= next_pc;

                        // Update is synchronous so we move on after one cycle
                        core_state <= FETCH;
                    end
                end
                DONE: begin 
                    // no-op
                end
            endcase
        end
    end
endmodule
