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

    signal clk  : std_logic;
    signal arst : std_logic;

    signal sram_address      : std_logic_vector(19 downto 0);
    signal sram_write_data   : std_logic_vector(15 downto 0);
    signal sram_read_data    : std_logic_vector(15 downto 0);
    signal sram_write_enable : std_logic;

    procedure sim_sram_write16(word_address : integer; value : integer) is
    begin
    end procedure sim_sram_write16;
    attribute foreign of sim_sram_write16 : procedure is "VHPIDIRECT sim_sram_write16";

    function handle_event return integer is
    begin
    end function handle_event;
    attribute foreign of handle_event : function is "VHPIDIRECT handle_event";

    procedure redraw_framebuffer is
    begin
    end procedure redraw_framebuffer;
    attribute foreign of redraw_framebuffer : procedure is "VHPIDIRECT redraw_framebuffer";
begin
    U_gpu : entity work.gpu
    port map (
        clk  => clk,
        arst => arst,

        sram_address      => sram_address,
        sram_write_data   => sram_write_data,
        sram_read_data    => sram_read_data,
        sram_write_enable => sram_write_enable
    );

    writer_p : process (clk) is
    begin
        if rising_edge(clk) then
            if (sram_write_enable = '1') then
                sim_sram_write16(
                    to_integer(unsigned(sram_address)),
                    to_integer(unsigned(sram_write_data))
                );
            end if;
        end if;
    end process writer_p;

    stimulus_p: process
        variable event : integer := CMD_NONE;
    begin
        arst <= '0';
        wait for CLK_PERIOD;
        arst <= '1';

        while (event /= CMD_FINISH) loop
            event := handle_event;
            case (event) is
                when CMD_STEP_ONE =>
                    clk <= '1';
                    wait for CLK_PERIOD / 2;
                    clk <= '0';
                    wait for CLK_PERIOD / 2;
                    redraw_framebuffer;
                when CMD_STEP_MANY =>
                    for i in 1 to 1000 loop
                        clk <= '1';
                        wait for CLK_PERIOD / 2;
                        clk <= '0';
                        wait for CLK_PERIOD / 2;
                    end loop;
                    redraw_framebuffer;
                when others =>
            end case;
        end loop;
        finish;
    end process stimulus_p;
end architecture behave;
