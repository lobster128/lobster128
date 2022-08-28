// Top computer module SoC

`timescale 1ns / 1ps
`include "rtl/execman.sv"

module lobster_CPU
#( // Parameter
  parameter ADDR_WIDTH = 36
)
( // Interface
  input rst, // Reset
  input clk, // Clock
  input rdy, // Ready signal from SRAM
  output reg ce, // Command-enable
  output reg we, // Write-enable
  output [ADDR_WIDTH - 1:0] addr_in, // Input
  input [63:0] data_in,
  output [ADDR_WIDTH - 1:0] addr_out, // Output
  output [63:0] data_out
);
  // ---------------------------------------------------------------------------
  // Storage
  // ---------------------------------------------------------------------------
  reg [127:0] gp_regs[0:127];             // General registers
  localparam REG_ZERO = 7'd0;             // Hardwired zero
  localparam REG_PC   = 7'd1;             // Program counter
  localparam REG_SP   = 7'd2;             // Stack pointer
  localparam REG_TMP  = 7'd127;           // Temporal register
  reg [127:0] cycl_count;

  reg [127:0] task_context[0:127];        // Saved task context registers
  reg [ADDR_WIDTH - 1:0] task_evec[0:31]; // 32 task interrupt handlers
  reg [15:0] rep_count;                   // Repeat counter, separate from
                                          // registers as iterations is 64K
  reg [7:0] cc_flags;                     // Condition code flags

  // ---------------------------------------------------------------------------
  // RISC instruction executor
  // ---------------------------------------------------------------------------
  reg [63:0] insn_par_cache[0:127];       // Instruction parallel cache
  reg insn_par_free[0:127];               // If it's free for use
  function [1:0] risc_parse_execution(
    input par_is_free,
    input [63:0] par_inst,
  );

  endfunction

  // ---------------------------------------------------------------------------
  // Instruction decoder
  // ---------------------------------------------------------------------------
  wire [63:0] exec_inst = data_in[63:0];
  // Prefixed instructions
  wire [1:0] inst_prefix = exec_inst[1:0];    // Prefix, LOCK and REP
  localparam PREFIX_MICROINST = 2'b00;      // Micro instruction
  localparam PREFIX_LONGINST  = 2'b01;      // Long VLIW instruction
  localparam PREFIX_MINIINST  = 2'b10;      // Bigger than micro, smaller than
                                            // long instruction
  localparam PREFIX_REP       = 2'b11;      // Repeat prefix
  // ---------------------------------------------------------------------------
  // uinst -> Micro instruction format
  // sinst -> Short instruction format
  // rinst -> Repeating instruction control format
  // vinst -> Length instruction format
  // ---------------------------------------------------------------------------
  wire [3:0] sinst_deleg = exec_inst[5:2];    // Delegator value
  localparam DELEG_ALU  = 4'b0000;          // Arithmethic
  localparam DELEG_FPU  = 4'b0001;          // Floating Point
  localparam DELEG_VPU  = 4'b0010;          // Vector
  localparam DELEG_VFPU = 4'b0011;          // Vector Floating Point
  localparam DELEG_CTRL = 4'b1011;          // Control operation
  localparam DELEG_MEM  = 4'b1100;          // Memory operation
  localparam DELEG_LOCK = 4'b1???;          // Atomic operation
  // ---------------------------------------------------------------------------
  // Memory
  // Instructions can have a memory modifier telling it the data size on
  // which the operation should be done, even if no memory is touched
  // and a noop is used, the size modifier will affect the behaviour of some
  // instructions.
  // ---------------------------------------------------------------------------
  wire [3:0] sinst_mem   = exec_inst[9:6];    // Memory operation
  wire [1:0] sinst_memop = exec_inst[7:6];    // - Operation
  wire [1:0] sinst_memsz = exec_inst[9:8];    // - Size
  localparam MEM_8       = 2'b00;
  localparam MEM_16      = 2'b01;
  localparam MEM_32      = 2'b10;
  localparam MEM_64      = 2'b11;
  localparam MEM_NOOP    = 4'b??00;         // Nop, usually register transfer
  localparam MEM_LOAD    = 4'b??01;         // Load
  localparam MEM_LOAD8   = 4'b0001;
  localparam MEM_LOAD16  = 4'b0101;
  localparam MEM_LOAD32  = 4'b1001;
  localparam MEM_LOAD64  = 4'b1101;
  localparam MEM_STORE   = 4'b??10;         // Store
  localparam MEM_STORE8  = 4'b0010;
  localparam MEM_STORE16 = 4'b0110;
  localparam MEM_STORE32 = 4'b1010;
  localparam MEM_STORE64 = 4'b1110;
  // ---------------------------------------------------------------------------
  // Arithmethic unit delegation
  // ---------------------------------------------------------------------------
  wire [3:0] uinst_xluop = exec_inst[5:2];    // Micro variant
  wire [3:0] sinst_xluop = exec_inst[13:10];  // (V/A/F)LU operation
  localparam XLU_ADD  = 4'b0000;            // Add
  localparam XLU_SUB  = 4'b0001;            // Subtract
  localparam XLU_AND  = 4'b0010;            // AND
  localparam XLU_NOT  = 4'b0011;            // NOT
  localparam XLU_LSH  = 4'b0100;            // Left-shift
  localparam XLU_RSH  = 4'b0101;            // Right-shift
  localparam XLU_OR   = 4'b0110;            // OR
  localparam XLU_XOR  = 4'b0111;            // XOR
  localparam XLU_MUL  = 4'b1000;            // Multiply
  localparam XLU_DIV  = 4'b1001;            // Divide
  localparam XLU_SET  = 4'b1010;            // Set
  localparam XLU_REM  = 4'b1011;            // Remainder
  localparam XLU_SEX  = 4'b1100;            // Sign extend
  localparam XLU_PUSH = 4'b1101;            // Push increment A, place D
                                            // to A + B
  localparam XLU_POP  = 4'b1110;            // Pop decrement A, place D to A + B
  localparam XLU_EXT  = 4'b1111;            // Delegator-specific extensions
  function automatic [127:0] alu_op_imm_result(
    input [3:0] op,
    input [127:0] a,
    input [127:0] b
  );
    casez(op)
    XLU_ADD: begin // ADD [a], [b], [d]
      alu_op_imm_result <= a + b;
      $display("%m: XLU %x + %x", a, b);
      end
    XLU_SUB: begin // SUB [a], [b], [d]
      alu_op_imm_result <= a - b;
      $display("%m: XLU %x - %x", a, b);
      end
    XLU_OR: begin // OR [a], [b], [d]
      alu_op_imm_result <= a | b;
      $display("%m: XLU %x | %x", a, b);
      end
    XLU_XOR: begin // XOR [a], [b], [d]
      alu_op_imm_result <= a ^ b;
      $display("%m: XLU %x ^ %x", a, b);
      end
    XLU_AND: begin // AND [a], [b], [d]
      alu_op_imm_result <= a & b;
      $display("%m: XLU %x & %x", a, b);
      end
    XLU_LSH: begin // LSH [a], [b], [d]
      alu_op_imm_result <= a << b;
      $display("%m: XLU %x << %x", a, b);
      end
    XLU_RSH: begin // RSH [a], [b], [d]
      alu_op_imm_result <= a >> b;
      $display("%m: XLU %x >> %x", a, b);
      end
    XLU_MUL: begin // MUL [a], [b], [d]
      alu_op_imm_result <= a * b;
      $display("%m: XLU %x * %x", a, b);
      end
    XLU_DIV: begin // DIV [a], [b], [d]
      alu_op_imm_result <= a / b;
      $display("%m: XLU %x / %x", a, b);
      end
    XLU_REM: begin // MUL [a], [b], [d]
      alu_op_imm_result <= a % b;
      $display("%m: XLU %x %% %x", a, b);
      end
    XLU_NOT: begin // NOT [a], [b], [d]
      alu_op_imm_result <= ~(a | b);
      $display("%m: XLU %x | %x", a, b);
      end
    XLU_SET: begin // SET [a], [b], [d]
      alu_op_imm_result <= a;
      $display("%m: XLU bad %x", b);
      end
    default: begin
      $display("%m: Unhandled ALU case %x", op);
      end
    endcase
  endfunction
  function automatic [127:0] alu_op_result(
    input [3:0] op,
    input [6:0] a, // Source
    input [6:0] b // Operand 2
  );
    alu_op_result <= alu_op_imm_result(op, gp_regs[a], gp_regs[b]);
  endfunction
  function automatic void vpu_op_result(
    input [3:0] op, // Operation
    input [6:0] b, // Desinations
    input [6:0] c,
    input [6:0] d,
    input [6:0] a, // Source
  );
    gp_regs[b] <= alu_op_result(op, a, b);
    gp_regs[c] <= alu_op_result(op, a, c);
    gp_regs[d] <= alu_op_result(op, a, d);
  endfunction

  // Micro inst format:
  // [ 5-bits Register A ][ 5-bits Register B ][ 4 bits OP ][ 00 ]
  // 0                16
  // aaaa abbb bboo oo00
  function automatic void uinst_execute(
    input [15:0] inst
  );
    //wire [3:0] uinst_op    = inst[5:2];         // Operation
    //wire [4:0] uinst_reg_a = inst[10:6];        // Register A
    //wire [4:0] uinst_reg_b = inst[15:11];       // Register B
    $display("%m: executing micro insn Op(%x) R%x, R%x", inst[5:2], inst[10:6], inst[15:11]);
    gp_regs[{ 2'b00, inst[10:6] }] <= alu_op_result(inst[5:2], { 2'b00, inst[10:6] }, { 2'b00, inst[15:11] });
  endfunction
  // Mini inst format:
  // [ ... ][ 4 bits OP ][ 4 bits memory ][ 4 bits deleg ][ 10 ]
  // 0                16                  32
  // 0000 0000 0000 0000 00oo oomm mmdd dd10
  //
  // Depending on the memory value, if it's a NOP (aka. register):
  // [ 13 bits immediate ][ 5 bits reg ][ 4 bits OP ][ 4 bits memory ][ 4 bits deleg ][ 10 ]
  // 0                16                  32
  // iiii iiii iiii iDDD DDoo oomm mmdd dd10
  //
  // For both stores and loads:
  // [ 6 bits A reg ][ 6 bits B reg ][ 6 bits dest reg ][ 4 bits OP ][ 4 bits memory ][ 4 bits deleg ][ 10 ]
  // 0                16                  32
  // AAAA AABB BBBB DDDD DDoo oomm mmdd dd10
  // Load address in register D, then perform OP between B and the
  // value stored at D - save on A
  function automatic void sinst_execute(
    input [31:0] inst
  );
    //wire [3:0] sinst_op     = ;        // Operation
    //wire [3:0] sinst_mem    = inst[9:6];        // Memory operation
    //wire [4:0] sinst_reg_d  = inst[18:14];
    //wire [12:0] sinst_imm13 = inst[31:19];

    // For load/store:
    //wire [5:0] sinst_reg_d  = inst[19:14];
    //wire [5:0] sinst_reg_b  = inst[25:20];
    //wire [5:0] sinst_reg_a  = inst[31:26];
    if(inst[9:6] == MEM_NOOP) begin
      // TODO: Account for sizes (eg. trim/truncate)
      // Register D is used for the arithmethic & also used
      // to store the result
      $display("%m: executing mini IMM insn Op(%x), Imm13=%x, R%x", inst[5:2], inst[31:19], inst[18:14]);
      gp_regs[{ 2'b00, inst[18:14] }] = alu_op_imm_result(inst[5:2], gp_regs[{ 2'b00, inst[18:14] }], { 115'b00, inst[31:19] });
    end else if(inst[9:6] == MEM_LOAD) begin
      // TODO: A smarter way to store multiple stuff
      $display("%m: buffering mini Load insn Op(%x), RA=%x, RB=%x, RD=%x", inst[5:2], inst[31:26], inst[25:20], inst[19:14]);
      // TODO: Not parallel safe!
      // TODO: Maybe we should place it on RD + 64 aka. RD | 0x40? so we make some fine use fo those extra missing bits on the encoding!
      // Save the address from RD into the dbus so we can tell it to load shit
      //dbus_load_addr <= gp_regs[{ 1'b0, inst[19:14] }][ADDR_WIDTH - 1:0];
      dbus_load_insn[dbus_load_cnt] <= inst; // Store instruction aswell!
      dbus_load_cnt <= dbus_load_cnt + 1;
      dbus_mode <= DBUS_LOAD;
    end
  endfunction

  // Execute a mini instruction after a DBUS RDY signal
  function automatic void sinst_dbus_execute(
    input [31:0] inst
  );
    if(inst[9:6] == MEM_LOAD) begin
      gp_regs[{ 1'b1, inst[31:26] }] <= alu_op_imm_result(inst[5:2], gp_regs[{ 1'b1, inst[25:20] }], { 64'b0, data_in });
      dbus_load_exec_cnt <= dbus_load_exec_cnt + 1;
    end else begin
      // Ignore...
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Control
  // ---------------------------------------------------------------------------
  wire [3:0] sinst_ctrlop = exec_inst[13:10];// Control operation
  localparam CTL_TLBSET  = 4'b0000;       // Set TLB entry
  localparam CTL_TLBFLSH = 4'b0001;       // Flush TLB bucket
  localparam CTL_TLBPERM = 4'b0010;       // Set permissions for TLB entry
  localparam CTL_TLBPOKE = 4'b0011;       // Poke a TLB entry
  localparam CTL_TSSL    = 4'b1000;       // Load hardware task context
  localparam CTL_TSSS    = 4'b1001;       // Store hardware task context
  localparam CTL_TSCSWT  = 4'b1010;       // Perform a task switch

  // ---------------------------------------------------------------------------
  // Execution engine
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    gp_regs[REG_ZERO] <= 0; // Hardwired 0
    cycl_count <= cycl_count + 1; // Increment internal
                                  // cycle counter
    $display("%m: cycle count=%x", cycl_count);
  end

  // Parts of the pipeline can simultaneously execute various things
  // however the pipeline can't fetch, write and read at the same time
  reg pipeline_active[0:3];
  localparam PIPELINE_EXEC  = 2'b00; // Executing
  localparam PIPELINE_DBUS  = 2'b01; // Interacting with data bus
  reg [1:0] dbus_mode;
  // Load buffers
  reg [ADDR_WIDTH - 1:0] dbus_load_addr[0:63]; // Store the address to load
  reg [31:0] dbus_load_insn[0:63]; // Instruction (stored)
  reg [5:0] dbus_load_exec_cnt; // Counter of the current executing insn
  reg [5:0] dbus_load_cnt; // Counter for keeping track of the current load buffer
  reg [63:0] dbus_store_buffer[0:63];
  localparam DBUS_NOP   = 2'b00; // No-op
  localparam DBUS_FETCH = 2'b01; // Fetching from RAM
  localparam DBUS_LOAD  = 2'b10; // Reading from RAM
  localparam DBUS_STORE = 2'b11; // Writing to RAM

  lobster_execman execman(
    .rst(rst),
    .clk(clk),
    .addr_in(addr_in),
    .data_in(data_in)
  );

  always @(posedge clk) begin
    we <= 0;
    // -------------------------------------------------------------------------
    // Pipeline - Executor
    // -------------------------------------------------------------------------
    if(pipeline_active[PIPELINE_EXEC]) begin
      /*
      // Long instruction
      casez(inst_prefix)
      PREFIX_LONGINST: begin
        casez(sinst_deleg)
        DELEG_MEM: begin
          // Activate load pipe side - otherwise activate store one
          // remember they're mutually exclusive
          casez(sinst_mem)
          MEM_LOAD: begin
            dbus_mode <= DBUS_LOAD;
            we <= 0;
            ce <= 1;
            end
          MEM_STORE: begin
            dbus_mode <= DBUS_STORE;
            we <= 1;
            ce <= 1;
            end
          default: begin end
          endcase
          end
        default: begin
          $display("%m: invalid delegator %b", sinst_deleg);
          end
        endcase
        end
      default: begin
        uinst_execute(exec_inst[15:0]);
        end
      endcase*/
      $display("%m: execute");
    // -------------------------------------------------------------------------
    // Pipeline - Accesor
    // -------------------------------------------------------------------------
    end if(pipeline_active[PIPELINE_DBUS]) begin
      ce <= 1; // Tell SRAM we want to read
      addr_in <= gp_regs[REG_PC][ADDR_WIDTH - 1:0];
      $display("%m: fetching addr=%x", addr_in);
      if(rdy) begin
        // Micro instructions only take 1 cycle to execute
        case(dbus_mode)
        DBUS_FETCH: begin
          case(inst_prefix)
          // 32-bits mini-instruction
          PREFIX_MINIINST: begin
            sinst_execute(exec_inst[31:0]);
            sinst_execute(exec_inst[63:32]);
            gp_regs[REG_PC] <= gp_regs[REG_PC] + 8;
            end
          // 16-bits micro-instruction
          PREFIX_MICROINST: begin
            uinst_execute(exec_inst[15:0]);
            uinst_execute(exec_inst[31:16]);
            uinst_execute(exec_inst[47:32]);
            uinst_execute(exec_inst[63:48]);
            gp_regs[REG_PC] <= gp_regs[REG_PC] + 8;
            end
          default: begin
            end
          endcase
          end
        default: begin end
        endcase
        $display("%m: read addr=%x,data=%x", addr_in, data_in);
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Reset procedcure
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    if(rst) begin
      cycl_count <= 0;
      gp_regs[REG_PC] <= 128'hF800;
      pipeline_active[PIPELINE_EXEC] <= 1; // Reset the pipeline
      pipeline_active[PIPELINE_DBUS] <= 1;
      dbus_mode <= DBUS_FETCH;
    end
  end
endmodule
