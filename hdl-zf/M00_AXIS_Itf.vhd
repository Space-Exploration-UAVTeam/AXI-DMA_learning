library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity M00_AXIS_Itf is
port (
    -- Master AXIS port
    M_AXIS_ACLK     : in std_logic;        -- AXI4-Stream时钟
    M_AXIS_ARESETN  : in std_logic;        -- 异步复位（低有效）
    M_AXIS_TVALID   : out std_logic;       -- 主设备数据有效信号
    M_AXIS_TDATA    : out std_logic_vector(31 downto 0);  -- 输出数据（32位）
    -- M_AXIS_TSTRB    : out std_logic_vector(3 downto 0);  -- 字节使能（未使用，默认全启用）
    M_AXIS_TLAST    : out std_logic;       -- 标记数据流最后一个数据包
    M_AXIS_TREADY   : in std_logic;        -- 从设备接收就绪信号
        -- 自定义接口（读取RAM）
    tx_req          : in std_logic;        -- 发送请求信号
    tx_ack          : out std_logic;       -- 发送确认信号
    RAM_RADDR       : out std_logic_vector(9 downto 0);  -- RAM读地址（10位，支持1024地址）
    RAM_RDATA       : in std_logic_vector(31 downto 0);  -- RAM读数据（32位）
    -- debug
    debug_state     : out std_logic_vector(31 downto 0)
);
end M00_AXIS_Itf;

architecture implementation of M00_AXIS_Itf is
type state_type is (s0, s1, s2, s3, s4);  -- 状态机定义：(空闲，预发送，传输，结束，握手)                                                                                   
signal state : state_type;                -- 当前状态
signal decode_state: std_logic_vector(3 downto 0);-- debug
signal last_TREADY     : std_logic;      -- 上一个周期的TREADY信号
signal last_RAM_RDATA  : std_logic_vector(31 downto 0);  -- 上一个周期的RAM数据
signal RAM_RADDR_t     : std_logic_vector(9 downto 0);  -- RAM读地址内部信号
signal tx_count        : integer range 0 to 1023;  -- 发送计数器（最大1024个数据包）
signal tx_ack_t        : std_logic;      -- 发送确认内部信号
-- for debug 
signal last_tx_ack_t: std_logic;
signal clk_count: std_logic_vector(15 downto 0);

