library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Misc is
port (
    -- SYS
    CLK             : in std_logic;
    RST_N           : in std_logic;
    -- ctl
    set_flag    : in std_logic;   -- 1 clock width
    set_data    : in std_logic_vector(31 downto 0);
    -- for tx_ram write
    tx_ram_wen      : out std_logic;
    tx_ram_waddr    : out std_logic_vector(9 downto 0);
    tx_ram_wdata    : out std_logic_vector(31 downto 0);
    -- for rx_ram read
    rx_ram_raddr    : out std_logic_vector(9 downto 0);
    rx_ram_rdata    : in std_logic_vector(31 downto 0)
);
end Misc;

architecture arch_imp of Misc is
-- state                                                                          
type state_type is (s0, s1, s2);                                                                                              
signal state : state_type; 

-- cnt
signal cnt: integer range 0 to 1023;

-- signal
signal sel: std_logic_vector(1 downto 0);

begin

process(CLK, RST_N)
begin
if(CLK'event and CLK='1')then
    if(RST_N='0')then
        cnt         <= 0;
        tx_ram_wen  <= '0';
        tx_ram_waddr <= (others=>'0');
        tx_ram_wdata <= x"00000000";
        rx_ram_raddr <= (others=>'0');
        sel     <= "00";
        state   <= s0;
    else
        case state is
            when s0 => -- @idle (wait ctl set)
                 cnt         <= 0;
                 tx_ram_wen  <= '0';
                 tx_ram_waddr <= (others=>'0');
                 tx_ram_wdata <= x"00000000";
                 rx_ram_raddr <= (others=>'0');   
                 if(set_flag='1')then
                    state   <= s1;
                    case set_data is
                        when x"00000001" => 
                            sel     <= "01";
                        when x"00000002" =>
                            sel     <= "10";
                        when x"00000003" =>
                            sel     <= "11";
                            rx_ram_raddr <=  CONV_STD_LOGIC_VECTOR(1, 10);
                        when others => -- ignore
                            state   <= s0;
                    end case;
                 end if;
                 
            when s1 =>  -- @ filled tx_ram 
                tx_ram_wen  <= '1';
                tx_ram_waddr<= CONV_STD_LOGIC_VECTOR(cnt, 10);
                case sel is
                    when "01" => tx_ram_wdata<= CONV_STD_LOGIC_VECTOR(cnt, 32);      -- for inc data
                    when "10" => tx_ram_wdata<= CONV_STD_LOGIC_VECTOR(1023-cnt, 32); -- for dec data
                    when "11" => tx_ram_wdata<= rx_ram_rdata;                           -- for rx_ram
                                  rx_ram_raddr <= CONV_STD_LOGIC_VECTOR(cnt+2, 10);
                    when others=>
                end case;
                
                if(cnt<1023)then
                    cnt <= cnt+1;
                else
                    state <= s2;
                end if;
                 
            when s2 => -- @ end
                tx_ram_wen  <= '0';
                tx_ram_waddr <= (others=>'0');
                tx_ram_wdata <= x"00000000";   
                state <= s0;
                
            when others =>
        end case;
    end if;
end if;
end process;

end arch_imp;