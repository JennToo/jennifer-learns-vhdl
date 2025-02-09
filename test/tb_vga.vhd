library std;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;

use work.graphics.all;

entity tb_vga is
end tb_vga;

architecture behave of tb_vga is
    -- 25.175 MHz
    constant CLK_PERIOD : time := 39.72194638 ns;
    constant epsilon    : time := 1 ns;

    -- Timing data from http://tinyvga.com/vga-timing/640x480@60Hz
    constant hsync_pulse : time  := 3.8133068520357 us;
    constant vsync_pulse : time  := 0.063555114200596 ms;

    signal clk  : std_logic;
    signal arst : std_logic;

    signal pixel_i : wide_pixel_t;
    signal pixel_o : wide_pixel_t;

    signal hsync     : std_logic;
    signal vsync     : std_logic;
    signal hblank    : std_logic;
    signal vblank    : std_logic;
    signal pixel_clk : std_logic;

    signal last_hsync : std_logic;
    signal last_vsync : std_logic;
    signal hsync_start : time;
    signal vsync_start : time;

    signal r_fifo_empty   : std_logic;
    signal r_fifo_data    : std_logic_vector(15 downto 0);
    signal r_fifo_request : std_logic;

    signal blanking_soon : std_logic;
begin
    clk <= not clk after CLK_PERIOD / 2;

    vga_0: entity work.vga
    port map (
        clk       => clk,
        arst      => arst,
        pixel_i   => pixel_i,
        pixel_o   => pixel_o,
        hsync     => hsync,
        vsync     => vsync,
        hblank    => hblank,
        vblank    => vblank,
        pixel_clk => pixel_clk
    );

    vga_fifo_reader_0: entity work.vga_fifo_reader
    port map(
        clk               => clk,
        arst              => arst,
        fifo_empty        => r_fifo_empty,
        fifo_data         => r_fifo_data,
        fifo_read_request => r_fifo_request,
        blanking_soon     => blanking_soon,
        pixel             => pixel_i
    );

    sync_verification: process(clk, arst) is
        variable time_difference : time;
    begin
        if (arst = '0') then
            last_hsync <= '1';
            last_vsync <= '1';
        elsif rising_edge(clk) then
            if (hsync = '0' and last_hsync = '1') then
                hsync_start <= now;
            end if;
            if (hsync = '1' and last_hsync = '0') then
                time_difference := now - hsync_start;
                assert time_difference - hsync_pulse < epsilon
                    report "Invalid HSYNC pulse length " & time'image(time_difference)
                    severity error;
            end if;
            if (vsync = '0' and last_vsync = '1') then
                hsync_start <= now;
            end if;
            if (vsync = '1' and last_vsync = '0') then
                time_difference := now - vsync_start;
                assert time_difference - vsync_pulse < epsilon
                    report "Invalid VSYNC pulse length " & time'image(time_difference)
                    severity error;
            end if;
            last_hsync <= hsync;
            last_vsync <= vsync;
        end if;
    end process sync_verification;

    stimulus: process
    begin
        arst <= '0';
        wait for 1 ns;
        arst <= '1';

        -- A bit over 2 frames
        wait for 35 ms;

        finish;
    end process stimulus;
end behave;
