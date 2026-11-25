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
  // output stage O (1) + pre-read stage P (1) + 14-word body = 16 words.
  logic [31:0] mem [0:13];
  logic [31:0] pre;
  logic        pv, run;
  logic [3:0]  wr, rd, msize;
  wire full  = out_valid & pv & (msize == 4'd14);
  assign in_ready = run & (~full | out_ready);
  wire enq    = in_valid & in_ready;
  wire deq    = out_valid & out_ready;
  wire olood  = ~out_valid | deq;
  wire takep  = olood & pv;
  wire pload  = ~pv | takep;
  wire bne    = (msize != 4'd0);
  wire toO    = enq & olood & ~pv;
  wire toP    = enq & pload & ~bne & ~toO;
  wire popm   = pload & bne;
  wire push   = enq & ~toO & ~toP;
  always_ff @(posedge core_clk) begin
    if (!rst_n) begin
      wr <= 4'd0; rd <= 4'd0; msize <= 4'd0; run <= 1'b0;
      out_valid <= 1'b0; out_data <= 32'd0; pv <= 1'b0; pre <= 32'd0;
    end else begin
      run <= 1'b1;
      if (olood) begin
        if (pv)       begin out_data <= pre;     out_valid <= 1'b1; end
        else if (enq) begin out_data <= in_data; out_valid <= 1'b1; end
        else          begin out_data <= 32'd0;   out_valid <= 1'b0; end
      end
      if (pload) begin
        if (bne)      begin pre <= mem[rd];  pv <= 1'b1; end
        else if (toP) begin pre <= in_data;  pv <= 1'b1; end
        else          begin pv <= 1'b0; end
      end
      if (push) begin mem[wr] <= in_data; wr <= (wr == 4'd13) ? 4'd0 : wr + 4'd1; end
      if (popm) rd <= (rd == 4'd13) ? 4'd0 : rd + 4'd1;
      msize <= msize + {3'd0, push} - {3'd0, popm};
    end
  end
endmodule
