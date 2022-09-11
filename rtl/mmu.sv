`include "rtl/cache.sv"

// MMU module
// Takes a virtual address and transforms it into a physical address
module lobster_mmu
#( // Parameter
  parameter ADDR_WIDTH = 36,
  parameter NUM_TLB_ENTRIES = 8192 // How many TLB entries
)
( // Interface
  input rst,
  input clk,
  input [ADDR_WIDTH - 1:0] virt_addr,
  output [ADDR_WIDTH - 1:0] phys_addr,
  input we,
  input [63:0] page_in
);
  wire exec = 
endmodule
