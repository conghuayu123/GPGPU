`default_nettype none
`timescale 1ns/1ns

// INSTRUCTION DECODER
// > Decodes an instruction into the control signals necessary to execute it
// > Each core has it's own decoder
module decoder #(
    parameter PROGRAM_MEM_ADDR_BITS = 8,
    parameter PROGRAM_MEM_DATA_BITS = 32
)(
    input wire clk,
    input wire reset,

    input wire [2:0] core_state,
    input wire [PROGRAM_MEM_DATA_BITS-1:0] instruction,
    
    // Instruction Signals
    output reg [7:0] decoded_rd_address,
    output reg [7:0] decoded_rs_address,
    output reg [7:0] decoded_rt_address,
    //output reg [2:0] decoded_nzp,
    output reg [7:0] decoded_immediate,
    
    // Control Signals
    output reg decoded_reg_write_enable,           // Enable writing to a register
    output reg decoded_mem_read_enable,            // Enable reading from memory
    output reg decoded_mem_write_enable,           // Enable writing to memory
    //output reg decoded_nzp_write_enable,           // Enable writing to NZP register
    output reg [1:0] decoded_reg_input_mux,        // Select input to register
    output reg [1:0] decoded_alu_arithmetic_mux,   // Select arithmetic operation
    output reg decoded_alu_output_mux,             // Select operation in ALU
    output reg decoded_pc_mux,                     // Select source of next PC
    output reg decoded_predicate_address,
    
   

    output reg decoded_predicate_write_enable, // 用于SETP指令
    output reg decoded_always_execute,          // 用于总是执行的指令
    output reg decoded_predicate_on,          // 使用谓词指令

    // Return (finished executing thread)
    output reg decoded_ret
);
//基础指令，可自行扩展
//定点浮点数ALU指令
    localparam ADD = 6'b000000,
        SUB = 6'b000001,
        MUL = 6'b000010,
        FADD = 6'b010000,
        FSUB = 6'b010001,
        FMUL = 6'b010010,
//谓词执行下的ALU指令
        PADD = 6'b100000,
        PSUB = 6'b100001,
        PMUL = 6'b100010,
        PFADD = 6'b110000,
        PFSUB = 6'b110001,
        PFMUL = 6'b110010,

//标量矩阵存取指令        
        LDR = 6'b000100,
        MATLDR = 6'b010100,
        STR = 6'b000101,
        MATSTR = 6'b010101,
        GEMM = 6'b000111,
        FGEMM = 6'b10111,
//常值指令
        CONST = 6'b000110,
        FCONST = 6'b010110,
        PCONST  = 6'b101100,  
        PFCONST  = 6'b111100,  
//谓词设置指令
        STEPLT = 6'b001101,//若rs<rt 设置谓词
        //可扩展指令
        
        RET =  6'b111111;

    always @(posedge clk) begin 
        if (reset) begin 
            decoded_rd_address <= 0;
            decoded_rs_address <= 0;
            decoded_rt_address <= 0;
            decoded_immediate <= 0;
            //decoded_nzp <= 0;
            decoded_reg_write_enable <= 0;
            decoded_mem_read_enable <= 0;
            decoded_mem_write_enable <= 0;
            //decoded_nzp_write_enable <= 0;
            decoded_reg_input_mux <= 0;
            decoded_alu_arithmetic_mux <= 0;
            decoded_alu_output_mux <= 0;
            decoded_pc_mux <= 0;
            decoded_ret <= 0;
           decoded_predicate_address <=0;
           
            decoded_predicate_write_enable <= 0;
            decoded_always_execute <= 0;
            decoded_predicate_on <= 0;
        end else begin 
            // Decode when core_state = DECODE
            if (core_state == 3'b010) begin 
                // Get instruction signals from instruction every time
                decoded_rd_address <= instruction[23:16];
                decoded_rs_address <= instruction[15:8];
                decoded_rt_address <= instruction[7:0];
                decoded_immediate <= instruction[7:0];
                //decoded_nzp <= instruction[23:21];
                decoded_predicate_address <= instruction[25:24];

                // Control signals reset on every decode and set conditionally by instruction
                decoded_reg_write_enable <= 0;
                decoded_mem_read_enable <= 0;
                decoded_mem_write_enable <= 0;
                //decoded_nzp_write_enable <= 0;
                decoded_reg_input_mux <= 0;
                decoded_alu_arithmetic_mux <= 0;
                decoded_alu_output_mux <= 0;
                decoded_pc_mux <= 0;
                decoded_ret <= 0;
                
               
                decoded_predicate_write_enable <= 0;
                decoded_always_execute <= 0;
                decoded_predicate_on <= 0;
                // Set the control signals for each instruction
                //设置具体控制信号，可自定义
                case (instruction[31:26])
                    
                   
                   
                    ADD: begin 
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 2'b00;
                         decoded_predicate_on <= 0;
                    end
                    PADD: begin 
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 2'b00;
                        //decoded_alu <= 1;
                        decoded_predicate_on <= 1;
                    end
                    SUB: begin 
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 2'b01;
                        //decoded_alu <= 1;
                        decoded_predicate_on <= 0;
                    end
                    PSUB: begin 
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 2'b01;
                        //decoded_alu <= 1;
                        decoded_predicate_on <= 1;
                    end
                    MUL: begin 
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 2'b10;
                        decoded_predicate_on <= 0;
                    end
                    PMUL: begin 
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 2'b10;
                        //decoded_alu <= 1;
                        decoded_predicate_on <= 1;
                    end
                    
                    LDR: begin 
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b01;
                        decoded_mem_read_enable <= 1;
                        decoded_always_execute <= 1;
                    end
                    STR: begin 
                        decoded_mem_write_enable <= 1;
                        decoded_always_execute <= 1;
                    end
                    CONST: begin 
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b10;
                        decoded_predicate_on <= 0;
                    end
                    PCONST: begin 
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b10;
                        decoded_predicate_on <= 1;
                    end
                    GEMM:begin
                        decoded_reg_write_enable <= 1;
                        
                        decoded_reg_input_mux <= 2'b11;
                        decoded_always_execute <= 1;
                    end
                    STEPLT: begin 
                        decoded_predicate_write_enable <= 1;
                        decoded_alu_output_mux <= 1;
                        //decoded_nzp_write_enable <= 1;
                         decoded_always_execute <= 1;
                        
                        
                       
                    end
                    RET: begin 
                        decoded_ret <= 1;
                        decoded_always_execute <= 1; // RET总是执行
                    end
                endcase
            end
        end
    end
endmodule
