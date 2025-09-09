`default_nettype none
`timescale 1ns/1ns

// REGISTER FILE

// > Read-only registers hold the familiar %blockIdx, %blockDim, and %threadIdx values critical to SIMD
module registers #(
    parameter THREADS_PER_BLOCK = 4,
    parameter THREAD_ID = 0,
    parameter DATA_BITS = 8

) (
    input wire clk,
    input wire reset,
    input wire enable, // If current block has less threads then block size, some registers will be inactive

    // Kernel Execution
    input wire [7:0] block_id,

    // State
    input wire [2:0] core_state,

    // Instruction Signals
    input wire [7:0] decoded_rd_address,
    input wire [7:0] decoded_rs_address,
    input wire [7:0] decoded_rt_address,
    input wire [1:0] decoded_predicate_address,

    // Control Signals
    input wire decoded_reg_write_enable,
    input wire [1:0] decoded_reg_input_mux,
    input wire [DATA_BITS-1:0] decoded_immediate,

    input wire decoded_predicate_on,

    
    input wire decoded_always_execute,
    input wire decoded_predicate_write_enable,

    // Thread Unit Outputs
    input wire [DATA_BITS-1:0] alu_out,
    input wire [DATA_BITS-1:0] lsu_out,
    input wire [DATA_BITS-1:0] tensor_out,
    
    // Registers
    output reg [DATA_BITS-1:0] rs,
    output reg [DATA_BITS-1:0] rt,
    output reg [3:0] predicate_value //谓词寄存器P0-P3
);
    localparam ARITHMETIC = 2'b00,
        MEMORY = 2'b01,
        CONSTANT = 2'b10,
        GEMM_OUT = 2'b11;

 integer i;
    // GPR寄存器
    reg [7:0] registers[255:0];
    reg [3:0] predicate_reg;

    always @(posedge clk) begin
        if (reset) begin
            // Empty rs, rt
            rs <= 0;
            rt <= 0;
            predicate_value <= 0;
             predicate_reg <= 0;
            // Initialize all free registers
            for (i = 0; i < 253; i = i + 1) begin
            registers[0] <= 8'b0;
        end
            
            // Initialize read-only registers
            registers[253] <= 8'b0;              // %blockIdx
            registers[254] <= THREADS_PER_BLOCK; // %blockDim
            registers[255] <= THREAD_ID;         // %threadIdx
        end else if (enable) begin 
            // [Bad Solution] Shouldn't need to set this every cycle
            registers[253] <= block_id; // Update the block_id when a new block is issued from j dispatcher
            
            // Fill rs/rt when core_state = REQUEST
            if (core_state == 3'b011) begin 
                
                    rs <= registers[decoded_rs_address];
                    rt <= registers[decoded_rt_address];
                    predicate_value <= predicate_reg[decoded_predicate_address];
                

                
            end

            // Store rd when core_state = UPDATE
            if (core_state == 3'b110) begin 
                if (decoded_predicate_write_enable) begin 
                    //设置谓词
                    
                        predicate_reg[decoded_predicate_address] <= alu_out[0];
                end 
                // Only allow writing to R0 - R12
                if (decoded_reg_write_enable && decoded_rd_address < 13) begin
                     if (decoded_always_execute || (predicate_value[decoded_predicate_address] && decoded_predicate_on)||(!decoded_predicate_on)) begin 
                        //总是执行的指令&&谓词寄存器为真的线程&&不使用寄存器的指令
                    case (decoded_reg_input_mux)
                        ARITHMETIC: begin 
                            // ADD, SUB, MUL
                            registers[decoded_rd_address] <= alu_out;
                        end
                        MEMORY: begin 
                            // LDR
                            registers[decoded_rd_address] <= lsu_out;
                        end
                        CONSTANT: begin 
                            // CONST
                            registers[decoded_rd_address] <= decoded_immediate;
                        end
                        GEMM_OUT:begin
                            //GEMM输出
                            registers[decoded_rd_address] <= tensor_out;
                        end
                    endcase
                    end
                end
            end
        end
    end

  



endmodule
