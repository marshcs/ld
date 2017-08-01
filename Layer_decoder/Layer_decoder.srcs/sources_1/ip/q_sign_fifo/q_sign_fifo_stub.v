// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.1 (win64) Build 1215546 Mon Apr 27 19:22:08 MDT 2015
// Date        : Thu Jul 27 11:16:52 2017
// Host        : DESKTOP-LNNBH4P running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/PROJECT/Layer_decoder/Layer_decoder.srcs/sources_1/ip/q_sign_fifo/q_sign_fifo_stub.v
// Design      : q_sign_fifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7vx980tffg1930-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v12_0,Vivado 2015.1" *)
module q_sign_fifo(clk, rst, din, wr_en, rd_en, dout, full, empty, valid, data_count)
/* synthesis syn_black_box black_box_pad_pin="clk,rst,din[507:0],wr_en,rd_en,dout[507:0],full,empty,valid,data_count[4:0]" */;
  input clk;
  input rst;
  input [507:0]din;
  input wr_en;
  input rd_en;
  output [507:0]dout;
  output full;
  output empty;
  output valid;
  output [4:0]data_count;
endmodule
