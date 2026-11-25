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
  // ADR-07: output stage of 2 words (ping-pong, data loads independent of out_ready),
  // pre-read stage P (1) and body of 14 words. Held words limited to 16 by cnt.
  logic [31:0] o0, o1, pre;
  logic [31:0] mem [0:13];
  logic        ov0, ov1, h, t, pv, run;
  logic [3:0]  wr, rd, msize;
  logic [4:0]  cnt;
  assign out_valid = h ? ov1 : ov0;
  assign out_data  = h ? (ov1 ? o1 : 32'd0) : (ov0 ? o0 : 32'd0);
  wire full = (cnt == 5'd16);
  assign in_ready = run & (~full | out_ready);
  wire enq   = in_valid & in_ready;
  wire deq   = out_valid & out_ready;
  wire tfree = t ? ~ov1 : ~ov0;
  wire bne   = (msize != 4'd0);
  wire mvPO  = pv & tfree;
  wire toO   = enq & ~pv & ~bne & tfree;
  wire pload = ~pv | mvPO;
  wire toP   = enq & ~bne & pload & ~toO;
  wire popm  = bne & pload;
  wire push  = enq & ~toO & ~toP;
  wire setO  = mvPO | toO;
  always_ff @(posedge core_clk) begin
    if (!rst_n) begin
      wr <= 4'd0; rd <= 4'd0; msize <= 4'd0; run <= 1'b0; cnt <= 5'd0;
      ov0 <= 1'b0; ov1 <= 1'b0; h <= 1'b0; t <= 1'b0; pv <= 1'b0;
      o0 <= 32'd0; o1 <= 32'd0; pre <= 32'd0;
    end else begin
      run <= 1'b1;
      cnt <= cnt + {4'd0, enq} - {4'd0, deq};
      // data loads: enables depend on state only
      if (~ov0 & ~t) o0 <= pv ? pre : in_data;
      if (~ov1 &  t) o1 <= pv ? pre : in_data;
      if (pload) pre <= bne ? mem[rd] : in_data;
      if (msize != 4'd14) mem[wr] <= in_data;
      // control
      if (deq & ~h) ov0 <= 1'b0; else if (setO & ~t) ov0 <= 1'b1;
      if (deq &  h) ov1 <= 1'b0; else if (setO &  t) ov1 <= 1'b1;
      if (deq) h <= ~h;
      if (setO) t <= ~t;
      if (pload) pv <= bne | toP;
      if (push) wr <= (wr == 4'd13) ? 4'd0 : wr + 4'd1;
      if (popm) rd <= (rd == 4'd13) ? 4'd0 : rd + 4'd1;
      msize <= msize + {3'd0, push} - {3'd0, popm};
    end
  end
endmodule
