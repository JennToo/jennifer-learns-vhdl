library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math.all;

package gpu_pkg is
    constant SCREEN_WIDTH   : natural := 640;
    constant SCREEN_HEIGHT  : natural := 480;
    constant FB_WIDTH       : natural := 320;
    constant FB_HEIGHT      : natural := 240;
    constant FB_WIDTH_LOG2  : natural := clog2(FB_WIDTH);
    constant FB_HEIGHT_LOG2 : natural := clog2(FB_HEIGHT);

    subtype coord_x_t is unsigned(FB_WIDTH_LOG2  - 1 downto 0);
    subtype coord_y_t is unsigned(FB_HEIGHT_LOG2 - 1 downto 0);

    type rasterizer_params_t is record
        e0, e1, e2 : signed(31 downto 0); -- TODO: We don't need this many bits

        x0, y0, x1, y1, x2, y2 : signed(15 downto 0);
        dx0, dy0, dx1, dy1, dx2, dy2 : signed(15 downto 0);

        cursor_x : coord_x_t;
        cursor_y : coord_y_t;
        max_y    : coord_y_t;
    end record rasterizer_params_t;
end package gpu_pkg;
