library std;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_spi_rx is
end tb_spi_rx;

architecture behav of tb_spi_rx is
    constant CLK_PERIOD     : time := 2 ns;
    constant SPI_CLK_PERIOD : time := 10 ns;

    signal clk        : std_logic := '0';
    signal srst       : std_logic;
    signal enable     : std_logic;
    signal spi_clk    : std_logic;
    signal spi_mosi   : std_logic;
    signal data_out   : std_logic_vector(7 downto 0);
    signal data_ready : std_logic;
begin
    clk <= not clk after CLK_PERIOD / 2;

    spi_rx_0: entity work.spi_rx port map (
        clk        => clk,
        srst       => srst,
        enable     => enable,
        spi_clk    => spi_clk,
        spi_mosi   => spi_mosi,
        data_out   => data_out,
        data_ready => data_ready
    );

    enable <= '1';

    stimulus: process begin
        srst <= '0';
        spi_clk <= '0';
        spi_mosi <= '0';
        wait until falling_edge(clk);

        assert data_ready = '0' report "data should not be ready yet" severity error;

        srst <= '1';
        wait until falling_edge(clk);

        -- Clock in the first 7 bits
        for ii in 0 to 6 loop
            spi_mosi <= not spi_mosi;
            wait for SPI_CLK_PERIOD / 2;
            assert data_ready = '0' report "data should not be ready yet" severity error;
            spi_clk <= '1';
            wait for SPI_CLK_PERIOD / 2;
            assert data_ready = '0' report "data should not be ready yet" severity error;
            spi_clk <= '0';
            wait for SPI_CLK_PERIOD / 2;
            assert data_ready = '0' report "data should not be ready yet" severity error;
        end loop;

        -- Clock in the last bit
        spi_mosi <= not spi_mosi;
        wait for SPI_CLK_PERIOD / 2;
        assert data_ready = '0' report "data should not be ready yet" severity error;
        spi_clk <= '1';
        wait for SPI_CLK_PERIOD / 2;
        assert data_ready = '1' report "data should be ready now" severity error;
        assert data_out = "01010101" report "data is wrong" severity error;

        -- Trigger the start of the next byte
        spi_clk <= '0';
        wait for SPI_CLK_PERIOD / 2;
        spi_clk <= '1';
        wait for SPI_CLK_PERIOD / 2;
        assert data_ready = '0' report "data should not be ready anymore" severity error;

        finish;
    end process stimulus;
end behav;
