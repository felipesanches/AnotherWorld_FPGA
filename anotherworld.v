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
  reg [7:0] opcode;
  reg [7:0] PC;
  reg [7:0] mem[0:'h6E];
  initial $readmemh("bytecode.mem", mem);

  always @ (posedge clk)
  begin
    opcode = mem[PC];
  end

  always @ (posedge clk)
  begin
    if (~reset)
      step <= 0;
    else
      step <= step + 1;
  end

  always @ (step) begin     
    case(step)
      3'b000    : opcode = mem[PC];
      default  : opcode = 0;
    endcase
  end

endmodule
