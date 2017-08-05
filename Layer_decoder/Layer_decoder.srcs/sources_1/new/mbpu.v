module mbpu	#(
	parameter	BLOCK_SIZE		= 127,
	parameter 	C2V_WIDTH		= 4,
	parameter	ROW_BLOCK		= 6,		// 行块数
	parameter	COL_BLOCK		= 72,		// 列块数
	parameter	COL_CNT_WIDTH	= 7,
	parameter	ROW_CNT_WIDTH	= 2,
	parameter	MB_COL			= 4,
	parameter	MB_ROW			= 2
)(
	input													i_clk			,
	input													i_rst_n			,

	input			[MB_COL-1:0]							i_vld_1			,
	input			[ROW_CNT_WIDTH-1:0]						i_row_cnt_1		,
	input			[COL_CNT_WIDTH-1:0]						i_col_cnt_1		,
	input													i_1_last		,

	input			[MB_COL-1:0]							i_vld_2			,
	input			[ROW_CNT_WIDTH-1:0]						i_row_cnt_2		,
	input			[COL_CNT_WIDTH-1:0]						i_col_cnt_2		,
	input													i_2_last		,

	input			[MB_COL*BLOCK_SIZE*C2V_WIDTH-1:0]		i_l				,
	input			[MB_COL*BLOCK_SIZE-1:0]					i_1_sign_q		,
	input			[MB_COL*BLOCK_SIZE-1:0]					i_2_sign_q		,
	input			[MB_COL*BLOCK_SIZE-1:0]					i_2_sign_q_ap	,

	output			[MB_COL*BLOCK_SIZE*C2V_WIDTH-1:0]		o_d				,
	output			[MB_COL*BLOCK_SIZE-1:0]					o_1_sign_q
	
);

	localparam APP_WIDTH = C2V_WIDTH;

	genvar	i;	// 1-> BLOCK_SIZE
	genvar	j;	// 1-> MB_COL

	generate
		
		for	(i=0; i < BLOCK_SIZE; i=i+1)	begin: pe_cluster

			wire	[MB_COL*APP_WIDTH-1:0]	w_i_l			;
			wire	[MB_COL-1:0]			w_1_sign_q		;
			wire	[MB_COL-1:0]			w_2_sign_q		;
			wire	[MB_COL-1:0]			w_2_sign_q_ap	;
			wire	[MB_COL*APP_WIDTH-1:0]	w_o_d			;
			wire	[MB_COL-1:0]			w_o_1_sign_q		;

			for	(j=0; j< MB_COL; j=j+1)	begin: pe_cluster_assign
				assign	w_i_l[(j+1)*APP_WIDTH-1:j*APP_WIDTH] = i_l[(j*BLOCK_SIZE+i)*APP_WIDTH +: APP_WIDTH];
				assign	w_1_sign_q[j] = i_1_sign_q[(j)*BLOCK_SIZE + i];
				assign	w_2_sign_q[j] = i_2_sign_q[(j)*BLOCK_SIZE + i];
				assign	w_2_sign_q_ap[j] = i_2_sign_q_ap[(j)*BLOCK_SIZE + i];

				assign	o_d[((j)*BLOCK_SIZE+i)*APP_WIDTH +: APP_WIDTH] = w_o_d[(j)*APP_WIDTH +: APP_WIDTH];
				assign	o_1_sign_q[(j)*BLOCK_SIZE + i] = w_o_1_sign_q[j]; 
			end

			pe #(
				.C2V_WIDTH		(C2V_WIDTH		),
				.ROW_BLOCK	    (ROW_BLOCK	  	),
				.COL_BLOCK	    (COL_BLOCK	  	),
				.COL_CNT_WIDTH  (COL_CNT_WIDTH	),
				.ROW_CNT_WIDTH  (ROW_CNT_WIDTH	),
				.MB_COL			(MB_COL			),
				.MB_ROW			(MB_ROW			)
				) pe_unit (
				.i_clk			(i_clk					),
				.i_rst_n		(i_rst_n				),

				.i_vld_1		(i_vld_1				),
				.i_row_cnt_1	(i_row_cnt_1			),
				.i_col_cnt_1	(i_col_cnt_1			),
				.i_1_last		(i_1_last				),

				.i_vld_2		(i_vld_2				),
				.i_row_cnt_2	(i_row_cnt_2			),
				.i_col_cnt_2	(i_col_cnt_2			),
				.i_2_last		(i_2_last				),

				.i_l			(w_i_l					),
				.i_1_sign_q		(w_1_sign_q				),
				.i_2_sign_q		(w_2_sign_q				),
				.i_2_sign_q_ap	(w_2_sign_q_ap			),

				.o_d			(w_o_d					),
				.o_1_sign_q		(w_o_1_sign_q			)
			);

		end

	endgenerate
	
endmodule