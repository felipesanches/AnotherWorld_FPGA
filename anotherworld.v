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
  reg [7:0] subopcode;
  reg [7:0] PC;
  reg [7:0] src;
  reg [7:0] dst;
  reg [7:0] value_H;
  reg [7:0] value_L;
  reg condition;
  reg [7:0] mem[0:8'h6E];
  reg [15:0] vmvar[0:255];

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
        ///////////////////////////////
       // GENERIC CPU INSTRUCTIONS: //
      ///////////////////////////////

      `opcode_movConst: begin
        case(step)
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
      end

      `opcode_ret: begin
      end

      `opcode_sub: begin
        case(step)
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
      end

      `opcode_shr: begin
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
        // ...
      end

      `opcode_selectVideoPage: begin
        // ...
      end

      `opcode_fillVideoPage: begin
        // ...
      end

      `opcode_copyVideoPage: begin
      end

      `opcode_blitFrameBuffer: begin
        // ...
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
