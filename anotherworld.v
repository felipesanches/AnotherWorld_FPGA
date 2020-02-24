`include "hvsync_generator.v"

`define opcode_movConst 8'h00
`define opcode_mov 8'h01
`define opcode_add 8'h02
`define opcode_addConst 8'h03
`define opcode_call 8'h04
`define opcode_ret 8'h05
`define opcode_pauseThread 8'h06
`define opcode_jmp 8'h07
`define opcode_setVec 8'h08
`define opcode_djnz 8'h09
`define opcode_condJmp 8'h0A
`define opcode_setPalette 8'h0B
`define opcode_updateChannel 8'h0C
`define opcode_selectVideoPage 8'h0D
`define opcode_fillVideoPage 8'h0E
`define opcode_copyVideoPage 8'h0F
`define opcode_blitFrameBuffer 8'h10
`define opcode_killThread 8'h11
`define opcode_text 8'h12
`define opcode_sub 8'h13
`define opcode_and 8'h14
`define opcode_or 8'h15
`define opcode_shl 8'h16
`define opcode_shr 8'h17
`define opcode_playSound 8'h18
`define opcode_updateMemList 8'h19
`define opcode_playMusic 8'h1A

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
  reg [7:0] mem[0:8'h6E];
  reg [7:0] vmvar[0:255];

  integer i;
  initial begin
    $readmemh("bytecode.mem", mem);
    for (i=0; i<=256; i=i+1)
      vmvar[i] = 0;
  end

  always @ (posedge clk)
  begin
    if (step==0) begin
      // fetch opcode
      opcode = mem[PC];
      PC <= PC + 1;
    end

    if (~reset) begin
        step <= 0;
        PC <= 8'b00000000;
      end	
    else
      step <= step + 1;

    case(opcode)
      `opcode_movConst: begin
      end

      `opcode_mov: begin
      end

      `opcode_add: begin
      end

      `opcode_addConst: begin
      end

      `opcode_call: begin
      end

      `opcode_ret: begin
      end

      `opcode_pauseThread: begin
      end

      `opcode_jmp: begin
      end

      `opcode_setVec: begin
      end

      `opcode_djnz: begin
      end

      `opcode_condJmp: begin
      end

      `opcode_setPalette: begin
      end

      `opcode_updateChannel: begin
      end

      `opcode_selectVideoPage: begin
      end

      `opcode_fillVideoPage: begin
      end

      `opcode_copyVideoPage: begin
      end

      `opcode_blitFrameBuffer: begin
      end

      `opcode_killThread: begin
      end

      `opcode_text: begin
      end

      `opcode_sub: begin
      end

      `opcode_and: begin
      end

      `opcode_or: begin
      end

      `opcode_shl: begin
      end

      `opcode_shr: begin
      end

      `opcode_playSound: begin
      end

      `opcode_updateMemList: begin
      end

      `opcode_playMusic: begin
      end

    endcase
  end

endmodule
