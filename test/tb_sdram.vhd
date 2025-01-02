library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.test_util.all;
   use work.util.all;

entity tb_sdram is
end tb_sdram;

architecture behav of tb_sdram is
    constant CLK_PERIOD : time := 10 ns; -- 100 MHz
    -- Most real RAM has a much larger powerup time. But that makes the
    -- simulation waveforms harder to read.
    constant powerup_time : time := 50 * CLK_PERIOD;

    signal axi_initiator : axi4l_initiator_signals_t;
    signal axi_target    : axi4l_target_signals_t;

    signal clk  : std_logic;
    signal cke  : std_logic;
    signal csn  : std_logic;
    signal casn : std_logic;
    signal rasn : std_logic;
    signal wen  : std_logic;
    signal dqm  : std_logic_vector(1 downto 0);
    signal ba   : std_logic_vector(1  downto 0);
    signal a    : std_logic_vector(12 downto 0);
    signal dq   : std_logic_vector(15 downto 0);
    signal arst : std_logic;

    signal stop : boolean := false;
begin
    sim_sdram_0: entity work.sim_sdram
    generic map(
        required_power_on_wait => powerup_time
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
        dq         => dq,
        arst_model => arst
    );

    basic_sdram_0: entity work.basic_sdram
    generic map(
        clk_period             => CLK_PERIOD,
        required_power_on_wait => powerup_time
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
        dq_o          => dq,
        dq_i          => dq,
        dq_oe         => open
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
        arst <= '0';
        wait for 1 ns;
        arst <= '1';

        wait for powerup_time;
        wait for CLK_PERIOD * 100;

        axi_write_word(
            (others => '0'),
            std_logic_vector(to_unsigned(42, 16)),
            CLK_PERIOD * 20,
            clk,
            axi_initiator,
            axi_target
        );

        wait for CLK_PERIOD * 100;
        stop <= true;
        wait;
    end process stimulus;
end behav;
