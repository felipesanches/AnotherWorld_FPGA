`include "hvsync_generator.v"

module anotherworld_cpu(clk, reset, hsync, vsync, rgb);

  input clk, reset;
  output hsync, vsync;
  output [2:0] rgb;
  wire display_on;
  wire [9:0] hpos;
  wire [9:0] vpos;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(0),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  wire r = display_on && vpos[5];
  wire g = display_on && 0;
  wire b = display_on && hpos[5];
  assign rgb = {b,g,r};


  reg [3:0] step;
  always @ (posedge clk)
    begin
      if (~reset)
        step <= 0;  // reset register
      else
        step <= step + 1;  // increment register
    end

endmodule
