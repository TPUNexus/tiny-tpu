`timescale 1 ps / 1 ps

module tb_top();
    parameter WIDTH_HEIGHT = 16;

    // inputs to DUT
    reg clk;
    reg reset;
    reg active;
    reg [WIDTH_HEIGHT - 1:0] inputMem_wr_en;
    reg [(WIDTH_HEIGHT * 8) - 1:0] inputMem_wr_addr;
    reg [(WIDTH_HEIGHT * 8) - 1:0] inputMem_wr_data;
    reg [(WIDTH_HEIGHT * 8) - 1:0] inputMem_rd_addr_base;
    reg [WIDTH_HEIGHT - 1:0] outputMem_rd_en;
    reg [(WIDTH_HEIGHT * 8) - 1:0] outputMem_rd_addr;
    reg [(WIDTH_HEIGHT * 8) - 1:0] outputMem_wr_addr_base;
    reg [WIDTH_HEIGHT - 1:0] weightMem_wr_en;
    reg [(WIDTH_HEIGHT * 8) - 1:0] weightMem_wr_addr;
    reg [(WIDTH_HEIGHT * 8) - 1:0] weightMem_wr_data;
    reg [WIDTH_HEIGHT - 1:0] weightMem_rd_en;
    reg [(WIDTH_HEIGHT * 8) - 1:0] weightMem_rd_addr;
    reg load_weights_to_array;
    reg [WIDTH_HEIGHT - 1:0] weight_write;

    // outputs from DUT
    wire fifo_done;
    wire [(WIDTH_HEIGHT * 16) - 1:0] outputMem_rd_data;

    // instantiation of DUT
    top DUT (
        .clk                   (clk),
        .reset                 (reset),
        .active                (active),
        .inputMem_wr_en        (inputMem_wr_en),
        .inputMem_wr_addr      (inputMem_wr_addr),
        .inputMem_wr_data      (inputMem_wr_data),
        .inputMem_rd_addr_base (inputMem_rd_addr_base),
        .outputMem_rd_en       (outputMem_rd_en),
        .outputMem_rd_addr     (outputMem_rd_addr),
        .outputMem_wr_addr_base(outputMem_wr_addr_base),
        .weightMem_wr_en       (weightMem_wr_en),
        .weightMem_wr_addr     (weightMem_wr_addr),
        .weightMem_wr_data     (weightMem_wr_data),
        .weightMem_rd_en       (weightMem_rd_en),
        .weightMem_rd_addr     (weightMem_rd_addr),
        .load_weights_to_array (load_weights_to_array),
        .weight_write          (weight_write),
        .fifo_done             (fifo_done),
        .outputMem_rd_data     (outputMem_rd_data)
    );

    // start clock
    always begin
        #5;
        clk = ~clk;
    end // always

    integer i;

    // test suite
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        active = 1'b0;
        inputMem_wr_en = 16'h0000;
        inputMem_wr_addr = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        inputMem_wr_data = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        inputMem_rd_addr_base = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        outputMem_rd_en = 16'h0000;
        outputMem_rd_addr = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        outputMem_wr_addr_base = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        weightMem_wr_en = 16'h0000;
        weightMem_wr_addr = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        weightMem_wr_data = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        weightMem_rd_en = 16'h0000;
        weightMem_rd_addr = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        load_weights_to_array = 1'b0;
        weight_write = 16'h0000;

        #20;

        reset = 1'b0;

        #20;

        // Write to the weight and input Memory
        weightMem_wr_en = 16'hFFFF;
        inputMem_wr_en = 16'hFFFF;
        weightMem_wr_data = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        inputMem_wr_data = 128'h0101_0101_0101_0101_0101_0101_0101_0101;
        weightMem_wr_addr = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        inputMem_wr_addr = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        for (i = 0; i < 16; i = i + 1) begin
            #10;
            weightMem_wr_data = weightMem_wr_data + 128'h0101_0101_0101_0101_0101_0101_0101_0101;
            inputMem_wr_data = inputMem_wr_data + 128'h0101_0101_0101_0101_0101_0101_0101_0101;
            weightMem_wr_addr = weightMem_wr_addr + 128'h0101_0101_0101_0101_0101_0101_0101_0101;
            inputMem_wr_addr = inputMem_wr_addr + 128'h0101_0101_0101_0101_0101_0101_0101_0101;
        end // for
        weightMem_wr_en = 16'h0000;
        inputMem_wr_en = 16'h0000;

        #10;

        // Load weights into FIFO's
        // Need to enable FIFO's
        weightMem_rd_en = 16'hFFFF;
        weightMem_rd_addr = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        for (i = 0; i < 16; i = i + 1) begin
            #10;
            load_weights_to_array = 1'b1; // enables fifos
            weightMem_rd_addr = weightMem_rd_addr + 128'h0101_0101_0101_0101_0101_0101_0101_0101;
        end // for
        weightMem_rd_en = 16'h0000;
        load_weights_to_array = 1'b0;

        #160;

        load_weights_to_array = 1'b1;
        weight_write = 16'hFFFF;

        #160;

        weight_write = 16'h0000;
        load_weights_to_array = 1'b0;

        // At this point, weights are loaded. Begin multiplication.

        active = 1'b1;

        #190;

        active = 1'b0;

        #30;

        $stop;
    end // initial
endmodule // tb_top