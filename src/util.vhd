library ieee;
   use ieee.math_real.all;

package util is
    function period_to_cycles(period: time; clk_period: time)
        return integer;
    function clog2(n: integer)
        return integer;
end package util;

package body util is
    function period_to_cycles(period: time; clk_period: time)
        return integer is
    begin
        return integer(ceil(real(period / 1 ps) / real(clk_period / 1 ps)));
    end function period_to_cycles;

    function clog2(n: integer)
        return integer is
    begin
        return integer(ceil(log2(real(n))));
    end function clog2;
end package body util;
