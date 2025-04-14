library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- AXI4-Stream Slave接口模块
-- 主要功能包括：
-- 1. 接收 AXI-Stream 输入数据
-- 2. 将数据存储到 FIFO 中
-- 3. 管理 FIFO 的写入操作和状态
entity usr_hdl_verilog_v1_0_S00_AXIS is
	generic (
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32          -- 通用参数：数据总线宽度，默认为 32 位
	);
	port (
        S_AXIS_ACLK    : in  std_logic;  -- 主时钟（上升沿有效）
        S_AXIS_ARESETN : in  std_logic;  -- 同步复位（低电平有效）
        S_AXIS_TREADY  : out std_logic;  -- 准备好接收数据信号 --这些默认端口都是面向PS的！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
        S_AXIS_TDATA   : in  std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);  -- 输入数据
        -- S_AXIS_TSTRB   : in  std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);  -- 数据选通信号（未使用）
        S_AXIS_TLAST   : in  std_logic;  -- 数据包结束标志
        S_AXIS_TVALID  : in  std_logic   -- 数据有效信号
	);
end usr_hdl_verilog_v1_0_S00_AXIS;

architecture arch_imp of usr_hdl_verilog_v1_0_S00_AXIS is
    -- 函数声明：计算以2为底的对数并向上取整
    -- 用于根据FIFO地址位宽计算寻址范围
	function clogb2 (bit_depth : integer) return integer is 
	variable depth  : integer := bit_depth;
	  begin
	    if (depth = 0) then
	      return(0);
	    else
	      for clogb2 in 1 to bit_depth loop  -- Works for up to 32 bit integers
	        if(depth <= 1) then 
	          return(clogb2);      
	        else
	          depth := depth / 2;
	        end if;
	      end loop;
	    end if;
	end;    

    constant NUMBER_OF_INPUT_WORDS : integer := 8;        -- FIFO地址位宽（8个byte），由vivado设定（32 bits width）
    constant bit_num : integer := clogb2(NUMBER_OF_INPUT_WORDS-1);  -- FIFO寻址范围
    -- 状态机定义
    type state is (
        IDLE,        -- 初始/空闲状态
        WRITE_FIFO   -- 向 FIFO 写入数据状态
    );

    -- 内部信号声明
    signal axis_tready    : std_logic;                    -- 内部就绪信号
    signal mst_exec_state : state;                        -- 当前状态
    signal byte_index     : integer;                      -- 字节索引（用于生成语句）
    signal fifo_wren      : std_logic;                    -- FIFO写使能
    -- signal fifo_full_flag : std_logic;                    -- FIFO满标志（未使用）
    signal write_pointer  : integer range 0 to bit_num-1; -- 写指针（循环寻址）
    signal writes_done    : std_logic;                    -- 写完成标志

	-- 在 VHDL 中，没有直接的多维数组语法，但可以通过嵌套数组类型模拟多维数组：
	-- 外层数组：array(0 to N-1) 是第一维（0-7）。【FIFO深度8】
	-- 内层数组：每个元素是 std_logic_vector，构成第二维（位宽=8）。【FIFO按字节进行存储】
	type BYTE_FIFO_TYPE is array (0 to (NUMBER_OF_INPUT_WORDS-1)) of std_logic_vector(((C_S_AXIS_TDATA_WIDTH/4)-1)downto 0);

begin
	S_AXIS_TREADY	<= axis_tready; -- 内外端口连接
	-- 主状态机逻辑
	process(S_AXIS_ACLK)
	begin
	  if (rising_edge (S_AXIS_ACLK)) then
	    if(S_AXIS_ARESETN = '0') then
	      mst_exec_state      <= IDLE; -- 复位时进入空闲状态
	    else
	      case (mst_exec_state) is
	        when IDLE     => 
	          if (S_AXIS_TVALID = '1')then
	            mst_exec_state <= WRITE_FIFO;	  -- 当数据有效时，进入写 FIFO 状态
	          else
	            mst_exec_state <= IDLE;
	          end if;
	        when WRITE_FIFO => 
	          if (writes_done = '1') then
	            mst_exec_state <= IDLE;	          -- 当所有数据写入完成时返回空闲状态
	          else
	            mst_exec_state <= WRITE_FIFO;	  -- 没写完则继续写
	          end if;
	        when others    => 
	          mst_exec_state <= IDLE;
	      end case;
	    end if;  
	  end if;
	end process;

    -- TREADY信号生成逻辑
    -- 当处于写入状态且未满时允许接收数据
	axis_tready <= '1' when ((mst_exec_state = WRITE_FIFO) and (write_pointer <= NUMBER_OF_INPUT_WORDS-1)) else '0';

    -- 写指针和完成标志逻辑
	process(S_AXIS_ACLK)
	begin
	  if (rising_edge (S_AXIS_ACLK)) then
	    if(S_AXIS_ARESETN = '0') then
	      write_pointer <= 0;
	      writes_done <= '0';
	    else
	      if (write_pointer <= NUMBER_OF_INPUT_WORDS-1) then -- 写指针递增条件：计数不满NUMBER_OF_INPUT_WORDS，并且写使能=1
	        if (fifo_wren = '1') then
	          write_pointer <= write_pointer + 1;
	          writes_done <= '0';
	        end if;
	        if ((write_pointer = NUMBER_OF_INPUT_WORDS-1) or S_AXIS_TLAST = '1') then   -- 写入完成条件：计数满NUMBER_OF_INPUT_WORDS，并且结束标志=1
	          writes_done <= '1';
	        end if;
	      end  if;
	    end if;
	  end if;
	end process;

	-- FIFO写使能信号生成
	fifo_wren <= S_AXIS_TVALID and axis_tready;

	-- FIFO实现（按字节分割存储）
	 FIFO_GEN: for byte_index in 0 to (C_S_AXIS_TDATA_WIDTH/8-1) generate
	 signal stream_data_fifo : BYTE_FIFO_TYPE;
	 begin   
	  -- Streaming input data is stored in FIFO
	  process(S_AXIS_ACLK)
	  begin
	    if (rising_edge (S_AXIS_ACLK)) then
	      if (fifo_wren = '1') then
	        stream_data_fifo(write_pointer) <= S_AXIS_TDATA((byte_index*8+7) downto (byte_index*8));
	      end if;  
	    end  if;
	  end process;

	end generate FIFO_GEN;

	-- Add user logic here

	-- User logic ends

end arch_imp;
