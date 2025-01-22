library ieee;
use ieee.std_logic_1164.all;

entity tb_uart_rx is
end tb_uart_rx;

architecture behave of tb_uart_rx is
    -- 25.175 MHz
    constant CLK_PERIOD : time := 39.72194638 ns;

    signal clk  : std_logic;
    signal arst : std_logic;

    signal stop : boolean := false;
begin
    clocker: process begin
        while not stop loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clocker;

    stimulus: process
    begin
        arst <= '0';
        wait for 1 ns;
        arst <= '1';

        stop <= true;
        wait;
    end process stimulus;
end behave;
