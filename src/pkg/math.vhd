library ieee;
use ieee.math_real.all;

package math is
    function period_to_cycles(period: time; clk_period: time; round_up: boolean)
        return integer;
    function clog2(n: integer)
        return integer;
end package math;

package body math is
    function period_to_cycles(period: time; clk_period: time; round_up: boolean)
        return integer is
    begin
        if (round_up) then
            return integer(ceil(real(period / 1 ps) / real(clk_period / 1 ps)));
        else
            return integer(floor(real(period / 1 ps) / real(clk_period / 1 ps)));
        end if;
    end function period_to_cycles;

    function clog2(n: integer)
        return integer is
    begin
        return integer(ceil(log2(real(n))));
    end function clog2;
end package body math;
