module top (
    clk,
    reset,
    active,
    inputMem_wr_en,
    inputMem_wr_addr,
    inputMem_wr_data,
    inputMem_rd_addr_base,
    outputMem_rd_en,
    outputMem_rd_addr,
    outputMem_wr_addr_base,
    outputMem_rd_data,
    weightMem_wr_en,
    weightMem_wr_addr,
    weightMem_wr_data,
    weightMem_rd_addr_base,
    fill_fifo,
    drain_fifo,
    mem_to_fifo_done,
    fifo_to_arr_done,
    output_done
 );


// ========================================
// ---------- Parameters ------------------
// ========================================

    parameter WIDTH_HEIGHT = 16;
    parameter DATA_WIDTH = 8;
    parameter MAX_MAT_WH = 128;


// ========================================
// ------------ Inputs --------------------
// ========================================
    input clk;
    input reset;

    // start signal for matrix multiply
    input active;

    // input memory signals
    input [WIDTH_HEIGHT - 1:0] inputMem_wr_en;
    input [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] inputMem_wr_addr;
    input [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] inputMem_wr_data;

    // base read address (input) for matrix multiply
    input [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] inputMem_rd_addr_base;

    // output memory signals
    input [WIDTH_HEIGHT - 1:0] outputMem_rd_en;
    input [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] outputMem_rd_addr;

    // base write address (output) for matrix multiply
    input [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] outputMem_wr_addr_base;

    // weight memory signals
    input [WIDTH_HEIGHT - 1:0] weightMem_wr_en;
    input [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] weightMem_wr_addr;
    input [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] weightMem_wr_data;
    input [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] weightMem_rd_addr_base;

    // FIFO stuff
    input fill_fifo;
    input drain_fifo;


// ========================================
// ------------ Outputs -------------------
// ========================================
    // tell host cpu when loading weights is done
    output mem_to_fifo_done;
    // tell host CPU when multiply is done
    output fifo_to_arr_done;
    output output_done;

    // output memory read port
    output [(WIDTH_HEIGHT * DATA_WIDTH * 2) - 1:0] outputMem_rd_data;


// ========================================
// ------- Local Wires and Regs -----------
// ========================================
    wire [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] inputMem_to_sysArr;
    wire [WIDTH_HEIGHT - 1:0] inputMem_rd_en;
    wire [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] inputMem_rd_addr_offset;
    wire [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] weightMem_rd_data;
    wire [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] weightFIFO_to_sysArr;
    wire [WIDTH_HEIGHT - 1:0] outputMem_wr_en;
    //wire [(WIDTH_HEIGHT * 16) - 1:0] sysArr_to_outputMem;
    wire [WIDTH_HEIGHT - 1:0] accumTable_wr_control_en_in;
    wire [2*DATA_WIDTH*WIDTH_HEIGHT-1:0] accumTable_wr_data;
    wire [$clog2(MAX_MAT_WH * (MAX_MAT_WH/WIDTH_HEIGHT))*WIDTH_HEIGHT-1:0] accumTable_wr_addr;
    wire [WIDTH_HEIGHT-1:0] accumTable_wr_en_in;
    wire [$clog2(MAX_MAT_WH * (MAX_MAT_WH/WIDTH_HEIGHT))*WIDTH_HEIGHT-1:0] accumTable_rd_addr;
    wire [2*DATA_WIDTH*WIDTH_HEIGHT-1:0] accumTable_data_out_to_relu;
    wire [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] outputMem_wr_addr_offset;
    wire [(WIDTH_HEIGHT * 16) - 1:0] outputMem_wr_data;
    wire [WIDTH_HEIGHT - 1:0] mem_to_fifo_en;
    wire [WIDTH_HEIGHT - 1:0] fifo_to_arr_en;
    wire rd_to_wr_start;
    wire mem_to_fifo;

    wire [(WIDTH_HEIGHT * DATA_WIDTH) - 1:0] weightMem_rd_addr_offset;
    wire [WIDTH_HEIGHT - 1:0] weightMem_rd_en;
    wire weight_write;

    // set sys_arr_active 2 cycles after we start reading memory
    wire sys_arr_active;
    reg sys_arr_active1;
    reg sys_arr_active2;

    // counter for the accumulator table write input (will later satisfied by master controller instead)
    reg [$clog2(WIDTH_HEIGHT)-1:0] accumTable_row_count;
    reg [$clog2(WIDTH_HEIGHT)-1:0] accumTable_row_count_c;

