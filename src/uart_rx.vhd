library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math.all;

entity uart_rx is
    generic (
        clk_period  : time;
        baud_period : time := 8680 ns -- 115200
    );
    port(
        clk        : in std_logic;
        arst       : in std_logic;
        uart       : in std_logic;
        data       : out std_logic_vector(7 downto 0);
        data_ready : out std_logic;
        data_error : out std_logic
    );
end uart_rx;

architecture rtl of uart_rx is
    constant clks_per_baud     : integer := period_to_cycles(baud_period, clk_period, false);
    constant clk_counter_width : integer := clog2(clks_per_baud);

    signal uart_d      : std_logic;
    signal bit_counter : unsigned(3 downto 0);
    signal clk_counter : unsigned(clk_counter_width-1 downto 0);
    signal bits        : std_logic_vector(10 downto 0);
    signal parity_ok   : std_logic;
    signal bits_ok     : std_logic;
begin
    data <= bits(8 downto 1);

    -- Odd parity
    parity_ok <= xor bits(9 downto 1);
    bits_ok <= parity_ok and bits(10) and not bits(0);

    receive : process(arst, clk) 
    begin
        if (arst = '1') then
            uart_d      <= '1';
            data_ready  <= '0';
            data_error  <= '0';
            bit_counter <= to_unsigned(0, 4);
            clk_counter <= to_unsigned(0, clk_counter_width-1);
        elsif (rising_edge(clk)) then
            uart_d <= uart;
            data_ready <= '0';
            data_error <= '0';
            if (clk_counter = 0) then
                if (bit_counter = 0) then
                    if (uart = '0' and uart_d = '1') then
                        -- Possible start bit
                    end if;
                elsif (bit_counter = 11) then
                    data_ready <= bits_ok;
                    data_error <= not bits_ok;
                    bit_counter <= to_unsigned(0, 4);
                else
                    bits(to_integer(bit_counter-to_unsigned(1, 4))) <= uart_d;
                    bit_counter <= bit_counter + 1;
                    clk_counter <= to_unsigned(clks_per_baud, clk_counter_width-1);
                end if;
            else
                clk_counter <= clk_counter - 1;
            end if;
        end if;
    end process;
end architecture;
