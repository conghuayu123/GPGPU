`timescale 1ns/1ns

module controller #(
    parameter ADDR_BITS = 8,
    parameter DATA_BITS = 16,
    parameter NUM_CONSUMERS = 4,
    parameter NUM_CHANNELS = 1,
    parameter WRITE_ENABLE = 1
) (
    input wire clk,
    input wire reset,

    // Consumer Interface (扁平化为一维)
    input wire [NUM_CONSUMERS-1:0] consumer_read_valid,
    input wire [NUM_CONSUMERS*ADDR_BITS-1:0] consumer_read_address, // 一维向量
    output reg [NUM_CONSUMERS-1:0] consumer_read_ready,
    output reg [NUM_CONSUMERS*DATA_BITS-1:0] consumer_read_data,    // 一维向量
    input wire [NUM_CONSUMERS-1:0] consumer_write_valid,
    input wire [NUM_CONSUMERS*ADDR_BITS-1:0] consumer_write_address, // 一维向量
    input wire [NUM_CONSUMERS*DATA_BITS-1:0] consumer_write_data,   // 一维向量
    output reg [NUM_CONSUMERS-1:0] consumer_write_ready,

    // Memory Interface (扁平化为一维)
    output reg [NUM_CHANNELS-1:0] mem_read_valid,
    output reg [NUM_CHANNELS*ADDR_BITS-1:0] mem_read_address,      // 一维向量
    input wire [NUM_CHANNELS-1:0] mem_read_ready,
    input wire [NUM_CHANNELS*DATA_BITS-1:0] mem_read_data,         // 一维向量
    output reg [NUM_CHANNELS-1:0] mem_write_valid,
    output reg [NUM_CHANNELS*ADDR_BITS-1:0] mem_write_address,     // 一维向量
    output reg [NUM_CHANNELS*DATA_BITS-1:0] mem_write_data,        // 一维向量
    input wire [NUM_CHANNELS-1:0] mem_write_ready
);

    localparam IDLE = 3'b000, 
        READ_WAITING = 3'b010, 
        WRITE_WAITING = 3'b011,
        READ_RELAYING = 3'b100,
        WRITE_RELAYING = 3'b101;

    reg [2:0] controller_state [NUM_CHANNELS-1:0];
    reg [$clog2(NUM_CONSUMERS)-1:0] current_consumer [NUM_CHANNELS-1:0];
    reg [NUM_CONSUMERS-1:0] channel_serving_consumer;
    integer i ;

    always @(posedge clk) begin
        if (reset) begin 
            mem_read_valid <= 0;
            mem_read_address <= 0;
            mem_write_valid <= 0;
            mem_write_address <= 0;
            mem_write_data <= 0;
            consumer_read_ready <= 0;
            consumer_read_data <= 0;
            consumer_write_ready <= 0;
            for (i=0; i<NUM_CHANNELS; i = i + 1) begin
                controller_state[i] <= IDLE;
                current_consumer[i] <= 0;
            end
            channel_serving_consumer <= 0;
        end else begin 
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin 
                case (controller_state[i])
                    IDLE: begin

                        if (consumer_read_valid[i] && !channel_serving_consumer[i]) begin 
                                channel_serving_consumer[i] <= 1;
                                current_consumer[i] <= i;
                                mem_read_valid[i] <= 1;
                                // 地址分段赋值：j*ADDR_BITS 起始，取 ADDR_BITS 位
                                mem_read_address[i*ADDR_BITS +: ADDR_BITS] <= 
                                    consumer_read_address[i*ADDR_BITS +: ADDR_BITS];
                                controller_state[i] <= READ_WAITING;
                               // break;
                            end else if (WRITE_ENABLE && consumer_write_valid[i] && !channel_serving_consumer[i]) begin 
                                channel_serving_consumer[i] <= 1;
                                current_consumer[i] <= i;
                                mem_write_valid[i] <= 1;
                                mem_write_address[i*ADDR_BITS +: ADDR_BITS] <= 
                                    consumer_write_address[i*ADDR_BITS +: ADDR_BITS];
                                mem_write_data[i*DATA_BITS +: DATA_BITS] <= 
                                    consumer_write_data[i*DATA_BITS +: DATA_BITS];
                                controller_state[i] <= WRITE_WAITING;
                              //  break;
                            end
                    end
                    READ_WAITING: begin
                        if (mem_read_ready[i]) begin 
                            mem_read_valid[i] <= 0;
                            consumer_read_ready[current_consumer[i]] <= 1;
                            // 分段写入读返回数据
                            consumer_read_data[current_consumer[i]*DATA_BITS +: DATA_BITS] <= 
                                mem_read_data[i*DATA_BITS +: DATA_BITS];
                            controller_state[i] <= READ_RELAYING;
                        end
                    end
                    WRITE_WAITING: begin 
                        if (mem_write_ready[i]) begin 
                            mem_write_valid[i] <= 0;
                            consumer_write_ready[current_consumer[i]] <= 1;
                            controller_state[i] <= WRITE_RELAYING;
                        end
                    end
                    READ_RELAYING: begin
                        if (!consumer_read_valid[current_consumer[i]]) begin 
                            channel_serving_consumer[current_consumer[i]] <= 0;
                            consumer_read_ready[current_consumer[i]] <= 0;
                            controller_state[i] <= IDLE;
                        end
                    end
                    WRITE_RELAYING: begin 
                        if (!consumer_write_valid[current_consumer[i]]) begin 
                            channel_serving_consumer[current_consumer[i]] <= 0;
                            consumer_write_ready[current_consumer[i]] <= 0;
                            controller_state[i] <= IDLE;
                        end
                    end
                endcase
            end
        end
    end
endmodule
