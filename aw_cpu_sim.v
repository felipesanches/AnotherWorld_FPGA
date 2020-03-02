module aw_cpu_sim;

  reg reset = 0;

  initial begin
    $dumpfile("aw_cpu_dumpfile.vcd");
    $dumpvars;
    #10 reset = 1;
    #100 $stop; // stop after 100 cycles
  end

  // Make clock :)
  reg clk = 0;
  always #5 clk = !clk;

  output wire [2:0] r;
  output wire [2:0] g;
  output wire [2:0] b;
  output wire vsync;
  output wire hsync;

  anotherworld_cpu aw_cpu(clk, reset, hsync, vsync, r, g, b);
endmodule
