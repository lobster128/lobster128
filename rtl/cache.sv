module lobster_cache
#( // Parameter
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter NUM_ENTRIES = 4096
)
( // Interface
  input rst,
  input clk,
  input we, // Write enable
  input find, // Whetever to perform find-mode (uses data-in for finding)
  input [ADDR_WIDTH - 1:0] addr_in, // Address-in
  input [DATA_WIDTH - 1:0] data_in, // Data-in
  input [ADDR_WIDTH - 1:0] addr_out, // Address-out
  output reg [DATA_WIDTH - 1:0] data_out // Data-out
  // TODO: RDY output state wire
);
  integer i;
  function [DATA_WIDTH - 1:0] hash_result(
    input [DATA_WIDTH - 1:0] x
  );
    // https://stackoverflow.com/questions/664014/what-integer-hash-function-are-good-that-accepts-an-integer-hash-key
    // x = ((x >> 16) ^ x) * 0x45d9f3b;
    // x = ((x >> 16) ^ x) * 0x45d9f3b;
    // x = (x >> 16) ^ x;
    hash_result = (((((((x >> 16) ^ x) * 32'h45d9f3b) >> 16) ^ (((x >> 16) ^ x) * 32'h45d9f3b)) * 32'h45d9f3b) >> 16) ^ ((((((x >> 16) ^ x) * 32'h45d9f3b) >> 16) ^ (((x >> 16) ^ x) * 32'h45d9f3b)) * 32'h45d9f3b);
  endfunction

  reg [DATA_WIDTH - 1:0] cache[0:NUM_ENTRIES - 1];

  always @(posedge clk) begin
    if(rst) begin
      $display("%m: Reset");
      for(i = 0; i < NUM_ENTRIES; i++) begin
        cache[i] = 0;
      end
      data_out <= 0;
    end
  end

  always @(posedge clk) begin
    $display("%m: k_out=0x%h,v_out=0x%h,k_in=0x%h,v_in=0x%h,we=%b,k_out_hash=0x%h,k_in_hash=0x%h", addr_out, data_out, addr_in, data_in, we, hash_result(addr_out), hash_result(addr_in));
    if(we) begin
      cache[hash_result(addr_in) & (NUM_ENTRIES - 1)] <= data_in;
    end
    if(find) begin
      data_out <= { 1'b1, 31'h0 }; // Negative value
      for(i = 0; i < NUM_ENTRIES; i++) begin
        if(cache[i] == data_in) begin
          data_out <= i[31:0];
        end
      end
    end else begin
      data_out <= cache[hash_result(addr_out) & (NUM_ENTRIES - 1)];
    end
  end

  initial begin
    $display("%m: size=%0dKB,data_width=%0d bits", (NUM_ENTRIES * (DATA_WIDTH / 8)) / 1000, DATA_WIDTH);
  end
endmodule

module lobster_cache_tb;
  reg rst, clk, we, find;
  reg [32 - 1:0] addr_in;
  reg [32 - 1:0] data_in;
  reg [32 - 1:0] addr_out;
  wire [32 - 1:0] data_out;

  lobster_cache UUT (
    .rst(rst),
    .clk(clk),
    .we(we),
    .find(find),
    .addr_in(addr_in),
    .data_in(data_in),
    .addr_out(addr_out),
    .data_out(data_out)
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
