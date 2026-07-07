module memory (
  input  logic                    clk_i,
  input  logic                    rst_i,
  input  logic                    wr_rd_i,
  input  logic [`WIDTH-1:0]       wdata_i,
  output logic [`WIDTH-1:0]       rdata_o,
  output logic                    ready_o,
  input  logic [`ADDR_WIDTH-1:0]  addr_i,
  input  logic                    valid_i
);

  logic [`WIDTH-1:0] mem [0:`DEPTH-1];
  integer idx;

  assign ready_o = ~rst_i;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      rdata_o <= '0;
      for (idx = 0; idx < `DEPTH; idx++) begin
        mem[idx] <= '0;
      end
    end
    else if (valid_i) begin
      if (wr_rd_i)
        mem[addr_i] <= wdata_i;
      else
        rdata_o <= mem[addr_i];
    end
  end

endmodule
