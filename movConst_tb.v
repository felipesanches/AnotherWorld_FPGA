`include "movConst.v"


module movConst_tb();
 
  reg clk, rst_n;
 
  movConst #() DUT (
    .clk(clk),
    .rst_n(rst_n),
  );
 
  initial begin
    clk = 1'b0;
    rst_n = 1'b1;
    forever #10 clk = ~clk; // generate a clock
  end

  initial begin
    repeat(4) @(posedge clk);
    $finish;
  end
 
endmodule
