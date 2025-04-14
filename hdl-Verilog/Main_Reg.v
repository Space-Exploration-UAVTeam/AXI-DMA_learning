module Main_Reg (
    // 系统信号
    input         CLK,        // 时钟信号
    input         RST_N,      // 复位信号（低电平有效）
    // 寄存器读写接口
    input         reg_wr,     // 寄存器写信号
    input  [15:0] reg_waddr,  // 寄存器写地址
    input  [31:0] reg_wdata,  // 寄存器写数据
    input         reg_rd,     // 寄存器读信号
    input  [15:0] reg_raddr,  // 寄存器读地址
    output reg [31:0] reg_rdata, // 寄存器读数据
    // 杂项功能接口
    output reg        misc_set_flag, // 杂项设置标志
    output reg [31:0] misc_set_data, // 杂项设置数据
    output reg        Usr_Int,    // 用户中断信号
    output reg        tx_req_bit, // 发送请求位
    // 调试状态接口
    input  [31:0] m00_axis_debug_state, // M00_AXIS调试状态
    input  [31:0] s00_axis_debug_state  // S00_AXIS调试状态
);

// 测试寄存器
reg [31:0] slv_test_reg0;      // 测试寄存器0
reg [31:0] slv_test_reg1;      // 测试寄存器1
reg [31:0] int_vec_reg;        // 中断向量寄存器
// 模块版本日期
localparam [31:0] IP_MODIFY_DATE = 32'h20181101; // 使用localparam定义常量，适合固定值（如版本号、常量），无需外部配置的场景。
// parameter IP_MODIFY_DATE = 32'h20181101;//可能被外部修改
   
// 寄存器写操作进程
always @(posedge CLK) begin
    if (!RST_N) begin                // 同步复位（低电平有效）
        slv_test_reg0 <= 32'd0;
        slv_test_reg1 <= 32'd0;
        int_vec_reg <= 32'd0;
        misc_set_flag <= 1'b0;
        misc_set_data <= 32'h00000000;
        Usr_Int <= 1'b0;
        tx_req_bit <= 1'b0;
    end else begin
        // 先清除标志信号
        misc_set_flag <= 1'b0;
        Usr_Int <= 1'b0;
        tx_req_bit <= 1'b0;
        if (reg_wr) begin
            case (reg_waddr)
                16'h0008: slv_test_reg0 <= reg_wdata;    // 写测试寄存器0
                16'h000C: slv_test_reg1 <= reg_wdata;    // 写测试寄存器1
                16'h0010: begin
                    Usr_Int        <= reg_wdata[0];      // 设置用户中断
                    int_vec_reg[0] <= int_vec_reg[0] | reg_wdata[0]; // 更新中断向量
                end
                16'h0014: int_vec_reg <= int_vec_reg ^ reg_wdata; // 异或更新中断向量
                16'h0018: begin
                    misc_set_flag <= 1'b1;               // 触发杂项设置
                    misc_set_data <= reg_wdata;
                end
                16'h001C: tx_req_bit <= reg_wdata[0];    // 设置发送请求位
                default: ;                               // 忽略其他地址
            endcase
        end
    end
end

// 寄存器读操作进程
always @(posedge CLK) begin
    if (!RST_N) begin
        reg_rdata <= 32'd0;
    end else begin
        if (reg_rd) begin
            case (reg_raddr)
                16'h0000: reg_rdata <= 32'hEB9055AA;     // 模块标识
                16'h0004: reg_rdata <= IP_MODIFY_DATE;   // 版本日期
                16'h0008: reg_rdata <= slv_test_reg0;    // 读测试寄存器0
                16'h000C: reg_rdata <= slv_test_reg1;    // 读测试寄存器1
                16'h0014: reg_rdata <= int_vec_reg;      // 读中断向量
                16'h0020: reg_rdata <= m00_axis_debug_state; // 读M00状态
                16'h0024: reg_rdata <= s00_axis_debug_state; // 读S00状态
                default: reg_rdata <= 32'h0;            // 默认返回0
            endcase
        end
        else begin
            reg_rdata <= 32'h0;  // 非读周期保持输出为0
        end
    end
end

endmodule