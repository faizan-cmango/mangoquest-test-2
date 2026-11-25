module sync_fifo (
  input  logic        core_clk,
  input  logic        rst_n,
  input  logic        in_valid,
  output logic        in_ready,
  input  logic [31:0] in_data,
  output logic        out_valid,
  input  logic        out_ready,
  output logic [31:0] out_data
);
  // 15-word body store plus a dedicated output register: 16 words in total.
  logic [31:0] mem [0:15];
  logic [3:0]  wr, rd;
  logic [3:0]  msize;   // words in mem, 0..15
  logic        run;
  wire full  = out_valid & (msize == 4'd15);
  assign in_ready = run & (~full | out_ready);
  wire enq    = in_valid & in_ready;
  wire deq    = out_valid & out_ready;
  wire load   = ~out_valid | deq;
  wire popm   = load & (msize != 4'd0);
  wire direct = load & (msize == 4'd0) & enq;
  wire push   = enq & ~direct;
  always_ff @(posedge core_clk) begin
    if (!rst_n) begin
      wr <= 4'd0; rd <= 4'd0; msize <= 4'd0; run <= 1'b0;
      out_valid <= 1'b0; out_data <= 32'd0;
    end else begin
      run <= 1'b1;
      if (load) begin
        if (msize != 4'd0) begin out_data <= mem[rd]; out_valid <= 1'b1; end
        else if (enq)      begin out_data <= in_data; out_valid <= 1'b1; end
        else               begin out_data <= 32'd0;   out_valid <= 1'b0; end
      end
      if (push) begin mem[wr] <= in_data; wr <= wr + 4'd1; end
      if (popm) rd <= rd + 4'd1;
      msize <= msize + {3'd0, push} - {3'd0, popm};
    end
  end
endmodule
