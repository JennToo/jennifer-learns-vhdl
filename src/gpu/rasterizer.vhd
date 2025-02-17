library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math.all;
use work.gpu_pkg.all;

entity rasterizer is
    port (
        clk    : in std_logic;
        clk_en : in std_logic;
        arst   : in std_logic;

        pixel_x       : out coord_x_t;
        pixel_y       : out coord_y_t;
        pixel_visible : out std_logic
    );
end rasterizer;

architecture rtl of rasterizer is
    signal cursor_x : coord_x_t;
    signal cursor_y : coord_y_t;
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
