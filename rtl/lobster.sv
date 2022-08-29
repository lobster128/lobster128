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
  reg [127:0] cycl_count;
  // ---------------------------------------------------------------------------
  // Instruction decoder
  // ---------------------------------------------------------------------------
  wire [63:0] exec_inst = data_in[63:0];
  // ---------------------------------------------------------------------------
  // Control
  // ---------------------------------------------------------------------------
  wire [3:0] sinst_ctrlop = exec_inst[13:10];// Control operation
  localparam CTL_TLBSET  = 4'b0000;          // Set TLB entry
  localparam CTL_TLBFLSH = 4'b0001;          // Flush TLB bucket
  localparam CTL_TLBPERM = 4'b0010;          // Set permissions for TLB entry
  localparam CTL_TLBPOKE = 4'b0011;          // Poke a TLB entry
  localparam CTL_TSSL    = 4'b1000;          // Load hardware task context
  localparam CTL_TSSS    = 4'b1001;          // Store hardware task context
  localparam CTL_TSCSWT  = 4'b1010;          // Perform a task switch

  // ---------------------------------------------------------------------------
  // Execution engine
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
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
    .data_in(data_in),
    .ip_out(addr_in)
  );

  always @(posedge clk) begin
    we <= 0;
  end

  // ---------------------------------------------------------------------------
  // Reset procedcure
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    if(rst) begin
      cycl_count <= 0;
      pipeline_active[PIPELINE_EXEC] <= 1; // Reset the pipeline
      pipeline_active[PIPELINE_DBUS] <= 1;
      dbus_mode <= DBUS_FETCH;
      ce <= 1;
    end
  end
endmodule
