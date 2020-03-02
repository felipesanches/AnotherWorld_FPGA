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

module anotherworld_cpu(clk, reset, hsync, vsync, r, g, b);

  input clk, reset;
  output hsync, vsync;
  output reg [2:0] r;
  output reg [2:0] g;
  output reg [2:0] b;

// == Amount of RAM needed ==
// Total of 5 pages:
//   - 1 active_video page
//   - 4 "work" video pages
//
// Each page has 320x200 pixels.
// Each pixel has 4 bits
// Total = 5*320*200*4 = 1280000 bits = approx. 1.28 Mbits
//
// There's not enough RAM in the NAND Land Go-Board for that and
// I suspect that's the reason why this project does not build sucessfully at this point.
// I am considering adapting this code to run on the ULX3S board:
// https://hackaday.com/2019/01/14/ulx3s-an-open-source-lattice-ecp5-fpga-pcb/

  wire display_on;
  wire [9:0] hpos;
  wire [9:0] vpos;
  reg [4:0] curPalette = 0;
  reg [1:0] curPage = 0;
  reg [4:0] curStage = 0;
  reg [3:0] active_video[0:63999]; // 320*200 = 64000 pixels
  reg [3:0] pages[0:255999]; // 4*320*200 = 256000 pixels
  reg [15:0] palettes[0:9215]; // 18*32*16 = 9216 entries
                              // 18 stages with 32 palettes
                             // of 16 colors (16 bits each)
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(1'b0),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  //actual resolution is 320x200 starting at line 40:
  wire video_is_active = display_on && vpos >= 40 && vpos <= 440;
  wire [3:0] color_index = active_video[(vpos[9:1]-20)*320 + hpos[9:1]];
  wire [13:0] pal_addr = curStage*32*16 + curPalette*16 + color_index;
  wire [15:0] color_bits = palettes[pal_addr];

  wire [15:0] pixel_addr = y*320 + x;
  wire [17:0] pages_addr = dst[1:0]*320*200 + y*320 + x;

  always @ (posedge clk)
  begin

    case (video_is_active)
      1'b1: begin
        // Here's the actual color-scheme from
        // the original VM with 6 bits per channel:
        //
        // wire [5:0] r = {color_bits[11:8], color_bits[11:10]};
        // wire [5:0] g = {color_bits[7:4], color_bits[7:6]};
        // wire [5:0] b = {color_bits[3:0], color_bits[3:2]};
        //
        // But this is what we'll use on the NAND LAND Go-Board
        // because it only has 3 bits per color channel in the
        // DACs connected to its VGA connector:
        r = color_bits[11:9];
        g = color_bits[7:5];
        b = color_bits[3:1];

        // FIXME: planning to use the ULX3S board, I'll have to figure out
        // how many color bits the board can support via its HDMI output.
      end
      1'b0: begin
        r = 3'b000;
        g = 3'b000;
        b = 3'b000;
      end
    endcase
  end

  reg [3:0] step = 0;
  reg [7:0] opcode = 0;
  reg [7:0] subopcode;
  reg [15:0] PC = 0;
  reg [7:0] SP = 0;
  reg [7:0] src;
  reg [7:0] dst;
  reg [7:0] value_H;
  reg [7:0] value_L;
  reg condition;
  reg [7:0] mem[0:8'hFF]; // for now I'll only declare 256 bytes which is enough for the small sample bytecode used for testing. Later we should increase this to cover the full 16 bit addressing range: 16'hFFFF
  reg [15:0] stack[0:255];
  reg [15:0] vmvar[0:255];
  reg [8:0] x; //count up to 319
  reg [7:0] y; //count up to 199

  integer i;
  initial begin
    $readmemh("ROMs/palettes.mem", palettes, 0, 18*32*16 - 1);

    $readmemh("bytecode.mem", mem);

    for (i=0; i<=8'hFF; i=i+1)
      vmvar[i] = 0;
  end

  always @ (posedge clk)
  begin
    if (~reset) begin
      step <= 4'b0000;
      PC <= 16'h0000;
      opcode <= 8'h00;
    end
    else
    case(opcode)
        ///////////////////////////////
       // GENERIC CPU INSTRUCTIONS: //
      ///////////////////////////////

      `opcode_movConst: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            value_H <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            value_L <= mem[PC];
            PC <= PC + 1;
            step <= 4;
          end
          4: begin
            vmvar[dst] <= {value_H, value_L};
            step <= 0;
          end
        endcase
      end

      `opcode_mov: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            src <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            vmvar[dst] <= vmvar[src];
            step <= 0;
          end
        endcase
      end

      `opcode_add: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            src <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            vmvar[dst] <= vmvar[dst] + vmvar[src];
            step <= 0;
          end
        endcase
      end

      `opcode_addConst: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            value_L <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            vmvar[dst] <= vmvar[dst] + value_L;
            step <= 0;
          end
        endcase
      end

      `opcode_jmp: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            value_H <= mem[PC];
            step <= 2;
          end
          2: begin
            value_L <= mem[PC];
            step <= 3;
          end
          3: begin
            PC <= {value_H, value_L};
            step <= 0;
          end
        endcase
      end

      `opcode_djnz: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            step <= 2;
            PC <= PC + 1;
          end
          2: begin
            value_H <= mem[PC];
            vmvar[dst] <= vmvar[dst] - 1;
            step <= 3;
            PC <= PC + 1;
          end
          3: begin
            value_L <= mem[PC];
            step <= 4;
            PC <= PC + 1;
          end
          4: begin
            if (vmvar[dst] != 0)
              PC <= {value_H, value_L};
            step <= 0;
          end
        endcase
      end

      `opcode_condJmp: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            subopcode <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            src <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            value_L <= mem[PC];
            PC <= PC + 1;
            step <= 4;
          end
          4: begin
            if (subopcode[7])
              {value_H, value_L} <= vmvar[value_L];
            else if (subopcode[6]) begin
              value_L <= {value_L, mem[PC]};
              PC <= PC + 1;
            end
            step <= 5;
          end
          5: begin
            case(subopcode[2:0])
              0: condition <= vmvar[src] == {value_H, value_L}; // jz
              1: condition <= vmvar[src] != {value_H, value_L}; // jnz
              2: condition <= vmvar[src] > {value_H, value_L};  // jg
              3: condition <= vmvar[src] >= {value_H, value_L}; // jge
              4: condition <= vmvar[src] < {value_H, value_L};  // jl
              5: condition <= vmvar[src] <= {value_H, value_L}; // jle
              default: condition <= 0;
            endcase
            step <= 6;
          end
          6: begin
            if (condition) begin
              PC <= {value_H, value_L};
            end
            step <= 0;
          end
        endcase
      end

      `opcode_call: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            value_H <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            value_L <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            stack[SP] <= PC;
            SP <= SP + 1;
            PC <= {value_H, value_L};
            step <= 0;
          end
        endcase
      end

      `opcode_ret: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            SP <= SP - 1;
            step <= 2;
          end
          2: begin
            PC <= stack[SP];
            step <= 0;
          end
        endcase
      end

      `opcode_sub: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            src <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            vmvar[dst] <= vmvar[dst] - vmvar[src];
            step <= 0;
          end
        endcase
      end

      `opcode_and: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            src <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            vmvar[dst] <= vmvar[dst] & vmvar[src];
            step <= 0;
          end
        endcase
      end

      `opcode_or: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            src <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            vmvar[dst] <= vmvar[dst] | vmvar[src];
            step <= 0;
          end
        endcase
      end

      `opcode_shl: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            value_H <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            value_L <= mem[PC];
            PC <= PC + 1;
            step <= 4;
          end
          4: begin
            vmvar[dst] <= vmvar[dst] << {value_H, value_L};
            step <= 0;
          end
        endcase
      end

      `opcode_shr: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            value_H <= mem[PC];
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            value_L <= mem[PC];
            PC <= PC + 1;
            step <= 4;
          end
          4: begin
            vmvar[dst] <= vmvar[dst] >> {value_H, value_L};
            step <= 0;
          end
        endcase
      end

        /////////////////////////////////////
       // THREAD MANAGEMENT INSTRUCTIONS: //
      /////////////////////////////////////

      `opcode_pauseThread: begin
      end

      `opcode_setVec: begin
      end

      `opcode_updateChannel: begin
      end

      `opcode_killThread: begin
      end

        /////////////////////////
       // VIDEO INSTRUCTIONS: //
      /////////////////////////

      `opcode_setPalette: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            // Note: This seems a bug in the original VM, since the palette IDs do not really
            //       need more than 5 bits to be selected, but the instruction is encoded
            //       with a 16 bit operand. So, value_H is not used at all in here...
            value_H <= mem[PC];
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            curPalette <= mem[PC][4:0]; // "value_L"
            PC <= PC + 1;
            step <= 0;
          end
        endcase
      end

      `opcode_selectVideoPage: begin
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            curPage <= mem[PC][1:0];
            PC <= PC + 1;
            step <= 0;
          end
        endcase
      end

      `opcode_fillVideoPage: begin
        //TODO: move this into a separate circuit and make the
        //      instruction simply request the video operation
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC]; // pageID
            x <= 0;
            y <= 0;
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            value_L <= mem[PC]; // color
            PC <= PC + 1;
            step <= 3;
          end
          3: begin
            pages[pages_addr] <= value_L[3:0];
            if (x == 319) begin
              if (y == 199)
                step <= 0;
              else begin
                x <= 0;
                y <= y + 1;
              end
            end
            else
              x <= x + 1;
          end
        endcase
      end

      `opcode_copyVideoPage: begin
      end

      `opcode_blitFrameBuffer: begin
        //TODO: move this into a separate circuit and make the
        //      instruction simply request the video operation
        case(step)
          0: begin
            opcode = mem[PC];
            PC <= PC + 1;
            step <= 1;
          end
          1: begin
            dst <= mem[PC]; // pageID src (even though we use the dst register)
            x <= 0;
            y <= 0;
            PC <= PC + 1;
            step <= 2;
          end
          2: begin
            if (x <= 319 && y <= 199) begin
              active_video[pixel_addr] <= pages[pages_addr];
            end

            if (x == 319) begin
              if (y == 199)
                step <= 0;
              else begin
                x <= 0;
                y <= y + 1;
              end
            end
            else
              x <= x + 1;
          end
        endcase
      end

      `opcode_text: begin
      end

        /////////////////////////
       // AUDIO INSTRUCTIONS: //
      /////////////////////////

      `opcode_playSound: begin
      end

      `opcode_playMusic: begin
      end

        ///////////////////
       // VM RESOURCES: //
      ///////////////////

      `opcode_updateMemList: begin
      end

    endcase
  end

endmodule
