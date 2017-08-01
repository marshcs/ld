-- Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2015.1 (win64) Build 1215546 Mon Apr 27 19:22:08 MDT 2015
-- Date        : Tue Aug 01 19:34:46 2017
-- Host        : DESKTOP-LNNBH4P running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               d:/PROJECT/Layer_decoder/Layer_decoder.srcs/sources_1/ip/checkshift_rom/checkshift_rom_stub.vhdl
-- Design      : checkshift_rom
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7vx980tffg1930-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity checkshift_rom is
  Port ( 
    clka : in STD_LOGIC;
    addra : in STD_LOGIC_VECTOR ( 4 downto 0 );
    douta : out STD_LOGIC_VECTOR ( 167 downto 0 )
  );

end checkshift_rom;

architecture stub of checkshift_rom is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clka,addra[4:0],douta[167:0]";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "blk_mem_gen_v8_2,Vivado 2015.1";
begin
end;
