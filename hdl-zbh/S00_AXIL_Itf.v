module S00_AXIL_Itf (
    // AXI 时钟与复位
    input wire S_AXI_ACLK,           // AXI 时钟信号
    input wire S_AXI_ARESETN,        // 异步复位信号（低电平有效）
    
    // 写地址通道
    input wire [15:0] S_AXI_AWADDR,  // 写地址
    input wire [2:0] S_AXI_AWPROT,   // 保护信号（AXI-Lite 通常忽略）
    input wire S_AXI_AWVALID,        // 写地址有效信号
    output reg S_AXI_AWREADY,        // 写地址就绪信号（从设备确认接收地址）
    
    // 写数据通道
    input wire [31:0] S_AXI_WDATA,   // 写数据
    input wire [3:0] S_AXI_WSTRB,    // 字节使能（选择写入的字节）
    input wire S_AXI_WVALID,         // 写数据有效信号
    output reg S_AXI_WREADY,         // 写数据就绪信号（从设备确认接收数据）
    
    // 写响应通道
    output reg [1:0] S_AXI_BRESP,   // 写操作响应（2位： "00" 表示成功）
    output reg S_AXI_BVALID,         // 写响应有效信号
    input wire S_AXI_BREADY,         // 主设备（PS）确认写响应
    
    // 读地址通道
    input wire [15:0] S_AXI_ARADDR,  // 读地址
    input wire [2:0] S_AXI_ARPROT,   // 保护信号（AXI-Lite 通常忽略）
    input wire S_AXI_ARVALID,        // 读地址有效信号
    output reg S_AXI_ARREADY,        // 读地址就绪信号（从设备确认接收地址）
    
    // 读数据通道
    output reg [31:0] S_AXI_RDATA,   // 读数据
    output reg [1:0] S_AXI_RRESP,    // 读操作响应（如 "00" 表示成功）
    output reg S_AXI_RVALID,         // 读数据有效信号
    input wire S_AXI_RREADY,         // 主设备（PS）确认读响应
    
    // 自定义接口（连接到内部寄存器）
    output reg reg_wr,               // 寄存器写使能信号
    output reg [15:0] reg_waddr,     // 写地址
    output reg [31:0] reg_wdata,     // 写数据
    output reg reg_rd,               // 寄存器读使能信号
    output reg [15:0] reg_raddr,     // 读地址
    input wire [31:0] reg_rdata      // 从寄存器读取的数据
);

// 内部信号声明
reg [15:0] axi_awaddr;  // 写地址缓存
reg axi_awready;         // 写地址就绪信号
reg axi_wready;          // 写数据就绪信号
reg [1:0] axi_bresp;     // 写响应
reg axi_bvalid;          // 写响应有效
reg [15:0] axi_araddr;   // 读地址缓存
reg axi_arready;         // 读地址就绪信号
reg [31:0] axi_rdata;    // 读数据缓存
reg [1:0] axi_rresp;     // 读响应
reg axi_rvalid;          // 读数据有效
reg slv_reg_wren;        // 寄存器写使能（自定义）
reg slv_reg_rden;        // 寄存器读使能（自定义）

// 将内部信号连接到 AXI 接口
assign S_AXI_AWREADY = axi_awready;
assign S_AXI_WREADY = axi_wready;
assign S_AXI_BRESP = axi_bresp;
assign S_AXI_BVALID = axi_bvalid;
assign S_AXI_ARREADY = axi_arready;
assign S_AXI_RDATA = axi_rdata;
assign S_AXI_RRESP = axi_rresp;
assign S_AXI_RVALID = axi_rvalid;

