module freq_meas #(
  parameter int REF_CLK_FREQ = 100_000_000
)(
  input                 meas_clk_i,
  input                 rst_i,
  input                 ref_clk_i,
  output logic [31 : 0] freq_o
);

localparam int SEC_CNT_WIDTH = $clog2( REF_CLK_FREQ + 1 );

logic                         rst_ref_clk;
logic                         rst_meas_clk;

logic [SEC_CNT_WIDTH - 1 : 0] sec_cnt;
logic                         sec_stb;
logic                         sec_stm_meas_clk;
logic [31 : 0]                meas_cnt;
logic [31 : 0]                meas_cnt_gray_comb;
// False path between two following registers
logic [31 : 0]                meas_cnt_gray;
logic [31 : 0]                meas_cnt_gray_ref_clk;
logic [31 : 0]                meas_cnt_gray_ref_clk_mtstb;
logic [31 : 0]                meas_cnt_comb_ref_clk;
logic [31 : 0]                meas_cnt_ref_clk;

rst_sync ref_rst_sync
(
  .arst_i ( rst_i       ),
  .clk_i  ( ref_clk_i   ),
  .rst_o  ( rst_ref_clk )
);

rst_sync meas_rst_sync
(
  .arst_i ( rst_i        ),
  .clk_i  ( meas_clk_i   ),
  .rst_o  ( rst_meas_clk )
);

stb_cdc sec_stb_cdc
(
  .stb_i_clk ( ref_clk_i        ),
  .stb_o_clk ( meas_clk_i       ),
  .stb_i     ( sec_stb          ),
  .stb_o     ( sec_stm_meas_clk )
);

always_ff @( posedge ref_clk_i, posedge rst_ref_clk )
  if( rst_ref_clk )
    sec_cnt <= SEC_CNT_WIDTH'( 0 );
  else
    if( sec_cnt == SEC_CNT_WIDTH'( REF_CLK_FREQ ) )
      sec_cnt <= SEC_CNT_WIDTH'( 0 );
    else
      sec_cnt <= sec_cnt + 1'b1;

assign sec_stb = sec_cnt == SEC_CNT_WIDTH'( REF_CLK_FREQ );

always_ff @( posedge meas_clk_i, posedge rst_meas_clk )
  if( rst_meas_clk )
    meas_cnt <= 32'd0;
  else
    if( sec_stm_meas_clk )
      meas_cnt <= 32'd0;
    else
      meas_cnt <= meas_cnt + 1'b1;

bin2gray #(
  .DATA_WIDTH ( 32                 )
) meas_cnt_to_gray (
  .bin_i      ( meas_cnt           ),
  .gray_o     ( meas_cnt_gray_comb )
);

always_ff @( posedge meas_clk_i, posedge rst_meas_clk )
  if( rst_meas_clk )
    meas_cnt_gray <= 32'd0;
  else
    meas_cnt_gray <= meas_cnt_gray_comb;

always_ff @( posedge ref_clk_i, posedge rst_ref_clk )
  if( rst_ref_clk )
    begin
      meas_cnt_gray_ref_clk       <= 32'd0;
      meas_cnt_gray_ref_clk_mtstb <= 32'd0;
    end
  else
    begin
      meas_cnt_gray_ref_clk       <= meas_cnt_gray;
      meas_cnt_gray_ref_clk_mtstb <= meas_cnt_gray_ref_clk;
    end

gray2bin #(
  .DATA_WIDTH ( 32                           )
) meas_cnt_to_bin (
  .gray_i     ( meas_cnt_gray_ref_clk_mtstb ),
  .bin_o      ( meas_cnt_comb_ref_clk       )
);

always_ff @( posedge ref_clk_i, posedge rst_ref_clk )
  if( rst_ref_clk )
    meas_cnt_ref_clk <= 32'd0;
  else
    meas_cnt_ref_clk <= meas_cnt_comb_ref_clk;

always_ff @( posedge ref_clk_i, posedge rst_ref_clk )
  if( rst_ref_clk )
    freq_o <= 32'd0;
  else
    if( sec_stb )
      freq_o <= meas_cnt_ref_clk;

endmodule
