

module hawk_axi_xbar_wrapper#(parameter PLACE_HOLDER=1)
(
    input clk_i,
    input rst_ni,
   
    input mstr_sel,

    //Master 1
    HACD_AXI_WR_BUS.slv mstr0_axi_wr_bus_slv, 
    HACD_AXI_RD_BUS.slv mstr0_axi_rd_bus_slv,  
    
    //Master 2
    HACD_AXI_WR_BUS.slv mstr1_axi_wr_bus_slv, 
    HACD_AXI_RD_BUS.slv mstr1_axi_rd_bus_slv,  

    //HACD<->MC
    //hacd will act as request master on request singslas to mc 
    HACD_MC_AXI_WR_BUS.mstr out_axi_wr_bus,  
    HACD_MC_AXI_RD_BUS.mstr out_axi_rd_bus  
);
 
    HACD_AXI_WR_BUS xbarOut_axi_wr_bus(); 
    HACD_AXI_RD_BUS xbarOut_axi_rd_bus();


always_comb
begin
	if(mstr_sel) begin
    		//WRITE ADDRESS CHANNEL
		xbarOut_axi_wr_bus.mstr.axi_awid 	=mstr1_axi_wr_bus_slv.axi_awid;
		xbarOut_axi_wr_bus.mstr.axi_awaddr	=mstr1_axi_wr_bus_slv.axi_awaddr;
		xbarOut_axi_wr_bus.mstr.axi_awlen	=mstr1_axi_wr_bus_slv.axi_awlen;
		xbarOut_axi_wr_bus.mstr.axi_awsize	=mstr1_axi_wr_bus_slv.axi_awsize;
		xbarOut_axi_wr_bus.mstr.axi_awburst	=mstr1_axi_wr_bus_slv.axi_awburst;
		xbarOut_axi_wr_bus.mstr.axi_awlock	=mstr1_axi_wr_bus_slv.axi_awlock;
		xbarOut_axi_wr_bus.mstr.axi_awcache	=mstr1_axi_wr_bus_slv.axi_awcache;
		xbarOut_axi_wr_bus.mstr.axi_awprot	=mstr1_axi_wr_bus_slv.axi_awprot;
		xbarOut_axi_wr_bus.mstr.axi_awqos	=mstr1_axi_wr_bus_slv.axi_awqos;
		xbarOut_axi_wr_bus.mstr.axi_awregion	=mstr1_axi_wr_bus_slv.axi_awregion;
		xbarOut_axi_wr_bus.mstr.axi_awuser	=mstr1_axi_wr_bus_slv.axi_awuser;
		xbarOut_axi_wr_bus.mstr.axi_awvalid	=mstr1_axi_wr_bus_slv.axi_awvalid;
        	mstr1_axi_wr_bus_slv.axi_awready 	=xbarOut_axi_wr_bus.mstr.axi_awready;

    		//READ ADDRESS CHANNEL
		xbarOut_axi_rd_bus.mstr.axi_arid 	=mstr1_axi_rd_bus_slv.axi_arid;
		xbarOut_axi_rd_bus.mstr.axi_araddr	=mstr1_axi_rd_bus_slv.axi_araddr;
		xbarOut_axi_rd_bus.mstr.axi_arprot	=mstr1_axi_rd_bus_slv.axi_arprot;
		xbarOut_axi_rd_bus.mstr.axi_arregion	=mstr1_axi_rd_bus_slv.axi_arregion;
		xbarOut_axi_rd_bus.mstr.axi_arlen	=mstr1_axi_rd_bus_slv.axi_arlen;
		xbarOut_axi_rd_bus.mstr.axi_arsize	=mstr1_axi_rd_bus_slv.axi_arsize;
		xbarOut_axi_rd_bus.mstr.axi_arburst	=mstr1_axi_rd_bus_slv.axi_arburst;
		xbarOut_axi_rd_bus.mstr.axi_arlock	=mstr1_axi_rd_bus_slv.axi_arlock;
		xbarOut_axi_rd_bus.mstr.axi_arcache	=mstr1_axi_rd_bus_slv.axi_arcache;
		xbarOut_axi_rd_bus.mstr.axi_arqos	=mstr1_axi_rd_bus_slv.axi_arqos;
		xbarOut_axi_rd_bus.mstr.axi_arvalid		=mstr1_axi_rd_bus_slv.axi_arvalid;
		xbarOut_axi_rd_bus.mstr.axi_aruser	=mstr1_axi_rd_bus_slv.axi_aruser;
        	mstr1_axi_rd_bus_slv.axi_arready 	=xbarOut_axi_rd_bus.mstr.axi_arready;

		//WRITE DATA CHANNEL
		xbarOut_axi_wr_bus.mstr.axi_wvalid	=mstr1_axi_wr_bus_slv.axi_wvalid;
		xbarOut_axi_wr_bus.mstr.axi_wdata	=mstr1_axi_wr_bus_slv.axi_wdata;
		xbarOut_axi_wr_bus.mstr.axi_wstrb	=mstr1_axi_wr_bus_slv.axi_wstrb;
		xbarOut_axi_wr_bus.mstr.axi_wuser	=mstr1_axi_wr_bus_slv.axi_wuser;
		xbarOut_axi_wr_bus.mstr.axi_wlast	=mstr1_axi_wr_bus_slv.axi_wlast;
	        mstr1_axi_wr_bus_slv.axi_wready		=xbarOut_axi_wr_bus.mstr.axi_wready;

    		//READ DATA CHANNEL
		mstr1_axi_rd_bus_slv.axi_rvalid		=xbarOut_axi_rd_bus.mstr.axi_rvalid;
		mstr1_axi_rd_bus_slv.axi_rdata 		=xbarOut_axi_rd_bus.mstr.axi_rdata;
		mstr1_axi_rd_bus_slv.axi_rresp 		=xbarOut_axi_rd_bus.mstr.axi_rresp;
		mstr1_axi_rd_bus_slv.axi_rlast 		=xbarOut_axi_rd_bus.mstr.axi_rlast;
		mstr1_axi_rd_bus_slv.axi_rid   		=xbarOut_axi_rd_bus.mstr.axi_rid;
		mstr1_axi_rd_bus_slv.axi_ruser 		=xbarOut_axi_rd_bus.mstr.axi_ruser;
		xbarOut_axi_rd_bus.mstr.axi_rready	=mstr1_axi_rd_bus_slv.axi_rready;

    		// WRITE RESPONSE CHANNEL
		mstr1_axi_wr_bus_slv.axi_bvalid		=xbarOut_axi_wr_bus.mstr.axi_bvalid;
		mstr1_axi_wr_bus_slv.axi_bresp		=xbarOut_axi_wr_bus.mstr.axi_bresp;
		mstr1_axi_wr_bus_slv.axi_bid		=xbarOut_axi_wr_bus.mstr.axi_bid;
		mstr1_axi_wr_bus_slv.axi_buser		=xbarOut_axi_wr_bus.mstr.axi_buser;
		xbarOut_axi_wr_bus.mstr.axi_bready 	=mstr1_axi_wr_bus_slv.axi_bready;
	end
	else begin
    		//WRITE ADDRESS CHANNEL
		xbarOut_axi_wr_bus.mstr.axi_awid 	=mstr0_axi_wr_bus_slv.axi_awid;
		xbarOut_axi_wr_bus.mstr.axi_awaddr	=mstr0_axi_wr_bus_slv.axi_awaddr;
		xbarOut_axi_wr_bus.mstr.axi_awprot	=mstr0_axi_wr_bus_slv.axi_awprot;
		xbarOut_axi_wr_bus.mstr.axi_awregion	=mstr0_axi_wr_bus_slv.axi_awregion;
		xbarOut_axi_wr_bus.mstr.axi_awlen	=mstr0_axi_wr_bus_slv.axi_awlen;
		xbarOut_axi_wr_bus.mstr.axi_awsize	=mstr0_axi_wr_bus_slv.axi_awsize;
		xbarOut_axi_wr_bus.mstr.axi_awburst	=mstr0_axi_wr_bus_slv.axi_awburst;
		xbarOut_axi_wr_bus.mstr.axi_awlock	=mstr0_axi_wr_bus_slv.axi_awlock;
		xbarOut_axi_wr_bus.mstr.axi_awcache	=mstr0_axi_wr_bus_slv.axi_awcache;
		xbarOut_axi_wr_bus.mstr.axi_awqos	=mstr0_axi_wr_bus_slv.axi_awqos;
		xbarOut_axi_wr_bus.mstr.axi_awvalid	=mstr0_axi_wr_bus_slv.axi_awvalid;
		xbarOut_axi_wr_bus.mstr.axi_awuser	=mstr0_axi_wr_bus_slv.axi_awuser;
        	mstr0_axi_wr_bus_slv.axi_awready 	=xbarOut_axi_wr_bus.mstr.axi_awready;

    		//READ ADDRESS CHANNEL
		xbarOut_axi_rd_bus.mstr.axi_arid 	=mstr0_axi_rd_bus_slv.axi_arid;
		xbarOut_axi_rd_bus.mstr.axi_araddr	=mstr0_axi_rd_bus_slv.axi_araddr;
		xbarOut_axi_rd_bus.mstr.axi_arprot	=mstr0_axi_rd_bus_slv.axi_arprot;
		xbarOut_axi_rd_bus.mstr.axi_arregion	=mstr0_axi_rd_bus_slv.axi_arregion;
		xbarOut_axi_rd_bus.mstr.axi_arlen	=mstr0_axi_rd_bus_slv.axi_arlen;
		xbarOut_axi_rd_bus.mstr.axi_arsize	=mstr0_axi_rd_bus_slv.axi_arsize;
		xbarOut_axi_rd_bus.mstr.axi_arburst	=mstr0_axi_rd_bus_slv.axi_arburst;
		xbarOut_axi_rd_bus.mstr.axi_arlock	=mstr0_axi_rd_bus_slv.axi_arlock;
		xbarOut_axi_rd_bus.mstr.axi_arcache	=mstr0_axi_rd_bus_slv.axi_arcache;
		xbarOut_axi_rd_bus.mstr.axi_arqos	=mstr0_axi_rd_bus_slv.axi_arqos;
		xbarOut_axi_rd_bus.mstr.axi_arvalid	=mstr0_axi_rd_bus_slv.axi_arvalid;
		xbarOut_axi_rd_bus.mstr.axi_aruser	=mstr0_axi_rd_bus_slv.axi_aruser;
        	mstr0_axi_rd_bus_slv.axi_arready 	=xbarOut_axi_rd_bus.mstr.axi_arready;

		//WRITE DATA CHANNEL
		xbarOut_axi_wr_bus.mstr.axi_wvalid	=mstr0_axi_wr_bus_slv.axi_wvalid;
		xbarOut_axi_wr_bus.mstr.axi_wdata	=mstr0_axi_wr_bus_slv.axi_wdata;
		xbarOut_axi_wr_bus.mstr.axi_wstrb	=mstr0_axi_wr_bus_slv.axi_wstrb;
		xbarOut_axi_wr_bus.mstr.axi_wuser	=mstr0_axi_wr_bus_slv.axi_wuser;
		xbarOut_axi_wr_bus.mstr.axi_wlast	=mstr0_axi_wr_bus_slv.axi_wlast;
	        mstr0_axi_wr_bus_slv.axi_wready		=xbarOut_axi_wr_bus.mstr.axi_wready;

    		//READ DATA CHANNEL
		mstr0_axi_rd_bus_slv.axi_rvalid		=xbarOut_axi_rd_bus.mstr.axi_rvalid;
		mstr0_axi_rd_bus_slv.axi_rdata 		=xbarOut_axi_rd_bus.mstr.axi_rdata;
		mstr0_axi_rd_bus_slv.axi_rresp 		=xbarOut_axi_rd_bus.mstr.axi_rresp;
		mstr0_axi_rd_bus_slv.axi_rlast 		=xbarOut_axi_rd_bus.mstr.axi_rlast;
		mstr0_axi_rd_bus_slv.axi_rid   		=xbarOut_axi_rd_bus.mstr.axi_rid;
		mstr0_axi_rd_bus_slv.axi_ruser 		=xbarOut_axi_rd_bus.mstr.axi_ruser;
		xbarOut_axi_rd_bus.mstr.axi_rready	=mstr0_axi_rd_bus_slv.axi_rready;

    		// WRITE RESPONSE CHANNEL
		mstr0_axi_wr_bus_slv.axi_bvalid		=xbarOut_axi_wr_bus.mstr.axi_bvalid;
		mstr0_axi_wr_bus_slv.axi_bresp		=xbarOut_axi_wr_bus.mstr.axi_bresp;
		mstr0_axi_wr_bus_slv.axi_bid		=xbarOut_axi_wr_bus.mstr.axi_bid;
		mstr0_axi_wr_bus_slv.axi_buser		=xbarOut_axi_wr_bus.mstr.axi_buser;
		xbarOut_axi_wr_bus.mstr.axi_bready 	=mstr0_axi_wr_bus_slv.axi_bready;
	end
