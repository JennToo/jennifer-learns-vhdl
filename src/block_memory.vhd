library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity block_memory is
    generic (
        word_size     : integer := 32;
        elements      : integer := 32;
        address_width : integer := 5
    );
    port(
        clk       : in  std_logic;
        address   : in  std_logic_vector(address_width - 1 downto 0);
        data_i    : in  std_logic_vector(word_size - 1 downto 0);
        data_o    : out std_logic_vector(word_size - 1 downto 0);
        rd_0_wr_1 : in  std_logic
    );
end block_memory;

architecture rtl of block_memory is
    type memory_array is array (0 to elements) of std_logic_vector(word_size - 1 downto 0);

    signal memory : memory_array;
begin
    process(clk) is
    begin
        if rising_edge(clk) then
            if (rd_0_wr_1 = '0') then
                data_o <= memory(to_integer(unsigned(address)));
            elsif (rd_0_wr_1 = '1') then
                memory(to_integer(unsigned(address))) <= data_i;
            end if;
        end if;
    end process;
end rtl;
