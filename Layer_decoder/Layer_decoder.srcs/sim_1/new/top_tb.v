`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/07/31 10:57:15
// Design Name: 
// Module Name: top_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ldpc_tb(

    );

parameter INIT_INFO_WIDTH 	= 2;		
parameter MESSAGE_WIDTH 	= 6;		
parameter BLK_INDEX_WIDTH 	= 7;		
parameter GF_SIZE_LOG2 		= 7;		
// PCM
parameter SUBPCM_ROWN 		= 2;		
parameter SUBPCM_COLN 		= 4;		
parameter PCM_ROWN 			= 6;	
parameter PCM_COLN 			= 72;	
// OTHER
parameter MAX_ITER 			= 20; 	
parameter MIN_NUM 			= 2;		
parameter RW_LATENCY		= 2;    

// -------------------------v clog2 v-------------------------

function integer clog2;
    input integer value;
    for(clog2 = 0; value > 0; clog2 = clog2 + 1) begin
	    value = value >> 1;
    end
endfunction

// -------------------------^ clog2 ^-------------------------

localparam BLK_SIZE = (1 << GF_SIZE_LOG2) - 1;
localparam LAYER_CNT_WIDTH = clog2(PCM_ROWN / SUBPCM_ROWN);//3层大的layer
localparam SUBPCM_NUM = PCM_ROWN * PCM_COLN / SUBPCM_COLN / SUBPCM_ROWN;
localparam SUBPCM_NUM_WIDTH = clog2(SUBPCM_NUM);
localparam SHIFT_MEM_WIDTH = BLK_INDEX_WIDTH * SUBPCM_ROWN * SUBPCM_COLN;//移位值ROM位宽为7*2*4
localparam FIFO_DELAY = 1;//FIFO读取数据的延时为1
localparam COL_CNT_WIDTH = clog2(PCM_COLN / SUBPCM_COLN); //5
localparam APP_INFO_DEPTH = PCM_COLN / SUBPCM_COLN;
localparam COL_CAL_DELAY = PCM_COLN / SUBPCM_COLN + 4; //5
localparam ITER_CNT_WIDTH = clog2(MAX_ITER);

reg clk;
reg rst_n;

reg [SUBPCM_COLN*BLK_SIZE*INIT_INFO_WIDTH-1:0] i_init_info;
reg i_init_info_valid = 0;


reg [31:0]  cnt;

wire [SUBPCM_COLN*BLK_SIZE-1:0] o_decoded_info;
wire o_decoded_info_valid;
wire o_decoded_info_last;
wire o_init_info_ready;
wire o_decoding_end;
wire o_parity_check_satisfied;


LDPC_soft_decoder #(
	// WIDTH
    .INIT_INFO_WIDTH    (INIT_INFO_WIDTH    ),
    .MESSAGE_WIDTH 	    (MESSAGE_WIDTH 	    ),
    .BLK_INDEX_WIDTH 	(BLK_INDEX_WIDTH    ),
    .GF_SIZE_LOG2 	    (GF_SIZE_LOG2 	    ),
    .SUBPCM_ROWN 		(SUBPCM_ROWN 	    ),
    .SUBPCM_COLN 		(SUBPCM_COLN 	    ),
    .PCM_ROWN 		    (PCM_ROWN 		    ),
    .PCM_COLN 		    (PCM_COLN 		    ),
    .MAX_ITER 		    (MAX_ITER 		    ),
    .MIN_NUM 			(MIN_NUM 		    ),
    .RW_LATENCY		    (RW_LATENCY		    )
)tb_LDPC_soft_decoder(
	.clk							(clk						    ),
	.rst_n						    (rst_n					        ),
	.i_strength0					(6'd8				            ),
	.i_strength1					(6'd12				            ),
	.i_init_info 				    (i_init_info 			        ),
	.i_init_info_valid 			    (i_init_info_valid 		        ),
	.o_init_info_ready 			    (o_init_info_ready 		        ),
	.o_decoding_end				    (o_decoding_end			        ),
	.o_parity_check_satisfied	    (o_parity_check_satisfied       ),
	.o_decoded_info				    (o_decoded_info			        ),
	.o_decoded_info_valid 		    (o_decoded_info_valid 	        ),
	.o_decoded_info_last			(o_decoded_info_last		    )
);

always # 5 clk = ~clk;

initial
begin
  clk     =   1'b1;
  rst_n   =   1'b0;
  # 1000
  rst_n   =   1'b1;
end

always @(posedge clk) begin
	if(~rst_n)									                cnt <= 0;
	else 										                cnt <= cnt + 1;
end

always @(posedge clk) begin
	if(~rst_n)									                i_init_info_valid <= 0;
	else if(cnt >= 300 && cnt < 318)							i_init_info_valid <= 1;
    else                                                        i_init_info_valid <= 0;
end

always @(posedge clk) begin
	if(~rst_n)									                i_init_info <= 0;
	else if(cnt >= 300 && cnt <= 307)							i_init_info <={{5{4'b1000}},{498{2'b00}}};
	else if(cnt >= 309 && cnt <= 311)							i_init_info <={{5{4'b0010}},{498{2'b00}}};
    else                                                        i_init_info <= 0;
end

// integer fid1;
// initial 
// begin
// 	fid1 = $fopen("D:\\decode.txt","w+");
// end
// always @(posedge I_clk)
// begin
// 	if(M_data_valid) 
// 	begin
// 	$fdisplay(fid1,"%b",M_data);
// 	end
// end

endmodule
