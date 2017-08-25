`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/07/27 14:51:07
// Design Name: 
// Module Name: Checkunit
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


module Checkunit#(
	parameter	BLOCK_SIZE		    = 127  ,
	parameter 	QUAN_WIDTH		    = 4    ,
	parameter	ROW_BLOCK		    = 6    ,	// 行块数
	parameter	COL_BLOCK		    = 72   ,	// 列块数
	parameter	COL_CNT_WIDTH	    = 7    ,
	parameter	ROW_CNT_WIDTH	    = 2    ,
	parameter	MB_COL			    = 4    ,
	
	parameter   DATA_WIDTH 			= 1	   ,	// 单个数据的位宽
	parameter   DATA_NUM		    = 127  ,	// 数据的总数
	parameter   SHIFT_OFFSET_WIDTH 	= 7		    // 移位值的位宽
) (
    input                                          I_clk                ,
	input                                          I_rst_n              ,

	input     [SHIFT_OFFSET_WIDTH*MB_COL-1:0]      I_shift_offset       ,
//	input                                          I_shift_offset_valid ,
//	input                                          I_shift_offset_last  ,
//	output                                         O_shift_offset_ready ,

	input     [DATA_NUM*MB_COL-1:0]                I_dsign              ,   //输入 DATA_NUM*MB_COL个符号位
    input                                          I_dsign_valid        ,
    input                                          I_dsign_last_delay   ,   //每行最后一个数延迟两个clk拉高，作为判决输出标志
//  output                                         O_dsign_ready        ,

	output     reg                                 O_result             ,   //输出判决结果,0表示成功校验，否则为1
	output     reg                                 O_result_valid      
//	output                                         O_result _last       ,
//	input                                          I_result _ready     

    );
	
	wire      [DATA_NUM-1:0]                       W_shift_dsign[MB_COL-1:0]        ;
	wire      [MB_COL-1:0]                         W_dsign_check[DATA_NUM-1:0]      ;	
//	wire                                           W_blk_ena            ;
	
	reg       [DATA_NUM-1:0]                       R_result             ;

//    assign  W_blk_ena = I_shift_offset_valid & I_dsign_valid ;
	

// -------------------------v 移位MB_COL个DATA_NUM bit符号位 v-------------------------
    genvar	i;
	generate
	    for	(i=0; i < MB_COL; i=i+1)	begin: shifter_cluster
            
			barrel_shifter_pblk #(
            	.DATA_WIDTH 			(DATA_WIDTH 	),	
            	.DATA_NUM				(DATA_NUM		),	
            	.SHIFT_OFFSET_WIDTH 	(SHIFT_OFFSET_WIDTH)	
            ) barrel_shifter_pblk (	
            	.i_blk_ena		        (I_dsign_valid                                                       ),		
            	.i_shift_offset	        (BLOCK_SIZE[SHIFT_OFFSET_WIDTH-1:0] - I_shift_offset [SHIFT_OFFSET_WIDTH*(i+1)-1:SHIFT_OFFSET_WIDTH*i]    ),	//8.24更改
            	.i_data			        (I_dsign        [DATA_NUM*(i+1)-1:DATA_NUM*i]                        ),	
            	.o_shift_data	        (W_shift_dsign  [i][DATA_NUM-1:0]                                    )	
            );	
		
		end
    endgenerate
	// genvar	i;
	// generate
	    // for	(i=0; i < MB_COL; i=i+1)	begin: shifter_cluster
	        // assign W_shift_dsign[i][DATA_NUM-1:0] = I_dsign        [DATA_NUM*(i+1)-1:DATA_NUM*i];
		// end
	// endgenerate
// -------------------------^ 移位MB_COL个DATA_NUM bit符号位 ^-------------------------

// -------------------------v MB_COL+1个符号位进行异或 v-------------------------
    genvar	j;	
	generate
	    for	(i=0; i < DATA_NUM; i=i+1)	begin: check_cluster
		    for	(j=0; j < MB_COL; j=j+1)	begin: check_cluster_assign
	            assign  W_dsign_check[i][j] = W_shift_dsign[j][i]                       ;
			end	
			always@(posedge I_clk)
			begin
                if(~I_rst_n)                    R_result[i] <= 0                                                 ;
				else if(I_dsign_last_delay)     R_result[i] <= 0                                                 ;
				else                            R_result[i] <= (^W_dsign_check[i]) ^ R_result[i]                 ;	
            end			
		end
	endgenerate
// -------------------------^ MB_COL+1个符号位进行异或 ^-------------------------

    always@(posedge I_clk)
    begin
        if(~I_rst_n)                                   O_result <= 0                     ;
    	else if(I_dsign_last_delay & R_result!=0)      O_result <= 1                     ;
    	else if(I_dsign_last_delay & R_result==0)      O_result <= 0                     ;
    	else                                           O_result <= 0                     ;
    end
	
	always@(posedge I_clk)
	begin
	    if(~I_rst_n)                                  O_result_valid <= 0               ;
		else if(I_dsign_last_delay)                   O_result_valid <= 1               ;
		else                                          O_result_valid <= 0               ;
	end
	

endmodule





