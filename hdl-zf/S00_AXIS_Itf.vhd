library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity S00_AXIS_Itf is
port (    
    -- Slave AXIS port
    S_AXIS_ACLK     : in std_logic;        -- AXI4-Stream时钟
    S_AXIS_ARESETN  : in std_logic;        -- 异步复位（低有效）
    S_AXIS_TREADY   : out std_logic;       -- 从设备数据接收就绪信号（给PS）
    S_AXIS_TDATA    : in std_logic_vector(31 downto 0);  -- 输入数据（32位）
    -- S_AXIS_TSTRB    : in std_logic_vector(3 downto 0);  -- 字节使能信号（未使用）
    S_AXIS_TLAST    : in std_logic;        -- 标记数据流最后一个数据包
    S_AXIS_TVALID   : in std_logic;        -- 输入数据有效信号
    
    --自定义的接口（写入RAM）
    RAM_WEN         : out std_logic;       -- RAM写使能信号
    RAM_WADDR       : out std_logic_vector(9 DOWNTO 0);  -- RAM写地址（10位，支持1024个地址）
    RAM_WDATA       : out std_logic_vector(31 DOWNTO 0); -- RAM写数据（32位）
    -- for debug
    debug_state     : out std_logic_vector(31 downto 0)
);
end S00_AXIS_Itf;

architecture arch_imp of S00_AXIS_Itf is
-- state machine
type state_type is (s0, s1);       -- 状态机定义:s0空闲，s1数据传输状态
signal  state : state_type;        -- 当前状态
signal decode_state: std_logic_vector(3 downto 0);
-- 内部信号声明
signal S_AXIS_TREADY_t : std_logic;    -- TREADY内部信号
signal write_count     : integer range 0 to 2047;  -- 写计数器（最大2048）
signal RAM_WEN_t       : std_logic;    -- 写使能内部信号
signal RAM_WADDR_t     : std_logic_vector(9 DOWNTO 0);  -- 写地址内部信号
-- for debug count
signal count_en: std_logic;
signal clk_count: std_logic_vector(15 downto 0);

begin
S_AXIS_TREADY	<= S_AXIS_TREADY_t;  -- 内外端口连接
    
 -- **状态机逻辑**
process(S_AXIS_ACLK)
begin
if (rising_edge (S_AXIS_ACLK)) then --时钟上升沿触发
    if(S_AXIS_ARESETN = '0') then
        S_AXIS_TREADY_t <= '0';    -- 复位时TREADY无效
        write_count     <= 0;      -- 清零计数器
        state           <= s0;     -- 返回空闲状态
    else
        case state is
            when s0  =>  -- 空闲状态
                S_AXIS_TREADY_t <= '0';  -- 不准备接收数据
                write_count <= 0;        -- 清零计数器
                if S_AXIS_TVALID = '1' then  -- 当数据有效时，接收就绪flag置1，state转为数据传输
                    S_AXIS_TREADY_t <= '1';  -- 准备接收
                    state <= s1;             -- 进入数据传输状态
                end if;
            when s1 =>  -- 数据传输状态
                S_AXIS_TREADY_t <= '1';  -- 持续准备接收
                if(S_AXIS_TVALID = '1')then  -- 当数据有效时，
                    if(S_AXIS_TLAST = '1')then -- 如果所有数据写入完成时返回空闲状态
                         state <= s0;
                    end if;
                    if(write_count < 1024)then  --写入数据不足1024个时则保持继续传输
                        write_count <= write_count+1;
                    end if;
                end if;
            when others  => 
                state <= s0;
        end case;
    end if;  
end if;
end process;
                   
-- **数据写入逻辑**
RAM_WEN     <= RAM_WEN_t;   -- 内外端口连接
RAM_WADDR   <= RAM_WADDR_t; -- 内外端口连接
process(S_AXIS_ACLK)
begin
--S_AXIS_ACLK'event：检测信号 S_AXIS_ACLK 是否发生了状态变化
--S_AXIS_ACLK = '1'：检查信号 S_AXIS_ACLK 的当前值是否为高电平
-- 不推荐
if (S_AXIS_ACLK'event and S_AXIS_ACLK='1') then 
    if(S_AXIS_ARESETN = '0') then
        RAM_WEN_t   <= '0';        -- 复位时禁止写入
        RAM_WADDR_t <= (others=>'0');  -- 清零地址
        RAM_WDATA   <= x"00000000";    -- 清零数据
    else
        -- 默认禁止写入
        RAM_WEN_t   <= '0';
        RAM_WADDR_t <= (others=>'0');
        RAM_WDATA   <= x"00000000";
        -- 当数据有效、准备接收、写入数据不足1024个时
        if(S_AXIS_TVALID='1' and S_AXIS_TREADY_t='1' and write_count < 1024) then -- 当满足条件时写入数据
            RAM_WEN_t   <= '1';
            RAM_WADDR_t <=  CONV_STD_LOGIC_VECTOR(write_count, 10);--根据write_count生成写入地址
            RAM_WDATA   <= S_AXIS_TDATA;                            --将输入数据赋给自定义写数据接口
        end if;
     end if;
end if;
end process;

---------------------------------------------------------------------------
-- for debug only
---------------------------------------------------------------------------
decode_state <= "0000" when state=s0 else  
                "0001" when state=s1 else
                "1111";
debug_state(31 downto 28)  <= decode_state;
debug_state(27 downto 24)  <= "0000";
debug_state(23 downto 16)  <= x"00";
debug_state(15 downto 0)   <= clk_count;
-- count clks during a treansfer
process(S_AXIS_ACLK)
begin
if(S_AXIS_ACLK'event and S_AXIS_ACLK='1')then
    if(S_AXIS_ARESETN='0')then
        count_en <= '0';
        clk_count <= x"0000";
    else
        if(RAM_WEN_t='1' and RAM_WADDR_t=CONV_STD_LOGIC_VECTOR(0,10))then -- reset to start new count
            clk_count <= x"0001";
            count_en <= '1';
        end if;
        if(RAM_WEN_t='1' and RAM_WADDR_t=CONV_STD_LOGIC_VECTOR(1023,10))then -- reset to start new count
            count_en <= '0';
         end if;
        if(count_en='1')then  -- continuous counting
            clk_count <= clk_count+1;
        end if;
    end if;
end if;
end process;

end arch_imp;