end

axi_size_conv_DOWNSIZE # 
(
    .AXI_ADDR_WIDTH(),
    //slave side
    .AXI_DATA_WIDTH_IN(),
    .AXI_USER_WIDTH_IN(),
    .AXI_ID_WIDTH_IN(),
    
    //master side
    .AXI_DATA_WIDTH_OUT(`HACD_AXI4_DATA_WIDTH),
    .AXI_USER_WIDTH_OUT(`HACD_AXI4_USER_WIDTH),
    .AXI_ID_WIDTH_OUT(`HACD_AXI4_ID_WIDTH)

) u_axi_size_DOWNSIZE (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // AXI4 SLAVE : for us, it is xbar should drive here
    //***************************************
    // WRITE ADDRESS CHANNEL
    .axi_slave_aw_valid_i(xbarOut_axi_wr_bus.mstr.axi_awvalid),
    .axi_slave_aw_addr_i(xbarOut_axi_wr_bus.mstr.axi_awaddr),
    .axi_slave_aw_prot_i(xbarOut_axi_wr_bus.mstr.axi_awprot),
    .axi_slave_aw_region_i(xbarOut_axi_wr_bus.mstr.axi_awregion),
    .axi_slave_aw_len_i(xbarOut_axi_wr_bus.mstr.axi_awlen),
    .axi_slave_aw_size_i(xbarOut_axi_wr_bus.mstr.axi_awsize),
    .axi_slave_aw_burst_i(xbarOut_axi_wr_bus.mstr.axi_awburst),
    .axi_slave_aw_lock_i(xbarOut_axi_wr_bus.mstr.axi_awlock),
    .axi_slave_aw_cache_i(xbarOut_axi_wr_bus.mstr.axi_awcache),
    .axi_slave_aw_qos_i(xbarOut_axi_wr_bus.mstr.axi_awqos),
    .axi_slave_aw_id_i(xbarOut_axi_wr_bus.mstr.axi_awid),
    .axi_slave_aw_user_i(xbarOut_axi_wr_bus.mstr.axi_awuser),
    .axi_slave_aw_ready_o(xbarOut_axi_wr_bus.slv.axi_awready),

    // READ ADDRESS CHANNEL
    .axi_slave_ar_valid_i(xbarOut_axi_rd_bus.slv.axi_arvalid),
    .axi_slave_ar_addr_i(xbarOut_axi_rd_bus.slv.axi_araddr),
    .axi_slave_ar_prot_i(xbarOut_axi_rd_bus.slv.axi_arprot),
    .axi_slave_ar_region_i(xbarOut_axi_rd_bus.slv.axi_arregion),
    .axi_slave_ar_len_i(xbarOut_axi_rd_bus.slv.axi_arlen),
    .axi_slave_ar_size_i(xbarOut_axi_rd_bus.slv.axi_arsize),
    .axi_slave_ar_burst_i(xbarOut_axi_rd_bus.slv.axi_arburst),
    .axi_slave_ar_lock_i(xbarOut_axi_rd_bus.slv.axi_arlock),
    .axi_slave_ar_cache_i(xbarOut_axi_rd_bus.slv.axi_arcache),
    .axi_slave_ar_qos_i(xbarOut_axi_rd_bus.slv.axi_arqos),
    .axi_slave_ar_id_i(xbarOut_axi_rd_bus.slv.axi_arid),
    .axi_slave_ar_user_i(xbarOut_axi_rd_bus.slv.axi_aruser),
    .axi_slave_ar_ready_o(xbarOut_axi_rd_bus.slv.axi_arready),

    // WRITE DATA CHANNEL
    .axi_slave_w_valid_i(xbarOut_axi_wr_bus.mstr.axi_wvalid),
    .axi_slave_w_data_i(xbarOut_axi_wr_bus.mstr.axi_wdata),
    .axi_slave_w_strb_i(xbarOut_axi_wr_bus.mstr.axi_wstrb),
    .axi_slave_w_user_i(xbarOut_axi_wr_bus.mstr.axi_wuser),
    .axi_slave_w_last_i(xbarOut_axi_wr_bus.mstr.axi_wlast),
    .axi_slave_w_ready_o(xbarOut_axi_wr_bus.slv.axi_wready),

    // READ DATA CHANNEL
    .axi_slave_r_valid_o(xbarOut_axi_rd_bus.slv.axi_rvalid),
    .axi_slave_r_data_o(xbarOut_axi_rd_bus.slv.axi_rdata),
    .axi_slave_r_resp_o(xbarOut_axi_rd_bus.slv.axi_rresp),
    .axi_slave_r_last_o(xbarOut_axi_rd_bus.slv.axi_rlast),
    .axi_slave_r_id_o(xbarOut_axi_rd_bus.slv.axi_rid),
    .axi_slave_r_user_o(xbarOut_axi_rd_bus.slv.axi_ruser),
    .axi_slave_r_ready_i(xbarOut_axi_rd_bus.slv.axi_rready),

    // WRITE RESPONSE CHANNEL
    .axi_slave_b_valid_o(xbarOut_axi_wr_bus.slv.axi_bvalid),
    .axi_slave_b_resp_o(xbarOut_axi_wr_bus.slv.axi_bresp),
    .axi_slave_b_id_o(xbarOut_axi_wr_bus.slv.axi_bid),
    .axi_slave_b_user_o(xbarOut_axi_wr_bus.slv.axi_buser),
    .axi_slave_b_ready_i(xbarOut_axi_wr_bus.mstr.axi_bready),

    //master port 
    //axi xbar in our case (size conversion is with respect to
    //master : xbar (512) -> mc (256)
    //***************************************
    // WRITE ADDRESS CHANNEL
    .axi_master_aw_valid_o(out_axi_wr_bus.axi_awvalid),
    .axi_master_aw_addr_o(out_axi_wr_bus.axi_awaddr),
    .axi_master_aw_prot_o(out_axi_wr_bus.axi_awprot),
    .axi_master_aw_region_o(out_axi_wr_bus.axi_awregion),
    .axi_master_aw_len_o(out_axi_wr_bus.axi_awlen),
    .axi_master_aw_size_o(out_axi_wr_bus.axi_awsize),
    .axi_master_aw_burst_o(out_axi_wr_bus.axi_awburst),
    .axi_master_aw_lock_o(out_axi_wr_bus.axi_awlock),
    .axi_master_aw_cache_o(out_axi_wr_bus.axi_awcache),
    .axi_master_aw_qos_o(out_axi_wr_bus.axi_awqos),
    .axi_master_aw_id_o(out_axi_wr_bus.axi_awid),
    .axi_master_aw_user_o(out_axi_wr_bus.axi_awuser),
    .axi_master_aw_ready_i(out_axi_wr_bus.axi_awready),

    // READ ADDRESS CHANNEL
    .axi_master_ar_valid_o(out_axi_rd_bus.axi_arvalid),
    .axi_master_ar_addr_o(out_axi_rd_bus.axi_araddr),
    .axi_master_ar_prot_o(out_axi_rd_bus.axi_arprot),
    .axi_master_ar_region_o(out_axi_rd_bus.axi_arregion),
    .axi_master_ar_len_o(out_axi_rd_bus.axi_arlen),
    .axi_master_ar_size_o(out_axi_rd_bus.axi_arsize),
    .axi_master_ar_burst_o(out_axi_rd_bus.axi_arburst),
    .axi_master_ar_lock_o(out_axi_rd_bus.axi_arlock),
    .axi_master_ar_cache_o(out_axi_rd_bus.axi_arcache),
    .axi_master_ar_qos_o(out_axi_rd_bus.axi_arqos),
    .axi_master_ar_id_o(out_axi_rd_bus.axi_arid),
    .axi_master_ar_user_o(out_axi_rd_bus.axi_aruser),
    .axi_master_ar_ready_i(out_axi_rd_bus.axi_arready),

    // WRITE DATA CHANNEL
    .axi_master_w_valid_o(out_axi_wr_bus.axi_wvalid),
    .axi_master_w_data_o(out_axi_wr_bus.axi_wdata),
    .axi_master_w_strb_o(out_axi_wr_bus.axi_wstrb),
    .axi_master_w_user_o(out_axi_wr_bus.axi_wuser),
    .axi_master_w_last_o(out_axi_wr_bus.axi_wlast),
    .axi_master_w_ready_i(out_axi_wr_bus.axi_wready),

    // READ DATA CHANNEL
    .axi_master_r_valid_i(out_axi_rd_bus.axi_rvalid),
    .axi_master_r_data_i(out_axi_rd_bus.axi_rdata),
    .axi_master_r_resp_i(out_axi_rd_bus.axi_rresp),
    .axi_master_r_last_i(out_axi_rd_bus.axi_rlast),
    .axi_master_r_id_i(out_axi_rd_bus.axi_rid),
    .axi_master_r_user_i(out_axi_rd_bus.axi_ruser),
    .axi_master_r_ready_o(out_axi_rd_bus.axi_rready),

    // WRITE RESPONSE CHANNEL
    .axi_master_b_valid_i(out_axi_wr_bus.axi_bvalid),
    .axi_master_b_resp_i(out_axi_wr_bus.axi_bresp),
    .axi_master_b_id_i(out_axi_wr_bus.axi_bid),
    .axi_master_b_user_i(out_axi_wr_bus.axi_buser),
    .axi_master_b_ready_o(out_axi_wr_bus.axi_bready)    
  );


endmodule
