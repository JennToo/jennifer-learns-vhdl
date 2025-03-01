library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math.all;
use work.gpu_pkg.all;

entity rasterizer is
    port (
        clk    : in std_logic;
        clk_en : in std_logic;
        arst   : in std_logic;

        start      : in std_logic;
        new_params : in rasterizer_params_t;

        pixel_x       : out coord_x_t;
        pixel_y       : out coord_y_t;
        pixel_visible : out std_logic;
        running       : out std_logic
    );
end rasterizer;

architecture rtl of rasterizer is
    type direction_t is (inc_x, dec_x, inc_y);

    signal next_e0, next_e1, next_e2 : signed(31 downto 0);

    signal params             : rasterizer_params_t;
    signal running_i          : std_logic;
    signal direction          : direction_t;
    signal prev_direction     : direction_t;
    signal seen_first_edge    : std_logic;
    signal traversing_forward : std_logic;
begin
    pixel_x <= params.cursor_x;
    pixel_y <= params.cursor_y;
    running <= running_i;

    pixel_visible <= '1' when (params.e0 >= 0 and params.e1 >= 0 and params.e2 >= 0) else
                     '0';

    direction <= inc_y when (pixel_visible = '0' and seen_first_edge = '1') else
                 inc_x when (traversing_forward = '1') else
                 dec_x;

    with direction select
        next_e0 <= params.e0 + params.dy0 when inc_x,
                   params.e0 - params.dy0 when dec_x,
                   params.e0 - params.dx0 when inc_y;
    with direction select
        next_e1 <= params.e1 + params.dy1 when inc_x,
                   params.e1 - params.dy1 when dec_x,
                   params.e1 - params.dx1 when inc_y;
    with direction select
        next_e2 <= params.e2 + params.dy2 when inc_x,
                   params.e2 - params.dy2 when dec_x,
                   params.e2 - params.dx2 when inc_y;

    rasterize_p : process (clk, arst) is
    begin
        if (arst = '0') then
            running_i <= '0';
        elsif (rising_edge(clk) and clk_en = '1') then
            if (start = '1') then
                params             <= new_params;
                running_i          <= '1';
                seen_first_edge    <= '0';
                traversing_forward <= '1';
            else
                case (direction) is
                    when inc_x =>
                        params.cursor_x <= params.cursor_x + 1;
                    when dec_x =>
                        params.cursor_x <= params.cursor_x - 1;
                    when inc_y =>
                        params.cursor_y <= params.cursor_y + 1;
                        traversing_forward <= not traversing_forward;
                end case;
                params.e0 <= next_e0;
                params.e1 <= next_e1;
                params.e2 <= next_e2;
                prev_direction <= direction;
            end if;
        end if;
    end process rasterize_p;
end rtl;
