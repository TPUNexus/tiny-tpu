// This module controls the fifo signals
// It set the enble of fifo to sequentially store fifo into mmu by col
// Alan Qin
// Apri 22 2019
module fifo_control(
  clk,
  reset,
  active,
  fifo_en
  );

  parameter fifo_width = 4;

  input clk, reset, active;
  output reg [fifo_width-1:0] fifo_en;
  reg [fifo_width-1:0] fifo_en_c;
  reg fifo_dec; // enable starts to decrease
  reg state, state_c;

  parameter Hold = 1'b0;
  parameter Start = 1'b1;

  always@(posedge clk) begin
    fifo_en <= fifo_en_c;
    state <= state_c;
  end

  always@(*) begin
    case (state)
      Hold: begin
        if(active) begin
          state_c = Start;
        end
      end

      Start: begin
        if(fifo_en == 4'b1111) begin
          fifo_dec = 1;
        end

        if(fifo_dec) begin
          fifo_en_c = fifo_en << 1;
        end

        else begin
          fifo_en_c = (fifo_en << 1) + 1;
        end
      end
      endcase

    if(reset) begin
      fifo_en_c = 4'b0000;
      state_c = Hold;
    end
  end
endmodule
