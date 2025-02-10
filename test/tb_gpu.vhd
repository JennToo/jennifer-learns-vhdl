library std;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_gpu is
end tb_gpu;

architecture behave of tb_gpu is
    constant CLK_PERIOD : time    := 10 ns; -- 100 MHz

    constant CMD_NONE      : integer := 0;
    constant CMD_STEP_ONE  : integer := 1;
    constant CMD_STEP_MANY : integer := 2;
    constant CMD_FINISH    : integer := 3;

    signal clk : std_logic;

    procedure gpu_framebuffer_write(x: integer; y: integer; color: integer) is
    begin
    end procedure gpu_framebuffer_write;
    attribute foreign of gpu_framebuffer_write : procedure is "VHPIDIRECT gpu_framebuffer_write";

    function handle_event return integer is
    begin
    end function handle_event;
    attribute foreign of handle_event : function is "VHPIDIRECT handle_event";
begin
    clk <= not clk after CLK_PERIOD / 2;

    stimulus: process
        variable event : integer := CMD_NONE;
    begin
        report "Hello linking/bind!" severity note;
        wait for 10 * CLK_PERIOD;

        while (event /= CMD_FINISH) loop
            event := handle_event;
            case (event) is
                when CMD_STEP_ONE =>
                    -- TODO: Drive this from the real logic
                    gpu_framebuffer_write(0, 0, 0);
                when others =>
            end case;
        end loop;
        finish;
    end process stimulus;
end architecture behave;
