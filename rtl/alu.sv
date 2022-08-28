// Arithmethic logic unit module

module lobster_alu
#( // Parameter

)
( // Interface
  input rst,
  input clk,
  input [3:0] op,
  input [127:0] a, // C = A (op) B
  input [127:0] b,
  output reg [127:0] c
);
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
  always @(posedge clk) begin
    c <= 128'h0; // Constant driven signal
    casez(op)
    XLU_ADD: begin // ADD [a], [b], [d]
      c <= a + b;
      $display("%m: XLU %x + %x", a, b);
      end
    XLU_SUB: begin // SUB [a], [b], [d]
      c <= a - b;
      $display("%m: XLU %x - %x", a, b);
      end
    XLU_OR: begin // OR [a], [b], [d]
      c <= a | b;
      $display("%m: XLU %x | %x", a, b);
      end
    XLU_XOR: begin // XOR [a], [b], [d]
      c <= a ^ b;
      $display("%m: XLU %x ^ %x", a, b);
      end
    XLU_AND: begin // AND [a], [b], [d]
      c <= a & b;
      $display("%m: XLU %x & %x", a, b);
      end
    XLU_LSH: begin // LSH [a], [b], [d]
      c <= a << b;
      $display("%m: XLU %x << %x", a, b);
      end
    XLU_RSH: begin // RSH [a], [b], [d]
      c <= a >> b;
      $display("%m: XLU %x >> %x", a, b);
      end
    XLU_MUL: begin // MUL [a], [b], [d]
      c <= a * b;
      $display("%m: XLU %x * %x", a, b);
      end
    XLU_DIV: begin // DIV [a], [b], [d]
      c <= a / b;
      $display("%m: XLU %x / %x", a, b);
      end
    XLU_REM: begin // MUL [a], [b], [d]
      c <= a % b;
      $display("%m: XLU %x %% %x", a, b);
      end
    XLU_NOT: begin // NOT [a], [b], [d]
      c <= ~(a | b);
      $display("%m: XLU %x | %x", a, b);
      end
    XLU_SET: begin // SET [a], [b], [d]
      c <= a;
      $display("%m: XLU bad %x", b);
      end
    default: begin
      $display("%m: Unhandled ALU case %x", op);
      end
    endcase
  end
endmodule
