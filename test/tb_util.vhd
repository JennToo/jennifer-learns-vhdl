library work;
use work.math.all;

entity tb_util is
end tb_util;

architecture behave of tb_util is
    constant cycles_10 : integer := period_to_cycles(100 ns, 10 ns, true);
    constant cycles_20 : integer := period_to_cycles(191 ns, 10 ns, true);
    constant cycles_19 : integer := period_to_cycles(191 ns, 10 ns, false);
begin
    stimulus: process begin
        assert cycles_10 = 10 report "cycles_10 should be 10" severity error;
        assert cycles_20 = 20 report "cycles_20 should be 20" severity error;
        assert cycles_19 = 19 report "cycles_19 should be 19" severity error;
        wait;
    end process stimulus;
end behave;
