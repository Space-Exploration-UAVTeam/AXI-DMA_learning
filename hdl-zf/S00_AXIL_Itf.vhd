library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity S00_AXIL_Itf is
port (          
    S_AXI_ACLK    : in std_logic;          -- AXI 时钟信号
    S_AXI_ARESETN : in std_logic;          -- 异步复位信号（低电平有效）
    -- 写地址通道
    S_AXI_AWADDR  : in std_logic_vector(15 downto 0);  -- 写地址
    S_AXI_AWPROT  : in std_logic_vector(2 downto 0);   -- 保护信号（AXI-Lite 通常忽略）
    S_AXI_AWVALID : in std_logic;          -- 写地址有效信号
    S_AXI_AWREADY : out std_logic;         -- 写地址就绪信号（从设备确认接收地址）
    -- 写数据通道
    S_AXI_WDATA   : in std_logic_vector(31 downto 0);  -- 写数据
    S_AXI_WSTRB   : in std_logic_vector(3 downto 0);   -- 字节使能（选择写入的字节）
    S_AXI_WVALID  : in std_logic;          -- 写数据有效信号
    S_AXI_WREADY  : out std_logic;         -- 写数据就绪信号（从设备确认接收数据）
    -- 写响应通道
    S_AXI_BRESP   : out std_logic_vector(1 downto 0);  -- 写操作响应（2位：如 "00" 表示成功）
    S_AXI_BVALID  : out std_logic;         -- 写响应有效信号
    S_AXI_BREADY  : in std_logic;          -- 主设备确认接收响应
    -- 读地址通道
    S_AXI_ARADDR  : in std_logic_vector(15 downto 0);  -- 读地址
    S_AXI_ARPROT  : in std_logic_vector(2 downto 0);   -- 保护信号（AXI-Lite 通常忽略）
    S_AXI_ARVALID : in std_logic;          -- 读地址有效信号
    S_AXI_ARREADY : out std_logic;         -- 读地址就绪信号（从设备确认接收地址）
    -- 读数据通道
    S_AXI_RDATA   : out std_logic_vector(31 downto 0); -- 读数据
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);  -- 读操作响应（如 "00" 表示成功）
    S_AXI_RVALID  : out std_logic;         -- 读数据有效信号
    S_AXI_RREADY  : in std_logic;          -- 主设备确认接收数据
    
    -- 自定义接口（连接到内部寄存器）
    reg_wr        : out std_logic;         -- 寄存器写使能信号
    reg_waddr     : out std_logic_vector(15 downto 0); -- 写地址
    reg_wdata     <= std_logic_vector(31 downto 0);    -- 写数据
    reg_rd        : out std_logic;         -- 寄存器读使能信号
    reg_raddr     : out std_logic_vector(15 downto 0); -- 读地址
    reg_rdata     : in std_logic_vector(31 downto 0)   -- 从寄存器读取的数据
);
end S00_AXIL_Itf;

architecture arch_imp of S00_AXIL_Itf is
-- 内部信号声明
signal axi_awaddr    : std_logic_vector(15 downto 0);  -- 写地址缓存
signal axi_awready   : std_logic;                      -- 写地址就绪信号
signal axi_wready    : std_logic;                      -- 写数据就绪信号
signal axi_bresp     : std_logic_vector(1 downto 0);   -- 写响应
signal axi_bvalid    : std_logic;                      -- 写响应有效
signal axi_araddr    : std_logic_vector(15 downto 0);  -- 读地址缓存
signal axi_arready   : std_logic;                      -- 读地址就绪信号
signal axi_rdata     : std_logic_vector(31 downto 0);  -- 读数据缓存
signal axi_rresp     : std_logic_vector(1 downto 0);   -- 读响应
signal axi_rvalid    : std_logic;                      -- 读数据有效
signal slv_reg_wren  : std_logic;                      -- 寄存器写使能（自定义）
signal slv_reg_rden  : std_logic;                      -- 寄存器读使能（自定义）

begin
    -- 将内部信号连接到 AXI 接口
    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= axi_bresp;
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= axi_rresp;
    S_AXI_RVALID  <= axi_rvalid;

    -- 写地址通道状态机
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awready <= '0';
	    else
			-- 当前未准备好且主设备发送有效地址和数据时，接受地址
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1') then
	        axi_awready <= '1';
	      else
	        axi_awready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- 写地址缓存
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awaddr <= (others => '0');
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1') then
	        axi_awaddr <= S_AXI_AWADDR; -- 保存写地址
	      end if;
	    end if;
	  end if;                   
	end process;

	-- 写数据通道状态机
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_wready <= '0';
	    else
			-- 当前未准备好且主设备发送有效数据时，接受数据
	      if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1') then         
	          axi_wready <= '1';
	      else
	        axi_wready <= '0';
	      end if;
	    end if;
	  end if;
	end process; 

	-- 生成写使能信号（当地址和数据通道均准备好时）
	slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;
    -- AXI 写操作 -> 自定义寄存器写接口
    reg_wr      <= slv_reg_wren;          -- 写使能
    reg_waddr   <= axi_awaddr;            -- 写地址
    reg_wdata   <= S_AXI_WDATA;           -- 写数据

	-- 写响应生成
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_bvalid  <= '0';
	      axi_bresp   <= "00";  -- 默认成功响应
	    else
			-- 当地址和数据通道均准备好且未发送响应时，生成响应
	      if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
	        axi_bvalid <= '1';
	        axi_bresp  <= "00"; 
			-- 当主设备确认响应后，复位响应信号
	      elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then   --check if bready is asserted while bvalid is high)
	        axi_bvalid <= '0';                                 -- (there is a possibility that bready is always asserted high)
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- 读地址通道状态机
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_arready <= '0';
	      axi_araddr  <= (others => '1');
	    else
			-- 当前未准备好且主设备发送有效地址时，接受地址
	      if (axi_arready = '0' and S_AXI_ARVALID = '1') then
	        -- indicates that the slave has acceped the valid read address
	        axi_arready <= '1';
	        -- Read Address latching 
	        axi_araddr  <= S_AXI_ARADDR;       -- 保存读地址     
	      else
	        axi_arready <= '0';
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- 读数据通道状态机
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_rvalid <= '0';
	      axi_rresp  <= "00";
	    else
			-- 当地址准备好且未发送数据时，生成读数据
	      if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
	        -- Valid read data is available at the read data bus
	        axi_rvalid <= '1';
	        axi_rresp  <= "00"; -- 'OKAY' response
			-- 当主设备确认数据后，复位数据有效信号
	      elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
	        -- Read data is accepted by the master
	        axi_rvalid <= '0';
	      end if;            
	    end if;
	  end if;
	end process;
	-- 生成读使能信号（当地址有效且未发送数据时）
	slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;
    -- AXI 读操作 -> 自定义寄存器读接口
    reg_rd      <= slv_reg_rden;          -- 读使能
    reg_raddr   <= axi_araddr;            -- 读地址
    axi_rdata   <= reg_rdata;             -- 从寄存器读取的数据
end arch_imp;
