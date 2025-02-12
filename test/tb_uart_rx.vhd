library std;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;

entity tb_uart_rx is
end tb_uart_rx;

architecture behave of tb_uart_rx is
    -- 25.175 MHz
    constant CLK_PERIOD : time := 39.72194638 ns;

    signal clk  : std_logic := '0';
    signal arst : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    stimulus: process
    begin
        arst <= '0';
        wait for 1 ns;
        arst <= '1';

        finish;
    end process stimulus;
end behave;
