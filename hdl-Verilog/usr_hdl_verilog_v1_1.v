
`timescale 1 ns / 1 ps

	module usr_hdl_verilog_v1_1 #
	(
		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 10,

		// Parameters of Axi Master Bus Interface M00_AXIS
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 32,
		parameter integer C_M00_AXIS_START_COUNT	= 32,	//张老师为什么没用???

		// Parameters of Axi Slave Bus Interface S00_AXIS
		parameter integer C_S00_AXIS_DATA_WIDTH	= 32,
		parameter integer C_S00_AXIS_ADDR_WIDTH	= 4			//VHDL为什么没有???
	)
	(
		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready,

		// Ports of Axi Master Bus Interface M00_AXIS
		input wire  m00_axis_aclk,
		input wire  m00_axis_aresetn,
		output wire  m00_axis_tvalid,
		output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
		output wire  m00_axis_tlast,
		input wire  m00_axis_tready,

		// Ports of Axi Slave Bus Interface S00_AXIS
		input wire  s00_axis_aclk,
		input wire  s00_axis_aresetn,
		input wire [C_S00_AXIS_ADDR_WIDTH-1 : 0] s00_axis_awaddr,
		input wire [2 : 0] s00_axis_awprot,
		input wire  s00_axis_awvalid,
		output wire  s00_axis_awready,
		input wire [C_S00_AXIS_DATA_WIDTH-1 : 0] s00_axis_wdata,
		input wire [(C_S00_AXIS_DATA_WIDTH/8)-1 : 0] s00_axis_wstrb,
		input wire  s00_axis_wvalid,
		output wire  s00_axis_wready,
		output wire [1 : 0] s00_axis_bresp,
		output wire  s00_axis_bvalid,
		input wire  s00_axis_bready,
		input wire [C_S00_AXIS_ADDR_WIDTH-1 : 0] s00_axis_araddr,
		input wire [2 : 0] s00_axis_arprot,
		input wire  s00_axis_arvalid,
		output wire  s00_axis_arready,
		output wire [C_S00_AXIS_DATA_WIDTH-1 : 0] s00_axis_rdata,
		output wire [1 : 0] s00_axis_rresp,
		output wire  s00_axis_rvalid,
		input wire  s00_axis_rready
	);
// Instantiation of Axi Bus Interface S00_AXI
	usr_hdl_verilog_v1_1_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) usr_hdl_verilog_v1_1_S00_AXI_inst (
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

// Instantiation of Axi Bus Interface M00_AXIS
	usr_hdl_verilog_v1_1_M00_AXIS # ( 
		.C_M_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH),
		.C_M_START_COUNT(C_M00_AXIS_START_COUNT)
	) usr_hdl_verilog_v1_1_M00_AXIS_inst (
		.M_AXIS_ACLK(m00_axis_aclk),
		.M_AXIS_ARESETN(m00_axis_aresetn),
		.M_AXIS_TVALID(m00_axis_tvalid),
		.M_AXIS_TDATA(m00_axis_tdata),
		.M_AXIS_TSTRB(m00_axis_tstrb),
		.M_AXIS_TLAST(m00_axis_tlast),
		.M_AXIS_TREADY(m00_axis_tready)
	);

// Instantiation of Axi Bus Interface S00_AXIS
	usr_hdl_verilog_v1_1_S00_AXIS # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXIS_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXIS_ADDR_WIDTH)
	) usr_hdl_verilog_v1_1_S00_AXIS_inst (
		.S_AXI_ACLK(s00_axis_aclk),
		.S_AXI_ARESETN(s00_axis_aresetn),
		.S_AXI_AWADDR(s00_axis_awaddr),
		.S_AXI_AWPROT(s00_axis_awprot),
		.S_AXI_AWVALID(s00_axis_awvalid),
		.S_AXI_AWREADY(s00_axis_awready),
		.S_AXI_WDATA(s00_axis_wdata),
		.S_AXI_WSTRB(s00_axis_wstrb),
		.S_AXI_WVALID(s00_axis_wvalid),
		.S_AXI_WREADY(s00_axis_wready),
		.S_AXI_BRESP(s00_axis_bresp),
		.S_AXI_BVALID(s00_axis_bvalid),
		.S_AXI_BREADY(s00_axis_bready),
		.S_AXI_ARADDR(s00_axis_araddr),
		.S_AXI_ARPROT(s00_axis_arprot),
		.S_AXI_ARVALID(s00_axis_arvalid),
		.S_AXI_ARREADY(s00_axis_arready),
		.S_AXI_RDATA(s00_axis_rdata),
		.S_AXI_RRESP(s00_axis_rresp),
		.S_AXI_RVALID(s00_axis_rvalid),
		.S_AXI_RREADY(s00_axis_rready)
	);

	// Add user logic here

	// User logic ends

	endmodule
