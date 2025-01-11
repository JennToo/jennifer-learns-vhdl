library ieee;
   use ieee.std_logic_1164.all;

entity lfsr_16 is
    generic (
        seed : std_logic_vector(15 downto 0) := (others => '1')
    );
    port (
        clk   : in std_logic;
        arst  : in std_logic;
        value : out std_logic_vector(15 downto 0)
    );
end lfsr_16;

architecture rtl of lfsr_16 is
    signal next_bit  : std_logic;
    signal out_value : std_logic_vector(15 downto 0);
begin
    next_bit <= out_value(5) xor out_value(3) xor out_value(2) xor out_value(0);
    value <= out_value;

    shifter: process(clk, arst) begin
        if (arst = '0') then
            out_value <= seed;
        elsif (rising_edge(clk)) then
            out_value <= out_value srl 1;
            out_value(15) <= next_bit;
        end if;
    end process shifter;
end rtl;
