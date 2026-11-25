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
  logic [31:0] mem [0:15];
  logic [3:0]  wr, rd;
  logic [4:0]  cnt;
  logic        run;
  wire full  = (cnt == 5'd16);
  wire empty = (cnt == 5'd0);
  assign in_ready  = run & (~full | out_ready);
  assign out_valid = ~empty;
  assign out_data  = empty ? 32'd0 : mem[rd];
  wire enq = in_valid & in_ready;
  wire deq = out_valid & out_ready;
  always_ff @(posedge core_clk) begin
    if (!rst_n) begin
      wr <= 4'd0; rd <= 4'd0; cnt <= 5'd0; run <= 1'b0;
    end else begin
      run <= 1'b1;
      if (enq) begin mem[wr] <= in_data; wr <= wr + 4'd1; end
      if (deq) rd <= rd + 4'd1;
      cnt <= cnt + {4'd0, enq} - {4'd0, deq};
    end
  end
endmodule
