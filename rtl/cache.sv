`ifndef CACHE_SV
`define CACHE_SV

// https://stackoverflow.com/questions/664014/what-integer-hash-function-are-good-that-accepts-an-integer-hash-key
// x = ((x >> 30) ^ x) * c1;
// x = ((x >> 27) ^ x) * c2;
// x = (x >> 31) ^ x;
`define HASH(C1, C2, X) \
  (((X ^ (X >> 30) * C1) ^ ((X ^ (X >> 30) * C1) >> 27)) * C2) \
  ^ ((((X ^ (X >> 30) * C1) ^ ((X ^ (X >> 30) * C1) >> 27)) * C2) >> 31);

module lobster_cache
#( // Parameter
  parameter ADDR_WIDTH = 36,
  parameter DATA_WIDTH = 64,
  parameter NUM_ENTRIES = 8192
)
( // Interface
  input rst,
  input clk,
  input we, // Write enable
  input inv, // 1 = Invalidate, 0 = nop
  input [ADDR_WIDTH - 1:0] addr_in, // Address-in
  input [DATA_WIDTH - 1:0] data_in, // Data-in
  input [ADDR_WIDTH - 1:0] addr_out, // Address-out
  output [DATA_WIDTH - 1:0] data_out // Data-out
  // TODO: RDY output state wire
);
  wire [63:0] c1 = 64'hbf58476d1ce4e5b9; // Magic constant values
  wire [63:0] c2 = 64'h94d049bb133111eb;

  reg [DATA_WIDTH - 1:0] cache[0:NUM_ENTRIES - 1];
  reg cache_status[0:NUM_ENTRIES - 1]; // 1 = valid, 0 = invalid
  wire [63:0] hashed_addr_in = `HASH(c1, c2, { 28'h0, addr_in });
  wire [63:0] hashed_addr_out = `HASH(c1, c2, { 28'h0, addr_out });
  assign data_out = cache_status[hashed_addr_in[12:0]] ? cache[hashed_addr_out[12:0]] : 0;

  integer i;

  always @(posedge clk) begin
    if(rst) begin
      $display("%m: Reset");
      for(i = 0; i < NUM_ENTRIES; i++) begin
        cache[i] = 0;
      end
    end
  end

  always @(posedge clk) begin
    $display("%m: k_out=0x%h,v_out=0x%h,k_in=0x%h,v_in=0x%h,we=%b", addr_out, data_out, addr_in, data_in, we);
    $display("%m: k_out_hash=0x%h,k_in_hash=0x%h,data=0x%h,inv=%b", hashed_addr_out, hashed_addr_in, cache[hashed_addr_in[12:0]], cache_status[hashed_addr_in[12:0]]);
    if(we) begin // On write revalidate
      cache[hashed_addr_in[12:0]] <= data_in;
      cache_status[hashed_addr_in[12:0]] <= 1;
    end if(inv) begin // Explicit invalidation
      cache_status[hashed_addr_in[12:0]] <= 0;
    end
  end

  initial begin
    $display("%m: size=%0dKB,data_width=%0d bits", (NUM_ENTRIES * (DATA_WIDTH / 8)) / 1000, DATA_WIDTH);
  end
endmodule

module lobster_cache_tb;
  reg rst, clk, we, inv;
  reg [32 - 1:0] addr_in;
  reg [32 - 1:0] data_in;
  reg [32 - 1:0] addr_out;
  wire [32 - 1:0] data_out;
  
  lobster_cache UUT (
    .rst(rst),
    .clk(clk),
    .we(we),
    .addr_in(addr_in),
    .data_in(data_in),
    .addr_out(addr_out),
    .data_out(data_out),
    .inv(inv)
  );

  always begin
    clk = 1;
    #10;
    clk = 0;
    #10;
  end

  always @(posedge clk) begin
    clk = 0;
    we = 0;
    find = 0;
    addr_in = 0;
    data_in = 0;
    addr_out = 0;
    data_out = 0;
    rst = 1; // Reset cache
    #5;

    // Write a value to an address and assert that the value was indeed
    // stored correctly
    we = 1;
    addr_in = 32'hFFF80000;
    data_in = 32'h12345678;
    #5;
    we = 0;
    #5;
    addr_out = 32'hFFF80000;
    #5;
    if(data_out != 32'h12345678)
      $display("%m: cache test failed");
    
    $stop;
  end
endmodule

`endif
