library std;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;

entity tb_lfsr is
end tb_lfsr;

architecture behave of tb_lfsr is
    constant CLK_PERIOD : time := 10 ns;

    signal clk         : std_logic := '0'; 
    signal arst        : std_logic;
    signal value       : std_logic_vector(15 downto 0);
    signal clk_counter : integer := 0;
begin
    clk <= not clk after CLK_PERIOD / 2;

    lfsr_16_0: entity work.lfsr_16
    generic map (
        seed => x"ACE1"
    )
    port map (
        clk   => clk,
        arst  => arst,
        value => value
    );

    counter: process(clk)
    begin
        if rising_edge(clk) then
            clk_counter <= clk_counter + 1;
        end if;
    end process counter;

    stimulus: process
        variable clk_snapshot : integer;
    begin
        arst <= '0';
        wait for 1 ns;
        arst <= '1';

        -- Values come from the example on Wikipedia
        wait until rising_edge(clk);
        assert value = x"ACE1"
            report "unexpected value " & to_string(value)
            severity error;
        clk_snapshot := clk_counter;
        wait until rising_edge(clk);
        assert value = x"5670"
            report "unexpected value " & to_string(value)
            severity error;

        wait until value = x"ACE1" for 100 ms;
        wait until falling_edge(clk);
        assert value = x"ACE1"
            report "unexpected value " & to_string(value)
            severity error;
        assert clk_counter - clk_snapshot = 65535
            report "repeated at unexpected period " & integer'image(clk_counter - clk_snapshot)
            severity error;

        finish;
    end process stimulus;
end behave;
