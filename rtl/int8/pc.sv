`default_nettype none
`timescale 1ns/1ns

// PROGRAM COUNTER

module pc #(
    parameter DATA_MEM_DATA_BITS = 8,
    parameter PROGRAM_MEM_ADDR_BITS = 8
) (
    input wire clk,
    input wire reset,
    input wire enable, // If current block has less threads then block size, some PCs will be inactive

    // State
    input wire [2:0] core_state,

    // Control Signals
    
    //input wire [DATA_MEM_DATA_BITS-1:0] decoded_immediate,
    
    input wire decoded_pc_mux, 

    
    

    // Current & Next PCs
    input wire [PROGRAM_MEM_ADDR_BITS-1:0] current_pc,
    output reg [PROGRAM_MEM_ADDR_BITS-1:0] next_pc,

    //input wire decoded_predicate_write_enable,
    input wire decoded_always_execute

    //input reg [4*16-1:0]predicate_value // 当前谓词值
    
);
   
   

    always @(posedge clk) begin
        if (reset) begin
           
            next_pc <= 0;
          
           
        end else  begin
            

            // Update PC when core_state = EXECUTE
            // 计算next_pc
            if (core_state == 3'b101) begin 
                if (decoded_always_execute) begin 
                    // 总是执行的指令
                    if (decoded_pc_mux == 1) begin 
                         
                            next_pc <= current_pc + 1;
                        
                    end else begin 
                        next_pc <= current_pc + 1;
                    end
                end else begin 
                    //有谓词执行时的PC同步
                    next_pc <= current_pc + 1;
                end
            end

             
        end
    end

endmodule
