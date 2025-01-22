library ieee;
use ieee.std_logic_1164.all;

entity sim_fifo is
    generic (
        element_width      : integer := 16;
        element_count      : integer := 64;
        element_count_log2 : integer := 6
    );
	port
	(
        arst          : in std_logic;

		write_clk     : in std_logic;
		write_request : in std_logic;
		write_data    : in std_logic_vector(element_width-1 downto 0);
		write_full    : out std_logic;
		write_used    : out std_logic_vector(element_count_log2-1 downto 0);

		read_clk      : in std_logic;
		read_request  : in std_logic;
		read_data     : out std_logic_vector(15 downto 0);
		read_empty    : out std_logic
	);
end sim_fifo;

architecture behave of sim_fifo is
    type memory_array is array (0 to element_count) of std_logic_vector(element_width-1 downto 0);

    signal memory         : memory_array;
    signal read_head      : integer;
    signal write_head     : integer;
begin

    process(write_clk, read_clk, arst)
    begin
        if (arst = '0') then
            read_head  <= 0;
            write_head <= 0;
        else
            if (rising_edge(write_clk)) then
                if (write_request = '1') then
                    memory(write_head) <= write_data;
                    if (write_head = element_count-1) then
                        write_head <= 0;
                    else
                        write_head <= write_head + 1;
                    end if;
                end if;
            end if;
            if (rising_edge(read_clk)) then
                if (read_request = '1') then
                    read_data <= memory(read_head);
                    if (read_head = element_count-1) then
                        read_head <= 0;
                    else
                        read_head <= read_head + 1;
                    end if;
                else
                    read_data <= (others => 'U');
                end if;
            end if;
        end if;
    end process;

end behave;
