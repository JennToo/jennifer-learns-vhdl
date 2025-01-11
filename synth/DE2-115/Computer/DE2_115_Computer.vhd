library ieee;
use ieee.std_logic_1164.all;

entity DE2_115_Computer is
    port (
        CLOCK_50   : in  std_logic;
        CLOCK2_50  : in  std_logic;
        CLOCK3_50  : in  std_logic;
        SMA_CLKIN  : in  std_logic;
        SMA_CLKOUT : out std_logic;

        KEY   : in    std_logic_vector(3 downto 0);
        SW    : in    std_logic_vector(17 downto 0);
        LEDG  : out   std_logic_vector(8  downto 0);
        LEDR  : out   std_logic_vector(17 downto 0);
        HEX0  : out   std_logic_vector(6 downto 0);
        HEX1  : out   std_logic_vector(6 downto 0);
        HEX2  : out   std_logic_vector(6 downto 0);
        HEX3  : out   std_logic_vector(6 downto 0);
        HEX4  : out   std_logic_vector(6 downto 0);
        HEX5  : out   std_logic_vector(6 downto 0);
        HEX6  : out   std_logic_vector(6 downto 0);
        HEX7  : out   std_logic_vector(6 downto 0);

        EX_IO : inout std_logic_vector(6 downto 0);

        LCD_BLON : out   std_logic;
        LCD_DATA : inout std_logic_vector(7 downto 0);
        LCD_EN   : out   std_logic;
        LCD_ON   : out   std_logic;
        LCD_RS   : out   std_logic;
        LCD_RW   : out   std_logic;

        UART_CTS : in  std_logic;
        UART_RTS : out std_logic;
        UART_RXD : in  std_logic;
        UART_TXD : out std_logic;

        PS2_CLK  : inout std_logic;
        PS2_CLK2 : inout std_logic;
        PS2_DAT  : inout std_logic;
        PS2_DAT2 : inout std_logic;

        SD_CLK  : out   std_logic;
        SD_CMD  : inout std_logic;
        SD_DAT  : inout std_logic_vector(3 downto 0);
        SD_WP_N : in    std_logic;

        VGA_CLK     : out std_logic;
        VGA_HS      : out std_logic;
        VGA_VS      : out std_logic;
        VGA_BLANK_N : out std_logic;
        VGA_SYNC_N  : out std_logic;
        VGA_R       : out std_logic_vector(7 downto 0);
        VGA_G       : out std_logic_vector(7 downto 0);
        VGA_B       : out std_logic_vector(7 downto 0);

        AUD_ADCDAT  : in    std_logic;
        AUD_ADCLRCK : inout std_logic;
        AUD_BCLK    : inout std_logic;
        AUD_DACDAT  : out   std_logic;
        AUD_DACLRCK : inout std_logic;
        AUD_XCK     : out   std_logic;

        EEP_I2C_SCLK : out   std_logic;
        EEP_I2C_SDAT : inout std_logic;

        I2C_SCLK : out   std_logic;
        I2C_SDAT : inout std_logic;

        ENET0_GTX_CLK : out   std_logic;
        ENET0_INT_N   : in    std_logic;
        ENET0_LINK100 : in    std_logic;
        ENET0_MDC     : out   std_logic;
        ENET0_MDIO    : inout std_logic;
        ENET0_RST_N   : out   std_logic;
        ENET0_RX_CLK  : in    std_logic;
        ENET0_RX_COL  : in    std_logic;
        ENET0_RX_CRS  : in    std_logic;
        ENET0_RX_DATA : in    std_logic_vector(3 downto 0);
        ENET0_RX_DV   : in    std_logic;
        ENET0_RX_ER   : in    std_logic;
        ENET0_TX_CLK  : in    std_logic;
        ENET0_TX_DATA : out   std_logic_vector(3 downto 0);
        ENET0_TX_EN   : out   std_logic;
        ENET0_TX_ER   : out   std_logic;
        ENETCLK_25    : in    std_logic;

        ENET1_GTX_CLK : out   std_logic;
        ENET1_INT_N   : in    std_logic;
        ENET1_LINK100 : in    std_logic;
        ENET1_MDC     : out   std_logic;
        ENET1_MDIO    : inout std_logic;
        ENET1_RST_N   : out   std_logic;
        ENET1_RX_CLK  : in    std_logic;
        ENET1_RX_COL  : in    std_logic;
        ENET1_RX_CRS  : in    std_logic;
        ENET1_RX_DATA : in    std_logic_vector(3 downto 0);
        ENET1_RX_DV   : in    std_logic;
        ENET1_RX_ER   : in    std_logic;
        ENET1_TX_CLK  : in    std_logic;
        ENET1_TX_DATA : out   std_logic_vector(3 downto 0);
        ENET1_TX_EN   : out   std_logic;
        ENET1_TX_ER   : out   std_logic;

        TD_CLK27   : in  std_logic;
        TD_DATA    : in  std_logic_vector(7 downto 0);
        TD_HS      : in  std_logic;
        TD_RESET_N : out std_logic;
        TD_VS      : in  std_logic;

        OTG_ADDR  : out   std_logic_vector(1 downto 0);
        OTG_CS_N  : out   std_logic;
        OTG_DATA  : inout std_logic_vector(15 downto 0);
        OTG_INT   : in    std_logic;
        OTG_RD_N  : out   std_logic;
        OTG_RST_N : out   std_logic;
        OTG_WE_N  : out   std_logic;

        IRDA_RXD : in std_logic;

        DRAM_ADDR  : out   std_logic_vector(12 downto 0);
        DRAM_BA    : out   std_logic_vector(1 downto 0);
        DRAM_CAS_N : out   std_logic;
        DRAM_CKE   : out   std_logic;
        DRAM_CLK   : out   std_logic;
        DRAM_CS_N  : out   std_logic;
        DRAM_DQ    : inout std_logic_vector(31 downto 0);
        DRAM_DQM   : out   std_logic_vector(3 downto 0);
        DRAM_RAS_N : out   std_logic;
        DRAM_WE_N  : out   std_logic;

        SRAM_ADDR : out   std_logic_vector(19 downto 0);
        SRAM_CE_N : out   std_logic;
        SRAM_DQ   : inout std_logic_vector(15 downto 0);
        SRAM_LB_N : out   std_logic;
        SRAM_OE_N : out   std_logic;
        SRAM_UB_N : out   std_logic;
        SRAM_WE_N : out   std_logic;

        FL_ADDR  : out   std_logic_vector(22 downto 0);
        FL_CE_N  : out   std_logic;
        FL_DQ    : inout std_logic_vector(7 downto 0);
        FL_OE_N  : out   std_logic;
        FL_RST_N : out   std_logic;
        FL_RY    : in    std_logic;
        FL_WE_N  : out   std_logic;
        FL_WP_N  : out   std_logic
    );
end entity DE2_115_Computer;

architecture rtl of DE2_115_Computer is
begin
    LEDG <= "010101100";
    HEX0 <= (others => '0');
    HEX1 <= (others => '0');
    HEX2 <= (others => '0');
    HEX3 <= (others => '0');
    HEX4 <= (others => '0');
    HEX5 <= (others => '0');
    HEX6 <= (others => '0');
    HEX7 <= (others => '0');
end rtl;
