`default_nettype none
`timescale 1ns/1ns

// ARITHMETIC-LOGIC UNIT
// > Executes computations on register values
// > In this minimal implementation, the ALU supports the 4 basic arithmetic operations
// > Each thread in each core has it's own ALU
// > ADD, SUB, MUL, DIV instructions are all executed here
module alu (
    input wire clk,
    input wire reset,
    input wire enable, // If current block has less threads then block size, some ALUs will be inactive

    input wire [2:0] core_state,

    input wire [1:0] decoded_alu_arithmetic_mux,
    input wire decoded_alu_output_mux,


    input wire [3:0] predicate,
    
    input wire decoded_always_execute,
    input wire decoded_predicate_on,

    input wire [7:0] rs,
    input wire [7:0] rt,
    output wire [7:0] alu_out
);
    

    reg [7:0] alu_out_reg;
    reg alu_out_preg;
    reg fp8_alu_out;
    int8_to_fp8 int8_to_fp8_inst(
        .int8_data(alu_out_reg),
        .fp8_data(fp8_alu_out)
    );
   assign alu_out = decoded_alu_output_mux?{7'b0,alu_out_preg}:fp8_alu_out;

   localparam ADD = 2'b00,
        SUB = 2'b01,
        MUL = 2'b10,
        DIV = 2'b11;

    always @(posedge clk) begin 
        if (reset) begin 
            alu_out_reg <= 8'b0;
        end else if (enable) begin
            // Calculate alu_out when core_state = EXECUTE
            if (core_state == 3'b101) begin 
                if (decoded_always_execute || (predicate && decoded_predicate_on)||(!decoded_predicate_on)) begin 
                    if (decoded_alu_output_mux == 1) begin 
                    // Set values to compare with NZP register in alu_out[2:0]
                        alu_out_preg <=  (rs < rt);
                    end else begin 
                    // Execute the specified arithmetic instruction
                        case (decoded_alu_arithmetic_mux)
                            ADD: begin 
                            alu_out_reg <= rs + rt;
                            end
                            SUB: begin 
                            alu_out_reg <= rs - rt;
                            end
                            MUL: begin 
                            alu_out_reg <= rs * rt;
                            end
                            DIV: begin 
                            alu_out_reg <= rs / rt;
                            end
                        endcase
                    end
                end
            end
        end
    end
endmodule
