library std;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_gpu is
end tb_gpu;

architecture behave of tb_gpu is
    constant CLK_PERIOD : time    := 10 ns; -- 100 MHz

    signal clk : std_logic;
begin
    clk <= not clk after CLK_PERIOD / 2;

    stimulus: process
    begin
        report "Hello linking/bind!" severity note;
        wait for 10 * CLK_PERIOD;
        finish;
    end process stimulus;
end architecture behave;
