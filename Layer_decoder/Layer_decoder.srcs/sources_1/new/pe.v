module pe #(
	parameter 	QUAN_WIDTH		= 4,
	parameter	ROW_BLOCK		= 6,		// 行块数
	parameter	COL_BLOCK		= 72,		// 列块数
	parameter	COL_CNT_WIDTH	= 7,
	parameter	ROW_CNT_WIDTH	= 2,
	parameter	MB_COL			= 4,
	parameter	MB_ROW			= 2
)(
	input									i_clk			,
	input									i_rst_n			,

	// stage1 ：生成C2V信息、找到最小值	
	input			[MB_COL-1:0]			i_vld_1			,
	input			[ROW_CNT_WIDTH-1:0]		i_row_cnt_1		,
	input			[COL_CNT_WIDTH-1:0]		i_col_cnt_1		,
	input									i_1_last		,

	// stage2：生成两次C2V信息的差值 D 	
	input			[MB_COL-1:0]			i_vld_2			,
	input			[ROW_CNT_WIDTH-1:0]		i_row_cnt_2		,
	input			[COL_CNT_WIDTH-1:0]		i_col_cnt_2		,
	input									i_2_last		,

	input			[MB_COL*QUAN_WIDTH-1:0]	i_l				,			// 输入信号
	input			[MB_COL-1:0]			i_1_sign_q		,
	input			[MB_COL-1:0]			i_2_sign_q		,
	input			[MB_COL-1:0]			i_2_sign_q_ap	,

	output			[MB_COL*QUAN_WIDTH-1:0]	o_d				,
	output			[MB_COL-1:0]			o_1_sign_q	

);

	localparam	MB_COL_WIDTH = 2;
	localparam	R_WIDTH = (QUAN_WIDTH-1)*2 + COL_CNT_WIDTH + MB_COL_WIDTH + 1;
	localparam	R_DEPTH = ROW_BLOCK/MB_ROW;
	
	reg		[R_WIDTH-1:0]	r_ping;
	reg		[R_WIDTH-1:0]	r_pong;

	wire	[QUAN_WIDTH-2:0]	w_pong_min1;
	wire	[QUAN_WIDTH-2:0]	w_pong_min2;
	wire	[COL_CNT_WIDTH-1:0]	w_pong_idx;
	wire	[MB_COL_WIDTH-1:0]	w_pong_mb_idx;
	wire						w_pong_tsign;

	wire	[2*(QUAN_WIDTH-1)-1:0]					w_min_fin;
	wire	[2*MB_COL_WIDTH+1:0]					w_min_idx;
	wire	[MB_COL_WIDTH-1:0]						w_min1_idx;

//------------------>> 端口预处理 >>--------------------------
	// input
	wire	[QUAN_WIDTH:0]	w_l		[MB_COL-1:0]			;		// lA:1 --> lD:MB_COL

	genvar i;
	generate
		for(i=0; i<MB_COL; i=i+1)	begin:	get_input
			assign	w_l[i] = {i_l[(i+1)*QUAN_WIDTH-1], i_l[(i+1)*QUAN_WIDTH-1:i*QUAN_WIDTH]};
		end
	endgenerate

	// output

//------------------<< 端口预处理 <<--------------------------	

//------------------>> R_regfile >>----------------------------

	reg		[R_WIDTH-1:0]	r_regfile	[R_DEPTH-1:0]	;
	wire	[R_WIDTH-1:0]	w_1_regfile				;
	wire	[R_WIDTH-1:0]	w_2_regfile				;

	assign	w_1_regfile = r_regfile[i_row_cnt_1];
	assign	w_2_regfile = r_regfile[i_row_cnt_2];
	
	wire	[QUAN_WIDTH-2:0]	w_1_r_min1	;
	wire	[QUAN_WIDTH-2:0]	w_1_r_min2	;
	wire	[COL_CNT_WIDTH-1:0]	w_1_r_idx	;
	wire	[MB_COL_WIDTH-1:0]	w_1_r_mb_idx;
	wire						w_1_r_tsign	;
	
	assign	w_1_r_min1	= (3 * w_1_regfile[QUAN_WIDTH-2:0]) >> 2;
	assign	w_1_r_min2	= (3 * w_1_regfile[QUAN_WIDTH-1 +: QUAN_WIDTH-1]) >> 2;
	assign	w_1_r_idx	= w_1_regfile[2*(QUAN_WIDTH-1) +: COL_CNT_WIDTH];
	assign	w_1_r_mb_idx= w_1_regfile[2*(QUAN_WIDTH-1)+COL_CNT_WIDTH +: MB_COL_WIDTH];
	assign	w_1_r_tsign	= w_1_regfile[R_WIDTH-1];
	
	wire	[QUAN_WIDTH-2:0]	w_2_r_min1	;
	wire	[QUAN_WIDTH-2:0]	w_2_r_min2	;
	wire	[COL_CNT_WIDTH-1:0]	w_2_r_idx	;
	wire	[MB_COL_WIDTH-1:0]	w_2_r_mb_idx;
	wire						w_2_r_tsign	;
	
	assign	w_2_r_min1	= (3 * w_2_regfile[QUAN_WIDTH-2:0]) >> 2;
	assign	w_2_r_min2	= (3 * w_2_regfile[QUAN_WIDTH-1 +: QUAN_WIDTH-1]) >> 2;
	assign	w_2_r_idx	= w_2_regfile[2*(QUAN_WIDTH-1) +: COL_CNT_WIDTH];
	assign	w_2_r_mb_idx= w_2_regfile[2*(QUAN_WIDTH-1)+COL_CNT_WIDTH +: MB_COL_WIDTH];
	assign	w_2_r_tsign	= w_2_regfile[R_WIDTH-1];

	generate
		for(i=0; i<R_DEPTH; i=i+1)	begin: Regfile_Blk
			always@(posedge i_clk)	begin
				if(~i_rst_n)	begin
					r_regfile[i] <= 'd0;
				end
				else if(i_2_last && (i_row_cnt_2==i))	begin
					r_regfile[i] <= r_pong;
				end
				else;
			end
		end
	endgenerate
	
