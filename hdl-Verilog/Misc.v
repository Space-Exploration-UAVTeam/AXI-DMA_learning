module Misc (
    // 系统信号
    input         CLK,
    input         RST_N,      // 低电平复位
    // 控制信号
    input         set_flag,   // 单周期脉冲
    input  [31:0] set_data,
    // TX RAM写接口
    output reg        tx_ram_wen,
    output reg [9:0]  tx_ram_waddr,
    output reg [31:0] tx_ram_wdata,
    // RX RAM读接口
    output reg [9:0]  rx_ram_raddr,
    input      [31:0] rx_ram_rdata
);

// 定义状态类型
typedef enum {s0, s1, s2} state_type;
reg state_type state;
// 状态机定义
localparam [1:0]  // 使用2-bit编码
    s0 = 2'b00,
    s1 = 2'b01,
    s2 = 2'b10;
reg [1:0] state;

reg [9:0] cnt;        // 10-bit计数器（0-1023）
reg [1:0] sel;        // 操作选择信号

always @(posedge CLK) begin
    if (!RST_N) begin  // 同步复位
        // 复位所有输出
        tx_ram_wen   <= 1'b0;
        tx_ram_waddr <= 10'h0;
        tx_ram_wdata <= 32'h0;
        rx_ram_raddr <= 10'h0;
        
        // 复位状态机
        cnt   <= 0;
        sel   <= 2'b00;
        state <= s0;
    end 
    else begin
        case (state)
            s0: begin  // 空闲状态
                // 默认输出
                tx_ram_wen   <= 1'b0;
                tx_ram_waddr <= 10'h0;
                tx_ram_wdata <= 32'h0;
                rx_ram_raddr <= 10'h0;
                cnt <= 0;

                if (set_flag) begin  // 检测设置脉冲
                    case (set_data)
                        32'h0000_0001: begin
                            sel <= 2'b01;  // 递增模式
                            state <= s1;
                        end
                        32'h0000_0002: begin
                            sel <= 2'b10;  // 递减模式
                            state <= s1;
                        end 
                        32'h0000_0003: begin
                            sel <= 2'b11;  // RX RAM模式
                            rx_ram_raddr <= 10'd1;  // 初始地址
                            state <= s1;
                        end
                        default: state <= s0;  // 无效参数保持状态
                    endcase
                end
            end

            s1: begin  // 数据写入状态
                tx_ram_wen <= 1'b1;
                tx_ram_waddr <= cnt;  // 自动转换为10-bit

                case (sel)
                    2'b01: tx_ram_wdata <= cnt;          // 递增数据
                    2'b10: tx_ram_wdata <= 1023 - cnt;   // 递减数据
                    2'b11: begin
                        tx_ram_wdata <= rx_ram_rdata;    // 转发RX数据
                        rx_ram_raddr <= cnt + 10'd2;     // 地址偏移+2
                    end
                    default: ;  // 保持默认
                endcase

                // 计数器控制
                if (cnt < 1023) begin
                    cnt <= cnt + 1;
                end else begin
                    state <= s2;
                end
            end

            s2: begin  // 结束状态
                tx_ram_wen   <= 1'b0;
                tx_ram_waddr <= 10'h0;
                tx_ram_wdata <= 32'h0;
                state <= s0;  // 返回空闲
            end

            default: state <= s0;  // 异常处理
        endcase
    end
end
endmodule