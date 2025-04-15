library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- 定义 Main_Reg 模块
entity Main_Reg is
port (
    -- 系统信号
    CLK                     : in  std_logic;  -- 时钟信号
    RST_N                   : in  std_logic;  -- 复位信号（低电平有效）
    -- 寄存器读写接口
    reg_wr                  : in  std_logic;  -- 寄存器写信号
    reg_waddr               : in  std_logic_vector(15 downto 0);  -- 寄存器写地址
    reg_wdata               : in  std_logic_vector(31 downto 0);  -- 寄存器写数据
    reg_rd                  : in  std_logic;  -- 寄存器读信号
    reg_raddr               : in  std_logic_vector(15 downto 0);  -- 寄存器读地址
    reg_rdata               : out std_logic_vector(31 downto 0);  -- 寄存器读数据
    -- 自定义功能接口
    misc_set_flag           : out std_logic;  -- 杂项设置标志
    misc_set_data           : out std_logic_vector(31 downto 0);  -- 杂项设置数据
    Usr_Int                 : out std_logic;  -- 用户中断信号
    tx_req_bit              : out std_logic;  -- 发送请求位
    -- 调试状态接口
    m00_axis_debug_state    : in  std_logic_vector(31 downto 0);  -- M00_AXIS 调试状态
    s00_axis_debug_state    : in  std_logic_vector(31 downto 0)  -- S00_AXIS 调试状态
);
end Main_Reg;

-- 架构实现
architecture arch_imp of Main_Reg is
    -- 测试寄存器
    signal slv_test_reg0       : std_logic_vector(31 downto 0);  -- 测试寄存器 0
    signal slv_test_reg1       : std_logic_vector(31 downto 0);  -- 测试寄存器 1
    -- 中断向量寄存器
    signal int_vec_reg         : std_logic_vector(31 downto 0);  -- 中断向量寄存器
    -- 模块版本日期
    constant IP_MODIFY_DATE    : std_logic_vector(31 downto 0) := x"20181101";  -- 模块修改日期
begin

    -- 寄存器写操作进程
    process (CLK)
    begin
    if rising_edge(CLK) then 
        if(RST_N = '0')then                -- 复位时初始化寄存器
            slv_test_reg0 <= (others => '0');
            slv_test_reg1 <= (others => '0');
            int_vec_reg   <= (others=>'0');
            misc_set_flag <= '0';
            misc_set_data <= x"00000000";
            Usr_Int       <= '0';
            tx_req_bit    <= '0';
        else                               -- 先清除标志信号
            misc_set_flag <= '0';
            Usr_Int       <= '0';
            tx_req_bit    <= '0';
            if (reg_wr = '1') then         -- 处理寄存器写操作
                case reg_waddr is          --使用 case 语句处理 reg_waddr 和 reg_raddr 是一种常见的设计方法，用于根据不同的地址选择要操作的寄存器【地址即指令！！！！！】
                    when x"0008" =>    slv_test_reg0 <= reg_wdata;-- 写测试寄存器 0
                    when x"000C" =>    slv_test_reg1 <= reg_wdata;-- 写测试寄存器 1            
                    when x"0010" =>
                        Usr_Int       <= reg_wdata(0); -- 设置用户中断         
                        int_vec_reg(0)<= int_vec_reg(0) or reg_wdata(0);-- 更新中断向量
                    when x"0014" =>    int_vec_reg   <= int_vec_reg xor reg_wdata; -- 异或更新中断向量
                    when x"0018" =>
                        misc_set_flag <= '1';-- 设置杂项功能
                        misc_set_data <= reg_wdata;
                    when x"001C" =>    tx_req_bit    <= reg_wdata(0);-- 设置发送请求位
                    when others =>                    -- 其他地址不处理
                end case;
            end if;
        end if;
    end if;                   
    end process; 

    -- 寄存器读操作进程
    process(CLK)
    begin
    if (rising_edge (CLK)) then
        if (RST_N = '0') then
            reg_rdata  <= (others => '0');                -- 复位时清空读数据
        else
            if (reg_rd = '1') then
                case reg_raddr is
                    when x"0000" =>    reg_rdata <= x"EB9055AA";    -- 读模块标识
                    when x"0004" =>    reg_rdata <= IP_MODIFY_DATE; -- 读模块版本日期
                    when x"0008" =>    reg_rdata <= slv_test_reg0;  -- 读测试寄存器 0
                    when x"000C" =>    reg_rdata <= slv_test_reg1;  -- 读测试寄存器 1
                    when x"0014" =>    reg_rdata <= int_vec_reg;    -- 读中断向量寄存器
                    when x"0020" =>    reg_rdata <= m00_axis_debug_state; -- 读 M00_AXIS 调试状态
                    when x"0024" =>    reg_rdata <= s00_axis_debug_state; -- 读 S00_AXIS 调试状态
                    when others =>     reg_rdata  <= (others => '0'); -- 其他地址返回 0
                end case;
            end if;   
        end if;
    end if;
    end process;

end arch_imp;