// 写地址就绪进程
always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        axi_awready <= 1'b0;
    end else begin
        // 当写地址未就绪、写地址有效、写数据有效时，才接受新的写地址，将写地址就绪flag置1
        if (axi_awready == 1'b0 && S_AXI_AWVALID == 1'b1 && S_AXI_WVALID == 1'b1) begin
            axi_awready <= 1'b1;
        end else begin
            axi_awready <= 1'b0;
        end
    end
end

// 写地址缓存进程
always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        axi_awaddr <= 16'b0;
    end else begin
        // 当写地址未就绪、写地址有效、写数据有效时，才接受新的写地址，保存写地址
        if (axi_awready == 1'b0 && S_AXI_AWVALID == 1'b1 && S_AXI_WVALID == 1'b1) begin
            axi_awaddr <= S_AXI_AWADDR; // 保存写地址
        end
    end
end

// 写数据就绪进程
always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        axi_wready <= 1'b0;
    end else begin
        // 当写数据未就绪、写地址有效、写数据有效时，接受新的写数据，将写数据就绪flag置1
        if (axi_wready == 1'b0 && S_AXI_WVALID == 1'b1 && S_AXI_AWVALID == 1'b1) begin
            axi_wready <= 1'b1;
        end else begin
            axi_wready <= 1'b0;
        end
    end
end

// 当地址和数据通道均准备好时，给自定义的写使能、写地址、写数据输出端口赋值
assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
assign reg_wr = slv_reg_wren;          // 写使能
assign reg_waddr = axi_awaddr;         // 写地址
assign reg_wdata = S_AXI_WDATA;        // 写数据

// 写响应进程
always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        axi_bvalid <= 1'b0;
        axi_bresp <= 2'b00;  // 默认成功响应
    end else begin
        // 当写地址就绪、写地址有效、写数据就绪、写数据有效、写响应并非有效时，生成写响应信号，将写响应有效flag置1
        if (axi_awready == 1'b1 && S_AXI_AWVALID == 1'b1 && axi_wready == 1'b1 && S_AXI_WVALID == 1'b1 && axi_bvalid == 1'b0) begin
            axi_bvalid <= 1'b1;
            axi_bresp <= 2'b00; // 写响应信号（2位： "00" 表示成功）
        end
        // 当主设备（PS）确认写响应后，复位写响应有效flag
        else if (S_AXI_BREADY == 1'b1 && axi_bvalid == 1'b1) begin
            axi_bvalid <= 1'b0;
        end
    end
end

// 读地址就绪与缓存进程
always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        axi_arready <= 1'b0;
        axi_araddr <= 16'b1;
    end else begin
        // 当读地址未就绪、读地址有效时，接受地址，将读地址就绪flag置1，保存读地址
        if (axi_arready == 1'b0 && S_AXI_ARVALID == 1'b1) begin
            axi_arready <= 1'b1;
            axi_araddr <= S_AXI_ARADDR;
        end else begin
            axi_arready <= 1'b0;
        end
    end
end

// 读数据就绪与读响应进程
always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        axi_rvalid <= 1'b0;
        axi_rresp <= 2'b00;
    end else begin
        // 当读地址就绪、读地址有效、读数据还未有效时，将读数据有效flag置1
        if (axi_arready == 1'b1 && S_AXI_ARVALID == 1'b1 && axi_rvalid == 1'b0) begin
            axi_rvalid <= 1'b1;
            axi_rresp <= 2'b00; // 'OKAY' 响应
        end
        // 当读数据有效、主设备确认读响应后，复位数据有效信号
        else if (axi_rvalid == 1'b1 && S_AXI_RREADY == 1'b1) begin
            axi_rvalid <= 1'b0;
        end
    end
end

// 当地址和数据通道均准备好时，给自定义的读使能、读地址输出端口赋值，将自定义读数据输入端口转接给AXI读数据输出端口
assign slv_reg_rden = axi_arready && S_AXI_ARVALID && !axi_rvalid;
assign reg_rd = slv_reg_rden;          // 读使能
assign reg_raddr = axi_araddr;         // 读地址
assign axi_rdata = reg_rdata;          // 从寄存器读取的数据

endmodule