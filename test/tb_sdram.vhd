library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
   use work.test_util.all;
   use work.util.all;

entity tb_sdram is
end tb_sdram;

architecture behav of tb_sdram is
    constant CLK_PERIOD : time := 10 ns; -- 100 MHz
    -- Most real RAM has a much larger powerup time. But that makes the
    -- simulation waveforms harder to read.
    constant powerup_time : time := 50 * CLK_PERIOD;
    -- Avoid spamming the sim waveform with as many refreshes as a real chip needs
    constant t_ref : time := 1 ms;
    constant periodic_refresh_count : integer := 10;

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
    signal dq_i   : std_logic_vector(15 downto 0);
    signal dq_o   : std_logic_vector(15 downto 0);
    signal dq_oe : std_logic;
    signal arst : std_logic;

    signal stop : boolean := false;
begin
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
        variable got_data : std_logic_vector(15 downto 0);
        variable expected_data : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(42, 16));
    begin
        arst <= '0';
        wait for 1 ns;
        arst <= '1';

        wait for powerup_time;
        wait for CLK_PERIOD * 100;

        axi_write_word(
            (others => '0'),
            expected_data,
            CLK_PERIOD * 20,
            clk,
            axi_initiator,
            axi_target
        );
        axi_read_word(
            (others => '0'),
            CLK_PERIOD * 20,
            clk,
            axi_initiator,
            axi_target,
            got_data
        );
        assert got_data = expected_data
            report "Data mismatch, got " & to_string(got_data)
            severity failure;

        wait for t_ref * 5;
        stop <= true;
        wait;
    end process stimulus;
end behav;
