library ieee;
   use ieee.std_logic_1164.all;
library work;
    use work.util.all;

package test_util is
    procedure axi_write_word(
        constant addr    : in std_logic_vector(31 downto 0);
        constant data    : in std_logic_vector(15 downto 0);
        constant timeout : in time;

        signal clk           : std_logic;
        signal axi_initiator : out axi4l_initiator_signals_t;
        signal axi_target    : in axi4l_target_signals_t
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
        if (axi_target.awready /= '1') then
            wait until axi_target.awready = '1' for timeout;
            assert axi_target.awready = '1' report "AXI awready not ready" severity failure;
        end if;
        wait until rising_edge(clk);

        axi_initiator.wvalid  <= '1';
        axi_initiator.wdata   <= data;
        if (axi_target.wready /= '1') then
            wait until axi_target.wready = '1' for timeout;
            assert axi_target.wready = '1' report "AXI wready not ready" severity failure;
        end if;
        wait until rising_edge(clk);

        -- This will always take at least one cycle
        wait until axi_target.bvalid = '1' for timeout;
        assert axi_target.bvalid = '1' report "AXI bvalid not valid" severity failure;
    end procedure axi_write_word;
end package body test_util;
