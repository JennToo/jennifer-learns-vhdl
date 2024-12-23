library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- A simulated SDRAM chip. Based on the MT48LC32M16 datasheet since that's what
-- the ULX3S uses.
entity sim_sdram is
    port(
        clk   : in    std_logic;
        cke   : in    std_logic;
        cs_l  : in    std_logic;
        cas_l : in    std_logic;
        ras_l : in    std_logic;
        we_l  : in    std_logic;
        dqml  : in    std_logic_vector(7 downto 0);
        dqmh  : in    std_logic_vector(7 downto 0);
        ba    : in    std_logic_vector(1 downto 0);
        a     : in    std_logic_vector(12 downto 0);
        dq    : inout std_logic_vector(15 downto 0);

        -- The real chip doesn't have a reset, but it can be useful to reset
        -- the model to simulate power-up
        arst_model : in std_logic
    );
end sim_sdram;

architecture behav of sim_sdram is
    -- Real chip has 32 MiB, 16-bit words. But if we do that, the simulator will crash
    constant word_count             : integer := 65536;
    constant required_power_on_wait : time    := 100 us;

    type memory_array is array (1 to word_count) of std_logic_vector(15 downto 0);
    type powerup_state_t is (
        powerup_want_wait,
        powerup_want_precharge,
        powerup_want_refresh1,
        powerup_want_refresh2,
        powerup_want_lmr,
        powerup_ready
    );
    type command_t is (
        command_nop,
        command_active,
        command_read,
        command_write,
        command_burst_terminate,
        command_precharge,
        command_refresh,
        command_load_mode_reg
    );

    signal memory        : memory_array;
    signal power_on_time : time            := 0 ns;
    signal powerup_state : powerup_state_t := powerup_want_wait;

    function get_command(
        f_cs_l  : in std_logic;
        f_cas_l : in std_logic;
        f_ras_l : in std_logic;
        f_we_l  : in std_logic
    ) return command_t is
        variable concat : std_logic_vector(2 downto 0) := f_cas_l & f_ras_l & f_we_l;
    begin
        if (f_cs_l = '1') then
            return command_nop;
        else
            case concat is
                when "111" =>
                    return command_nop;
                when "011" =>
                    return command_active;
                when "101" =>
                    return command_read;
                when "100" =>
                    return command_write;
                when "110" =>
                    return command_burst_terminate;
                when "010" =>
                    return command_precharge;
                when "001" =>
                    return command_refresh;
                when "000" =>
                    return command_load_mode_reg;
                when others =>
                    assert false report "unsupported command" severity error;
            end case;
        end if;
    end function get_command;
begin
    powerup: process(clk, arst_model)
        variable command : command_t;
    begin
        if (arst_model = '0') then
            power_on_time <= now;
            powerup_state <= powerup_want_wait;
            for word in 0 to word_count loop
                memory(word) <= "UUUUUUUUUUUUUUUU";
            end loop;
        elsif (rising_edge(clk) and cke = '1') then
            command := get_command(cs_l, ras_l, cas_l, we_l);

            -- Walk through and assert the powerup process
            case (powerup_state) is
                when powerup_want_wait =>
                    assert command = command_nop report "in wait period for power up, no cmds allowed yet" severity error;
                    if (power_on_time - now >= required_power_on_wait) then
                        -- TODO: There's more states actually lol
                        powerup_state <= powerup_want_precharge;
                    end if;
                when powerup_want_precharge =>
                    assert command = command_precharge report "expecting precharge" severity error;
                    -- TODO: verify it's precharge-all specifically
                    powerup_state <= powerup_want_refresh1;
                when powerup_want_refresh1 =>
                    assert command = command_refresh report "expecting refresh" severity error;
                    powerup_state <= powerup_want_refresh2;
                when powerup_want_refresh2 =>
                    assert command = command_refresh report "expecting refresh" severity error;
                    powerup_state <= powerup_want_lmr;
                when powerup_want_lmr =>
                    assert command = command_refresh report "expecting lmr" severity error;
                    powerup_state <= powerup_ready;
                when powerup_ready =>
                    -- Don't care
            end case;
        end if;
    end process powerup;
end behav;
