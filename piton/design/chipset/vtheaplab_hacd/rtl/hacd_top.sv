/////////////////////////////////////////////////////////////////////////////////
//
// Heap Lab Research
// Block: Hardware Accelerated Compressor Decompressor
//
// Author : Raghavendra Srinivas
// Contact : raghavs@vt.edu

// Author : Yuqing Liu
// Contact : nap64@vt.edu
/////////////////////////////////////////////////////////////////////////////////
// Description: top level module to encapsulate all module instantiation to
// support hardware accelerated compression/decompression
/////////////////////////////////////////////////////////////////////////////////

module hacd_top #(parameter int NOC_DWIDTH=32, parameter logic [63:0] HacdBase=64'h000000fff5100000, parameter bit          SwapEndianess   =  0)
(
    input  cfg_clk_i                              ,
    input  cfg_rst_ni                             ,
    input  clk_i                                  ,
    input  rst_ni                                 ,
    input  uart_boot_en                           ,

    input  [1:0] hawk_sw_ctrl                     ,
    output infl_interrupt                         ,
    output defl_interrupt                         ,
    input  [NOC_DWIDTH-1:0] buf_hacd_noc2_data_i  ,
    input  buf_hacd_noc2_valid_i                  ,
    output hacd_buf_noc2_ready_o                  ,
    output [NOC_DWIDTH-1:0] hacd_buf_noc3_data_o  ,
    output hacd_buf_noc3_valid_o                  ,
    input  buf_hacd_noc3_ready_i                  ,

    //CPU<->HACD
    //hacd will observe these for request signals from cpu
    HACD_AXI_WR_BUS.slv cpu_axi_wr_bus            ,
    HACD_AXI_RD_BUS.slv cpu_axi_rd_bus            ,

    //HACD<->MC
    //hacd will act as request master on request singslas to mc
    HACD_MC_AXI_WR_BUS.mstr mc_axi_wr_bus         ,
    HACD_MC_AXI_RD_BUS.mstr mc_axi_rd_bus         ,

    output wire dump_mem
);

