library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
    use work.util.all;

-- Simple SDRAM controller with no burst support, opens the row for every
-- request and closes it automatically.
entity basic_sdram is
    generic (
        clk_period             : time;
        required_power_on_wait : time := 200 us
    );
    port(
        clk  : in std_logic;
        arst : in std_logic;

        -- AXI-4 Lite signals
        -- Write address
        axi_awvalid : in std_logic;
        axi_awready : out std_logic;
        axi_awaddr  : in std_logic_vector(31 downto 0);
        axi_awprot  : in std_logic_vector(2 downto 0);
        -- Write data
        axi_wvalid : in std_logic;
        axi_wready : out std_logic;
        axi_wdata  : in std_logic_vector(15 downto 0);
        axi_wstrb  : in std_logic_vector(1 downto 0);
        -- Write response
        axi_bvalid : out std_logic;
        axi_bready : in std_logic;
        axi_bresp  : out std_logic_vector(1 downto 0);
        -- Read address
        axi_arvalid : in std_logic;
        axi_arready : out std_logic;
        axi_araddr  : in std_logic_vector(31 downto 0);
        axi_arprot  : in std_logic_vector(2 downto 0);
        -- Read data
        axi_rvalid : out std_logic;
        axi_rready : in std_logic;
        axi_rdata  : out std_logic_vector(15 downto 0);
        axi_rresp  : out std_logic_vector(1 downto 0);

        -- Signals to the chip
        cke   : out std_logic;
        cs_l  : out std_logic;
        cas_l : out std_logic;
        ras_l : out std_logic;
        we_l  : out std_logic;
        dqml  : out std_logic;
        dqmh  : out std_logic;
        ba    : out std_logic_vector(1 downto 0);
        a     : out std_logic_vector(12 downto 0);
        dq_o  : out std_logic_vector(15 downto 0);
        dq_i  : in  std_logic_vector(15 downto 0);
        dq_oe : out std_logic
    );
end basic_sdram;

architecture behave of basic_sdram is
    constant powerup_cycles : integer := period_to_cycles(
        required_power_on_wait, clk_period
    );
    constant powerup_cycles_width : integer := clog2(powerup_cycles);

    signal powerup_counter : unsigned(powerup_cycles_width - 1 downto 0);
begin

    commands: process(clk, arst) is
    begin
        if (arst = '0') then
            powerup_counter <= to_unsigned(powerup_cycles, powerup_cycles_width);
        elsif rising_edge(clk) then
            if powerup_counter /= 0 then
                powerup_counter <= powerup_counter - 1;
                -- TODO: Send NOPs
            end if;
        end if;
    end process commands;

end behave;
