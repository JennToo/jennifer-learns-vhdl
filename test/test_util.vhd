library ieee;
   use ieee.std_logic_1164.all;

package test_util is
    procedure axi_write_word(
        constant addr    : in std_logic_vector(31 downto 0);
        constant data    : in std_logic_vector(15 downto 0);
        constant timeout : in time;

        signal clk         : std_logic;
        signal axi_awvalid : out std_logic;
        signal axi_awready : in  std_logic;
        signal axi_awaddr  : out std_logic_vector(31 downto 0);
        signal axi_awprot  : out std_logic_vector(2 downto 0);
        signal axi_wvalid  : out std_logic;
        signal axi_wready  : in  std_logic;
        signal axi_wdata   : out std_logic_vector(15 downto 0);
        signal axi_wstrb   : out std_logic_vector(1 downto 0);
        signal axi_bvalid  : in  std_logic;
        signal axi_bready  : out std_logic;
        signal axi_bresp   : in  std_logic_vector(1 downto 0)
    );
end package test_util;

package body test_util is
    procedure axi_write_word(
        constant addr    : in std_logic_vector(31 downto 0);
        constant data    : in std_logic_vector(15 downto 0);
        constant timeout : in time;

        signal clk         : std_logic;
        signal axi_awvalid : out std_logic;
        signal axi_awready : in  std_logic;
        signal axi_awaddr  : out std_logic_vector(31 downto 0);
        signal axi_awprot  : out std_logic_vector(2 downto 0);
        signal axi_wvalid  : out std_logic;
        signal axi_wready  : in  std_logic;
        signal axi_wdata   : out std_logic_vector(15 downto 0);
        signal axi_wstrb   : out std_logic_vector(1 downto 0);
        signal axi_bvalid  : in  std_logic;
        signal axi_bready  : out std_logic;
        signal axi_bresp   : in  std_logic_vector(1 downto 0)
    ) is
    begin
        wait until falling_edge(clk);
        -- TODO; we are not allowed to wait for ready yet, need to set valid first
        wait until axi_awready = '1' for timeout;
        -- assert axi_awready = '1' report "axi_awready not ready" severity failure;
    end procedure axi_write_word;
end package body test_util;
