library ieee;
use ieee.std_logic_1164.all;

package graphics is
    type pixel_t is record
        red   : std_logic_vector(4 downto 0);
        green : std_logic_vector(5 downto 0);
        blue  : std_logic_vector(4 downto 0);
    end record pixel_t;

    type wide_pixel_t is record
        red   : std_logic_vector(7 downto 0);
        green : std_logic_vector(7 downto 0);
        blue  : std_logic_vector(7 downto 0);
    end record wide_pixel_t;

    constant c_fault_wide_pixel : wide_pixel_t := (
        red   => (others => '1'),
        green => (others => '0'),
        blue  => (others => '1')
    );

    type cursor_direction_t is (inc_x, dec_x, inc_y);

end package graphics;
