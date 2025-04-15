module S00_AXIS_Itf (
    // Slave AXIS port
    input wire S_AXIS_ACLK,        // AXI4-Stream时钟
    input wire S_AXIS_ARESETN,     // 异步复位（低有效）
    output reg S_AXIS_TREADY,      // 从设备数据接收就绪信号（给PS）
    input wire S_AXIS_TDATA,       // 输入数据（32位）
    input wire S_AXIS_TLAST,       // 标记数据流最后一个数据包
    input wire S_AXIS_TVALID,      // 输入数据有效信号
    // 自定义的接口（写入RAM）
    output reg RAM_WEN,            // RAM写使能信号
    output reg RAM_WADDR,          // RAM写地址（10位，支持1024个地址）
    output reg RAM_WDATA,          // RAM写数据（32位）
    // for debug
    output reg debug_state
);

// 内部信号声明
reg [3:0] decode_state;
reg S_AXIS_TREADY_t;
reg [9:0] write_count;
reg RAM_WEN_t;
reg [9:0] RAM_WADDR_t;
reg count_en;
reg [15:0] clk_count;

// 状态机定义
typedef enum {s0, s1} state_type;
state_type state;

// **状态机逻辑**
always @(posedge S_AXIS_ACLK) begin
    if (!S_AXIS_ARESETN) begin
        S_AXIS_TREADY_t <= 1'b0;
        write_count <= 10'd0;
        state <= s0;
    end else begin
        case (state)
            s0: begin  // 空闲状态
                S_AXIS_TREADY_t <= 1'b0;
                write_count <= 10'd0;
                if (S_AXIS_TVALID) begin
                    S_AXIS_TREADY_t <= 1'b1;
                    state <= s1;
                end
            end
            s1: begin  // 数据传输状态
                S_AXIS_TREADY_t <= 1'b1;
                if (S_AXIS_TVALID) begin
                    if (S_AXIS_TLAST) begin
                        state <= s0;
                    end
                    if (write_count < 10'd1024) begin
                        write_count <= write_count + 10'd1;
                    end
                end
            end
            default: begin
                state <= s0;
            end
        endcase
    end
end

// 内外端口连接
assign S_AXIS_TREADY = S_AXIS_TREADY_t;

// **数据写入逻辑**
always @(posedge S_AXIS_ACLK) begin
    if (!S_AXIS_ARESETN) begin
        RAM_WEN_t <= 1'b0;
        RAM_WADDR_t <= 10'b0;
        RAM_WDATA <= 32'h00000000;
    end else begin
        RAM_WEN_t <= 1'b0;
        RAM_WADDR_t <= 10'b0;
        RAM_WDATA <= 32'h00000000;
        if (S_AXIS_TVALID && S_AXIS_TREADY_t && write_count < 10'd1024) begin
            RAM_WEN_t <= 1'b1;
            RAM_WADDR_t <= write_count; // 根据write_count生成写入地址
            RAM_WDATA <= S_AXIS_TDATA;  // 将输入数据赋给自定义写数据接口
        end
    end
end

assign RAM_WEN = RAM_WEN_t;
assign RAM_WADDR = RAM_WADDR_t;

//-----------------------------------------------------------------------
// for debug only
//-----------------------------------------------------------------------
always @(*) begin
    decode_state = 4'b0000;
    case (state)
        s0: decode_state = 4'b0000;
        s1: decode_state = 4'b0001;
        default: decode_state = 4'b1111;
    endcase
end

assign debug_state[31:28] = decode_state;
assign debug_state[27:24] = 4'b0000;
assign debug_state[23:16] = 8'h00;
assign debug_state[15:0] = clk_count;

//-----------------------------------------------------------------------
// count clks during a transfer
//-----------------------------------------------------------------------
always @(posedge S_AXIS_ACLK) begin
    if (!S_AXIS_ARESETN) begin
        count_en <= 1'b0;
        clk_count <= 16'h0000;
    end else begin
        if (RAM_WEN_t && (RAM_WADDR_t == 10'd0)) begin
            clk_count <= 16'h0001;
            count_en <= 1'b1;
        end
        if (RAM_WEN_t && (RAM_WADDR_t == 10'd1023)) begin
            count_en <= 1'b0;
        end
        if (count_en) begin
            clk_count <= clk_count + 16'd1;
        end
    end
end

endmodule