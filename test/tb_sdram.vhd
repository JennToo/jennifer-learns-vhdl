library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.test_util.all;

entity tb_sdram is
end tb_sdram;

architecture behav of tb_sdram is
    constant CLK_PERIOD : time := 10 ns; -- 100 MHz
    -- Most real RAM has a much larger powerup time. But that makes the
    -- simulation waveforms harder to read.
    constant powerup_time : time := 50 * CLK_PERIOD;

    signal axi_awvalid : std_logic;
    signal axi_awready : std_logic;
    signal axi_awaddr  : std_logic_vector(31 downto 0);
    signal axi_awprot  : std_logic_vector(2 downto 0);
    signal axi_wvalid  : std_logic;
    signal axi_wready  : std_logic;
    signal axi_wdata   : std_logic_vector(15 downto 0);
    signal axi_wstrb   : std_logic_vector(1 downto 0);
    signal axi_bvalid  : std_logic;
    signal axi_bready  : std_logic;
    signal axi_bresp   : std_logic_vector(1 downto 0);
    signal axi_arvalid : std_logic;
    signal axi_arready : std_logic;
    signal axi_araddr  : std_logic_vector(31 downto 0);
    signal axi_arprot  : std_logic_vector(2 downto 0);
    signal axi_rvalid  : std_logic;
    signal axi_rready  : std_logic;
    signal axi_rdata   : std_logic_vector(15 downto 0);
    signal axi_rresp   : std_logic_vector(1 downto 0);

    signal clk   : std_logic;
    signal cke   : std_logic;
    signal cs_l  : std_logic;
    signal cas_l : std_logic;
    signal ras_l : std_logic;
    signal we_l  : std_logic;
    signal dqml  : std_logic;
    signal dqmh  : std_logic;
    signal ba    : std_logic_vector(1  downto 0);
    signal a     : std_logic_vector(12 downto 0);
    signal dq    : std_logic_vector(15 downto 0);
    signal arst  : std_logic;

    signal stop : boolean := false;
begin
    sim_sdram_0: entity work.sim_sdram
    generic map(
        required_power_on_wait => powerup_time
    )
    port map (
        clk        => clk,
        cke        => cke,
        cs_l       => cs_l,
        cas_l      => cas_l,
        ras_l      => ras_l,
        we_l       => we_l,
        dqml       => dqml,
        dqmh       => dqmh,
        ba         => ba,
        a          => a,
        dq         => dq,
        arst_model => arst
    );

    basic_sdram_0: entity work.basic_sdram
    generic map(
        clk_period => CLK_PERIOD,
        required_power_on_wait => powerup_time
    )
    port map (
        clk         => clk,
        arst        => arst,
        axi_awvalid => axi_awvalid,
        axi_awready => axi_awready,
        axi_awaddr  => axi_awaddr,
        axi_awprot  => axi_awprot,
        axi_wvalid  => axi_wvalid,
        axi_wready  => axi_wready,
        axi_wdata   => axi_wdata,
        axi_wstrb   => axi_wstrb,
        axi_bvalid  => axi_bvalid,
        axi_bready  => axi_bready,
        axi_bresp   => axi_bresp,
        axi_arvalid => axi_arvalid,
        axi_arready => axi_arready,
        axi_araddr  => axi_araddr,
        axi_arprot  => axi_arprot,
        axi_rvalid  => axi_rvalid,
        axi_rready  => axi_rready,
        axi_rdata   => axi_rdata,
        axi_rresp   => axi_rresp,
        cke         => cke,
        cs_l        => cs_l,
        cas_l       => cas_l,
        ras_l       => ras_l,
        we_l        => we_l,
        dqml        => dqml,
        dqmh        => dqmh,
        ba          => ba,
        a           => a,
        dq_o        => dq,
        dq_i        => dq,
        dq_oe       => open
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

        axi_write_word(
            (others => '0'),
            std_logic_vector(to_unsigned(42, 16)),
            CLK_PERIOD * 20,
            clk,
            axi_awvalid,
            axi_awready,
            axi_awaddr,
            axi_awprot,
            axi_wvalid,
            axi_wready,
            axi_wdata,
            axi_wstrb,
            axi_bvalid,
            axi_bready,
            axi_bresp
        );

        wait for CLK_PERIOD * 100;
        stop <= true;
        wait;
    end process stimulus;
end behav;
