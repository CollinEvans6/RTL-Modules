module mac #( //reusable module for main
    parameter DATA_WIDTH  = 16,
    parameter COEFF_WIDTH = 16,
    parameter NUM_TAPS    = 8
)( 
    input logic signed [DATA_WIDTH-1:0] x_val,
    input logic signed [COEFF_WIDTH-1:0] b_val,
    input logic signed [DATA_WIDTH+COEFF_WIDTH+3:0] acc_in,// this data_width can be a waste sometime, can be improved
    output logic signed [DATA_WIDTH+COEFF_WIDTH+3:0] acc_out
);
  assign acc_out = x_val * b_val + acc_in;
endmodule

module fir_filter #(
    parameter DATA_WIDTH  = 16,
    parameter COEFF_WIDTH = 16,
    parameter NUM_TAPS    = 8
) (
    input  logic                                     clk,
    input  logic                                     rst_n,

    input  logic signed [DATA_WIDTH-1:0]             x_in,
    input  logic                                     x_valid,//en x_in

    input  logic signed [COEFF_WIDTH-1:0]            coeffs [0:NUM_TAPS-1],

    output logic signed [DATA_WIDTH+COEFF_WIDTH+3:0] y_out,
    output logic                                     y_valid // delayed 1clk after x_v
);
  //logic signed [DATA_WIDTH+COEFF_WIDTH+1:0] mac; // x_in * coeffs + 
  localparam int ACC_WIDTH = // accumulation reg width; for conv
        DATA_WIDTH + COEFF_WIDTH + 4;
  reg [DATA_WIDTH-1:0] shift_reg [0:NUM_TAPS-1]; // 8 reg to store x_val
  logic [DATA_WIDTH+COEFF_WIDTH+3:0] acc_val [0:NUM_TAPS-1]; // the unpacked number is the same with coeffs
  // 7 reg to store mac_val
  reg x_valid_old;
//logic signed [DATA_WIDTH+COEFF_WIDTH+3:0] first_mac;

  mac u1 (
    .x_val(x_in),
    .b_val(coeffs[0]),
    .acc_in(0),
    .acc_out(acc_val[0])
  );

  genvar i_tap;
  generate 
    for (i_tap = 1; i_tap < NUM_TAPS; i_tap ++) begin 
      mac mac_gen (
        .x_val(shift_reg[i_tap-1]),
        .b_val(coeffs[i_tap-1]),
        .acc_in(acc_val[i_tap-1]),
        .acc_out(acc_val[i_tap])
      );
    end
  endgenerate
  
  always_ff @(posedge clk) begin // update vars: 1. shift_reg, 2. mac
    if (!rst_n) begin // reset should reset everything, initally, I only have shift_reg[0] <= '0;
    //  shift_reg <= '0; if all element in an unpacked array are assigned 0, shift_reg <= '{default: '0}; is recommemded
      shift_reg <= '{default: '0};
      y_out <= '0;
      x_valid_old <= 0;
    end

    else begin
      x_valid_old <= x_valid;
      if (x_valid) begin
      shift_reg [0] <= x_in;
      y_out <= acc_val[NUM_TAPS-1];
      y_valid <= 1; 
      for (int i = 1; i < NUM_TAPS; i ++) begin 
        shift_reg [i] <= shift_reg[i-1];
      end
      if (!x_valid) begin 
        y_valid <= 0;
      end
    end
        // each clk cycle,
        // shift_reg[0] = x_in like always
        // shift_reg [1] = shift_reg[0]
        // shift_reg [2] = shift_reg[1], etc
        // this should not be here: 
        //acc_val[0] <= x_in * coeffs[0];

        //this loop should be deleted
        /*
        for (int j = 1; j < NUM_TAPS; j++) begin 
          acc_val [j] <= acc_val [j-1];
        end
      // each clk cycle, similar to shift_reg
      end
      */
      /* redundancy
        if (!x_valid) begin 
        foreach (shift_reg[i])  shift_reg[i] <= shift_reg[i];
        foreach (acc_val[j]) acc_val[j] <= acc_val[j];
      end
      */
    end  
  end
  /* used always_ff twice, not necessary
  always_ff @(posedge clk) begin 
    x_valid_old <= x_valid;
    y_out <= acc_val[NUM_TAPS - 1];
  end
  */ 

 //assign y_valid = x_valid_old;

  //assign y_out = acc_val[7]; // this should not be here as y_out also update with clk edge.
  // also, use parameter, instead of assuming it to be 7.
  

endmodule
/*
//milestone1: y_out updated on negedge. 
//direction for next step:
Combinational logic: calculates all products and their accumulated sum.
Sequential logic: stores previous input samples, registers the output, and delays x_valid.
Each signal has exactly one driver.
*It seems that shift_mac_reg is unnecessary, as it could instead be wires. so it is renamed to acc_val and re-typed.
debug: x_in 1-->0; y_out did not update
*/
