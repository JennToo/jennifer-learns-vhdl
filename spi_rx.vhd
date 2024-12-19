library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- A byte-oriented CPOL=0 CPHA=0 client SPI receiver. data_ready will be
-- asserted for at least one cycle of clk whenever a new full byte is received
entity spi_rx is
    port(
        clk        : in std_logic;
        srst       : in std_logic;
        enable     : in std_logic;

        spi_clk    : in std_logic;
        spi_mosi   : in std_logic;
        
        data_out   : out std_logic_vector(7 downto 0);
        data_ready : out std_logic
    );
end spi_rx;

architecture rtl of spi_rx is
    signal bit_counter  : unsigned(2 downto 0);
    signal last_spi_clk : std_logic;
begin
    receive : process(clk) 
    begin
        if (clk'event and clk = '1') then
            if (srst = '0') then
                last_spi_clk <= '0';
                bit_counter  <= (others => '0');
                data_out     <= (others => '0');
                data_ready   <= '0';
            elsif (enable = '0') then
                -- Do nothing if disabled
            else
                -- Sample on rising edge of spi_clk, CPOL=0 CPHA=0
                if (spi_clk = '1' and last_spi_clk /= spi_clk) then
                    -- TODO: Is indexing into data_out more or less efficient
                    --       than making it a shift register? Maybe the tools
                    --       are smart enough to figure that out for us
                    data_out(to_integer(bit_counter)) <= spi_mosi;

                    if (bit_counter = 7) then
                        bit_counter <= (others => '0');
                        data_ready  <= '1';
                    else
                        bit_counter <= bit_counter + 1;
                        data_ready  <= '0';
                    end if;
                end if;
                last_spi_clk <= spi_clk;
            end if;
        end if;
    end process receive;
end architecture;
