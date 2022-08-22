`timescale 1ns / 1ps
`include "rtl/cache.sv"

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
    // ------------------------------------------------------------------------
    // Storage
    // -----------------------------------------------------------------------
    reg [127:0] gp_regs[0:127];             // General registers
    localparam REG_ZERO = 7'd0;             // Hardwired zero
    localparam REG_CYCL = 7'd125;           // Cycles counter
    localparam REG_PC   = 7'd126;           // Program counter
    localparam REG_SP   = 7'd127;           // Stack pointer

    reg [127:0] task_context[0:127];        // Saved task context registers
    reg [ADDR_WIDTH - 1:0] task_evec[0:31]; // 32 task interrupt handlers

    // ------------------------------------------------------------------------
    // Instruction decoder
    // ------------------------------------------------------------------------
    wire [63:0] exec_inst = data_in[63:0];
    // Prefixed instructions
    wire [1:0] inst_prefix = data_in[1:0];  // Prefix, LOCK and REP
    wire [3:0] inst_deleg = data_in[5:2];   // Delegator value
    localparam DELEG_ALU  = 4'b0000;        // Arithmethic
    localparam DELEG_FPU  = 4'b0001;        // Floating Point
    localparam DELEG_VPU  = 4'b0010;        // Vector
    localparam DELEG_VFPU = 4'b0011;        // Vector Floating Point
    localparam DELEG_CTRL = 4'b1011;        // Control operation
    localparam DELEG_MEM  = 4'b1100;        // Memory operation
    localparam DELEG_LOCK = 4'b1???;        // Atomic operation
    // ------------------------------------------------------------------------
    // Memory
    // Instructions can have a memory modifier telling it the data size on
    // which the operation should be done, even if no memory is touched
    // and a noop is used, the size modifier will affect the behaviour of some
    // instructions.
    // ------------------------------------------------------------------------
    wire [3:0] inst_mem    = data_in[9:6];  // Memory operation
    wire [1:0] inst_memop  = data_in[7:6];  // - Operation
    wire [1:0] inst_memsz  = data_in[9:8];  // - Size
    localparam MEM_8       = 2'b00;
    localparam MEM_16      = 2'b01;
    localparam MEM_32      = 2'b10;
    localparam MEM_64      = 2'b11;
    localparam MEM_NOOP    = 4'b??00;
    localparam MEM_LOAD    = 2'b01;
    localparam MEM_LOAD8   = 4'b0001;
    localparam MEM_LOAD16  = 4'b0101;
    localparam MEM_LOAD32  = 4'b1001;
    localparam MEM_LOAD64  = 4'b1101;
    localparam MEM_STORE   = 2'b10;
    localparam MEM_STORE8  = 4'b0010;
    localparam MEM_STORE16 = 4'b0110;
    localparam MEM_STORE32 = 4'b1010;
    localparam MEM_STORE64 = 4'b1110;
    // ------------------------------------------------------------------------
    // Arithmethic unit delegation
    // ------------------------------------------------------------------------
    wire [3:0] inst_xluop = data_in[13:10]; // (V/A/F)LU operation
    localparam XLU_ADD  = 4'b0000;          // Add
    localparam XLU_SUB  = 4'b0001;          // Subtract
    localparam XLU_AND  = 4'b0010;          // AND
    localparam XLU_NOT  = 4'b0011;          // NOT
    localparam XLU_LSH  = 4'b0100;          // Left-shift
    localparam XLU_RSH  = 4'b0101;          // Right-shift
    localparam XLU_OR   = 4'b0110;          // OR
    localparam XLU_XOR  = 4'b0111;          // XOR
    localparam XLU_MUL  = 4'b1000;          // Multiply
    localparam XLU_DIV  = 4'b1001;          // Divide
    localparam XLU_REM  = 4'b1011;          // Remainder
    localparam XLU_SEX  = 4'b1100;          // Sign extend
    localparam XLU_PUSH = 4'b1101;          // Push (increment A, place D to A + B)
    localparam XLU_POP  = 4'b1110;          // Pop (decrement A, place D to A + B)
    localparam XLU_EXT  = 4'b1111;          // Delegator-specific extensions
    function [127:0] alu_op_result(
        input [3:0] op,
        input [6:0] a, // Source
        input [6:0] b, // Operand 2
        input [6:0] d, // Dest
    );
        casez(op)
        XLU_ADD: begin // ADD [a], [b], [d]
            gp_regs[d] <= gp_regs[a] + gp_regs[b];
            end
        XLU_SUB: begin // SUB [a], [b], [d]
            gp_regs[d] <= gp_regs[a] - gp_regs[b];
            end
        XLU_OR: begin // OR [a], [b], [d]
            gp_regs[d] <= gp_regs[a] | gp_regs[b];
            end
        XLU_XOR: begin // AND [a], [b], [d]
            gp_regs[d] <= gp_regs[a] ^ gp_regs[b];
            end
        XLU_AND: begin // AND [a], [b], [d]
            gp_regs[d] <= gp_regs[a] & gp_regs[b];
            end
        XLU_LSH: begin // NOT [a], [b], [d]
            gp_regs[d] <= gp_regs[a] << gp_regs[b];
            end
        XLU_RSH: begin // NOT [a], [b], [d]
            gp_regs[d] <= gp_regs[a] >> gp_regs[b];
            end
        XLU_MUL: begin // MUL [a], [b], [d]
            gp_regs[d] <= gp_regs[a] * gp_regs[b];
            end
        XLU_DIV: begin // DIV [a], [b], [d]
            gp_regs[d] <= gp_regs[a] / gp_regs[b];
            end
        XLU_REM: begin // MUL [a], [b], [d]
            gp_regs[d] <= gp_regs[a] % gp_regs[b];
            end
        XLU_NOT: begin // NOT [a], [b], [d]
            // A and B are ignored in this case
            gp_regs[d] <= ~gp_regs[d];
            end
        default: begin
            $display("Unhandled ALU case %x", op);
            end
        endcase
    endfunction
    function [127:0] vpu_op_result(
        input [3:0] op, // Operation
        input [6:0] a, // Source
        input [6:0] b, // Desinations
        input [6:0] c,
        input [6:0] d
    );
        casez(op)
        XLU_ADD: begin // ADD [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] + gp_regs[a];
            gp_regs[c] <= gp_regs[c] + gp_regs[a];
            gp_regs[d] <= gp_regs[d] + gp_regs[a];
            end
        XLU_SUB: begin // SUB [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] - gp_regs[a];
            gp_regs[c] <= gp_regs[c] - gp_regs[a];
            gp_regs[d] <= gp_regs[d] - gp_regs[a];
            end
        XLU_OR: begin // OR [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] | gp_regs[a];
            gp_regs[c] <= gp_regs[c] | gp_regs[a];
            gp_regs[d] <= gp_regs[d] | gp_regs[a];
            end
        XLU_XOR: begin // AND [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] ^ gp_regs[a];
            gp_regs[c] <= gp_regs[c] ^ gp_regs[a];
            gp_regs[d] <= gp_regs[d] ^ gp_regs[a];
            end
        XLU_AND: begin // AND [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] & gp_regs[a];
            gp_regs[c] <= gp_regs[c] & gp_regs[a];
            gp_regs[d] <= gp_regs[d] & gp_regs[a];
            end
        XLU_LSH: begin // NOT [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] << gp_regs[a];
            gp_regs[c] <= gp_regs[c] << gp_regs[a];
            gp_regs[d] <= gp_regs[d] << gp_regs[a];
            end
        XLU_RSH: begin // NOT [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] >> gp_regs[a];
            gp_regs[c] <= gp_regs[c] >> gp_regs[a];
            gp_regs[d] <= gp_regs[d] >> gp_regs[a];
            end
        XLU_MUL: begin // MUL [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] * gp_regs[a];
            gp_regs[c] <= gp_regs[c] * gp_regs[a];
            gp_regs[d] <= gp_regs[d] * gp_regs[a];
            end
        XLU_DIV: begin // DIV [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] / gp_regs[a];
            gp_regs[c] <= gp_regs[c] / gp_regs[a];
            gp_regs[d] <= gp_regs[d] / gp_regs[a];
            end
        XLU_REM: begin // REM [a], [b], [c], [d]
            gp_regs[b] <= gp_regs[b] % gp_regs[a];
            gp_regs[c] <= gp_regs[c] % gp_regs[a];
            gp_regs[d] <= gp_regs[d] % gp_regs[a];
            end
        XLU_NOT: begin // NOT [a], [b], [c], [d]
            // A is ignored in this case
            gp_regs[b] <= ~gp_regs[b];
            gp_regs[c] <= ~gp_regs[c];
            gp_regs[d] <= ~gp_regs[d];
            end
        default: begin
            $display("Unhandled VLU case %x", op);
            end
        endcase
    endfunction
    // ------------------------------------------------------------------------
    // Control
    // ------------------------------------------------------------------------
    wire [3:0] inst_ctrlop = data_in[13:10];// Control operation
    localparam CTL_TLBSET  = 4'b0000;       // Set TLB entry
    localparam CTL_TLBFLSH = 4'b0001;       // Flush TLB bucket
    localparam CTL_TLBPERM = 4'b0010;       // Set permissions for TLB entry
    localparam CTL_TLBPOKE = 4'b0011;       // Poke a TLB entry
    localparam CTL_TSSL    = 4'b1000;       // Load hardware task context
    localparam CTL_TSSS    = 4'b1001;       // Store hardware task context
    localparam CTL_TSCSWT  = 4'b1010;       // Perform a task switch

    // ------------------------------------------------------------------------
    // Execution engine
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        gp_regs[REG_ZERO] <= 0; // Hardwired 0
        gp_regs[REG_CYCL] <= gp_regs[REG_CYCL] + 1; // Increment internal cycle counter
        $display("%m: cycle count=%d", gp_regs[REG_CYCL]);
    end

    // Parts of the pipeline can simultaneously execute various things
    // however the pipeline can't fetch, write and read at the same time
    reg pipeline_active[0:3];
    localparam PIPELINE_EXEC  = 2'b00; // Executing
    localparam PIPELINE_DBUS  = 2'b01; // Interacting with data bus
    reg [1:0] dbus_mode;
    localparam DBUS_NOP   = 2'b00; // No-op
    localparam DBUS_FETCH = 2'b01; // Fetching from RAM
    localparam DBUS_LOAD  = 2'b10; // Reading from RAM
    localparam DBUS_STORE = 2'b11; // Writing to RAM

    always @(posedge clk) begin
        we <= 0;
    // ------------------------------------------------------------------------
    // Pipeline - Executor
    // ------------------------------------------------------------------------
        if(pipeline_active[PIPELINE_EXEC]) begin
            casez(inst_deleg)
            DELEG_MEM: begin
                // Activate load pipe side - otherwise activate store one
                // remember they're mutually exclusive
                casez(inst_memop)
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
            default: begin end
            endcase
            $display("%m: execute");
    // ------------------------------------------------------------------------
    // Pipeline - Accesor
    // ------------------------------------------------------------------------
        end if(pipeline_active[PIPELINE_DBUS]) begin
            ce <= 1; // Tell SRAM we want to read
            addr_in <= gp_regs[REG_PC][ADDR_WIDTH - 1:0];
            $display("%m: fetching pc=%x", gp_regs[REG_PC]);
        end
    end

    // ------------------------------------------------------------------------
    // Reset procedcure
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if(rst) begin
            gp_regs[REG_CYCL] <= 0;
            gp_regs[REG_PC] <= 128'hF800;
            pipeline_active[PIPELINE_EXEC] <= 1; // Reset the pipeline
            pipeline_active[PIPELINE_DBUS] <= 1;
            dbus_mode <= DBUS_FETCH;
        end
    end
endmodule