// ========================================
// -------------- Logic -------------------
// ========================================

    // sys_arr_active 2 cycles after we start reading memory
    assign sys_arr_active = inputMem_rd_en[0];


// ========================================
// ------- Module Instantiations ----------
// ========================================

    sysArr sysArr(
        .clk      (clk),
        .active   (sys_arr_active2),            // from control or software
        .datain   (inputMem_to_sysArr),         // from input memory
        .win      (weightFIFO_to_sysArr),       // from weight FIFO's
        .sumin    (256'd0),                     // Can be used for biases
        .wwrite   ({16{weight_write}}),         // from control
        .maccout  (accumTable_wr_data),         // to accumulator table
        .wout     (),                           // Not used
        .wwriteout(),                           // Not used
        .activeout(accumTable_wr_control_en_in),// Enable bit for accumTable_wr_control
        .dataout  ()                            // Not used
    );
    defparam sysArr.width_height = WIDTH_HEIGHT;


// =========================================
// --------- Input Side of Array -----------
// =========================================
    
    memArr inputMem(
        .clk    (clk),
        .rd_en  (inputMem_rd_en),               // from control
        .wr_en  (inputMem_wr_en),               // from interconnect (INPUT)
        .wr_data(inputMem_wr_data),             // from interconnect (INPUT)
        .rd_addr(inputMem_rd_addr_base + inputMem_rd_addr_offset),  // from control & interconnect
        .wr_addr(inputMem_wr_addr),             // from interconnect (INPUT)
        .rd_data(inputMem_to_sysArr)            // to sysArr
    );
    defparam inputMem.width_height = WIDTH_HEIGHT;

    rd_control inputMemControl (
        .clk    (clk),
        .reset  (reset),
        .active (active),                       // tied to sysArr Active
        .rd_en  (inputMem_rd_en),               // to input memory
        .rd_addr(inputMem_rd_addr_offset),      // to input memory
        .wr_active(rd_to_wr_start)              // to wr_control
    );
    defparam inputMemControl.width_height = WIDTH_HEIGHT;


// ========================================
// --------- Weight side of Array ---------
// ========================================
    
    memArr weightMem(
        .clk    (clk),
        .rd_en  (weightMem_rd_en),              // from interconnect
        .wr_en  (weightMem_wr_en),              // from interconnect
        .wr_data(weightMem_wr_data),            // from interconnect
        .rd_addr(weightMem_rd_addr_base + weightMem_rd_addr_offset), // from interconnect
        .wr_addr(weightMem_wr_addr),            // from interconnect
        .rd_data(weightMem_rd_data)             // to weightFIFO
    );
    defparam weightMem.width_height = WIDTH_HEIGHT;

    fifo_control mem_fifo (
        .clk         (clk),
        .reset       (reset),
        .active      (mem_to_fifo),             // from interconnect
        .stagger_load(1'b0),
        .fifo_en     (mem_to_fifo_en),          // to weightFIFO's
        .done        (mem_to_fifo_done),        // to interconect
        .weight_write()                         // not used
    );
    defparam mem_fifo.fifo_width = WIDTH_HEIGHT;

    fifo_fill_control fifo_fill_control (
        .clk              (clk),
        .reset            (reset),
        .active           (fill_fifo),
        .mem_to_fifo      (mem_to_fifo),
        .weightMem_rd_addr(weightMem_rd_addr_offset),
        .weightMem_rd_en  (weightMem_rd_en)
    );
    defparam fifo_fill_control.WIDTH_HEIGHT = WIDTH_HEIGHT;

    fifo_control fifo_arr (
        .clk         (clk),
        .reset       (reset),
        .active      (drain_fifo),             // from interconnect
        .stagger_load(1'b0),
        .fifo_en     (fifo_to_arr_en),          // to weightFIFO's
        .done        (fifo_to_arr_done),        // to interconnect
        .weight_write(weight_write)             // to sysArr
    );
    defparam fifo_arr.fifo_width = WIDTH_HEIGHT;

    weightFifo weightFIFO (
        .clk      (clk),
        .reset    (reset),
        .en       (mem_to_fifo_en | fifo_to_arr_en), // from fifoControl
        .weightIn (weightMem_rd_data),          // from weightMem
        .weightOut(weightFIFO_to_sysArr)        // to sysArr
    );
    defparam weightFIFO.DATA_WIDTH = DATA_WIDTH;
    defparam weightFIFO.FIFO_INPUTS = WIDTH_HEIGHT;
    defparam weightFIFO.FIFO_DEPTH = WIDTH_HEIGHT;


// =========================================
// --------- Output side of array ----------
// =========================================
    
    accumTable accumTable (
        .clk    (clk),
        .clear  ({WIDTH_HEIGHT{reset}}), // TODO: OR with a clear signal (from master control)
        .rd_en  ({WIDTH_HEIGHT{1'b1}}),
        .wr_en  (accumTable_wr_en_in),
        .rd_addr(accumTable_rd_addr),
        .wr_addr(accumTable_wr_addr),
        .rd_data(accumTable_data_out_to_relu), // to ReLU module
        .wr_data(accumTable_wr_data)
    );
    defparam accumTable.SYS_ARR_ROWS = WIDTH_HEIGHT;
    defparam accumTable.SYS_ARR_COLS = WIDTH_HEIGHT;
    defparam accumTable.DATA_WIDTH = 2*DATA_WIDTH;
    defparam accumTable.MAX_OUT_ROWS = MAX_MAT_WH;
    defparam accumTable.MAX_OUT_COLS = MAX_MAT_WH;

    accumTableRd_control accumTableRd_control (
        .sub_row    (4'b0000),
        .submat_m   (3'b000),
        .submat_n   (3'b000),
        .rd_addr_out(accumTable_rd_addr)
    );
    defparam accumTableRd_control.SYS_ARR_ROWS = WIDTH_HEIGHT;
    defparam accumTableRd_control.SYS_ARR_COLS = WIDTH_HEIGHT;
    defparam accumTableRd_control.MAX_OUT_ROWS = MAX_MAT_WH;
    defparam accumTableRd_control.MAX_OUT_COLS = MAX_MAT_WH;

    accumTableWr_control accumTableWr_control (
        .clk        (clk),
        .reset      (reset),
        .wr_en_in   (accumTable_wr_control_en_in[0]), // enable bit for the first column that is latched and passed along
        .sub_row    (accumTable_row_count), // subrow for the first column that is latches like wr_en_in. Controlled by master controller.
        .submat_m   (3'b000),
        .submat_n   (3'b000),
        .wr_en_out  (accumTable_wr_en_in),
        .wr_addr_out(accumTable_wr_addr)
    );
    defparam accumTableWr_control.SYS_ARR_ROWS = WIDTH_HEIGHT;
    defparam accumTableWr_control.SYS_ARR_COLS = WIDTH_HEIGHT;
    defparam accumTableWr_control.MAX_OUT_ROWS = MAX_MAT_WH;
    defparam accumTableWr_control.MAX_OUT_COLS = MAX_MAT_WH;

    reluArr reluArr (
        .en(1'b1),
        .in(accumTable_data_out_to_relu),
        .out(outputMem_wr_data) // to output memory
    );
    defparam reluArr.DATA_WIDTH = 2*DATA_WIDTH;
    defparam reluArr.ARR_INPUTS = WIDTH_HEIGHT;

    outputArr outputMem (
        .clk    (clk),
        .rd_en  (outputMem_rd_en),              // from interconnect
        .wr_en  (outputMem_wr_en),              // from outputMemControl
        .wr_data(outputMem_wr_data),          // from sysArr
        .rd_addr(outputMem_rd_addr),            // from interconnect
        .wr_addr(outputMem_wr_addr_base + outputMem_wr_addr_offset), // outputMemControl + base from interconnect
        .rd_data(outputMem_rd_data)             // to interconect
    );
    defparam outputMem.width_height = WIDTH_HEIGHT;

    wr_control outputMemControl (
        .clk    (clk),
        .reset  (reset),
        .active (rd_to_wr_start),               // ???? don't know source yet (sysArr?)
        .wr_en  (outputMem_wr_en),              // to outputMem
        .wr_addr(outputMem_wr_addr_offset),      // to outputMem
        .done   (output_done),
        .sys_arr_active(sys_arr_active)
    );
    defparam outputMemControl.width_height = WIDTH_HEIGHT;


// ======================================
// ----------- Flip flops ---------------
// ======================================

    always @(*) begin
        if (accumTable_wr_control_en_in[0]) begin
            accumTable_row_count_c = accumTable_row_count + 1; 
        end

        else begin
            accumTable_row_count_c = {$clog2(WIDTH_HEIGHT){0}};
        end
    end

    always @(posedge clk) begin

        // set sys_arr_active 2 cycles after we read memory
        sys_arr_active1 <= sys_arr_active;
        sys_arr_active2 <= sys_arr_active1;
        accumTable_row_count <= accumTable_row_count_c;

    end // always

endmodule // top
