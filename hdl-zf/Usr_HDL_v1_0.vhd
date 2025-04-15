library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Usr_HDL_v1_0 is
	generic (
		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32; -- 数据宽度
		C_S00_AXI_ADDR_WIDTH	: integer	:= 16; -- 地址宽度
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M00_AXIS_TDATA_WIDTH	: integer	:= 32;  -- 数据宽度
		C_M00_AXIS_START_COUNT	: integer	:= 32;  -- 启动计数
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S00_AXIS_TDATA_WIDTH	: integer	:= 32
	);
	port (	
	    -----------------------------------------------------------------------------	
		-- Ports of Axi Slave Bus Interface S00_AXI Lite
        -- AXI-Lite 接口分为写地址通道AW、写数据通道W、写相应通道B和读地址通道AR、读数据通道R。
		-----------------------------------------------------------------------------
		s00_axi_aclk	: in std_logic;  -- 时钟信号
		s00_axi_aresetn	: in std_logic;  -- 复位信号（n代表低电平有效）
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0); -- 写地址；定位从设备的寄存器或存储器位置；
        --意义：写保护信号（3位），定义访问权限、安全性和访问类型。
        --位0：特权访问（0=无特权，1=有特权）。
        --位1：安全访问（0=安全，1=不安全）。
        --位2：访问类型（0=数据访问，1=指令访问）。
        --AXI Lite协议中通常忽略此信号（默认为0），但需保留以兼容协议
		s00_axi_awprot	: in std_logic_vector(2 downto 0); -- 写保护信号
		s00_axi_awvalid	: in std_logic;  -- 写地址有效信号；高电平表示地址有效，请求从设备接收。
        --各种*valid和*ready信号用于主设备和从设备之间的握手，确保数据传输的正确性。具体可参考AXI协议的介绍文档。
		s00_axi_awready	: out std_logic;  -- 写地址就绪信号；高电平表示从设备已准备好接收写地址。
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0); -- 写数据；宽度由 C_S00_AXI_DATA_WIDTH 决定。
        --每位对应一个字节的有效性（例如，32位数据对应4位wstrb）；若wstrb[i]为1，则wdata的第i字节被写入目标地址。
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);  -- 写选通信号
		s00_axi_wvalid	: in std_logic;  -- 写数据有效信号
		s00_axi_wready	: out std_logic;  -- 写数据就绪信号
		s00_axi_bresp	: out std_logic_vector(1 downto 0);  -- 写响应
		s00_axi_bvalid	: out std_logic;  -- 写响应有效信号
		s00_axi_bready	: in std_logic;  -- 写响应就绪信号
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);  -- 读地址
		s00_axi_arprot	: in std_logic_vector(2 downto 0);  -- 读保护信号
		s00_axi_arvalid	: in std_logic;  -- 读地址有效信号
		s00_axi_arready	: out std_logic;  -- 读地址就绪信号
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0); -- 读数据
		s00_axi_rresp	: out std_logic_vector(1 downto 0);  -- 读响应
		s00_axi_rvalid	: out std_logic; -- 读数据有效信号
		s00_axi_rready	: in std_logic;  -- 读数据就绪信号
        -----------------------------------------------------------------------------
		-- Ports of Axi Master Bus Interface M00_AXIS
		-----------------------------------------------------------------------------
		m00_axis_aclk	: in std_logic;  -- 时钟信号
		m00_axis_aresetn: in std_logic;  -- 复位信号（低电平有效）
		m00_axis_tvalid	: out std_logic;  -- 数据有效信号
		m00_axis_tdata	: out std_logic_vector(C_M00_AXIS_TDATA_WIDTH-1 downto 0);  -- 数据
        -- m00_axis_tstrb    : out std_logic_vector((C_M00_AXIS_TDATA_WIDTH/8)-1 downto 0);  -- 数据选通信号（未使用）
		m00_axis_tlast	: out std_logic;  -- 最后一个数据信号
		m00_axis_tready	: in std_logic;  -- 数据就绪信号
        -----------------------------------------------------------------------------
		-- Ports of Axi Slave Bus Interface S00_AXIS
		-----------------------------------------------------------------------------
        s00_axis_aclk      : in  std_logic;  -- 时钟信号
        s00_axis_aresetn   : in  std_logic;  -- 复位信号（低电平有效）
        s00_axis_tready    : out std_logic;  -- 数据就绪信号
        s00_axis_tdata     : in  std_logic_vector(C_S00_AXIS_TDATA_WIDTH-1 downto 0);  -- 数据
        -- s00_axis_tstrb    : in  std_logic_vector((C_S00_AXIS_TDATA_WIDTH/8)-1 downto 0);  -- 数据选通信号（未使用）
        s00_axis_tlast     : in  std_logic;  -- 最后一个数据信号
        s00_axis_tvalid    : in  std_logic;  -- 数据有效信号
		-----------------------------------------------------------------------------
		-- Int interface
		-----------------------------------------------------------------------------
		Usr_Int           : out std_logic -- 用户中断信号
	);
