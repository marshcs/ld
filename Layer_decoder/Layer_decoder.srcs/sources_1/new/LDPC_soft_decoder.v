`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/07/27 15:05:53
// Design Name: 
// Module Name: LDPC_soft_decoder
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


module LDPC_soft_decoder #(
	// WIDTH
	parameter INIT_INFO_WIDTH 	= 2		,
	parameter MESSAGE_WIDTH 	= 6		,
	parameter BLK_INDEX_WIDTH 	= 7		,
	parameter GF_SIZE_LOG2 		= 7		,
	// PCM
	parameter SUBPCM_ROWN 		= 2		,
	parameter SUBPCM_COLN 		= 4		,
	parameter PCM_ROWN 			= 6	,
	parameter PCM_COLN 			= 72	,
	// OTHER
	parameter MAX_ITER 			= 20 	,
	parameter MIN_NUM 			= 2		,
	parameter RW_LATENCY		= 2		
)(
	clk							,
	rst_n						,

//	i_pcm_mask 					,
	i_strength0					,
	i_strength1					,

	i_init_info 				,
	i_init_info_valid 			,
	o_init_info_ready 			,

	o_decoding_end				,
	o_parity_check_satisfied	,

	o_decoded_info				,
	o_decoded_info_valid 		,
	o_decoded_info_last			
);

// -------------------------v clog2 v-------------------------

function integer clog2;
    input integer value;
    for(clog2 = 0; value > 0; clog2 = clog2 + 1) begin
	    value = value >> 1;
    end
endfunction

// -------------------------^ clog2 ^-------------------------

// -------------------------v 参数赋值 v-------------------------

localparam BLK_SIZE = (1 << GF_SIZE_LOG2) - 1;

//localparam MAX_ABS = {(MESSAGE_WIDTH-1){1'd1}};
//localparam DEFALUT_BLK_CN_MINS = {BLK_SIZE{MAX_ABS,6'd1,MAX_ABS,6'd0}};
//localparam DEFALUT_BLK_CN_GLOBAL_SIGN = {BLK_SIZE{1'd0}};
//localparam DEFALUT_BLK_CN_PARITY_CHECK = {BLK_SIZE{1'd0}};
//localparam CBLK_DEFAULT_DATA = {DEFALUT_BLK_CN_MINS,DEFALUT_BLK_CN_GLOBAL_SIGN,DEFALUT_BLK_CN_PARITY_CHECK};
localparam LAYER_CNT_WIDTH = clog2(PCM_ROWN / SUBPCM_ROWN);//3层大的layer
localparam SUBPCM_NUM = PCM_ROWN * PCM_COLN / SUBPCM_COLN / SUBPCM_ROWN;
localparam SUBPCM_NUM_WIDTH = clog2(SUBPCM_NUM);
localparam SHIFT_MEM_WIDTH = BLK_INDEX_WIDTH * SUBPCM_ROWN * SUBPCM_COLN;//移位值ROM位宽为7*2*4
//localparam STAGE1_DELAY = 2;//MSU处理单元处理stage1的延时
localparam FIFO_DELAY = 1;//FIFO读取数据的延时为1

//localparam  = MESSAGE_WIDTH - 1 + BLK_INDEX_WIDTH;
//localparam CBLK_MEM_WIDTH = BLK_SIZE * ( MIN_NUM * MIN_WIDTH + 2 );
//localparam CBLK_MEM_DEPTH = PCM_ROWN - SUBPCM_ROWN;
//localparam CBLK_MEM_ADDR_WIDTH = clog2(CBLK_MEM_DEPTH);

//localparam VBLK_MEM_WIDTH = SUBPCM_COLN * BLK_SIZE * (SUBPCM_ROWN + 1);

//localparam INIT_MEM_WIDTH = SUBPCM_COLN* BLK_SIZE * INIT_INFO_WIDTH;

//localparam SUBPCM_MEM_WIDTH = SUBPCM_ROWN * SUBPCM_COLN * GF_SIZE_LOG2;

localparam COL_CNT_WIDTH = clog2(PCM_COLN / SUBPCM_COLN); //5
localparam APP_INFO_DEPTH = PCM_COLN / SUBPCM_COLN;
localparam COL_CAL_DELAY = PCM_COLN / SUBPCM_COLN + 4; //5
//localparam SUBPCM_CNT_WIDTH = clog2(SUBPCM_NUM);
localparam ITER_CNT_WIDTH = clog2(MAX_ITER);

//localparam SUM_RESULT_WIDTH = MESSAGE_WIDTH + clog2(SUBPCM_ROWN + 1);
//localparam COMP_RESULT_WIDTH = clog2(SUBPCM_COLN + MIN_NUM);

// -------------------------^ 参数赋值 ^-------------------------

// -------------------------v 端口声明 v-------------------------

input 													clk							;
input 													rst_n						;

//input 		[SUBPCM_COLN*SUBPCM_ROWN*SUBPCM_NUM-1:0]	i_pcm_mask					;
input 		[MESSAGE_WIDTH-1:0] 						i_strength0 				;
input 		[MESSAGE_WIDTH-1:0] 						i_strength1 				;

input 		[SUBPCM_COLN*BLK_SIZE*INIT_INFO_WIDTH-1:0] 	i_init_info 				;
input 													i_init_info_valid 			;
output  reg 										    o_init_info_ready 			;

output 													o_decoding_end				;
output  												o_parity_check_satisfied	;

output 		[SUBPCM_COLN*BLK_SIZE-1:0]					o_decoded_info				;
output 													o_decoded_info_valid 		;	
output 													o_decoded_info_last			;

// -------------------------^ 端口声明 ^-------------------------

genvar i;
genvar j;

// -------------------------v 计数 v-------------------------

reg [COL_CNT_WIDTH-1:0] r_init_cnt; //llr输入个数计数，每次输入4*127个，输入18次完成

always @(posedge clk) begin
	if(~rst_n)									            r_init_cnt <= 0;
    else if(o_decoding_end)                                 r_init_cnt <= 0;
    else if(r_init_cnt == APP_INFO_DEPTH)                   r_init_cnt <= {COL_CNT_WIDTH{1'b1}};
	else if(i_init_info_valid && o_init_info_ready)		    r_init_cnt <= r_init_cnt + 1;
	else 										            r_init_cnt <= r_init_cnt;
end

always @(posedge clk) begin
	if(~rst_n)									                                            o_init_info_ready <= 1;
    else if(o_decoded_info_valid & o_decoded_info_last)                                     o_init_info_ready <= 1;
	else if(i_init_info_valid && o_init_info_ready && r_init_cnt == APP_INFO_DEPTH - 1)		o_init_info_ready <= 0;
	else 										                                            o_init_info_ready <= o_init_info_ready;
end

wire w_decoding_begin;
assign w_decoding_begin = r_init_cnt == APP_INFO_DEPTH;

reg [COL_CNT_WIDTH-1:0] r_output_cnt; //判决结果通过校验，app输出个数计数，每次输出4*127个，输入18次完成

always @(posedge clk) begin
	if(~rst_n)									                r_output_cnt <= 0;
    else if(o_decoding_end)                                     r_output_cnt <= 0;
	else 										                r_output_cnt <= r_output_cnt + 1;
end

reg r_decoding_end; //译码结束，输出结果

always @(posedge clk) begin
	if(~rst_n)									                r_decoding_end <= 0;
    else if(o_decoded_info_valid && o_decoded_info_last)        r_decoding_end <= 0;
    else if(o_decoding_end)                                     r_decoding_end <= 1;
	else 										                r_decoding_end <= r_decoding_end;
end

reg [COL_CNT_WIDTH-1:0] r_decode_cnt; //译码开始时的app menmory 地址 移位ROM 1的地址 生成，共18个地址

always @(posedge clk) begin
	if(~rst_n)									                r_decode_cnt <= 0;
    else if(w_decoding_begin)                                   r_decode_cnt <= 0;
    else if(r_decode_cnt == COL_CAL_DELAY)                      r_decode_cnt <= 0;//一层layer完成计算，开始下一层输入
	else										                r_decode_cnt <= r_decode_cnt + 1;
end

// reg [COL_CNT_WIDTH-1:0] r_stage2_cnt; //控制MSU的stage2的计数，共18个地址

// always @(posedge clk) begin
// 	if(~rst_n)									                        r_stage2_cnt <= 0;
//     else if(w_decoding_begin)                                           r_stage2_cnt <= 0;
//     else if(r_decode_cnt == RW_LATENCY + APP_INFO_DEPTH + FIFO_DELAY)    r_stage2_cnt <= 0;//stage1完成，stage2开始
// 	else if(r_iter_cnt > 0 || (r_layer_cnt > 0 || (r_layer_cnt == 0 && r_decode_cnt > RW_LATENCY + APP_INFO_DEPTH + FIFO_DELAY))) 								
//                                                                         r_stage2_cnt <= r_stage2_cnt + 1;
//     else                                                                r_stage2_cnt <= r_stage2_cnt;
// end

reg [LAYER_CNT_WIDTH-1:0] r_layer_cnt; //layer计数

always @(posedge clk) begin
	if(~rst_n)									                r_layer_cnt <= 0;
    else if(w_decoding_begin)                                   r_layer_cnt <= 0;
    else if(r_decode_cnt == COL_CAL_DELAY && r_layer_cnt == 2)  r_layer_cnt <= 0;
    else if(r_decode_cnt == COL_CAL_DELAY && r_layer_cnt < 2)   r_layer_cnt <= r_layer_cnt + 1;
	else 										                r_layer_cnt <= r_layer_cnt;
end

reg [ITER_CNT_WIDTH-1:0] r_iter_cnt;

always @(posedge clk) begin
	if(~rst_n)									                r_iter_cnt <= 0;
	else if(w_decoding_begin)					                r_iter_cnt <= 0;
	else if(r_decode_cnt == COL_CAL_DELAY && r_layer_cnt == 2)	r_iter_cnt <= (r_iter_cnt == MAX_ITER - 1)? 0 : r_iter_cnt + 1;
	else 										                r_iter_cnt <= r_iter_cnt;
end


//reg [SUBPCM_COLN*SUBPCM_ROWN*SUBPCM_NUM-1:0] r_pcm_mask;
//
//always @(posedge clk) begin
//	if(~rst_n)									r_pcm_mask <= 0;
//	else if(i_decoding_begin)					r_pcm_mask <= i_pcm_mask;
//	else 										r_pcm_mask <= {r_pcm_mask[SUBPCM_COLN*SUBPCM_ROWN*(SUBPCM_NUM-1)-1:0],r_pcm_mask[SUBPCM_COLN*SUBPCM_ROWN*SUBPCM_NUM-1:SUBPCM_COLN*SUBPCM_ROWN*(SUBPCM_NUM-1)]};
//end
//
//wire [SUBPCM_COLN*SUBPCM_ROWN-1:0] w_subpcm_mask;
//
//assign w_subpcm_mask = r_pcm_mask[SUBPCM_COLN*SUBPCM_ROWN*SUBPCM_NUM-1:SUBPCM_COLN*SUBPCM_ROWN*(SUBPCM_NUM-1)];


// -------------------------^ 计数 ^-------------------------


// -------------------------^ llr memory ^-------------------------
wire [MESSAGE_WIDTH*BLK_SIZE-1:0] w_new_app [0:3];
wire [COL_CNT_WIDTH-1:0] llr_mem_addr;
wire [MESSAGE_WIDTH*BLK_SIZE-1:0] llr_mem_din [0:3];
wire [MESSAGE_WIDTH*BLK_SIZE-1:0] llr_mem_dout [0:3];
wire [SUBPCM_COLN*BLK_SIZE*MESSAGE_WIDTH-1:0] i_init_llr;
wire llr_mem_wea;//llr存储写使能，初始化或者更新时有效 初始化写使能或者MUS输出结果使能
wire [MESSAGE_WIDTH*BLK_SIZE-1:0] llr_fifo_dout [0:3];
reg signed [MESSAGE_WIDTH+1:0] r_data_max = {3'b000, {(MESSAGE_WIDTH-1){1'b1}}};
reg signed [MESSAGE_WIDTH+1:0] r_data_min = {3'b111, {(MESSAGE_WIDTH-1){1'b0}}};

wire [MESSAGE_WIDTH*BLK_SIZE-1:0] r_stage2_shift_data [0:7];

assign llr_mem_addr = r_decoding_end ? r_output_cnt : r_init_cnt < APP_INFO_DEPTH ? r_init_cnt : r_decode_cnt - RW_LATENCY;
assign llr_mem_wea = r_init_cnt < APP_INFO_DEPTH ? i_init_info_valid && o_init_info_ready : (r_iter_cnt > 0 || r_layer_cnt > 0) && ~r_decoding_end && (r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt >= RW_LATENCY) && (r_decode_cnt < RW_LATENCY + APP_INFO_DEPTH);

generate
	for(i = 0; i < SUBPCM_COLN; i = i + 1) begin: app_update_1	
        for(j = 0; j < BLK_SIZE; j = j + 1) begin: app_update_2	
			wire signed [MESSAGE_WIDTH+1:0] w_temp_add_result;//计算过程中用8bit运算
            assign w_temp_add_result = {{2{r_stage2_shift_data[i][MESSAGE_WIDTH*(j+1)-1]}}, r_stage2_shift_data[i][MESSAGE_WIDTH*(j+1)-1:MESSAGE_WIDTH*j]} + {{2{r_stage2_shift_data[i+4][MESSAGE_WIDTH*(j+1)-1]}}, r_stage2_shift_data[i+4][MESSAGE_WIDTH*(j+1)-1:MESSAGE_WIDTH*j]} + {{2{llr_fifo_dout[i][MESSAGE_WIDTH*(j+1)-1]}}, llr_fifo_dout[i][MESSAGE_WIDTH*(j+1)-1:MESSAGE_WIDTH*j]};
            assign w_new_app[i][MESSAGE_WIDTH*(j+1)-1:MESSAGE_WIDTH*j] = (w_temp_add_result >= r_data_max) ? {1'b0, {(MESSAGE_WIDTH-1){1'b1}}} : (w_temp_add_result <= r_data_min) ? {1'b1, {(MESSAGE_WIDTH-1){1'b0}}} : {w_temp_add_result[MESSAGE_WIDTH+1], w_temp_add_result[MESSAGE_WIDTH-2:0]};
        end
    end	
endgenerate

generate
	for(i = 0; i < SUBPCM_COLN*BLK_SIZE; i = i + 1) begin: llr_init	
        assign i_init_llr[MESSAGE_WIDTH*(i+1)-1:MESSAGE_WIDTH*i] = (i_init_info[INIT_INFO_WIDTH*(i+1)-1:INIT_INFO_WIDTH*i] == 2'b00) ? i_strength0 : (i_init_info[INIT_INFO_WIDTH*(i+1)-1:INIT_INFO_WIDTH*i] == 2'b01) ? i_strength1 : (i_init_info[INIT_INFO_WIDTH*(i+1)-1:INIT_INFO_WIDTH*i] == 2'b10) ? 1 + ~i_strength0 : 1 + ~i_strength1;
	end	
endgenerate

generate
	for(i = 0; i < 4; i = i + 1) begin: llr_mem	

        assign llr_mem_din[i] = r_init_cnt < APP_INFO_DEPTH ? i_init_llr[MESSAGE_WIDTH*BLK_SIZE*(4-i)-1:MESSAGE_WIDTH*BLK_SIZE*(3-i)] : w_new_app[i];// MSU处理后求和的结果;

		llr_mem inst_llr_mem (
          .clka(clk),    // input wire clka
          .wea(llr_mem_wea),      // input wire [0 : 0] wea
          .addra(llr_mem_addr),  // input wire [4 : 0] addra
          .dina(llr_mem_din[i]),    // input wire [761 : 0] dina
          .douta(llr_mem_dout[i])  // output wire [761 : 0] douta
        );

	end	
endgenerate

// -------------------------^ llr memory ^-------------------------


// -------------------------^ llr fifo ^-------------------------
wire llr_fifo_wr;
wire llr_fifo_rd;
assign llr_fifo_wr = llr_mem_wea;//和RAM同时写入
assign llr_fifo_rd = (r_init_cnt > APP_INFO_DEPTH) && (r_iter_cnt > 0 || r_layer_cnt > 0) && (r_decode_cnt >= FIFO_DELAY) && (r_decode_cnt < FIFO_DELAY + APP_INFO_DEPTH);//FIFO一个clk出结果，MSU收到后马上给结果
generate
	for(i = 0; i < 4; i = i + 1) begin: llr_fifo	

		llr_fifo inst_llr_fifo (
          .clk(clk),                // input wire clk
          .rst(o_decoding_end || ~rst_n),                // input wire rst
          .din(llr_mem_din[i]),                // input wire [761 : 0] din
          .wr_en(llr_fifo_wr),            // input wire wr_en
          .rd_en(llr_fifo_rd),            // input wire rd_en
          .dout(llr_fifo_dout[i]),              // output wire [761 : 0] dout
          .full(),              // output wire full
          .empty(),            // output wire empty
          .valid(),            // output wire valid
          .data_count()  // output wire [4 : 0] data_count
        );

	end	
endgenerate

// -------------------------^ llr fifo ^-------------------------

// -------------------------^ new q_sign fifo ^-------------------------
wire [SUBPCM_COLN*BLK_SIZE-1:0] new_q_sign_fifo_din [0:1];
wire [SUBPCM_COLN*BLK_SIZE-1:0] new_q_sign_fifo_dout [0:1];
wire new_q_sign_fifo_wr;
wire new_q_sign_fifo_rd;
wire new_q_sign_fifo_valid [0:1];
assign new_q_sign_fifo_wr = (r_init_cnt > APP_INFO_DEPTH) && ~r_decoding_end && (r_decode_cnt >= RW_LATENCY + RW_LATENCY) && (r_decode_cnt < RW_LATENCY + RW_LATENCY + APP_INFO_DEPTH);//除第一次，和写回APP RAM的数据同时出结果 r_init_cnt < APP_INFO_DEPTH ? 0 : (r_decode_cnt >= RW_LATENCY + FIFO_DELAY) && (r_decode_cnt < RW_LATENCY + FIFO_DELAY + APP_INFO_DEPTH);//MSU输出q符号信息有效;
assign new_q_sign_fifo_rd = (r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt >= FIFO_DELAY) && (r_decode_cnt < FIFO_DELAY + APP_INFO_DEPTH) && (r_iter_cnt > 0 || r_layer_cnt > 0);//第一层layer的stage1后，开始读取q运算

generate
	for(i = 0; i < 2; i = i + 1) begin: new_q_sign_fifo	

		q_sign_fifo inst_q_sign_fifo (
            .clk(clk),                // input wire clk
            .rst(o_decoding_end || ~rst_n),                // input wire rst
            .din(new_q_sign_fifo_din[i]),                // input wire [507 : 0] din
            .wr_en(new_q_sign_fifo_wr),            // input wire wr_en
            .rd_en(new_q_sign_fifo_rd),            // input wire rd_en
            .dout(new_q_sign_fifo_dout[i]),              // output wire [507 : 0] dout
            .full(),              // output wire full
            .empty(),            // output wire empty
            .valid(new_q_sign_fifo_valid[i]),            // output wire valid
            .data_count()  // output wire [4 : 0] data_count
        );

	end	
endgenerate

// -------------------------^ new q_sign fifo ^-------------------------


// -------------------------^ old q_sign fifo ^-------------------------
wire [SUBPCM_COLN*BLK_SIZE-1:0] old_q_sign_fifo_din [0:5];
wire [SUBPCM_COLN*BLK_SIZE-1:0] old_q_sign_fifo_dout [0:5];
wire old_q_sign_fifo_wr [0:5];
wire old_q_sign_fifo_rd [0:5];
wire old_q_sign_fifo_valid [0:5];

generate
	for(i = 0; i < 6; i = i + 1) begin: old_q_sign_fifo	
        //初始化写入全0，第一次读取时写入自己的值，第二次读取的时候写新的q值
        assign old_q_sign_fifo_wr[i] = r_init_cnt < APP_INFO_DEPTH ? (i_init_info_valid && o_init_info_ready) : r_layer_cnt == (i + 1) % 3 ? new_q_sign_fifo_valid[0] : old_q_sign_fifo_valid[i];
        assign old_q_sign_fifo_din[i] = r_init_cnt < APP_INFO_DEPTH ? 0 : r_layer_cnt == (i + 1) % 3 ? new_q_sign_fifo_dout[i/3] : old_q_sign_fifo_dout[i];
        assign old_q_sign_fifo_rd[i] = r_layer_cnt == i % 3 ? (r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt >= RW_LATENCY + FIFO_DELAY) && (r_decode_cnt < RW_LATENCY + FIFO_DELAY + APP_INFO_DEPTH) : r_layer_cnt == (i + 1) % 3 ? (r_init_cnt > APP_INFO_DEPTH) && (r_iter_cnt > 0 || r_layer_cnt > 0) && (r_decode_cnt >= FIFO_DELAY) && (r_decode_cnt < FIFO_DELAY + APP_INFO_DEPTH) : 0;

		q_sign_fifo inst_q_sign_fifo (
            .clk(clk),                // input wire clk
            .rst(o_decoding_end || ~rst_n),                // input wire rst
            .din(old_q_sign_fifo_din[i]),                // input wire [507 : 0] din
            .wr_en(old_q_sign_fifo_wr[i]),            // input wire wr_en
            .rd_en(old_q_sign_fifo_rd[i]),            // input wire rd_en
            .dout(old_q_sign_fifo_dout[i]),              // output wire [507 : 0] dout
            .full(),              // output wire full
            .empty(),            // output wire empty
            .valid(old_q_sign_fifo_valid[i]),            // output wire valid
            .data_count()  // output wire [4 : 0] data_count
        );

	end	
endgenerate

// -------------------------^ old q_sign fifo ^-------------------------

// -------------------------^ shift rom ^-------------------------
wire [SHIFT_MEM_WIDTH-1:0] w_shift_rom_dout [0:1];
wire [COL_CNT_WIDTH:0] shift_rom_addr1;
wire [COL_CNT_WIDTH:0] shift_rom_addr2;
assign shift_rom_addr1 = r_layer_cnt == 0 ? (r_decode_cnt - RW_LATENCY) : r_layer_cnt == 1 ? (r_decode_cnt + APP_INFO_DEPTH - RW_LATENCY) : (r_decode_cnt + 2*APP_INFO_DEPTH - RW_LATENCY);
assign shift_rom_addr2 = r_layer_cnt == 0 ? (r_decode_cnt + 2*APP_INFO_DEPTH) : r_layer_cnt == 1 ? r_decode_cnt : (r_decode_cnt + APP_INFO_DEPTH);

shift_rom first_shift_rom (
  .clka(clk),    // input wire clka
  .addra(shift_rom_addr1),  // input wire [5 : 0] addra
  .douta(w_shift_rom_dout[0])  // output wire [55 : 0] douta
);

shift_rom second_shift_rom (
  .clka(clk),    // input wire clka
  .addra(shift_rom_addr2),  // input wire [5 : 0] addra 控制MSU输出结果移位的地址信号
  .douta(w_shift_rom_dout[1])  // output wire [55 : 0] douta
);

// -------------------------^ shift rom ^-------------------------


// -------------------------^ even and odd mbpu ^-------------------------
wire [MESSAGE_WIDTH*BLK_SIZE-1:0] r_stage1_shift_data [0:7];

wire [SUBPCM_COLN-1:0] w_valid_stage1;
wire [SUBPCM_COLN-1:0] w_valid_stage2;
//assign w_valid_stage1 = ((r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt >= RW_LATENCY + RW_LATENCY) && ~r_decoding_end) ? ((r_decode_cnt < RW_LATENCY + RW_LATENCY + APP_INFO_DEPTH - 1) ? 4'b1111 : (r_decode_cnt < RW_LATENCY + RW_LATENCY + APP_INFO_DEPTH) ? 4'b1110 : 4'b0000) : 4'b0000; 
//assign w_valid_stage2 = ((r_iter_cnt > 0 || r_layer_cnt > 0) && (r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt >= RW_LATENCY) && ~r_decoding_end) ? ((r_decode_cnt < RW_LATENCY + APP_INFO_DEPTH - 1) ? 4'b1111 : (r_decode_cnt < RW_LATENCY + APP_INFO_DEPTH) ? 4'b1110 : 4'b0000) : 4'b0000; 
assign w_valid_stage1 = ((r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt >= RW_LATENCY + RW_LATENCY) && ~r_decoding_end) ? ((r_decode_cnt < RW_LATENCY + RW_LATENCY + APP_INFO_DEPTH - 1) ? 4'b1111 : (r_decode_cnt < RW_LATENCY + RW_LATENCY + APP_INFO_DEPTH) ? 4'b1111 : 4'b0000) : 4'b0000; 
assign w_valid_stage2 = ((r_iter_cnt > 0 || r_layer_cnt > 0) && (r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt >= RW_LATENCY) && ~r_decoding_end) ? ((r_decode_cnt < RW_LATENCY + APP_INFO_DEPTH - 1) ? 4'b1111 : (r_decode_cnt < RW_LATENCY + APP_INFO_DEPTH) ? 4'b1111 : 4'b0000) : 4'b0000; 

wire [LAYER_CNT_WIDTH-1:0] r_row_cnt_2;
wire [SUBPCM_COLN*BLK_SIZE*MESSAGE_WIDTH-1:0] w_shift_llr [0:1];
wire [SUBPCM_COLN*BLK_SIZE-1:0] w_1_sign_q [0:1];
wire [SUBPCM_COLN*BLK_SIZE-1:0] w_2_sign_q [0:1];
wire [SUBPCM_COLN*BLK_SIZE*MESSAGE_WIDTH-1:0] w_stage1_data [0:1];
wire r_stage1_last;
wire r_stage2_last;

assign r_stage1_last = (r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt == RW_LATENCY + RW_LATENCY +  APP_INFO_DEPTH - 1) &&  ~r_decoding_end;
assign r_stage2_last = (r_init_cnt > APP_INFO_DEPTH) && (r_iter_cnt > 0 || r_layer_cnt > 0) && (r_decode_cnt == RW_LATENCY +  APP_INFO_DEPTH - 1) &&  ~r_decoding_end;

generate
	for(i = 0; i < 2; i = i + 1) begin: even_and_odd_mbpu	

        assign w_shift_llr[i] = {r_stage1_shift_data[4*i],r_stage1_shift_data[4*i+1],r_stage1_shift_data[4*i+2],r_stage1_shift_data[4*i+3]};
        assign w_1_sign_q[i] = r_layer_cnt == 0 ? old_q_sign_fifo_dout[3*i] : r_layer_cnt == 1 ? old_q_sign_fifo_dout[3*i+1] : old_q_sign_fifo_dout[3*i+2];
        assign w_2_sign_q[i] = r_layer_cnt == 1 ? old_q_sign_fifo_dout[3*i] : r_layer_cnt == 2 ? old_q_sign_fifo_dout[3*i+1] : old_q_sign_fifo_dout[3*i+2];
        assign r_row_cnt_2 = r_layer_cnt > 0 ? r_layer_cnt - 1 : PCM_ROWN / SUBPCM_ROWN - 1;

        mbpu #(
        		.BLOCK_SIZE		(BLK_SIZE               ),                                    //= 127,
        	 	.C2V_WIDTH		(MESSAGE_WIDTH	        ),                                    //= 4,
        		.ROW_BLOCK		(PCM_ROWN               ),                                    //= 6,		// 行块数
        		.COL_BLOCK		(PCM_COLN               ),                                    //= 72,		// 列块数
        		.COL_CNT_WIDTH	(COL_CNT_WIDTH          ),                                    //= 5,
        		.ROW_CNT_WIDTH	(LAYER_CNT_WIDTH        ),                                    //= 2,
        		.MB_COL			(SUBPCM_COLN            ),                                    //= 4
                .MB_ROW			(SUBPCM_ROWN            )                                     //= 4
        ) inst_mbpu (
        	.i_clk          (clk                                                                                                                    ),		       
        	.i_rst_n        (rst_n && ~r_decoding_end                                                                                               ),    		 
        	.i_vld_1        (w_valid_stage1                                                                                                         ),		 
        	.i_row_cnt_1    (r_layer_cnt                                                                                                            ), 	 
        	.i_col_cnt_1    (r_decode_cnt - RW_LATENCY[COL_CNT_WIDTH-1:0] - RW_LATENCY[COL_CNT_WIDTH-1:0]                                           ),        	 
        	.i_1_last       (r_stage1_last 																											),		   
        	.i_vld_2        (w_valid_stage2                                                                                                         ),    		 
        	.i_row_cnt_2    (r_row_cnt_2                                                                                                            ),    	 
        	.i_col_cnt_2    (r_decode_cnt - RW_LATENCY[COL_CNT_WIDTH-1:0]                                                                           ),  
        	.i_2_last       (r_stage2_last                                 																			),	 
        	.i_l            (w_shift_llr[i]                                                                                                         ),    			 
        	.i_1_sign_q     (w_1_sign_q[i]                                                                                                          ),    		   
        	.i_2_sign_q     (w_2_sign_q[i]                                                                                                          ),    		   
        	.i_2_sign_q_ap  (new_q_sign_fifo_dout[i]                                                                                                ),    	   
        	.o_d            (w_stage1_data[i]                                                                                                       ),			 
        	.o_1_sign_q     (new_q_sign_fifo_din[i]                                                                                                 )    
        ); 

	end	
endgenerate

// -------------------------^ even and odd mbpu ^-------------------------


// -------------------------^ stage1_barrel_shifter ^-------------------------
generate
	for(i = 0; i < SUBPCM_ROWN * SUBPCM_COLN; i = i + 1) begin: stage1_barrel_shifter	

        barrel_shifter_pblk #(
            .DATA_WIDTH 			(MESSAGE_WIDTH),        //= 6	,	// 单个数据的位宽
            .DATA_NUM				(BLK_SIZE),             //= 127,	// 数据的个数
            .SHIFT_OFFSET_WIDTH 	(GF_SIZE_LOG2)          //= 7		// 移位值的位宽
        )inst_barrel_shifter_pblk (	
        	.i_blk_ena		(1'b1                                                           							),	// 该信号的每一位表示 QC Block 列中每个 QC Block 的使能信号，低电平表示对应的 QC Block 被全零矩阵掩盖
        	.i_shift_offset	(BLK_SIZE[GF_SIZE_LOG2-1:0] - w_shift_rom_dout[0][GF_SIZE_LOG2*(8-i)-1:GF_SIZE_LOG2*(7-i)]  ),	// 移位值
        	.i_data			(llr_mem_dout[i % 4]                                            							),	// 输入数据
        	.o_shift_data	(r_stage1_shift_data[i]                                         							)	// 移位后的数据
        );

	end	
endgenerate


// -------------------------^ stage1_barrel_shifter ^-------------------------


// -------------------------^ stage2_barrel_shifter ^-------------------------
generate
	for(i = 0; i < SUBPCM_ROWN * SUBPCM_COLN; i = i + 1) begin: stage2_barrel_shifter	

        barrel_shifter_pblk #(
            .DATA_WIDTH 			(MESSAGE_WIDTH),        //= 6	,	// 单个数据的位宽
            .DATA_NUM				(BLK_SIZE),             //= 127,	// 数据的个数
            .SHIFT_OFFSET_WIDTH 	(GF_SIZE_LOG2)          //= 7		// 移位值的位宽
        )inst_barrel_shifter (	
        	.i_blk_ena		(1'b1                                                                                           ),	// 该信号的每一位表示 QC Block 列中每个 QC Block 的使能信号，低电平表示对应的 QC Block 被全零矩阵掩盖
        	.i_shift_offset	(w_shift_rom_dout[1][GF_SIZE_LOG2*(8-i)-1:GF_SIZE_LOG2*(7-i)]      								),	// 移位值 应为BLK_SIZE[GF_SIZE_LOG2-1:0] - w_shift_rom_dout[1][GF_SIZE_LOG2*(8-i)-1:GF_SIZE_LOG2*(7-i)]
        	.i_data			(w_stage1_data[i/SUBPCM_COLN][BLK_SIZE*MESSAGE_WIDTH*(4-i%4)-1:BLK_SIZE*MESSAGE_WIDTH*(3-i%4)]  ),	// 输入数据
        	.o_shift_data	(r_stage2_shift_data[i]                                                                         )	// 移位后的数据
        );

	end	
endgenerate


// -------------------------^ stage2_barrel_shifter ^-------------------------

//-------------------------^ parity check ^-------------------------
wire w_check_start;
wire [SUBPCM_COLN*BLK_SIZE-1:0] w_check_data;
wire w_check_data_valid;
wire w_check_result_valid;
assign w_check_data_valid = (r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt >= RW_LATENCY + RW_LATENCY) && (r_decode_cnt < RW_LATENCY + RW_LATENCY + APP_INFO_DEPTH) && ~r_decoding_end;
assign w_check_start = (r_init_cnt > APP_INFO_DEPTH) && (r_decode_cnt == RW_LATENCY) && ~r_decoding_end;//start后两个clk给数据

generate
	for(i = 0; i < SUBPCM_COLN*BLK_SIZE; i = i + 1) begin: decode_check	
        assign w_check_data[SUBPCM_COLN*BLK_SIZE-i-1] = o_decoded_info[i];
	end	
endgenerate

Paritycheck #(
	.BLOCK_SIZE		    (BLK_SIZE           ),     //= 127  ,
	.QUAN_WIDTH		    (MESSAGE_WIDTH      ),     //= 4    ,
	.ROW_BLOCK		    (PCM_ROWN           ),     //= 6    ,	// 行块数
	.COL_BLOCK		    (PCM_COLN           ),     //= 72   ,	// 列块数
	.COL_CNT_WIDTH	    (COL_CNT_WIDTH      ),     //= 5    ,
	.ROW_CNT_WIDTH	    (LAYER_CNT_WIDTH    ),     //= 2    ,
	.MB_COL			    (SUBPCM_COLN        ),     //= 4    ,
	.DATA_WIDTH 		(1'b1               ),     //        	= 1	   ,	// 单个数据的位宽
	.DATA_NUM		    (BLK_SIZE           ),     //        = 127  ,	// 数据的总数
	.SHIFT_OFFSET_WIDTH (GF_SIZE_LOG2       )     //	= 7		    // 移位值的位宽
)inst_Paritycheck (
    .I_clk                 (clk            				),
	.I_rst_n               (rst_n          				),
	.I_start               (w_check_start  				),
	.I_dsign               (w_check_data				),   //输入 DATA_NUM*MB_COL个符号位
    .I_dsign_valid         (w_check_data_valid			), 
	.O_result              (o_parity_check_satisfied	),   //输出判决结果,1表示成功校验，否则为0
	.O_result_valid        (w_check_result_valid		)

    );

//-------------------------^ parity check ^-------------------------

// -------------------------^ decode word output ^-------------------------
wire [SUBPCM_COLN*MESSAGE_WIDTH*BLK_SIZE-1:0] w_decode_output;
assign w_decode_output = {llr_mem_dout[0], llr_mem_dout[1], llr_mem_dout[2], llr_mem_dout[3]};

generate
	for(i = 0; i < SUBPCM_COLN*BLK_SIZE; i = i + 1) begin: decode_word_output	
        assign o_decoded_info[i] = w_decode_output[MESSAGE_WIDTH*(i+1)-1] ? 1 : 0;//译码判决，app为负即为1，否则为0
	end	
endgenerate

// -------------------------^ decode word output ^-------------------------

assign o_decoding_end = ((r_init_cnt > APP_INFO_DEPTH) && (r_iter_cnt == MAX_ITER - 1) && r_decode_cnt == COL_CAL_DELAY && r_layer_cnt == 2) || (o_parity_check_satisfied && w_check_result_valid);
assign o_decoded_info_valid = r_decoding_end && (r_output_cnt >= RW_LATENCY) &&  (r_output_cnt < RW_LATENCY + APP_INFO_DEPTH);
assign o_decoded_info_last = r_decoding_end && (r_output_cnt == RW_LATENCY + APP_INFO_DEPTH - 1);




endmodule
