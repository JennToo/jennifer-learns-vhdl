library std;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi.all;

entity tb_sdram_memtester is
end tb_sdram_memtester;

architecture behav of tb_sdram_memtester is
    constant CLK_PERIOD             : time    := 10 ns; -- 100 MHz
    constant powerup_time           : time    := 50 * CLK_PERIOD;
    constant t_ref                  : time    := 1 ms;
    constant periodic_refresh_count : integer := 10;

    signal axi_initiator : axi4l_initiator_signals_t;
    signal axi_target    : axi4l_target_signals_t;

    signal clk   : std_logic := '0';
    signal cke   : std_logic;
    signal csn   : std_logic;
    signal casn  : std_logic;
    signal rasn  : std_logic;
    signal wen   : std_logic;
    signal dqm   : std_logic_vector(1 downto 0);
    signal ba    : std_logic_vector(1  downto 0);
    signal a     : std_logic_vector(12 downto 0);
    signal dq_i  : std_logic_vector(15 downto 0);
    signal dq_o  : std_logic_vector(15 downto 0);
    signal dq_oe : std_logic;
    signal arst  : std_logic;

    signal fault  : std_logic;
    signal enable : std_logic;
begin
    clk <= not clk after CLK_PERIOD / 2;

    sim_sdram_0: entity work.sim_sdram
    generic map(
        required_power_on_wait => powerup_time,
        t_ref => t_ref,
        periodic_refresh_count => periodic_refresh_count
    )
    port map (
        clk        => clk,
        cke        => cke,
        csn        => csn,
        casn       => casn,
        rasn       => rasn,
        wen        => wen,
        dqm        => dqm,
        ba         => ba,
        a          => a,
        dq_i       => dq_o,
        dq_o       => dq_i,
        arst_model => arst
    );

    basic_sdram_0: entity work.basic_sdram
    generic map(
        clk_period             => CLK_PERIOD,
        required_power_on_wait => powerup_time,
        t_ref => t_ref,
        periodic_refresh_count => periodic_refresh_count
    )
    port map (
        clk           => clk,
        arst          => arst,
        axi_initiator => axi_initiator,
        axi_target    => axi_target,
        cke           => cke,
        csn           => csn,
        casn          => casn,
        rasn          => rasn,
        wen           => wen,
        dqm           => dqm,
        ba            => ba,
        a             => a,
        dq_o          => dq_o,
        dq_i          => dq_i,
        dq_oe         => dq_oe
    );

    memtester_0: entity work.memtester
    generic map(
        words_to_cover => 128
    )
    port map (
        clk => clk,
        arst => arst,
        enable => enable,
        axi_target => axi_target,
        axi_initiator => axi_initiator,
        address => open,
        fault => fault
    );

    stimulus: process
    begin
        enable <= '0';
        arst   <= '0';
        wait for 1 ns;
        arst   <= '1';
        enable <= '1';

        assert fault = '0' report "Memory fault" severity error;
        wait until fault = '1' for 3 * t_ref;
        assert fault = '0' report "Memory fault" severity error;

        finish;
    end process stimulus;
end behav;