end Usr_HDL_v1_0;

architecture arch_imp of Usr_HDL_v1_0 is
component S00_AXIL_Itf                  -- 声明lite组件
port (
    S_AXI_ACLK	    : in std_logic;
    S_AXI_ARESETN	: in std_logic;
    S_AXI_AWADDR	: in std_logic_vector(15 downto 0);
    S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
    S_AXI_AWVALID	: in std_logic;
    S_AXI_AWREADY	: out std_logic;
    S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
    S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
    S_AXI_WVALID	: in std_logic;
    S_AXI_WREADY	: out std_logic;
    S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
    S_AXI_BVALID	: out std_logic;
    S_AXI_BREADY	: in std_logic;
    S_AXI_ARADDR	: in std_logic_vector(15 downto 0);
    S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
    S_AXI_ARVALID	: in std_logic;
    S_AXI_ARREADY	: out std_logic;
    S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
    S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
    S_AXI_RVALID	: out std_logic;
    S_AXI_RREADY	: in std_logic;
    -- 以下是模板没有、用户添加的参数
    reg_wr         : out std_logic;  -- 寄存器写信号
    reg_waddr      : out std_logic_vector(15 downto 0);  -- 寄存器写地址
    reg_wdata      : out std_logic_vector(31 downto 0);  -- 寄存器写数据
    reg_rd         : out std_logic;  -- 寄存器读信号
    reg_raddr      : out std_logic_vector(15 downto 0);  -- 寄存器读地址
    reg_rdata      : in  std_logic_vector(31 downto 0)  -- 寄存器读数据
);
end component;

--管理模块的配置和状态信息，处理来自 AXI-Lite 接口的寄存器读写操作；
--生成用户中断信号 Usr_Int;
--可能用于存储模块的配置参数、状态信息和调试信息；
component Main_Reg
port (
    CLK             : in std_logic;
    RST_N           : in std_logic;

    reg_wr          : in std_logic;
    reg_waddr       : in std_logic_vector(15 downto 0);
    reg_wdata       : in std_logic_vector(31 downto 0);
    reg_rd          : in std_logic;
    reg_raddr       : in std_logic_vector(15 downto 0);
    reg_rdata       : out std_logic_vector(31 downto 0); 

    misc_set_flag   : out std_logic;  -- misc设置标志
    misc_set_data   : out std_logic_vector(31 downto 0);   -- misc设置数据
    Usr_Int         : out std_logic;    -- 用户中断信号
    tx_req_bit      : out std_logic;    -- 发送请求位
    m00_axis_debug_state: in std_logic_vector(31 downto 0);--调试用
    s00_axis_debug_state: in std_logic_vector(31 downto 0)
);
end component;

component M00_AXIS_Itf                  -- 声明从PS读入组件
port (
    M_AXIS_ACLK	    : in std_logic;
    M_AXIS_ARESETN	: in std_logic;
    M_AXIS_TVALID	: out std_logic;
    M_AXIS_TDATA	: out std_logic_vector(31 downto 0);
    --  M_AXIS_TSTRB	: out std_logic_vector(3 downto 0);
    M_AXIS_TLAST	: out std_logic;
    M_AXIS_TREADY	: in std_logic;
    tx_req          : in std_logic; -- 发送请求信号
    tx_ack          : out std_logic;-- 发送确认信号
    RAM_RADDR       : out std_logic_vector(9 downto 0);  -- RAM 读地址
    RAM_RDATA       : in std_logic_vector(31 downto 0);  -- RAM 读数据
    debug_state     : out std_logic_vector(31 downto 0)  -- 调试状态
);
end component;

