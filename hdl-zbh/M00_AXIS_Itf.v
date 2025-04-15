module M00_AXIS_Itf (
    // Master AXIS port
    input wire M_AXIS_ACLK,        // AXI4-Stream时钟
    input wire M_AXIS_ARESETN,     // 异步复位（低有效）
    output reg M_AXIS_TVALID,      // 主设备数据有效信号
    output reg [31:0] M_AXIS_TDATA,// 输出数据（32位）
    // output wire [3:0] M_AXIS_TSTRB,  // 字节使能（未使用，默认全启用）
    output reg M_AXIS_TLAST,       // 标记数据流最后一个数据包
    input wire M_AXIS_TREADY,      // 从设备接收就绪信号
    
    // 自定义接口（读取RAM）
    input wire tx_req,             // 发送请求信号
    output reg tx_ack,             // 发送确认信号
    output reg [9:0] RAM_RADDR,    // RAM读地址（10位，支持1024地址）
    input wire [31:0] RAM_RDATA,   // RAM读数据（32位）
    
    // debug
    output wire [31:0] debug_state
);

// 状态机定义
localparam [2:0] 
    s0 = 3'd0, 
    s1 = 3'd1, 
    s2 = 3'd2, 
    s3 = 3'd3, 
    s4 = 3'd4;
reg [2:0] state;                  // 当前状态
reg [3:0] decode_state;           // debug
reg last_TREADY;                  // 上一个周期的TREADY信号
reg [31:0] last_RAM_RDATA;        // 上一个周期的RAM数据
reg [9:0] RAM_RADDR_t;            // RAM读地址内部信号
reg [9:0] tx_count;               // 发送计数器（最大1024个数据包）
reg tx_ack_t;                     // 发送确认内部信号
// debug signals
reg last_tx_ack_t;
reg [15:0] clk_count;

// 外部信号连接
assign RAM_RADDR = RAM_RADDR_t;
assign tx_ack = tx_ack_t;

// **主状态机逻辑**
always @(posedge M_AXIS_ACLK) begin
    if (!M_AXIS_ARESETN) begin
        // 复位时的默认值
        M_AXIS_TVALID <= 1'b0;
        M_AXIS_TLAST <= 1'b0;
        M_AXIS_TDATA <= 32'b0;
        tx_count <= 10'd0;
        tx_ack_t <= 1'b0;
        last_TREADY <= 1'b1;
        RAM_RADDR_t <= 10'b0;
        last_RAM_RDATA <= 32'h00000000;
        state <= s0;
    end 
    else begin
        case (state)
            s0: begin  // 状态s0：空闲状态（等待发送请求）
                M_AXIS_TVALID <= 1'b0;
                M_AXIS_TLAST <= 1'b0;
                M_AXIS_TDATA <= 32'b0;
                tx_ack_t <= 1'b0;
                last_TREADY <= 1'b1;
                RAM_RADDR_t <= 10'b0;
                last_RAM_RDATA <= 32'h00000000;
                tx_count <= 10'd0;
                if (tx_req) begin
                    tx_ack_t <= 1'b1;
                    RAM_RADDR_t <= RAM_RADDR_t + 10'd1;
                    state <= s1;
                end
            end

            s1: begin  // 状态s1：预发送（发送第一个数据）
                last_TREADY <= 1'b1;
                M_AXIS_TVALID <= 1'b1;
                M_AXIS_TDATA <= RAM_RDATA;
                tx_count <= 10'd1;
                RAM_RADDR_t <= RAM_RADDR_t + 10'd1;
                state <= s2;
            end

            s2: begin  // 状态s2：持续发送：根据从设备接受就绪信号判断发送新数据还是旧数据
                last_TREADY <= M_AXIS_TREADY;
                M_AXIS_TVALID <= 1'b1;
                if (M_AXIS_TREADY) begin
                    tx_count <= tx_count + 10'd1;
                    RAM_RADDR_t <= RAM_RADDR_t + 10'd1;
                    if (!last_TREADY) begin
                        M_AXIS_TDATA <= last_RAM_RDATA;
                    end else begin
                        M_AXIS_TDATA <= RAM_RDATA;
                    end
                    if (tx_count == 10'd1023) begin
                        M_AXIS_TLAST <= 1'b1;
                        state <= s3;
                    end
                end else begin
                    if (last_TREADY) begin
                        last_RAM_RDATA <= RAM_RDATA;
                    end
                end
            end

            s3: begin  // 状态s3：传输结束（等待最后一个数据确认）
                if (M_AXIS_TREADY) begin
                    M_AXIS_TVALID <= 1'b0;
                    M_AXIS_TLAST <= 1'b0;
                    state <= s4;
                end
            end

            s4: begin  // 状态s4：握手完成（等待请求释放）
                tx_ack_t <= 1'b0;
                if (!tx_req) begin
                    state <= s0;
                end
            end

            default: state <= s0;
        endcase
    end
end

//-----------------------------------------------------------------------
// for debug only
//-----------------------------------------------------------------------
always @(*) begin
    decode_state = 4'b0000;
    case (state)
        s0: decode_state = 4'b0000;
        s1: decode_state = 4'b0001;
        s2: decode_state = 4'b0010;
        s3: decode_state = 4'b0011;
        s4: decode_state = 4'b0100;
        default: decode_state = 4'b1111;
    endcase
end

assign debug_state[31:28] = decode_state;
assign debug_state[27:24] = {2'b00, tx_ack_t, tx_req};
assign debug_state[23:16] = 8'h00;
assign debug_state[15:0] = clk_count;

//-----------------------------------------------------------------------
// count clks during a transfer
//-----------------------------------------------------------------------
always @(posedge M_AXIS_ACLK) begin
    if (!M_AXIS_ARESETN) begin
        last_tx_ack_t <= 1'b0;
        clk_count <= 16'h0000;
    end else begin
        last_tx_ack_t <= tx_ack_t;
        if (!last_tx_ack_t && tx_ack_t) begin
            clk_count <= 16'h0001;
        end else if (tx_ack_t) begin
            clk_count <= clk_count + 16'd1;
        end
    end
end

endmodule