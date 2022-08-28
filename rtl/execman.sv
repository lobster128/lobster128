`include "rtl/cache.sv"
`include "rtl/alu.sv"

module lobster_micro_exec
#( // Parameter

)
( // Interface
  input rst,
  input clk,
  input [15:0] inst,
  output [6:0] ra_select, // A is used both as an input & output
  input [127:0] ra_valin,
  output [127:0] ra_valout,
  output [6:0] rb_select, // B is input only
  input [127:0] rb_value
);
  // Micro inst format:
  // [ 5-bits Register A ][ 5-bits Register B ][ 4 bits OP ][ 00 ]
  // 0                16
  // aaaa abbb bboo oo00
  wire [3:0] op = inst[5:2]; // Operation
  wire [4:0] reg_a = inst[10:6]; // Register A
  wire [4:0] reg_b = inst[15:11]; // Register B
  assign ra_select = { 2'b00, reg_a };
  assign rb_select = { 2'b00, reg_b };

  lobster_alu alu(
    .rst(rst),
    .clk(clk),
    .op(op),
    .a(ra_valin),
    .b(rb_value),
    .c(ra_valout)
  );
  
  always @(posedge clk) begin
    $display("%m: executing micro insn Op(%x) R%x, R%x", op, reg_a, reg_b);
  end
endmodule

module lobster_mini_exec
#( // Parameter
  parameter ADDR_WIDTH = 36
)
( // Interface
  input rst,
  input clk,
  input [31:0] inst,
  output [6:0] rd_select,
  output [127:0] rd_value,
  output [ADDR_WIDTH - 1:0] ls_addr, // Load-Store address
  output load, // 1 = load, 0 = store
  output mem_enable, // 1 = using memory, 0 = not
  output [6:0] ra_select,
  input [127:0] ra_value,
  output [6:0] rb_select,
  input [127:0] rb_value
);
  // Mini inst format:
  // [ ... ][ 4 bits OP ][ 4 bits memory ][ 4 bits deleg ][ 10 ]
  // 0                16                  32
  // 0000 0000 0000 0000 00oo oomm mmdd dd10
  //
  // Depending on the memory value, if it's a NOP (aka. register):
  // [ 13 bits immediate ][ 5 bits reg ][ 4 bits OP ][ 4 bits memory ][ 4 bits deleg ][ 10 ]
  // 0                16                  32
  // iiii iiii iiii iAAA AAoo oomm mmdd dd10
  //
  // For both stores and loads:
  // [ 6 bits A reg ][ 6 bits B reg ][ 6 bits dest reg ][ 4 bits OP ][ 4 bits memory ][ 4 bits deleg ][ 10 ]
  // 0                16                  32
  // AAAA AABB BBBB DDDD DDoo oomm mmdd dd10
  // Load address in register D, then perform OP between B and the
  // value stored at D - save on A
  wire [3:0] mem      = inst[9:6]; // Memory operation
  wire [1:0] memop    = inst[7:6];    // - Operation
  wire [1:0] memsz    = inst[9:8];    // - Size
  localparam MEM_8       = 2'b00;
  localparam MEM_16      = 2'b01;
  localparam MEM_32      = 2'b10;
  localparam MEM_64      = 2'b11;
  localparam MEM_NOOP    = 2'b00;         // Nop, usually register transfer
  localparam MEM_LOAD    = 2'b01;         // Load
  localparam MEM_LOAD8   = 4'b0001;
  localparam MEM_LOAD16  = 4'b0101;
  localparam MEM_LOAD32  = 4'b1001;
  localparam MEM_LOAD64  = 4'b1101;
  localparam MEM_STORE   = 2'b10;         // Store
  localparam MEM_STORE8  = 4'b0010;
  localparam MEM_STORE16 = 4'b0110;
  localparam MEM_STORE32 = 4'b1010;
  localparam MEM_STORE64 = 4'b1110;
  wire [3:0] op       = inst[13:10]; // Operation
  // For immediate
  wire [4:0] i_reg_a  = inst[18:14];
  wire [12:0] i_imm13 = inst[31:19];
  // For load/store:
  wire [5:0] ls_reg_d  = inst[19:14];
  wire [5:0] ls_reg_b  = inst[25:20];
  wire [5:0] ls_reg_a  = inst[31:26];

  wire [127:0] ls_valout; // Load/Store arithmethic value-out

  assign ra_select = (memop == MEM_NOOP) ? { 2'b0, i_reg_a } : { 1'b0, ls_reg_a };
  assign rb_select = { 1'b0, ls_reg_b };
  // Top executor is meant to always be on setter - however when we load/store
  // we can't overwrite the pre-existing registers so we set it to zero
  assign rd_select = (memop == MEM_NOOP) ? { 1'b0, ls_reg_d } : 0;

  lobster_alu alu(
    .rst(rst),
    .clk(clk),
    .op(op),
    .a(ra_value),
    .b({ 115'b00, i_imm13 }),
    .c(rd_value)
  );

  always @(posedge clk) begin
    if(memop == MEM_NOOP) begin
      // TODO: Account for sizes (eg. trim/truncate)
      // Register D is used for the arithmethic & also used
      // to store the result
      $display("%m: executing mini imm13 insn Op(%x), Imm13=%x, R%x", op, i_imm13, i_reg_a);
      //gp_regs[i_reg_a] = alu_op_imm_result(op, gp_regs[i_reg_a], { 115'b00, i_imm13 });
    end else if(memop == MEM_LOAD) begin
      // TODO: A smarter way to store multiple stuff
      //$display("%m: buffering mini Load insn Op(%x), RA=%x, RB=%x, RD=%x", inst[5:2], inst[31:26], inst[25:20], inst[19:14]);
      // TODO: Not parallel safe!
      // TODO: Maybe we should place it on RD + 64 aka. RD | 0x40? so we make some fine use fo those extra missing bits on the encoding!
    end
  end
endmodule

module lobster_execman
#( // Parameter
  parameter ADDR_WIDTH = 36,
  parameter NUM_INSN_ENTRIES = 8192 // How many instructions are to be held
                                    // for the scheduler/insn dispatcher
)
( // Interface
  input rst,
  input clk,
  input [ADDR_WIDTH - 1:0] addr_in,
  input [63:0] data_in
);
  reg i_cache_we;
  reg [35:0] i_cache_addr_out;
  wire [63:0] i_cache_data_out;
  wire i_cache_inv;
  
  lobster_cache i_cache(
    .rst(rst),
    .clk(clk),
    .we(i_cache_we),
    .addr_in(addr_in), // Hardwired directly to I-cache!
    .data_in(data_in),
    .addr_out(i_cache_addr_out),
    .data_out(i_cache_data_out),
    .inv(i_cache_inv)
  );
  defparam i_cache.ADDR_WIDTH = ADDR_WIDTH;
  defparam i_cache.DATA_WIDTH = 64;

  reg [127:0] gp_regs[0:127]; // Register file
  // Hardwired hardware registers
  localparam REG_ZERO = 7'd0;             // Hardwired zero
  localparam REG_PC   = 7'd1;             // Program counter
  localparam REG_TMP  = 7'd127;           // Temporal register
  // Hardware accelerated ABI
  localparam REG_SP   = 7'd2;             // Stack pointer
  localparam REG_FP   = 7'd3;             // Frame pointer

  reg [63:0] insn_holder[0:NUM_INSN_ENTRIES - 1];
  reg [12:0] insn_holder_cnt;

  reg rs_load; // Register is loaded from memory

  wire [6:0] ue_ra_select[0:3];
  wire [6:0] ue_rb_select[0:3];
  wire [127:0] ue_ra_valout[0:3];
  genvar i;
  generate
    for(i = 0; i < 4; i += 1) begin
      lobster_micro_exec u_exec(
        .rst(rst),
        .clk(clk),
        .inst(data_in[(((i + 1) * 16) - 1):(i * 16)]),
        .ra_select(ue_ra_select[i]),
        .ra_valin(gp_regs[ue_ra_select[i]]),
        .ra_valout(ue_ra_valout[i]),
        .rb_select(ue_rb_select[i]),
        .rb_value(gp_regs[ue_rb_select[i]])
      );
    end
  endgenerate

  wire [6:0] me_ra_select[0:1];
  wire [6:0] me_rb_select[0:1];
  wire [6:0] me_rd_select[0:1];
  reg [127:0] me_rd_value[0:1];
  wire [ADDR_WIDTH - 1:0] me_ls_addr[0:1];
  wire me_load[0:1];
  wire me_mem_enable[0:1];
  generate
    for(i = 0; i < 2; i += 1) begin
      lobster_mini_exec m_exec(
        .rst(rst),
        .clk(clk),
        .inst(data_in[(((i + 1) * 32) - 1):(i * 32)]),
        .ra_select(me_ra_select[i]),
        .ra_value(gp_regs[me_ra_select[i]]),
        .rb_select(me_rb_select[i]),
        .rb_value(gp_regs[me_rb_select[i]]),
        .rd_select(me_rd_select[i]),
        .rd_value(me_rd_value[i]),
        .ls_addr(me_ls_addr[i]),
        .load(me_load[i]),
        .mem_enable(me_mem_enable[i])
      );
    end
  endgenerate

  wire [1:0] inst_prefix = data_in[1:0];    // Prefix, LOCK and REP
  localparam PREFIX_MICROINST = 2'b00;      // Micro instruction
  localparam PREFIX_LONGINST  = 2'b01;      // Long VLIW instruction
  localparam PREFIX_MINIINST  = 2'b10;      // Bigger than micro, smaller than
                                            // long instruction
  localparam PREFIX_REP       = 2'b11;      // Repeat prefix

  always @(posedge clk) begin
    $display("%m: data_in=0x%x", data_in);
    i_cache_we <= 1; // Enable writing by default
    if(inst_prefix == PREFIX_MICROINST) begin
      $display("%m: executing microinst quadruples");
      gp_regs[ue_ra_select[0]] <= ue_ra_valout[0];
      gp_regs[ue_ra_select[1]] <= ue_ra_valout[1];
      gp_regs[ue_ra_select[2]] <= ue_ra_valout[2];
      gp_regs[ue_ra_select[3]] <= ue_ra_valout[3];
    end else if(inst_prefix == PREFIX_MINIINST) begin
      $display("%m: executing mini inst pairs");
      if(!me_mem_enable[0]) begin // Immediate
        gp_regs[me_rd_select[0]] <= me_rd_value[0];
      end else begin

      end
      
      if(!me_mem_enable[1]) begin
        gp_regs[me_rd_select[1]] <= me_rd_value[1];
      end else begin

      end
    end
  end

  always @(posedge clk) begin
    integer j;
    for(j = 0; j < 128; j += 4) begin
      $display("r%3d=0x%x, r%3d=0x%x, r%3d=0x%x, r%3d=0x%x",
        j, gp_regs[j],
        j + 1, gp_regs[j + 1],
        j + 2, gp_regs[j + 2],
        j + 3, gp_regs[j + 3]);
    end
  end
endmodule