begin
    RAM_RADDR       <= RAM_RADDR_t; -- 内外端口连接
    --M_AXIS_TSTRB	<= "1111";  -- always use full 4-byte of TDATA
    tx_ack <= tx_ack_t;             -- 内外端口连接

    -- **主状态机逻辑**     
    process(M_AXIS_ACLK)                                                                        
    begin                                                                                       
        if (rising_edge (M_AXIS_ACLK)) then  --时钟上升沿触发                                                    
            if(M_AXIS_ARESETN = '0') then
                -- 复位时的默认值
                M_AXIS_TVALID   <= '0';      -- 禁止发送
                M_AXIS_TLAST    <= '0';      -- 不标记结束
                M_AXIS_TDATA    <= (others=>'0');  -- 清零数据
                tx_count        <= 0;        -- 清零计数器
                tx_ack_t        <= '0';      -- 清零确认信号
                last_TREADY     <= '1';      -- 初始化TREADY状态
                RAM_RADDR_t     <= (others=>'0');  -- 清零地址
                last_RAM_RDATA  <= x"00000000";  -- 清零RAM数据缓存
                state           <= s0;       -- 返回空闲状态                                                                                                       
            else                                                                                    
                case state is                                                              
                    when s0   =>             -- 状态s0：空闲状态（等待发送请求）
                        -- 默认禁止发送
                        M_AXIS_TVALID   <= '0';
                        M_AXIS_TLAST    <= '0';
                        M_AXIS_TDATA    <= (others=>'0');   
                        tx_ack_t        <= '0';
                        last_TREADY     <= '1'; 
                        RAM_RADDR_t     <= (others=>'0');  --(others=>'0') 表示将信号 所有未指定的位 设置为 '0'        
                        last_RAM_RDATA  <= x"00000000"; 
                        tx_count        <= 0;   
                        if(tx_req='1')then  -- 当收到tx_req请求时，开始传输
                            tx_ack_t        <= '1';  -- 发送确认信号
                            RAM_RADDR_t     <= RAM_RADDR_t + 1;  -- 读取数据的RAM地址，注意：内存内部读写操作需要时间，D触发器要等到时钟周期才刷新！所以当前周期更新的RAM地址所对应的data，要等待下一周期才接收到（地址快数据一个周期）！
                            state           <= s1;    -- 进入预发送状态                                                
                        end if;
                            
                    when s1 =>               -- 状态s1：预发送（发送第一个数据）
                        last_TREADY     <= '1';      -- 记录TREADY状态，没用
                        M_AXIS_TVALID   <= '1';      -- 标记数据有效
                        M_AXIS_TDATA    <= RAM_RDATA;  -- 发送当前RAM地址数据
                        tx_count        <= 1;        -- 计数器初始化为1
                        RAM_RADDR_t     <= RAM_RADDR_t + 1;  -- 地址+1    
                        state           <= s2;       -- 进入持续发送状态
                                                                                                                                                                                            
                    when s2  =>             -- 状态s2：持续发送：根据从设备接受就绪信号判断发送新数据还是旧数据
                        last_TREADY     <= M_AXIS_TREADY;  -- 记录从设备当前TREADY状态，注意非阻塞赋值 (<=)等待时钟边沿生效！！！
                        M_AXIS_TVALID   <= '1';            -- 保持数据有效
                        if(M_AXIS_TREADY='1')then     -- 如果从设备准备好接收                                                                              
                            tx_count    <= tx_count + 1;   -- 增加计数器
                            RAM_RADDR_t <= RAM_RADDR_t + 1;  -- 地址+1  --每发送完一次数据，就执行一次地址+1
                            if(last_TREADY='0') then -- 当前从设备M_AXIS_TREADY=1，上一周期last_TREADY=0，M_AXIS_TREADY构成了上升沿！！！
                                M_AXIS_TDATA <= last_RAM_RDATA;  -- 发送上一周期的RAM数据
                            else                     -- 当前从设备M_AXIS_TREADY=1，上一周期last_TREADY=1，一直高电平
                                M_AXIS_TDATA <= RAM_RDATA;       -- 发送当前RAM数据
                            end if;
                            if(tx_count = 1023)then -- 检查tx_count，如果达到最大传输量
                                M_AXIS_TLAST    <= '1';  -- 标记最后一个数据包
                                state           <= s3;   -- 进入传输结束状态
                            end if;
                        else -- M_AXIS_TREADY='0'    -- 如果当前从设备未准备好
                            if(last_TREADY='1')then  -- 但是上一周期准备好，M_AXIS_TREADY构成了下降沿！！！
                                last_RAM_RDATA <= RAM_RDATA; -- 缓存当前数据
                            end if;
                        end if;                                                 
                    
                    when s3 =>              -- 状态s3：传输结束（等待最后一个数据确认）
                        if (M_AXIS_TREADY = '1')then
                            M_AXIS_TVALID   <= '0';   -- 清除数据有效
                            M_AXIS_TLAST    <= '0';   -- 清除结束标志
                            state           <= s4;    -- 进入握手状态
                        end if;   
                    
                    when s4 =>               -- 状态s4：握手完成（等待请求释放）
                        tx_ack_t <= '0';     -- 清除确认信号
                        if tx_req = '0' then
                            state <= s0;     -- 返回空闲状态
                        end if;
                                                                            
                    when others  =>                                                                   
                        state <= s0;                                                           	                                                                                            
                end case;                                                                             
            end if;                                                                                 
        end if;                                                                                   
    end process;    

    ---------------------------------------------------------------------------
    -- for debug only
    ---------------------------------------------------------------------------
    decode_state <= "0000" when state=s0 else  
                    "0001" when state=s1 else
                    "0010" when state=s2 else  
                    "0011" when state=s3 else
                    "0100" when state=s4 else  
                    "1111";

    debug_state(31 downto 28)  <= decode_state;
    debug_state(27 downto 24)  <= "00" & tx_ack_t & tx_req;
    debug_state(23 downto 16)  <= x"00";
    debug_state(15 downto 0)   <= clk_count;

    -- count clks during a treansfer
    process(M_AXIS_ACLK)
    begin
    if(M_AXIS_ACLK'event and M_AXIS_ACLK='1')then
        if(M_AXIS_ARESETN='0')then
            last_tx_ack_t <= '0';
            clk_count <= x"0000";
        else
            last_tx_ack_t <= tx_ack_t;
            if(last_tx_ack_t='0' and tx_ack_t='1')then -- reset to start new count
                clk_count <= x"0001";
            elsif(tx_ack_t='1')then  -- continuous counting
                clk_count <= clk_count+1;
            end if;
        end if;
    end if;
    end process;
end implementation;
