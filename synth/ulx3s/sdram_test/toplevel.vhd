library ieee;
   use ieee.std_logic_1164.all;
   use work.util.all;

entity toplevel is
    port(
        clk_25mhz  : in     std_logic;
        btn        : in     std_logic_vector(6 downto 0);
        led        : out    std_logic_vector(7 downto 0);
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
begin

    clk <= clk_25mhz;
    sdram_d <= dq_o when dq_oe = '1' else (others => 'Z');
    sdram_clk <= clk;
    -- TODO: Just make a reset generator
    arst <= btn(0);

    led(7) <= fault;
    led(6 downto 0) <= address(23 downto 17);

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
end architecture rtl;
