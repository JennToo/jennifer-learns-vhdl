library ieee;
use ieee.std_logic_1164.all;

package graphics is
    type pixel_t is record
        red   : std_logic_vector(7 downto 0);
        green : std_logic_vector(7 downto 0);
        blue  : std_logic_vector(7 downto 0);
    end record pixel_t;
end package graphics;
