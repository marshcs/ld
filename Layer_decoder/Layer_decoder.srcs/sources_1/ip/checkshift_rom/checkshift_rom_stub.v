// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.1 (win64) Build 1215546 Mon Apr 27 19:22:08 MDT 2015
// Date        : Tue Aug 01 19:34:46 2017
// Host        : DESKTOP-LNNBH4P running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/PROJECT/Layer_decoder/Layer_decoder.srcs/sources_1/ip/checkshift_rom/checkshift_rom_stub.v
// Design      : checkshift_rom
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7vx980tffg1930-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_2,Vivado 2015.1" *)
module checkshift_rom(clka, addra, douta)
/* synthesis syn_black_box black_box_pad_pin="clka,addra[4:0],douta[167:0]" */;
  input clka;
  input [4:0]addra;
  output [167:0]douta;
endmodule