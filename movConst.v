`define opcode_movConst 8'h00

module movConst(clk, rst_n);

  input clk, rst_n;

  reg [3:0] step;
  reg [7:0] opcode;
  reg [7:0] PC;
  reg [7:0] dst;
  reg [7:0] value_H;
  reg [7:0] value_L;
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

    if (~rst_n) begin
        step <= 0;
        PC <= 8'b00000000;
      end
    else
      step <= step + 1;

  always @ (posedge clk)
  begin
    case(opcode)
      `opcode_movConst: begin
        case(step)
          1: begin
            rom_addr <= PC;
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
    endcase
  end
endmodule
