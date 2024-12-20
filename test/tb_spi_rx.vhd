library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity tb_spi_rx is
end tb_spi_rx;

architecture behav of tb_spi_rx is
    component spi_rx
        port (
            clk        : in std_logic;
            srst       : in std_logic;
            enable     : in std_logic;

            spi_clk    : in std_logic;
            spi_mosi   : in std_logic;
            
            data_out   : out std_logic_vector(7 downto 0);
            data_ready : out std_logic
        );
    end component;

    for spi_rx_0: spi_rx use entity work.spi_rx;

    signal clk        : std_logic;
    signal srst       : std_logic;
    signal enable     : std_logic;
    signal spi_clk    : std_logic;
    signal spi_mosi   : std_logic;
    signal data_out   : std_logic_vector(7 downto 0);
    signal data_ready : std_logic;
begin
    spi_rx_0: spi_rx port map (
        clk        => clk,
        srst       => srst,
        enable     => enable,
        spi_clk    => spi_clk,
        spi_mosi   => spi_mosi,
        data_out   => data_out,
        data_ready => data_ready
    );

    -- clk <= '0', not clk after 1 ns;
    enable <= '1';

    clocker: process begin
        clk <= '0';
        wait for 1 ns;
        clk <= '1';
        wait for 1 ns;
    end process clocker;

    stimulus: process begin
        srst <= '0';
        spi_clk <= '0';
        spi_mosi <= '0';
        wait until falling_edge(clk) for 5 ns;

        assert data_ready = '0' report "data should not be ready yet" severity error;

        srst <= '1';
        wait until falling_edge(clk) for 5 ns;

        -- Clock in the first 7 bits
        for ii in 0 to 6 loop
            spi_mosi <= not spi_mosi;
            wait for 5 ns;
            assert data_ready = '0' report "data should not be ready yet" severity error;
            spi_clk <= '1';
            wait for 5 ns;
            assert data_ready = '0' report "data should not be ready yet" severity error;
            spi_clk <= '0';
            wait for 5 ns;
            assert data_ready = '0' report "data should not be ready yet" severity error;
        end loop;

        -- Clock in the last bit
        spi_mosi <= not spi_mosi;
        wait for 5 ns;
        assert data_ready = '0' report "data should not be ready yet" severity error;
        spi_clk <= '1';
        wait for 5 ns;
        assert data_ready = '1' report "data should be ready now" severity error;
        assert data_out = "01010101" report "data is wrong" severity error;

        -- Trigger the start of the next byte
        spi_clk <= '0';
        wait for 5 ns;
        spi_clk <= '1';
        wait for 5 ns;
        assert data_ready = '0' report "data should not be ready anymore" severity error;

        assert false report "end of test" severity note;
        wait;
    end process stimulus;
end behav;
