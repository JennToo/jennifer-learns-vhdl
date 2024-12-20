library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity tb_sdram is
end tb_sdram;

architecture behav of tb_sdram is
    component sim_sdram is
        port(
            clk   : in    std_logic;
            cke   : in    std_logic;
            cs_l  : in    std_logic;
            cas_l : in    std_logic;
            ras_l : in    std_logic;
            we_l  : in    std_logic;
            dqml  : in    std_logic_vector(7 downto 0);
            dqmh  : in    std_logic_vector(7 downto 0);
            ba    : in    std_logic_vector(1 downto 0);
            a     : in    std_logic_vector(12 downto 0);
            dq    : inout std_logic_vector(15 downto 0);
            arst_model : in std_logic
        );
    end component;

    for sim_sdram_0: sim_sdram use entity work.sim_sdram;

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
begin
    sim_sdram_0: sim_sdram port map (
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
        clk <= '0';
        wait for 1 ns;
        clk <= '1';
        wait for 1 ns;
    end process clocker;

    stimulus: process begin

        assert false report "end of test" severity note;
        wait;
    end process stimulus;
end behav;
