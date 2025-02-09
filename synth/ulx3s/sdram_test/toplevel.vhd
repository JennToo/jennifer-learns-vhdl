library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi.all;

entity toplevel is
    port(
        clk_25mhz  : in     std_logic;
        btn        : in     std_logic_vector(6 downto 0);
        led        : out    std_logic_vector(7 downto 0);
        wifi_gpio0 : out    std_logic;
        sdram_clk  : out    std_logic;
        sdram_cke  : out    std_logic;
        sdram_csn  : out    std_logic;
        sdram_casn : out    std_logic;
        sdram_rasn : out    std_logic;
        sdram_wen  : out    std_logic;
        sdram_dqm  : out    std_logic_vector(1 downto 0);
        sdram_ba   : out    std_logic_vector(1 downto 0);
        sdram_a    : out    std_logic_vector(12 downto 0);
        sdram_d    : inout std_logic_vector(15 downto 0)
    );
end toplevel;

architecture rtl of toplevel is
    signal arst          : std_logic;
    signal axi_initiator : axi4l_initiator_signals_t;
    signal axi_target    : axi4l_target_signals_t;
    signal dq_o          : std_logic_vector(15 downto 0);
    signal dq_oe         : std_logic;
    signal clk           : std_logic;
    signal fault         : std_logic;
    signal address       : std_logic_vector(31 downto 0);
    signal clk_100mhz    : std_logic;

    signal lfsr_value    : std_logic_vector(15 downto 0);
    signal nonsense_value_1 : unsigned(31 downto 0);
    signal nonsense_value_2 : unsigned(31 downto 0);
    signal nonsense_value_3 : unsigned(31 downto 0);
    signal nonsense_value_vec : std_logic_vector(31 downto 0);

    component pll is
        port (
            clkin : in std_logic;
            clkout0 : out std_logic;
            locked : out std_logic
        );
    end component;
begin

    wifi_gpio0 <= '1';
    clk <= clk_100mhz;
    sdram_d <= dq_o when dq_oe = '1' else (others => 'Z');
    sdram_clk <= clk;
    -- TODO: Just make a reset generator
    arst <= btn(0);

    led(7) <= fault;
    led(6 downto 0) <= nonsense_value_vec(23 downto 17);

    pll_0: pll
    port map (
        clkin => clk_25mhz,
        clkout0 => clk_100mhz
    );

    basic_sdram_0: entity work.basic_sdram
    generic map(
        clk_period => 40 ns, -- TODO use a PLL for better speeds
        required_power_on_wait => 200 us
    )
    port map (
        clk           => clk,
        arst          => arst,
        axi_initiator => axi_initiator,
        axi_target    => axi_target,
        cke           => sdram_cke,
        csn           => sdram_csn,
        casn          => sdram_casn,
        rasn          => sdram_rasn,
        wen           => sdram_wen,
        dqm           => sdram_dqm,
        ba            => sdram_ba,
        a             => sdram_a,
        dq_o          => dq_o,
        dq_i          => sdram_d,
        dq_oe         => dq_oe
    );

    memtester_0: entity work.memtester
    generic map(
        words_to_cover => (256 * 1024 * 1024) / 16
    )
    port map (
        clk => clk,
        arst => arst,
        enable => '1',
        axi_target => axi_target,
        axi_initiator => axi_initiator,
        address => address,
        fault => fault
    );

    lfsr_16_0: entity work.lfsr_16
    generic map (
        seed => x"ACE1"
    )
    port map (
        clk   => clk,
        arst  => arst,
        value => lfsr_value
    );

    nonsense_value_1 <= unsigned(lfsr_value & lfsr_value);
    nonsense_value_vec <= std_logic_vector(nonsense_value_3);
    nonsense: process(clk, arst) begin
        if (arst = '0') then
            nonsense_value_2 <= to_unsigned(0, 32);
            nonsense_value_3 <= (others => '0');
        elsif (rising_edge(clk)) then
            nonsense_value_2 <= nonsense_value_1;
            nonsense_value_3 <= nonsense_value_1 + nonsense_value_2;
        end if;
    end process nonsense;
end architecture rtl;
