library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math.all;

entity gpu is
    port (
        clk  : in std_logic;
        arst : in std_logic;

        sram_address      : out std_logic_vector(19 downto 0);
        sram_write_data   : out std_logic_vector(15 downto 0);
        sram_read_data    : in  std_logic_vector(15 downto 0);
        sram_write_enable : out std_logic
    );
end gpu;

architecture rtl of gpu is
    signal sram_address_i      : std_logic_vector(19 downto 0);
    signal sram_write_data_i   : std_logic_vector(15 downto 0);
    signal sram_write_enable_i : std_logic;

    signal clear_enable : std_logic;
begin
    sram_address      <= sram_address_i;
    sram_write_enable <= sram_write_enable_i;
    sram_write_data   <= sram_write_data_i;

    clear_enable <= '1';

    U_clear : entity work.clear
    port map (
        clk               => clk,
        clk_en            => clear_enable,
        arst              => arst,
        sram_address      => sram_address_i,
        sram_write_data   => sram_write_data_i,
        sram_write_enable => sram_write_enable_i
    );
        
end rtl;
