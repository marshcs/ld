`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/07/27 14:36:31
// Design Name: 
// Module Name: Paritycheck
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


module Paritycheck#(
	parameter	BLOCK_SIZE		    = 127  ,
	parameter 	QUAN_WIDTH		    = 4    ,
	parameter	ROW_BLOCK		    = 6    ,	// 行块数
	parameter	COL_BLOCK		    = 72   ,	// 列块数
	parameter	COL_CNT_WIDTH	    = 5    ,
	parameter	ROW_CNT_WIDTH	    = 2    ,
	parameter	MB_COL			    = 4    ,
	
	parameter   DATA_WIDTH 			= 1	   ,	// 单个数据的位宽
	parameter   DATA_NUM		    = 127  ,	// 数据的总数
	parameter   SHIFT_OFFSET_WIDTH 	= 7		    // 移位值的位宽
) (
    input                                                    I_clk                ,
	input                                                    I_rst_n              ,
	input                                                    I_start              ,
	input     [DATA_NUM*MB_COL-1:0]                          I_dsign              ,   //输入 DATA_NUM*MB_COL个符号位
    input                                                    I_dsign_valid        ,

	output    reg                                            O_result             ,   //输出判决结果,1表示成功校验，否则为0
	output    reg                                            O_result_valid      

    );
	localparam    ITERATION_NUM = COL_BLOCK/MB_COL                                ;
	
	wire      [ROW_BLOCK-1:0]                                W_result             ;
	wire                                                     W_result_valid       ;
	wire      [SHIFT_OFFSET_WIDTH*MB_COL*ROW_BLOCK-1:0]      W_shift_offset       ;
	wire      [COL_CNT_WIDTH-1:0]                            W_shift_rom_addr     ; 
	
	reg                                                      R_dsign_last_delay   ;  //每行最后一个数延迟两个clk拉高,作为判决输出标志
	
	reg       [COL_CNT_WIDTH-1:0]                            R_col_cnt            ;  //
	
	reg       [COL_CNT_WIDTH-1:0]                            R_shift_rom_addr     ;  //ROM读数地址
	
	// reg       [DATA_NUM*MB_COL-1:0]                          R_dsign_delay1       ;  //对I_dsign延迟一个clk
    // reg                                                      R_dsign_delay1_valid ;
    // reg       [DATA_NUM*MB_COL-1:0]                          R_dsign_delay2       ;  //对I_dsign延迟两个clk
    // reg                                                      R_dsign_delay2_valid ;
	
// -------------------------v APP信息delay v-------------------------	

	// always@(posedge I_clk)
	// begin
	    // if(~I_rst_n)                          R_dsign_delay1       <= 0                         ;
		// else                                  R_dsign_delay1       <= I_dsign                   ;
	// end
	
	// always@(posedge I_clk)
	// begin
	    // if(~I_rst_n)                          R_dsign_delay1_valid <= 0                         ;
		// else                                  R_dsign_delay1_valid <= I_dsign_valid             ;
	// end
	
	// always@(posedge I_clk)
	// begin
	    // if(~I_rst_n)                          R_dsign_delay2       <= 0                         ;
		// else                                  R_dsign_delay2       <= R_dsign_delay1            ;
	// end
	
	// always@(posedge I_clk)
	// begin
	    // if(~I_rst_n)                          R_dsign_delay2_valid <= 0                         ;
		// else                                  R_dsign_delay2_valid <= R_dsign_delay1_valid      ;
	// end
// -------------------------^ APP信息delay ^-------------------------	
	
	//	assign    W_dsign_last_delay = (R_col_cnt == ITERATION_NUM) ? 1:0 ;       //每行最后一个数延迟两个clk拉高
	
// -------------------------v 延迟计数及生成判决输出标志 v-------------------------	
	always@(posedge I_clk)
	begin
	    if(~I_rst_n)                                                      R_col_cnt <= 0                    ;
		else if(I_dsign_valid & (R_col_cnt < ITERATION_NUM))              R_col_cnt <= R_col_cnt + 1        ;
		else if(R_col_cnt == ITERATION_NUM)                               R_col_cnt <= 0                    ;
		else                                                              R_col_cnt <= R_col_cnt            ;
	end
	
	always@(posedge I_clk)
	begin
	    if(~I_rst_n)                              R_dsign_last_delay    <=    0;
		else if(R_col_cnt == ITERATION_NUM-1)     R_dsign_last_delay    <=    1;
		else                                      R_dsign_last_delay    <=    0;
	end
// -------------------------^ 延迟计数及生成判决输出标志 ^-------------------------		



// -------------------------v 计数作为ROM读取地址 v-------------------------
always@(posedge I_clk)
	begin
	    if(~I_rst_n)                                                      R_shift_rom_addr <= 0                    ;
		else if(I_start)                                                  R_shift_rom_addr <= 1                    ;
		else                                                              R_shift_rom_addr <= R_shift_rom_addr + 1 ;
	end
	
	assign W_shift_rom_addr = (I_start)? 0:R_shift_rom_addr;
// -------------------------^ 计数作为ROM读取地址 ^-------------------------



// -------------------------v ROW_BLOCK个校验结果 v-------------------------	
	genvar	i;
	generate
	    for	(i=0; i < ROW_BLOCK; i=i+1)	 begin: checkunit_cluster
	        Checkunit#(
	        .BLOCK_SIZE		    (BLOCK_SIZE		   )    ,
	        .QUAN_WIDTH		    (QUAN_WIDTH		   )    ,
	        .ROW_BLOCK		    (ROW_BLOCK		   )    ,	
	        .COL_BLOCK		    (COL_BLOCK		   )    ,	
	        .COL_CNT_WIDTH	    (COL_CNT_WIDTH	   )    ,
	        .ROW_CNT_WIDTH	    (ROW_CNT_WIDTH	   )    ,
	        .MB_COL			    (MB_COL			   )    ,
	        .DATA_WIDTH 		(DATA_WIDTH 	   )    ,	
	        .DATA_NUM		    (DATA_NUM		   )    ,	
	        .SHIFT_OFFSET_WIDTH (SHIFT_OFFSET_WIDTH)	    
            ) Checkunit_ins(
            .I_clk                (I_clk                                                                              ),
	        .I_rst_n              (I_rst_n                                                                            ),
	        .I_shift_offset       (W_shift_offset[SHIFT_OFFSET_WIDTH*MB_COL*(i+1)-1:SHIFT_OFFSET_WIDTH*MB_COL*i]      ),
//	        .I_shift_offset_valid (I_shift_offset_valid                                                               ),
	        .I_dsign              (I_dsign                                                                            ),   //输入 DATA_NUM*MB_COL个符号位
            .I_dsign_valid        (I_dsign_valid                                                                      ),
			.I_dsign_last_delay   (R_dsign_last_delay                                                                 ),
	        .O_result             (W_result[i]                                                                        ),   //输出判决结果,1表示成功校验，否则为0
	        .O_result_valid       (W_result_valid                                                                     )
			);
	    end
	endgenerate 
// -------------------------^ ROW_BLOCK个校验结果 ^-------------------------	



    always@(posedge I_clk)
    begin
        if(~I_rst_n)                                               O_result <= 0                     ;
    	else if(W_result_valid & (W_result!=0))                    O_result <= 0                     ;
    	else if(W_result_valid & (W_result==0))                    O_result <= 1                     ;
    	else                                                       O_result <= 0                     ;
    end
	
	always@(posedge I_clk)
	begin
	    if(~I_rst_n)                                  O_result_valid <= 0               ;
		else if(W_result_valid)                       O_result_valid <= 1               ;
		else                                          O_result_valid <= 0               ;
	end
	
	checkshift_rom inst_checkshift_rom
    (
        .clka       (I_clk             ),
        .addra      (W_shift_rom_addr  ),
        .douta      (W_shift_offset    )
    );
endmodule


























