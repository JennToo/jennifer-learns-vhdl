library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math.all;

entity clear is
    generic (
        framebuffer_width  : integer := 320;
        framebuffer_height : integer := 240
    );
    port (
        clk    : in std_logic;
        clk_en : in std_logic;
        arst   : in std_logic;

        sram_address      : out std_logic_vector(19 downto 0);
        sram_write_data   : out std_logic_vector(15 downto 0);
        sram_write_enable : out std_logic
    );
end clear;

architecture rtl of clear is
    constant framebuffer_words : integer := framebuffer_width * framebuffer_height;
    constant cursor_width      : integer := clog2(framebuffer_words);
    constant clear_color       : std_logic_vector(15 downto 0) := 16x"CF0B";

    signal sram_address_i      : std_logic_vector(19 downto 0);
    signal sram_write_data_i   : std_logic_vector(15 downto 0);
    signal sram_write_enable_i : std_logic;
    signal cursor              : unsigned(cursor_width-1 downto 0);
begin
    sram_address      <= sram_address_i;
    sram_write_enable <= sram_write_enable_i;
    sram_write_data   <= sram_write_data_i;

    clear_p : process (clk, arst) is
    begin
        if (arst = '0') then
            cursor              <= to_unsigned(0, cursor_width);
            sram_write_enable_i <= '0';
        elsif (rising_edge(clk) and clk_en = '1') then
            if (cursor < to_unsigned(framebuffer_words, cursor_width)) then
                sram_write_data_i   <= clear_color;
                sram_write_enable_i <= '1';
                sram_address_i      <= std_logic_vector(resize(cursor, sram_address_i'length));
                cursor              <= cursor + 1;
            else
                sram_write_enable_i <= '0';
                sram_write_data_i   <= (others => 'U');
            end if;
        end if;
    end process clear_p;
end rtl;
