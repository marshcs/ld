// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.1 (win64) Build 1215546 Mon Apr 27 19:22:08 MDT 2015
// Date        : Tue Aug 01 11:01:16 2017
// Host        : DESKTOP-LNNBH4P running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/PROJECT/Layer_decoder/Layer_decoder.srcs/sources_1/ip/llr_mem/llr_mem_stub.v
// Design      : llr_mem
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7vx980tffg1930-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_2,Vivado 2015.1" *)
module llr_mem(clka, wea, addra, dina, douta)
/* synthesis syn_black_box black_box_pad_pin="clka,wea[0:0],addra[4:0],dina[761:0],douta[761:0]" */;
  input clka;
  input [0:0]wea;
  input [4:0]addra;
  input [761:0]dina;
  output [761:0]douta;
endmodule