component S00_AXIS_Itf                  -- 声明向PS写出组件
port (
    S_AXIS_ACLK	    : in std_logic;
    S_AXIS_ARESETN	: in std_logic;
    S_AXIS_TREADY	: out std_logic;
    S_AXIS_TDATA	: in std_logic_vector(31 downto 0);
 --   S_AXIS_TSTRB	: in std_logic_vector(3 downto 0);
    S_AXIS_TLAST	: in std_logic;
    S_AXIS_TVALID	: in std_logic;
    RAM_WEN         : out std_logic;    -- RAM 写使能
    RAM_WADDR       : out std_logic_vector(9 downto 0);  -- RAM 写地址
    RAM_WDATA       : out std_logic_vector(31 downto 0);  -- RAM 写数据
    debug_state     : out std_logic_vector(31 downto 0)  -- 调试状态
);
end component;

--若端口B的读操作与端口A的写操作冲突（例如同时访问同一地址），
--则读数据的行为由 Operating Mode（操作模式）决定（如 Write First、Read First 或 No Change）。
--在 Vivado 的 Block Memory Generator 中，你可以通过配置 Operating Mode 来选择这些模式，但代码中未直接体现，需通过内部逻辑实现。
component myDP_RAM                      -- 声明双端口 RAM 组件
PORT (
    clka        : IN  STD_LOGIC;          -- 端口A的时钟
    wea         : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);  -- 端口A的写使能（1位，高电平允许写入）
    addra       : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);  -- 端口A的地址（10位，支持 1024 个地址，每个地址对应一个 32 位 的存储单元）
    dina        : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); -- 端口A的数据输入（32位）
    clkb        : IN  STD_LOGIC;          -- 端口B的时钟
    addrb       : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);  -- 端口B的地址（10位）
    doutb       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)  -- 端口B的数据输出（32位）
);
END component;

--将某些数据写入发送 RAM，或者从接收 RAM 中读取数据;
--其他辅助功能。
component Misc
port (
    CLK             : in  std_logic;
    RST_N           : in  std_logic;
    set_flag        : in  std_logic;  -- 设置标志
    set_data        : in  std_logic_vector(31 downto 0);  -- 设置数据
    tx_ram_wen      : out std_logic;  -- 发送 RAM 写使能
    tx_ram_waddr    : out std_logic_vector(9 downto 0);  -- 发送 RAM 写地址
    tx_ram_wdata    : out std_logic_vector(31 downto 0);  -- 发送 RAM 写数据
    rx_ram_raddr    : out std_logic_vector(9 downto 0);  -- 接收 RAM 读地址
    rx_ram_rdata    : in  std_logic_vector(31 downto 0)  -- 接收 RAM 读数据
);
end component;

-- 系统信号 
signal rst_n    : std_logic;
signal clk      : std_logic;
-- 寄存器读写接口信号
signal reg_wr_wire      : std_logic;
signal reg_waddr_wire   : std_logic_vector(15 downto 0); --16 位地址总线可以寻址 65536 个地址，此模块实际占用了多少个地址？？？？？？？？？？？？？？
signal reg_wdata_wire   : std_logic_vector(31 downto 0);
signal reg_rd_wire      : std_logic;
signal reg_raddr_wire   : std_logic_vector(15 downto 0);
signal reg_rdata_wire   : std_logic_vector(31 downto 0);
-- M00_AXIS 接口信号
signal tx_req         : std_logic;  -- 发送请求信号
signal tx_ack         : std_logic;  -- 发送确认信号
signal tx_req_bit     : std_logic;  -- 发送请求位
signal last_tx_req_bit: std_logic;  -- 上一个发送请求位
-- for Main_Reg
signal misc_set_flag: std_logic;
signal misc_set_data: std_logic_vector(31 downto 0);    
signal m00_axis_debug_state: std_logic_vector(31 downto 0);
signal s00_axis_debug_state: std_logic_vector(31 downto 0);
-- for tx_ram
signal tx_ram_wen: std_logic;
signal tx_ram_waddr: std_logic_vector(9 downto 0);
signal tx_ram_wdata: std_logic_vector(31 downto 0);
signal tx_ram_raddr: std_logic_vector(9 downto 0);
signal tx_ram_rdata: std_logic_vector(31 downto 0);
-- for rx_ram
signal rx_ram_wen: std_logic;
signal rx_ram_waddr: std_logic_vector(9 downto 0);
signal rx_ram_wdata: std_logic_vector(31 downto 0);
signal rx_ram_raddr: std_logic_vector(9 downto 0);
signal rx_ram_rdata: std_logic_vector(31 downto 0);
    
