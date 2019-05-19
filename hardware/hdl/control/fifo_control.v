// This module controls the fifo signals
// It set the enble of fifo to sequentially store fifo into mmu by col
// Alan Qin
// Apri 22 2019
module fifo_control(
  clk,
  reset,
  active, // active fifo control
  stagger_load, // en stagger load way
  fifo_en, // output fifo en
  done // done loading fifo
  );

  parameter fifo_width = 16;
  localparam  count_width = $clog2(fifo_width * 2);

  input clk, reset, active, stagger_load;
  output reg [fifo_width-1:0] fifo_en;
  output reg done;
  reg [fifo_width-1:0] fifo_en_c;
  reg fifo_dec; // enable starts to decrease
  reg fifo_start;
  reg [count_width-1:0] count, count_c; // count the number of clock circle

  always@(posedge clk) begin
    fifo_en <= fifo_en_c;
    count <= count_c;
  end

  always@(*) begin
    if(active) begin
      fifo_start = 1;
      done = 0;
    end

    // start generate fifo_en signal 
    if(fifo_start) begin
      // start stagger loading, working for successive fifo loading. 
      if(stagger_load) begin
        if(fifo_en == 16'hffff) begin
          fifo_dec = 1;
        end

        if(fifo_dec) begin
          fifo_en_c = fifo_en >> 1;
          if(fifo_en == 16'h0000) begin
            done = 1;
            fifo_start = 0;
            count_c = 0;
          end
        end

        else begin
          fifo_en_c = (fifo_en >> 1) + 16'h8000;
        end
      end

      // row loading. use for the first time loading of fifo.
      // need fifo_width clock cycle to finish
      else begin
        fifo_en = 16'hffff;
        if(count >= fifo_width) begin
          done = 1;
          fifo_start = 0;
          count_c = 0;
          fifo_en = 16'h0000;
        end
      end

      count_c = count + 1;

    end

    if(reset) begin
      fifo_en_c = 16'h0000;
      fifo_start = 0;
      count_c = 0;
      done = 0;
    end
  end
endmodule
