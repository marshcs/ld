/* ====================================================================================
Company: 南京大学
Engineer: 陈帅

---------------------------------------------------------------------------------------
Create Date: 2017-07-20 
Design Name: min_find.v
Project Name: 

---------------------------------------------------------------------------------------
Description: 	从 IN_NUM 个输入和 MIN_NUM 个数中找到最小的两个值输出，

				并输出新的最小值的index

---------------------------------------------------------------------------------------
Revision: 0.01

Revision 0.01 - File Created

==================================================================================== */

module min #(
	parameter	ABS_WIDTH			= 5	,
	parameter	IN_NUM 				= 4	,
	parameter	MIN_NUM				= 2 ,
	parameter	IDX_WIDTH			= 3	,
	parameter	COMP_RESULT_WIDTH	= 3
	)(
	input	[IN_NUM *ABS_WIDTH-1:0]		i_new,
	input	[MIN_NUM*ABS_WIDTH-1:0]		i_min,
	
	output	[MIN_NUM*ABS_WIDTH-1:0]		o_min,			// 第一最小值在最低位；
	output	[MIN_NUM*IDX_WIDTH-1:0]		o_idx			// 0-->TOT_NUM: i_new LSB --> i_new MSB --> i_min smallest--> i_min --> largest 
	);
	
	localparam TOT_NUM = IN_NUM + MIN_NUM;
	reg		[ABS_WIDTH-1:0]		r_new_min				[MIN_NUM-1:0]	;
	reg 	[IDX_WIDTH-1:0]		r_new_min_idx			[MIN_NUM-1:0]	;
//--------------->> 接口信号预处理 >>-----------------------------
	genvar i;
	
	wire	[ABS_WIDTH-1:0]		w_sort_data				[TOT_NUM-1:0]	;
	
	generate
		for(i=0; i< TOT_NUM; i=i+1)	begin: sort_data_assign
			if(i< IN_NUM)	begin	// 前 IN_NUM 个数为输入的新值；
				assign	w_sort_data[i] = i_new[(i+1)*ABS_WIDTH-1 : i*ABS_WIDTH];
			end
			else begin			// 后NUM_MIN个为原来的最小值；
				assign	w_sort_data[i] = i_min[(i+1-IN_NUM)*ABS_WIDTH-1 : (i-IN_NUM)*ABS_WIDTH];
			end
		end
	endgenerate
	
	generate
		for(i=0; i < MIN_NUM; i=i+1)	begin: out_data_assign
			assign o_min[(i+1)*ABS_WIDTH-1:i*ABS_WIDTH] = r_new_min[i];
			assign o_idx[(i+1)*IDX_WIDTH-1:i*IDX_WIDTH] = r_new_min_idx[i];
		end
	endgenerate
//---------------<< 接口信号预处理 <<----------------------------

//--------------->> 交叉比较 >>--------------------------------
	reg [TOT_NUM-1:0] 	r_data_cross_comp [TOT_NUM-1:0];
	genvar j;
	generate
		for(i=0; i<TOT_NUM; i=i+1) begin: cross_comp_c
			for(j=0; j<TOT_NUM; j=j+1) begin: cross_comp
				if(i<=j)	begin
					always@(*)	begin
						r_data_cross_comp[i][j] = (w_sort_data[i] <= w_sort_data[j]);
					end
				end
				else begin
					always@(*)	begin
						r_data_cross_comp[i][j] = (w_sort_data[i] < w_sort_data[j]);
					end
				end
			end
		end
	endgenerate
//---------------<< 交叉比较 <<--------------------------------
	
//--------------->> 找NUM_MIN个最小值 >>------------------------	
	wire 	[COMP_RESULT_WIDTH-1:0] w_data_comp_result_sum 	[TOT_NUM-1:0];

	generate
		// if(IN_NUM+MIN_NUM = 6)	begin:
		
			assign w_data_comp_result_sum[5] = r_data_cross_comp[5][5] + r_data_cross_comp[5][4] + r_data_cross_comp[5][3] + r_data_cross_comp[5][2] + r_data_cross_comp[5][1] + r_data_cross_comp[5][0];
			assign w_data_comp_result_sum[4] = r_data_cross_comp[4][5] + r_data_cross_comp[4][4] + r_data_cross_comp[4][3] + r_data_cross_comp[4][2] + r_data_cross_comp[4][1] + r_data_cross_comp[4][0];
			assign w_data_comp_result_sum[3] = r_data_cross_comp[3][5] + r_data_cross_comp[3][4] + r_data_cross_comp[3][3] + r_data_cross_comp[3][2] + r_data_cross_comp[3][1] + r_data_cross_comp[3][0];
			assign w_data_comp_result_sum[2] = r_data_cross_comp[2][5] + r_data_cross_comp[2][4] + r_data_cross_comp[2][3] + r_data_cross_comp[2][2] + r_data_cross_comp[2][1] + r_data_cross_comp[2][0];
			assign w_data_comp_result_sum[1] = r_data_cross_comp[1][5] + r_data_cross_comp[1][4] + r_data_cross_comp[1][3] + r_data_cross_comp[1][2] + r_data_cross_comp[1][1] + r_data_cross_comp[1][0];
			assign w_data_comp_result_sum[0] = r_data_cross_comp[0][5] + r_data_cross_comp[0][4] + r_data_cross_comp[0][3] + r_data_cross_comp[0][2] + r_data_cross_comp[0][1] + r_data_cross_comp[0][0];

		for(i=0; i< MIN_NUM; i=i+1)	begin: find_min
		
			always @(*) begin
				if(w_data_comp_result_sum[0] == TOT_NUM - i) begin
					r_new_min[i] 	= w_sort_data[0];
					r_new_min_idx[i]= 0				;
				end
				else if(w_data_comp_result_sum[1] == TOT_NUM - i) begin
					r_new_min[i] 	= w_sort_data[1];
					r_new_min_idx[i]= 1				;
				end
				else if(w_data_comp_result_sum[2] == TOT_NUM - i) begin
					r_new_min[i] 	= w_sort_data[2];
					r_new_min_idx[i]= 2				;
				end
				else if(w_data_comp_result_sum[3] == TOT_NUM - i) begin
					r_new_min[i] 	= w_sort_data[3];
					r_new_min_idx[i]= 3				;
				end
				else if(w_data_comp_result_sum[4] == TOT_NUM - i) begin
					r_new_min[i] 	= w_sort_data[4];
					r_new_min_idx[i]= 4				;
				end
				else begin
					r_new_min[i]	= w_sort_data[5];
					r_new_min_idx[i]= 5				;
				end
			end
			
		end

	endgenerate
//---------------<< 找NUM_MIN个最小值 <<------------------------	

endmodule