begin
    -- 复位和时钟信号连接
    rst_n   <= s00_axi_aresetn;  -- Assume s00_axi_aresetn, s00_axi_aresetn, m00_axis_aresetns_aclk from the same rst singnal source at higher level
    clk     <= s00_axi_aclk;      -- Assume s00_axi_aclk, m00_axis_aclk, s00_axis_aclk from the same clock singnal source at higher level

    -- 实例化 AXI-Lite 接口模块，更新reg_wr、reg_waddr、reg_wdata、reg_rd、reg_raddr的时候触发Main_Reg
    -- vivado生成的众多slv_reg*用不到就可以删！！
    -- 包含6个时序(写4个，读合并为2个，官方模板就这样……)：
    -- 1.写地址就绪进程，时钟上升沿触发：当写地址未就绪、写地址有效、写数据有效时，才接受新的写地址，将写地址就绪flag置1
    -- 2.写地址缓存进程，时钟上升沿触发：当写地址未就绪、写地址有效、写数据有效时，才接受新的写地址，保存写地址
    -- 3.写数据就绪进程，时钟上升沿触发：当写数据未就绪、写地址有效、写数据有效时，接受新的写数据，将写数据就绪flag置1
    -- 4.写响应进程，时钟上升沿触发：当写地址就绪、写地址有效、写数据就绪、写数据有效、写响应并非有效时，生成写响应信号，将写响应有效flag置1
    --                            当主设备（PS）确认写响应后，复位写响应有效flag
    -- 5.读地址就绪与缓存进程，时钟上升沿触发：当读地址未就绪、读地址有效时，接受地址，将读地址就绪flag置1，保存读地址
    -- 6.读数据就绪与读响应进程，时钟上升沿触发：当读地址就绪、读地址有效、读数据还未有效时，将读数据有效flag
    --                            当读数据有效、主设备确认读响应后，复位数据有效信号
    -- 自定义接口通过两个逻辑连接标准接口：
    -- 1.当写地址和数据通道均准备好时，给自定义的写使能、写地址、写数据输出端口赋值
	-- 2.当读地址和数据通道均准备好时，给自定义的读使能、读地址输出端口赋值，将自定义读数据输入端口转接给AXI读数据输出端口
    S00_AXIL_Itf_t : S00_AXIL_Itf
    port map (
        S_AXI_ACLK      => s00_axi_aclk,    
        S_AXI_ARESETN	=> s00_axi_aresetn,    
        S_AXI_AWADDR	=> s00_axi_awaddr,
        S_AXI_AWPROT	=> s00_axi_awprot,    
        S_AXI_AWVALID	=> s00_axi_awvalid,    
        S_AXI_AWREADY	=> s00_axi_awready,
        S_AXI_WDATA	    => s00_axi_wdata,    
        S_AXI_WSTRB	    => s00_axi_wstrb,    
        S_AXI_WVALID	=> s00_axi_wvalid,
        S_AXI_WREADY	=> s00_axi_wready,    
        S_AXI_BRESP	    => s00_axi_bresp,    
        S_AXI_BVALID	=> s00_axi_bvalid,
        S_AXI_BREADY	=> s00_axi_bready,    
        S_AXI_ARADDR	=> s00_axi_araddr,    
        S_AXI_ARPROT	=> s00_axi_arprot,
        S_AXI_ARVALID	=> s00_axi_arvalid,    
        S_AXI_ARREADY	=> s00_axi_arready,    
        S_AXI_RDATA	    => s00_axi_rdata,
        S_AXI_RRESP	    => s00_axi_rresp,    
        S_AXI_RVALID	=> s00_axi_rvalid,    
        S_AXI_RREADY	=> s00_axi_rready,
        --下面是自定义的接口
        reg_wr           => reg_wr_wire,
        reg_waddr        => reg_waddr_wire,
        reg_wdata        => reg_wdata_wire,
        reg_rd           => reg_rd_wire,
        reg_raddr        => reg_raddr_wire,
        reg_rdata        => reg_rdata_wire
    );
    -- 实例化主寄存器模块
    -- 从S00_AXIL_Itf输入reg_wr、reg_waddr、reg_wdata、reg_rd、reg_raddr
    -- 包含两个时序逻辑：
    --  1.写寄存器进程，有reg_wr信号时触发
        --根据reg_waddr地址将reg_wdata相关数值赋值给Usr_Int、misc_set_flag、misc_set_data、tx_req_bit以及多种调试变量；
        -- 输出misc_set_flag、misc_set_data；更新的时候触发Misc！
        -- 输出Usr_Int单独通道返回PS；
        -- 输出tx_req_bit给Usr_HDL的时序逻辑
    --  2.读寄存器进程，有reg_rd信号时触发
        --根据reg_raddr地址将多种调试变量赋值给reg_rdata；
        -- 输出reg_rdata；更新reg_rdata的时候触发S00_AXIL_Itf！
    Main_Reg_t: Main_Reg
    port  MAP(
        CLK              => s00_axi_aclk,
        RST_N            => s00_axi_aresetn,
        reg_wr           => reg_wr_wire,
        reg_waddr        => reg_waddr_wire,
        reg_wdata        => reg_wdata_wire,
        reg_rd           => reg_rd_wire,
        reg_raddr        => reg_raddr_wire,
        reg_rdata        => reg_rdata_wire,
        misc_set_flag    => misc_set_flag,
        misc_set_data    => misc_set_data,
        Usr_Int          => Usr_Int,
        tx_req_bit       => tx_req_bit,
        m00_axis_debug_state => m00_axis_debug_state,
        s00_axis_debug_state => s00_axis_debug_state
    );
    -- 实例化杂项处理模块，向myDP_RAM写入和读出数据！
    -- 从Main_Reg输入misc_set_flag、misc_set_data
    -- 向myDP_RAM输出tx_ram_wen、tx_ram_waddr、tx_ram_wdata以及rx_ram_raddr
    -- 从myDP_RAM读入rx_ram_rdata
    -- 包含一个状态机驱动的时序逻辑，每个时钟上升沿触发：
        --case状态机： 
            --空闲状态下，重置tx_ram_wen、tx_ram_waddr、tx_ram_wdata，如果misc_set_flag、misc_set_data非空，则转入写数据状态；
            --写数据状态下，使能tx_ram_wen，赋值tx_ram_waddr，读入rx_ram_rdata，进行相应操作，赋值tx_ram_wdata；同时运行计数器，计数触发时结束写数据，转入结束状态；
            --结束状态下，重置tx_ram_wen、tx_ram_waddr、tx_ram_wdata，再转入空闲状态。
    Misc_t: Misc
    port map(
        CLK              => clk,
        RST_N            => rst_n,
        set_flag         => misc_set_flag,
        set_data         => misc_set_data,
        tx_ram_wen       => tx_ram_wen,
        tx_ram_waddr     => tx_ram_waddr,
        tx_ram_wdata     => tx_ram_wdata,
        rx_ram_raddr     => rx_ram_raddr,
        rx_ram_rdata     => rx_ram_rdata
    );
    -- 实例化接收 RAM
    Rx_RAM_t: myDP_RAM
    port  map(
        clka        => s00_axis_aclk,
        wea(0)      => rx_ram_wen,  --来自S00_AXIS_Itf
        addra       => rx_ram_waddr,--来自S00_AXIS_Itf
        dina        => rx_ram_wdata,--来自S00_AXIS_Itf
        clkb        => clk,
        addrb       => rx_ram_raddr,--来自Misc
        doutb       => rx_ram_rdata --唯一的输出，给Misc
    );
    -- 实例化发送RAM
    Tx_RAM_t: myDP_RAM
    PORT  MAP(
        clka        => clk,
        wea(0)      => tx_ram_wen,  --来自Misc
        addra       => tx_ram_waddr,--来自Misc
        dina        => tx_ram_wdata,--来自Misc
        clkb        => m00_axis_aclk,
        addrb       => tx_ram_raddr,--来自M00_AXIS_Itf
        doutb       => tx_ram_rdata --唯一的输出，给M00_AXIS_Itf
    );
    -- 实例化 M00_AXIS 接口模块
    -- 主状态机逻辑，时钟上升沿触发:
        -- case state:
        -- 空闲状态下，当收到tx_req请求时，发送确认信号，初始化读取数据的RAM地址，进入预发送状态
        -- 预发送状态下，发送当前RAM地址数据，计数器初始化为1，进入持续发送状态
        -- 持续发送状态下，根据从设备接受就绪信号变化状态，判断发送新数据还是上一周期的旧数据；如果达到最大传输量，标记最后一个数据包，转入传输结束状态
        -- 传输结束状态下，清除数据有效、清除结束标志，转入握手状态
        -- 握手状态下，清除确认信号，返回空闲状态
    M00_AXIS_Itf_t : M00_AXIS_Itf
    port map (
        M_AXIS_ACLK	    => m00_axis_aclk,    
        M_AXIS_ARESETN	=> m00_axis_aresetn,    
        M_AXIS_TVALID	=> m00_axis_tvalid,
        M_AXIS_TDATA	=> m00_axis_tdata,    
        --   M_AXIS_TSTRB	=> m00_axis_tstrb,    
        M_AXIS_TLAST	=> m00_axis_tlast,
        M_AXIS_TREADY	=> m00_axis_tready, 
        --下面是自定义的接口
        tx_req          => tx_req,
        tx_ack          => tx_ack,
        RAM_RADDR       => tx_ram_raddr,
        RAM_RDATA       => tx_ram_rdata,
        debug_state     => m00_axis_debug_state
    );
    -- 实例化 S00_AXIS 接口模块
    -- 从PS输入S_AXIS_ACLK、S_AXIS_ARESETN、S_AXIS_TDATA、S_AXIS_TLAST、S_AXIS_TVALID
    -- 向PS输出S_AXIS_TREADY
    -- 自定义接口向RAM模块输出RAM_WEN、RAM_WADDR、RAM_WDATA
    -- 包含两个时序逻辑：
    -- 1.状态机逻辑，时钟上升沿触发
        --case状态机： 
            --空闲状态下：当数据有效时，接收就绪flag置1，state转为数据传输
            --数据传输状态下：接收就绪flag持续置1，当数据有效时：
                -- 如果所有数据写入完成时返回空闲状态
                --写入数据write_count不足1024个时则保持继续传输
    -- 2.数据写入逻辑，，时钟上升沿触发：当数据有效、准备接收、写入数据不足1024个时，根据write_count生成写入地址，将输入数据赋给自定义写数据接口
    S00_AXIS_Itf_t : S00_AXIS_Itf
    port map (
        S_AXIS_ACLK	    => s00_axis_aclk,
        S_AXIS_ARESETN	=> s00_axis_aresetn,    
        S_AXIS_TREADY	=> s00_axis_tready,
        S_AXIS_TDATA	=> s00_axis_tdata,    
        --  S_AXIS_TSTRB	=> s00_axis_tstrb,
        S_AXIS_TLAST	=> s00_axis_tlast,    
        S_AXIS_TVALID	=> s00_axis_tvalid, 
        --下面是自定义的接口
        RAM_WEN         => rx_ram_wen,
        RAM_WADDR       => rx_ram_waddr,
        RAM_WDATA       => rx_ram_wdata,
        debug_state     => s00_axis_debug_state
    );

    --触发M00_AXIS_Itf发送数据的时序逻辑
    -- generate tx_req according tx_req_bit and tx_ack
    process(clk)
    begin
        if(clk'event and clk='1') then                                                       
            if(rst_n = '0') then                                                                                                                  
                last_tx_req_bit <= '0';
                tx_req    <= '0';
            else
                last_tx_req_bit <= tx_req_bit;
                if(last_tx_req_bit='0' and  tx_req_bit='1')then --tx_req_bit产生上升沿
                    tx_req    <= '1';                           --由M00_AXIS_Itf发送
                end if;
                if(tx_ack='1')then                              --从M00_AXIS_Itf接收
                    tx_req <= '0';
                end if;
            end if;
    end if;
    end process;

end arch_imp;
