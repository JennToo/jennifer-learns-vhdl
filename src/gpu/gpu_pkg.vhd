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
end package gpu_pkg;
