library ieee;
use ieee.std_logic_1164.all;
library work;
use work.axi.all;

package test_util is
    procedure axi_write_word(
        constant addr    : in std_logic_vector(31 downto 0);
        constant data    : in std_logic_vector(15 downto 0);
        constant timeout : in time;

        signal clk           : std_logic;
        signal axi_initiator : out axi4l_initiator_signals_t;
        signal axi_target    : in axi4l_target_signals_t
    );
    procedure axi_read_word(
        constant addr    : in std_logic_vector(31 downto 0);
        constant timeout : in time;

        signal clk           : std_logic;
        signal axi_initiator : out axi4l_initiator_signals_t;
        signal axi_target    : in axi4l_target_signals_t;

        variable data        : out std_logic_vector(15 downto 0)
    );
end package test_util;

package body test_util is
    procedure axi_write_word(
        constant addr    : in std_logic_vector(31 downto 0);
        constant data    : in std_logic_vector(15 downto 0);
        constant timeout : in time;

        signal clk           : std_logic;
        signal axi_initiator : out axi4l_initiator_signals_t;
        signal axi_target    : in axi4l_target_signals_t
    ) is
    begin
        wait until rising_edge(clk);
        axi_initiator.awvalid <= '1';
        axi_initiator.awaddr  <= addr;
        axi_initiator.awprot  <= (others => '0');
        axi_initiator.wvalid  <= '1';
        axi_initiator.wdata   <= data;
        if (axi_target.awready /= '1') then
            wait until axi_target.awready = '1' for timeout;
            assert axi_target.awready = '1' report "AXI awready not ready" severity failure;
        end if;
        if (axi_target.wready /= '1') then
            wait until axi_target.wready = '1' for timeout;
            assert axi_target.wready = '1' report "AXI wready not ready" severity failure;
        end if;
        wait until rising_edge(clk);
        axi_initiator.awvalid <= '0';
        axi_initiator.wvalid  <= '0';

        axi_initiator.bready <= '1';
        -- This will always take at least one cycle
        wait until axi_target.bvalid = '1' for timeout;
        assert axi_target.bvalid = '1' report "AXI bvalid not valid" severity failure;
        assert axi_target.bresp = "00" report "AXI bresp not OK" severity failure;
        wait until rising_edge(clk);
        axi_initiator.bready <= '0';

        -- Wait for valid to disappear
        wait until axi_target.bvalid = '0' for timeout;
        assert axi_target.bvalid = '0' report "AXI bvalid still valid" severity failure;
    end procedure axi_write_word;

    procedure axi_read_word(
        constant addr    : in std_logic_vector(31 downto 0);
        constant timeout : in time;

        signal clk           : std_logic;
        signal axi_initiator : out axi4l_initiator_signals_t;
        signal axi_target    : in axi4l_target_signals_t;

        variable data        : out std_logic_vector(15 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        axi_initiator.arvalid <= '1';
        axi_initiator.araddr  <= addr;
        axi_initiator.arprot  <= (others => '0');
        if (axi_target.arready /= '1') then
            wait until axi_target.arready = '1' for timeout;
            assert axi_target.arready = '1' report "AXI arready not ready" severity failure;
        end if;
        wait until rising_edge(clk);
        axi_initiator.arvalid <= '0';

        axi_initiator.rready <= '1';
        -- This will always take at least one cycle
        wait until axi_target.rvalid = '1' for timeout;
        assert axi_target.rvalid = '1' report "AXI rvalid not valid" severity failure;
        assert axi_target.rresp = "00" report "AXI rresp not OK" severity failure;
        data := axi_target.rdata;
        wait until rising_edge(clk);
        axi_initiator.rready <= '0';

        -- Wait for valid to disappear
        wait until axi_target.rvalid = '0' for timeout;
        assert axi_target.rvalid = '0' report "AXI rvalid still valid" severity failure;
    end procedure axi_read_word;
end package body test_util;
