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
    signal next_bit : std_logic;
begin
    --next_bit <= value(15) xor value(13) xor value(12) xor value(10) xor value(0);
    --next_bit <= value(0) xor value(10) xor value(12) xor value(13) xor value(15);
    --next_bit <= value(0) xor value(2) xor value(3) xor value(5);
    next_bit <= value(5) xor value(3) xor value(2) xor value(0);

    shifter: process(clk, arst) begin
        if (arst = '0') then
            value <= seed;
        elsif (rising_edge(clk)) then
            value <= value srl 1;
            value(15) <= next_bit;
        end if;
    end process shifter;
end rtl;
