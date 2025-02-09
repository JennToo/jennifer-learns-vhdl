library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.graphics.all;

entity vga_fifo_reader is
    port(
        clk  : in std_logic;
        arst : in std_logic;

        fifo_empty        : in std_logic;
        fifo_data         : in std_logic_vector(15 downto 0);
        fifo_read_request : out std_logic;

        -- Rising edge exactly 1 clock cycle before an hblank and/or vblank starts
        -- and falling edge exactly 1 clock cycle before a blanking period ends. This
        -- allows data to be grabbed from the FIFO and made available in time
        blanking_soon : in std_logic;
        pixel         : out wide_pixel_t
    );
end entity vga_fifo_reader;

architecture rtl of vga_fifo_reader is
    signal fifo_pixel  : wide_pixel_t;
    signal fifo_read_request_i : std_logic;
begin
    -- Convert from 16-bit to 24-bit color, with RGB-565 scheme
    fifo_pixel.red   <= fifo_data(15 downto 11) & "000";
    fifo_pixel.green <= fifo_data(10 downto  5) & "00";
    fifo_pixel.blue  <= fifo_data( 4 downto  0) & "000";

    fifo_read_request <= fifo_read_request_i;

    process(clk, arst) is
    begin
        if (arst = '0') then
            pixel <= c_fault_wide_pixel;
            fifo_read_request_i <= '0';
        elsif (rising_edge(clk)) then
            -- If we requested a pixel last cycle, send it out. Otherwise, send fault.
            if (fifo_read_request_i = '1') then
                pixel <= fifo_pixel;
            else
                -- This should never be visible, since the blanking logic will
                -- filter out whatever we send
                pixel <= c_fault_wide_pixel;
            end if;

            -- Determine if we should request a pixel for the next cycle
            if (blanking_soon = '1') then
                fifo_read_request_i <= '0';
            else
                -- This shouldn't happen under normal operation. It shouldn't
                -- even happen at boot-up, since we start at the beginning of a
                -- VSYNC interval on reset
                if (fifo_empty = '1') then
                    fifo_read_request_i <= '0';
                    assert false
                        report "VGA FIFO is empty, this should not happen"
                        severity error;
                else
                    fifo_read_request_i <= '1';
                end if;
            end if;
        end if;
    end process;
end rtl;