//------------------<< R_regfile <<----------------------------

//------------------>> R_gen >>--------------------------------
	reg	signed	[QUAN_WIDTH  :0]	r_1_r		[MB_COL-1:0];
	reg	signed	[QUAN_WIDTH-1:0]	r_2_r		[MB_COL-1:0];
	reg	signed	[QUAN_WIDTH-1:0]	r_2_r_ap	[MB_COL-1:0];	// r apostrophe 
	
	generate
		for(i=0; i < MB_COL; i=i+1)	begin:	r_1_gen
			always@(*)	begin
				if(i_col_cnt_1 == w_1_r_idx && w_1_r_mb_idx == i)	begin
					if(i_1_sign_q[i] ^ w_1_r_tsign)	r_1_r[i] = {2'b1,~w_1_r_min2+1};
					else							r_1_r[i] = {2'b0,w_1_r_min2};
				end
				else	begin
					if(i_1_sign_q[i] ^ w_1_r_tsign)	r_1_r[i] = {2'b1,~w_1_r_min1+1};
					else							r_1_r[i] = {2'b0,w_1_r_min1};
				end
			end
		end
		
		for(i=0; i < MB_COL; i=i+1)	begin:	r_2_gen
			always@(*)	begin
				if(i_col_cnt_2 == w_2_r_idx && w_2_r_mb_idx == i)	begin
					if(i_2_sign_q[i] ^ w_2_r_tsign)	r_2_r[i] = {1'b1,~w_2_r_min2+1};
					else							r_2_r[i] = {1'b0,w_2_r_min2};
				end
				else	begin
					if(i_2_sign_q[i] ^ w_2_r_tsign)	r_2_r[i] = {1'b1,~w_2_r_min1+1};
					else							r_2_r[i] = {1'b0,w_2_r_min1};
				end
			end
		end

		for(i=0; i < MB_COL; i=i+1)	begin: r_2_ap_gen
			always@(*) begin
				if(i_col_cnt_2  == w_pong_idx && w_pong_mb_idx == i)	begin
					if(i_2_sign_q_ap[i] ^ w_pong_tsign)	r_2_r_ap[i]	= {1'b1,~w_pong_min2+1};
					else								r_2_r_ap[i]	= {1'b0, w_pong_min2};
				end
				else begin
					if(i_2_sign_q_ap[i] ^ w_pong_tsign)	r_2_r_ap[i]	= {1'b1,~w_pong_min1+1};
					else								r_2_r_ap[i]	= {1'b0, w_pong_min1};
				end
			end
		end

	endgenerate
//------------------<< R_gen <<--------------------------------

//------------------>> Q >>------------------------------------
	localparam MAX_POS = 2<<(QUAN_WIDTH-1) - 1;
	localparam MAX_NEG = -MAX_POS;
	wire	signed	[QUAN_WIDTH:0]		w_q_pre	[MB_COL-1:0];
	wire	signed	[QUAN_WIDTH-1:0]	w_q		[MB_COL-1:0];
	reg				[QUAN_WIDTH-2:0]	r_q_abs	[MB_COL-1:0];
	wire			[MB_COL-1:0]		w_q_sign			;
	
	wire	[MB_COL*(QUAN_WIDTH-1)-1:0]	w_q_abs_para;

	generate
		
		for(i=0; i < MB_COL; i=i+1)	begin: Cal_Q
			assign	w_q_pre[i] = w_l[i]-r_1_r[i];
			assign	w_q[i] = (w_q_pre[i] > MAX_POS) ? MAX_POS : (w_q_pre[i] < MAX_NEG ? MAX_NEG : w_q_pre[i][QUAN_WIDTH-1:0]);
			assign	w_q_sign[i] = w_q[i][QUAN_WIDTH-1];
			assign	w_q_abs_para[(i+1)*(QUAN_WIDTH-1)-1:i*(QUAN_WIDTH-1)] = r_q_abs[i];
			always@(*)	begin
				if(w_q[QUAN_WIDTH-1])		r_q_abs[i] = ~w_q[i][QUAN_WIDTH-2:0] + 1;
				else 						r_q_abs[i] =  w_q[i][QUAN_WIDTH-2:0];
			end
		end

	endgenerate

	assign	o_1_sign_q = w_q_sign;
//------------------<< Q <<------------------------------------

//------------------>> D >>------------------------------------
	reg	signed	[QUAN_WIDTH-1:0]	r_d	[MB_COL-1:0];
	
	generate
		for(i = 0; i<MB_COL; i=i+1)	begin: Cal_D
			always@(*) begin
				if(i_vld_2[i])
					r_d[i] = r_2_r_ap[i] - r_2_r[i];
				else
					r_d[i] = 0;
			end

		assign o_d[(i+1)*QUAN_WIDTH-1 : i*QUAN_WIDTH] = r_d[i];
		end

	endgenerate
//------------------<< D <<------------------------------------

//------------------>> PING-PONG >>------------------------------------
	// Ping: LSB --> MSB: min1,min2,index,total-sign
	always@(posedge i_clk)
	begin
		if(~i_rst_n)	begin
			r_ping[QUAN_WIDTH-2:0]						<= -'d1;
			r_ping[QUAN_WIDTH-1 +:QUAN_WIDTH-1]			<= -'d1;
			r_ping[R_WIDTH-2:2*(QUAN_WIDTH-1)]			<=  'd0;
			r_ping[R_WIDTH-1]							<= 1'b0;
		end
		else if(i_1_last)	begin	// clk after last i_col_cnt_1, reset ping;
			r_ping[QUAN_WIDTH-2:0]						<= -'d1;
		    r_ping[QUAN_WIDTH-1 +:QUAN_WIDTH-1]			<= -'d1;
		    r_ping[R_WIDTH-2:2*(QUAN_WIDTH-1)]			<=  'd0;
		    r_ping[R_WIDTH-1]							<= 1'b0;
		end
		else if(|i_vld_1)	begin	// Unpdate Ping register
			r_ping[2*(QUAN_WIDTH-1)-1:0]				<= w_min_fin;
			r_ping[R_WIDTH-1]							<= r_ping[R_WIDTH-1] ^ (^w_q_sign);
			if(w_min_idx[MB_COL_WIDTH:0] < MB_COL)
				r_ping[R_WIDTH-2:2*(QUAN_WIDTH-1)] <= {w_min1_idx, i_col_cnt_1};
			else
				r_ping[R_WIDTH-2:2*(QUAN_WIDTH-1)] <= r_ping[R_WIDTH-2:2*(QUAN_WIDTH-1)];
		end
		else;
	end

	// Pong
	assign	w_pong_min1 = (3 * r_pong[QUAN_WIDTH-2:0]) >> 2;
	assign	w_pong_min2 = (3 * r_pong[QUAN_WIDTH-1+:QUAN_WIDTH-1]) >> 2;
	assign	w_pong_idx  = r_pong[2*(QUAN_WIDTH-1) +: COL_CNT_WIDTH];
	assign	w_pong_mb_idx = r_pong[2*(QUAN_WIDTH-1)+COL_CNT_WIDTH +: MB_COL_WIDTH];
	assign	w_pong_tsign = r_pong[R_WIDTH-1];

	always@(posedge i_clk)
	begin
		if(~i_rst_n)	begin
			r_pong[QUAN_WIDTH-2:0]						<= -'d1;
			r_pong[QUAN_WIDTH-1 +:QUAN_WIDTH-1]			<= -'d1;
			r_pong[R_WIDTH-2:2*(QUAN_WIDTH-1)]			<=  'd0;
			r_pong[R_WIDTH-1]							<= 1'b0;
		end
		else if(i_1_last)	begin
			r_pong <= r_ping;
		end
		else;
	end

//------------------<< PING-PONG <<------------------------------------

//------------------>> Find-min >>-------------------------------

	min #(
		.ABS_WIDTH			(QUAN_WIDTH-1		),
		.IN_NUM 			(MB_COL				),
		.MIN_NUM			(2					),
		.IDX_WIDTH		    (MB_COL_WIDTH+1		),
		.COMP_RESULT_WIDTH  (3					)
	)
	min_fin2 (
		.i_new(w_q_abs_para					),
		.i_min(r_ping[2*(QUAN_WIDTH-1)-1:0]	),
		.o_min(w_min_fin					),
		.o_idx(w_min_idx					)
	);
	assign w_min1_idx = w_min_idx[MB_COL_WIDTH-1:0];
//------------------<< Find-min <<--------------------------------

endmodule