library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math.all;

entity rasterizer is
    generic (
        framebuffer_width  : integer := 320;
        framebuffer_height : integer := 240
    );
    port (
        clk    : in std_logic;
        clk_en : in std_logic;
        arst   : in std_logic;

        pixel_x       : out std_logic_vector(8 downto 0);
        pixel_y       : out std_logic_vector(8 downto 0);
        pixel_visible : out std_logic
    );
end rasterizer;

architecture rtl of rasterizer is
    signal cursor_x : std_logic_vector(8 downto 0);
    signal cursor_y : std_logic_vector(8 downto 0);
begin
    pixel_x <= cursor_x;
    pixel_y <= cursor_y;

    rasterize_p : process (clk, arst) is
    begin
        if (arst = '0') then
            -- TODO
        elsif (rising_edge(clk) and clk_en = '1') then
            -- TODO
        end if;
    end process rasterize_p;
end rtl;
