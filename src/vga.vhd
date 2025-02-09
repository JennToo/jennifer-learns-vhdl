library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.graphics.all;
use work.math.all;

entity vga is
    generic (
        -- Default resolution 640x480@60Hz
        -- Requires a pixel clock at 25.175 MHz
        horizontal_pixels : integer := 640;
        vertical_pixels   : integer := 480;

        hsync_front_porch : integer   := 16;
        hsync_sync_pulse  : integer   := 96;
        hsync_back_porch  : integer   := 48;
        hsync_polarity    : std_logic := '1';

        vsync_front_porch : integer   := 10;
        vsync_sync_pulse  : integer   := 2;
        vsync_back_porch  : integer   := 33;
        vsync_polarity    : std_logic := '1'
    );
    port(
        clk  : in std_logic;
        arst : in std_logic;

        pixel_i : in  wide_pixel_t;
        pixel_o : out wide_pixel_t;

        hsync     : out std_logic;
        vsync     : out std_logic;
        hblank    : out std_logic;
        vblank    : out std_logic;
        pixel_clk : out std_logic
    );
end entity vga;

architecture rtl of vga is
    constant hblank_region : integer := (
        hsync_back_porch + hsync_sync_pulse + hsync_front_porch
    );
    constant vblank_region : integer := (
        vsync_back_porch + vsync_sync_pulse + vsync_front_porch
    );
    constant hmax         : integer := horizontal_pixels + hblank_region;
    constant vmax         : integer := vertical_pixels   + vblank_region;
    constant htimer_width : integer := clog2(hmax);
    constant vtimer_width : integer := clog2(vmax);

    signal htimer : unsigned(htimer_width - 1 downto 0) := to_unsigned(0, htimer_width);
    signal vtimer : unsigned(vtimer_width - 1 downto 0) := to_unsigned(0, vtimer_width);
    signal black  : wide_pixel_t;
begin
    hblank      <= '1' when htimer < hblank_region else '0';
    vblank      <= '1' when vtimer < vblank_region else '0';
    black.red   <= (others => '0');
    black.green <= (others => '0');
    black.blue  <= (others => '0');
    pixel_o     <= pixel_i when hblank = '0' and vblank = '0' else black;
    -- TODO: We might support integer ratios in the future
    pixel_clk   <= clk;

    hsync <= not hsync_polarity when htimer >= hsync_front_porch and
                                     htimer < hsync_front_porch + hsync_sync_pulse
             else hsync_polarity;
    vsync <= not vsync_polarity when vtimer >= vsync_front_porch and
                                     vtimer < vsync_front_porch + vsync_sync_pulse
             else vsync_polarity;

    timers: process(clk, arst) is
    begin
        if (arst = '0') then
            htimer <= to_unsigned(0, htimer_width);
            vtimer <= to_unsigned(0, vtimer_width);
        elsif rising_edge(clk) then
            if (htimer < hmax) then
                htimer <= htimer + 1;
            else
                htimer <= to_unsigned(0, htimer_width);
                if (vtimer < vmax) then
                    vtimer <= vtimer + 1;
                else
                    vtimer <= to_unsigned(0, vtimer_width);
                end if;
            end if;
        end if;
    end process timers;
end rtl;