reg  [63:0] hawk_cmd_reg;
reg  hawk_cmd_flag_m;
wire hawk_cmd_flag_s;
// begin NOC_AXI
    localparam int unsigned AxiIdWidth    =  1;
    localparam int unsigned AxiAddrWidth  = 64;
    localparam int unsigned AxiDataWidth  = 64;
    localparam int unsigned AxiUserWidth  =  1;

    AXI_BUS #(
        .AXI_ID_WIDTH   ( AxiIdWidth   ),
        .AXI_ADDR_WIDTH ( AxiAddrWidth ),
        .AXI_DATA_WIDTH ( AxiDataWidth ),
        .AXI_USER_WIDTH ( AxiUserWidth )
    )
    hacd_master();

    noc_axilite_bridge #(
        // this enables variable width accesses
        // note that the accesses are still 64bit, but the
        // write-enables are generated according to the access size
        .SLAVE_RESP_BYTEWIDTH   ( 0             ),
        .SWAP_ENDIANESS         ( SwapEndianess ),
        // this disables shifting of unaligned read data
        .ALIGN_RDATA            ( 0             )
    )
    i_hacd_axilite_bridge (
        .clk                    ( cfg_clk_i                        ),
        .rst                    ( ~cfg_rst_ni                      ),
        // to/from NOC
        .splitter_bridge_val    ( buf_hacd_noc2_valid_i ),
        .splitter_bridge_data   ( buf_hacd_noc2_data_i  ),
        .bridge_splitter_rdy    ( hacd_buf_noc2_ready_o ),
        .bridge_splitter_val    ( hacd_buf_noc3_valid_o ),
        .bridge_splitter_data   ( hacd_buf_noc3_data_o  ),
        .splitter_bridge_rdy    ( buf_hacd_noc3_ready_i ),
        //axi lite signals
        //write address channel
        .m_axi_awaddr           ( hacd_master.aw_addr               ),
        .m_axi_awvalid          ( hacd_master.aw_valid              ),
        .m_axi_awready          ( hacd_master.aw_ready              ),
        //write data channel
        .m_axi_wdata            ( hacd_master.w_data                ),
        .m_axi_wstrb            ( hacd_master.w_strb                ),
        .m_axi_wvalid           ( hacd_master.w_valid               ),
        .m_axi_wready           ( hacd_master.w_ready               ),
        //read address channel
        .m_axi_araddr           ( hacd_master.ar_addr               ),
        .m_axi_arvalid          ( hacd_master.ar_valid              ),
        .m_axi_arready          ( hacd_master.ar_ready              ),
        //read data channel
        .m_axi_rdata            ( hacd_master.r_data                ),
        .m_axi_rresp            ( hacd_master.r_resp                ),
        .m_axi_rvalid           ( hacd_master.r_valid               ),
        .m_axi_rready           ( hacd_master.r_ready               ),
        //write response channel
        .m_axi_bresp            ( hacd_master.b_resp                ),
        .m_axi_bvalid           ( hacd_master.b_valid               ),
        .m_axi_bready           ( hacd_master.b_ready               ),
        // non-axi-lite signals
        .w_reqbuf_size          ( hacd_master.aw_size               ),
        .r_reqbuf_size          ( hacd_master.ar_size               )
    );

    // tie off signals not used by AXI-lite
    assign hacd_master.aw_id     = '0;
    assign hacd_master.aw_len    = '0;
    assign hacd_master.aw_burst  = '0;
    assign hacd_master.aw_lock   = '0;
    assign hacd_master.aw_cache  = '0;
    assign hacd_master.aw_prot   = '0;
    assign hacd_master.aw_qos    = '0;
    assign hacd_master.aw_region = '0;
    assign hacd_master.aw_atop   = '0;
    assign hacd_master.w_last    = 1'b1;
    assign hacd_master.ar_id     = '0;
    assign hacd_master.ar_len    = '0;
    assign hacd_master.ar_burst  = '0;
    assign hacd_master.ar_lock   = '0;
    assign hacd_master.ar_cache  = '0;
    assign hacd_master.ar_prot   = '0;
    assign hacd_master.ar_qos    = '0;
    assign hacd_master.ar_region = '0;

    logic [7:0][7:0] hawk_cmd_reg_n;
    logic [7:0][7:0] hacd_w_data;
    assign hacd_w_data = hacd_master.w_data;
    logic hawk_cmd_flag_m_n;
    enum logic [2:0] {Idle, WriteResp, ReadResp} state_q, state_d;
    logic hawk_reg_ready;
    reg  hawk_r_high;
    logic hawk_r_high_n, hawk_w_high;
    assign hawk_reg_ready = state_q == Idle;
    assign hacd_master.aw_ready = hawk_reg_ready;
    assign hacd_master.w_ready  = hawk_reg_ready;
    assign hacd_master.ar_ready = hawk_reg_ready;
    assign hacd_master.r_data   = hawk_r_high ? {{32'd0}, hawk_cmd_reg[63:32]} : hawk_cmd_reg;

    always_ff @(posedge cfg_clk_i) begin
        if (~cfg_rst_ni) begin
            state_q         <= Idle;
            hawk_cmd_reg    <= 'd0;
            hawk_cmd_flag_m <= 'd0;
            hawk_r_high     <= 'd0;
        end
        else begin
            state_q         <= state_d;
            hawk_cmd_reg    <= hawk_cmd_reg_n;
            hawk_cmd_flag_m <= hawk_cmd_flag_m_n;
            hawk_r_high     <= hawk_r_high_n;
        end
    end
    // this is a simplified AXI statemachine, since the
    // W and AW requests always arrive at the same time here

    always_comb begin
        hacd_master.r_valid  = 'd0;
        hacd_master.r_resp   = 'd0;
        hacd_master.b_valid  = 'd0;
        hacd_master.b_resp   = 'd0;
        // default
        state_d             = state_q;
        hawk_cmd_reg_n      = hawk_cmd_reg;
        hawk_cmd_flag_m_n   = hawk_cmd_flag_m;
        hawk_r_high_n       = hawk_r_high;
        //
        unique case (state_q)
            Idle: begin
                if (hacd_master.w_valid && hacd_master.aw_valid) begin
                    hawk_w_high = hacd_master.aw_addr != 64'(HacdBase);
                    if (hacd_master.aw_size == 3'b11) begin //check address??
                        for (int i = 0; i < 8; i++)
                            if (hacd_master.w_strb[i])
                                hawk_cmd_reg_n[i] = hacd_w_data[i];
                        hawk_cmd_flag_m_n = !hawk_cmd_flag_m;
                    end
                    else begin
                        for (int i = 0; i < 4; i++)
                            if (hacd_master.w_strb[i])
                                hawk_cmd_reg_n[i + hawk_w_high * 4] = hacd_w_data[i];
                        hawk_cmd_flag_m_n = hawk_w_high ? !hawk_cmd_flag_m : hawk_cmd_flag_m;
                    end
                    state_d = WriteResp;
                end else if (hacd_master.ar_valid) begin
                    hawk_r_high_n   = hacd_master.ar_addr != 64'(HacdBase);
                    state_d         = ReadResp;
                end
            end
            WriteResp: begin
                if (hacd_master.b_ready && (hawk_cmd_flag_m == hawk_cmd_flag_s)) begin
                    hacd_master.b_valid = 1'b1;
                    state_d             = Idle;
                end
            end
            ReadResp: begin
                hawk_r_high_n = hawk_r_high;
                if (hacd_master.r_ready) begin
                    hacd_master.r_valid = 1'b1;
                    state_d             = Idle;
                    hawk_r_high_n       = 'd0;
                end
            end
            default: state_d = Idle;
        endcase
    end
// end NOC_AXI

assign infl_interrupt = 0;
assign defl_interrupt = 0;
assign hawk_reg_inactive_ctrl =  0;

wire hawk_cmd_ready, hawk_cmd_run;
HACD_AXI_WR_BUS reg_axi_wr_bus();
HACD_AXI_RD_BUS reg_axi_rd_bus();
wire dump1, dump2;
assign dump_mem = dump1 | dump2;

hacd_regs u_hacd_regs (
    .rst_ni,//(cfg_rst_ni),
    .clk_i,//(cfg_clk_i),

    .hawk_cmd_reg,
    .hawk_cmd_flag_m,
    .hawk_cmd_flag_s,

    .reg_axi_wr_bus,
    .reg_axi_rd_bus,
    .hawk_cmd_ready,
    .hawk_cmd_run,
    .dump_mem(dump1)
);

hacd_core u_hacd_core (
    .rst_ni,
    .clk_i,
    .uart_boot_en,
    .hawk_sw_ctrl(hawk_sw_ctrl),
    .hawk_reg_inactive_ctrl(hawk_reg_inactive_ctrl),

    .cpu_axi_wr_bus,
    .cpu_axi_rd_bus,

    .reg_axi_wr_bus,
    .reg_axi_rd_bus,

    .mc_axi_wr_bus,
    .mc_axi_rd_bus,

    .hawk_cmd_ready,
    .hawk_cmd_run,

    .dump_mem(dump2)
);


endmodule

