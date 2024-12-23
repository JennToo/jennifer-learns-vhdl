library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity tb_sdram is
end tb_sdram;

architecture behav of tb_sdram is
    constant CLK_PERIOD : time := 10 ns; -- 100 MHz

    signal clk           : std_logic;
    signal cke           : std_logic;
    signal cs_l          : std_logic;
    signal cas_l         : std_logic;
    signal ras_l         : std_logic;
    signal we_l          : std_logic;
    signal dqml          : std_logic_vector(7  downto 0);
    signal dqmh          : std_logic_vector(7  downto 0);
    signal ba            : std_logic_vector(1  downto 0);
    signal a             : std_logic_vector(12 downto 0);
    signal dq            : std_logic_vector(15 downto 0);
    signal arst_dram_sim : std_logic;

    signal stop : boolean := false;
begin
    sim_sdram_0: entity work.sim_sdram port map (
        clk           => clk,
        cke           => cke,
        cs_l          => cs_l,
        cas_l         => cas_l,
        ras_l         => ras_l,
        we_l          => we_l,
        dqml          => dqml,
        dqmh          => dqmh,
        ba            => ba,
        a             => a,
        dq            => dq,
        arst_model    => arst_dram_sim
    );

    clocker: process begin
        while not stop loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clocker;

    stimulus: process begin
        stop <= true;
        wait;
    end process stimulus;
end behav;
